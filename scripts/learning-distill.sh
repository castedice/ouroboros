#!/usr/bin/env bash
# Route learning sources into per-skill stores, distill evidence, and optionally promote gotchas.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

ACTION="${1:-distill}"

usage() {
  echo "Usage: learning-distill.sh [distill|--promote|scope <component-path-or-skill-scope>]" >&2
}

case "$ACTION" in
  distill)
    shift || true
    ;;
  promote | --promote)
    ACTION="promote"
    shift || true
    ;;
  scope)
    shift || true
    ;;
  *)
    usage
    exit 1
    ;;
esac

PROJECT_ROOT="$(learning_project_root)"
LEARNING_DATA_ROOT="$(learning_base_dir)"
LEARNING_TEMPLATE_PATH="$PROJECT_ROOT/templates/core/learned-entry.md"
LEARNING_VERSION="2.3.0"
DEFAULT_HALF_LIFE_DAYS=23
ARCHIVE_THRESHOLD="0.15"
PROMOTION_THRESHOLD="0.55"
PROMOTION_MIN_OCCURRENCES=3
PROMOTION_MIN_TASKS=2
PROMOTION_MIN_SPAN_DAYS=30

declare -A CORE_COMMAND_SCOPE_MAP=(
  ["absorb"]="core/absorption"
  ["brainstorm"]="core/brainstorming"
  ["doctor"]="core/validation"
  ["evaluate"]="core/evaluation"
  ["evolve"]="core/evolution"
  ["generate"]="core/generation"
  ["research"]="core/research"
)
declare -A CORE_AGENT_SCOPE_MAP=(
  ["brainstormer"]="core/brainstorming"
  ["evaluator"]="core/evaluation"
  ["generator"]="core/generation"
  ["reconciler"]="core/routing"
  ["researcher"]="core/research"
)
declare -A CORE_TEMPLATE_SCOPE_MAP=(
  ["agents-md"]="core/generation"
  ["brainstorm-output"]="core/brainstorming"
  ["decision-absorb"]="core/absorption"
  ["decision-evolve"]="core/evolution"
  ["decision-generate"]="core/generation"
  ["decision-upgrade"]="core/general"
  ["evolution-analysis-output"]="core/evolution"
  ["knowledge-entry"]="core/research"
  ["module-scaffold"]="core/generation"
  ["multi-model-report"]="core/routing"
  ["project-detection-patterns"]="core/general"
  ["project-profile-output"]="core/general"
  ["research-analysis-output"]="core/research"
)
declare -A PA_COMMAND_SCOPE_MAP=(
  ["agenda"]="pa/executive-assistance"
  ["ask"]="pa/interviewing"
  ["brief"]="pa/executive-assistance"
  ["capture"]="pa/capture-distillation"
  ["compile"]="pa/content-pipeline"
  ["day"]="pa/executive-assistance"
  ["draft"]="pa/writing"
  ["focus"]="pa/executive-assistance"
  ["heartbeat"]="pa/executive-assistance"
  ["ingest"]="pa/context-assembly"
  ["init"]="pa/context-assembly"
  ["link"]="pa/context-assembly"
  ["reset"]="pa/context-assembly"
  ["review"]="pa/review-and-journaling"
  ["specialist"]="pa/domain-specialization"
  ["steward"]="pa/trust-and-boundaries"
  ["survey"]="pa/interviewing"
)
declare -A PA_AGENT_SCOPE_MAP=(
  ["cartographer"]="pa/personal-ontology"
  ["chief-of-staff"]="pa/executive-assistance"
  ["curator"]="pa/content-pipeline"
  ["librarian"]="pa/vault-modeling"
  ["scribe"]="pa/writing"
  ["sentinel"]="pa/trust-and-boundaries"
  ["weaver"]="pa/context-assembly"
)
declare -A RND_COMMAND_SCOPE_MAP=(
  ["rnd"]="rnd/methodology"
)
declare -A RND_AGENT_SCOPE_MAP=(
  ["collector"]="rnd/methodology"
  ["investigator"]="rnd/methodology"
  ["critic"]="rnd/methodology"
)
declare -A APPENDED_EVENT_MAP=()
declare -A KNOWN_SCOPE_MAP=()
declare -A ROUTED_CURSOR_MAP=()

STATE_JSON=""
LOOKUP_ID=""

log_error() {
  echo "[learning-distill] $*" >&2
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    log_error "jq is required."
    exit 2
  }
}

normalize_text() {
  printf '%s' "${1-}" |
    tr '\r\n' '  ' |
    sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

normalize_token() {
  normalize_text "${1-}" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9._:\/-]+/-/g; s/^-+//; s/-+$//'
}

escape_sed_replacement() {
  printf '%s' "${1-}" | sed -e 's/[\/&]/\\&/g'
}

format_decimal() {
  local raw_value="${1:-0}"
  awk -v value="$raw_value" 'BEGIN { printf "%.3f", value + 0 }'
}

epoch_from_iso() {
  local iso_ts="${1:?Missing timestamp}"
  local compact_ts

  if _learning_epoch_from_iso "$iso_ts" >/dev/null 2>&1; then
    _learning_epoch_from_iso "$iso_ts"
    return 0
  fi

  compact_ts="$(printf '%s' "$iso_ts" | sed -E 's/\.([0-9]+)(Z|[+-][0-9]{2}:[0-9]{2})$/\2/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"

  if date -j -u -f "%Y-%m-%dT%H:%M:%S%z" "$compact_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%S%z" "$compact_ts" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$compact_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$compact_ts" +%s
    return 0
  fi

  return 1
}

days_since_timestamp() {
  local iso_ts="${1:?Missing timestamp}"
  local now_epoch
  local target_epoch

  now_epoch="$(date -u +%s)"
  target_epoch="$(epoch_from_iso "$iso_ts")" || {
    printf '0\n'
    return 0
  }

  awk -v now_epoch="$now_epoch" -v target_epoch="$target_epoch" '
    BEGIN {
      diff = now_epoch - target_epoch
      if (diff < 0) {
        diff = 0
      }
      printf "%.3f", diff / 86400
    }
  '
}

days_between_timestamps() {
  local first_ts="${1:?Missing first timestamp}"
  local last_ts="${2:?Missing last timestamp}"
  local first_epoch
  local last_epoch

  first_epoch="$(epoch_from_iso "$first_ts")" || {
    printf '0\n'
    return 0
  }
  last_epoch="$(epoch_from_iso "$last_ts")" || {
    printf '0\n'
    return 0
  }

  awk -v first_epoch="$first_epoch" -v last_epoch="$last_epoch" '
    BEGIN {
      diff = last_epoch - first_epoch
      if (diff < 0) {
        diff = 0
      }
      printf "%.3f", diff / 86400
    }
  '
}

calc_decay_weight() {
  local days_since="${1:-0}"
  local half_life_days="${2:-$DEFAULT_HALF_LIFE_DAYS}"

  awk -v days_since="$days_since" -v half_life_days="$half_life_days" '
    BEGIN {
      if (days_since < 0) {
        days_since = 0
      }
      if (half_life_days <= 0) {
        half_life_days = 23
      }
      printf "%.3f", exp(log(0.5) * (days_since / half_life_days))
    }
  '
}

calc_effective_confidence() {
  local confidence="${1:-0}"
  local decay_weight="${2:-1}"

  awk -v confidence="$confidence" -v decay_weight="$decay_weight" '
    BEGIN {
      printf "%.3f", confidence * decay_weight
    }
  '
}

float_lt() {
  local left="${1:-0}"
  local right="${2:-0}"

  awk -v left="$left" -v right="$right" 'BEGIN { exit !(left < right) }'
}

float_ge() {
  local left="${1:-0}"
  local right="${2:-0}"

  awk -v left="$left" -v right="$right" 'BEGIN { exit !(left >= right) }'
}

skill_scope_dir() {
  local skill_scope="${1:?Missing skill scope}"
  learning_skill_dir "$skill_scope"
}

skill_events_path() {
  local skill_scope="${1:?Missing skill scope}"
  printf '%s\n' "$(skill_scope_dir "$skill_scope")/events.jsonl"
}

skill_state_path() {
  local skill_scope="${1:?Missing skill scope}"
  printf '%s\n' "$(skill_scope_dir "$skill_scope")/state.json"
}

skill_learned_path() {
  local skill_scope="${1:?Missing skill scope}"
  printf '%s\n' "$(skill_scope_dir "$skill_scope")/learned.md"
}

skill_gotchas_path() {
  local skill_scope="${1:?Missing skill scope}"
  printf '%s\n' "$(skill_scope_dir "$skill_scope")/gotchas.md"
}

mark_scope_known() {
  local skill_scope="${1:?Missing skill scope}"
  KNOWN_SCOPE_MAP["$skill_scope"]=1
}

ensure_scope_dir() {
  local skill_scope="${1:?Missing skill scope}"
  mkdir -p "$(skill_scope_dir "$skill_scope")"
  mark_scope_known "$skill_scope"
}

ensure_state_file() {
  local skill_scope="${1:?Missing skill scope}"
  local state_path
  local default_state_json

  ensure_scope_dir "$skill_scope"
  state_path="$(skill_state_path "$skill_scope")"
  if [ -f "$state_path" ]; then
    return 0
  fi

  default_state_json="$(jq -cn \
    --arg version "$LEARNING_VERSION" \
    --arg skill_scope "$skill_scope" \
    --argjson half_life_days "$DEFAULT_HALF_LIFE_DAYS" \
    '{
      version:$version,
      skill_scope:$skill_scope,
      next_learning_seq:1,
      next_gotcha_seq:1,
      last_distilled_at:null,
      half_life_days:$half_life_days,
      source_cursors:{},
      learning_index:{}
    }'
  )"
  printf '%s\n' "$default_state_json" >"$state_path"
}

load_state_json() {
  local skill_scope="${1:?Missing skill scope}"
  ensure_state_file "$skill_scope"
  cat "$(skill_state_path "$skill_scope")"
}

save_state_json() {
  local skill_scope="${1:?Missing skill scope}"
  local next_state_json="${2:?Missing state json}"
  printf '%s\n' "$next_state_json" >"$(skill_state_path "$skill_scope")"
}

allocate_learning_id() {
  local cluster_key="${1:?Missing cluster key}"
  local learning_id
  local sequence
  local day_key

  learning_id="$(printf '%s' "$STATE_JSON" | jq -r --arg key "$cluster_key" '.learning_index[$key].learning_id // empty')"
  if [ -n "$learning_id" ]; then
    LOOKUP_ID="$learning_id"
    return 0
  fi

  sequence="$(printf '%s' "$STATE_JSON" | jq -r '.next_learning_seq // 1')"
  day_key="$(date -u +%Y%m%d)"
  learning_id="$(printf 'LRN-%s-%03d' "$day_key" "$sequence")"
  STATE_JSON="$(printf '%s' "$STATE_JSON" | jq \
    --arg key "$cluster_key" \
    --arg learning_id "$learning_id" \
    --arg created_at "$(learning_timestamp_utc)" \
    '
      .learning_index[$key] = ((.learning_index[$key] // {}) + {learning_id:$learning_id,created_at:$created_at}) |
      .next_learning_seq = ((.next_learning_seq // 1) + 1)
    '
  )"
  LOOKUP_ID="$learning_id"
}

allocate_gotcha_id() {
  local cluster_key="${1:?Missing cluster key}"
  local gotcha_id
  local sequence
  local day_key

  gotcha_id="$(printf '%s' "$STATE_JSON" | jq -r --arg key "$cluster_key" '.learning_index[$key].gotcha_id // empty')"
  if [ -n "$gotcha_id" ]; then
    LOOKUP_ID="$gotcha_id"
    return 0
  fi

  sequence="$(printf '%s' "$STATE_JSON" | jq -r '.next_gotcha_seq // 1')"
  day_key="$(date -u +%Y%m%d)"
  gotcha_id="$(printf 'GOTCHA-%s-%03d' "$day_key" "$sequence")"
  STATE_JSON="$(printf '%s' "$STATE_JSON" | jq \
    --arg key "$cluster_key" \
    --arg gotcha_id "$gotcha_id" \
    --arg promoted_at "$(learning_timestamp_utc)" \
    '
      .learning_index[$key] = ((.learning_index[$key] // {}) + {gotcha_id:$gotcha_id,promoted_at:$promoted_at}) |
      .next_gotcha_seq = ((.next_gotcha_seq // 1) + 1)
    '
  )"
  LOOKUP_ID="$gotcha_id"
}

update_cluster_state_metadata() {
  local cluster_key="${1:?Missing cluster key}"
  local learning_id="${2:?Missing learning id}"
  local title="${3:-}"
  local category="${4:-observation}"
  local topic_key="${5:-}"
  local component_path="${6:-}"
  local last_seen="${7:-}"
  local archived_flag="${8:-false}"

  STATE_JSON="$(printf '%s' "$STATE_JSON" | jq \
    --arg key "$cluster_key" \
    --arg learning_id "$learning_id" \
    --arg title "$title" \
    --arg category "$category" \
    --arg topic_key "$topic_key" \
    --arg component_path "$component_path" \
    --arg last_seen "$last_seen" \
    --argjson archived "$archived_flag" \
    '
      .learning_index[$key] = (
        (.learning_index[$key] // {}) + {
          learning_id:$learning_id,
          title:$title,
          category:$category,
          topic_key:$topic_key,
          component:$component_path,
          last_seen:$last_seen,
          archived:$archived
        }
      )
    '
  )"
}

update_source_cursors_from_events() {
  local skill_scope="${1:?Missing skill scope}"
  local events_path
  local source_cursors_json='{}'

  events_path="$(skill_events_path "$skill_scope")"
  if [ -f "$events_path" ] && [ -s "$events_path" ]; then
    source_cursors_json="$(jq -cs '
      sort_by(.source_file, .ts, .event_id) |
      group_by(.source_file) |
      map(select(.[0].source_file != null and .[0].source_file != "")) |
      map({key:.[0].source_file,value:(.[-1].event_id)}) |
      from_entries
    ' "$events_path" 2>/dev/null || printf '{}')"
  fi

  STATE_JSON="$(printf '%s' "$STATE_JSON" | jq \
    --argjson source_cursors "$source_cursors_json" \
    '.source_cursors = $source_cursors'
  )"
}

looks_like_component_path() {
  learning_looks_like_component_path "${1:-}"
}

looks_like_skill_scope() {
  local candidate="${1:-}"

  case "$candidate" in
    commands/* | agents/* | skills/* | templates/* | hooks/* | scripts/* | */*/*)
      return 1
      ;;
  esac

  [[ "$candidate" =~ ^[a-z0-9._-]+/[a-z0-9._-]+$ ]]
}

normalize_component_path() {
  learning_normalize_component_path "${1:-}"
}

resolve_scope_input() {
  local raw_input="${1:-}"
  local normalized_input

  normalized_input="$(normalize_component_path "$raw_input")"
  if looks_like_skill_scope "$normalized_input"; then
    printf '%s\n' "$normalized_input"
    return 0
  fi

  scope_from_component_path "$normalized_input"
}

scope_from_command_name() {
  local command_name="${1:-}"

  if [ -n "${RND_COMMAND_SCOPE_MAP[$command_name]:-}" ]; then
    printf '%s\n' "${RND_COMMAND_SCOPE_MAP[$command_name]}"
    return 0
  fi
  if [ -n "${CORE_COMMAND_SCOPE_MAP[$command_name]:-}" ]; then
    printf '%s\n' "${CORE_COMMAND_SCOPE_MAP[$command_name]}"
    return 0
  fi
  if [ -n "${PA_COMMAND_SCOPE_MAP[$command_name]:-}" ]; then
    printf '%s\n' "${PA_COMMAND_SCOPE_MAP[$command_name]}"
    return 0
  fi

  case "$command_name" in
    constrain)
      printf 'swe/constraint\n'
      ;;
    design | dev | implement | interface | optimize | reverse | ship | spec | spiral | test | tune | understand | verify)
      printf 'swe/methodology\n'
      ;;
    *)
      printf 'core/general\n'
      ;;
  esac
}

scope_from_script_path() {
  local script_path="${1:-}"
  local script_name

  script_name="$(basename "$script_path")"

  case "$script_name" in
    rnd-*.sh)
      printf 'rnd/methodology\n'
      ;;
    learning-*.sh | agent-memory*.sh | ralph.sh)
      printf 'core/evolution\n'
      ;;
    eval-*.sh | regression.sh | judge-skill-output.sh | hook-eval-result.sh)
      printf 'core/evaluation\n'
      ;;
    spiral-state.sh | test-spiral-state.sh)
      printf 'swe/methodology\n'
      ;;
    codex-relay.sh | invoke-model.sh | parallel.sh | hook-route-outcome.sh)
      printf 'core/routing\n'
      ;;
    worktree.sh)
      printf 'core/worktree-governance\n'
      ;;
    knowledge-catalog.sh | kb-similarity.sh)
      printf 'core/research\n'
      ;;
    validate-url.sh | check-skills.sh | check-port-skills.sh | hook-pipeline-preflight.sh)
      printf 'core/validation\n'
      ;;
    *)
      printf 'core/general\n'
      ;;
  esac
}

resolve_skill_scope_from_path() {
  local normalized_path="${1:-}"
  local module candidate skill_dir module_dir fallback_count fallback_name entry

  IFS=/ read -r _ module candidate _ <<<"$normalized_path"

  if [ -z "$module" ] || [ -z "$candidate" ]; then
    printf 'core/general\n'
    return 0
  fi

  skill_dir="$PROJECT_ROOT/skills/$module/$candidate"
  if [ -d "$skill_dir" ]; then
    printf '%s/%s\n' "$module" "$candidate"
    return 0
  fi

  module_dir="$PROJECT_ROOT/skills/$module"
  if [ ! -d "$module_dir" ]; then
    printf 'core/general\n'
    return 0
  fi

  fallback_count=0
  fallback_name=""
  for entry in "$module_dir"/*/; do
    [ -d "$entry" ] || continue
    fallback_name="$(basename "$entry")"
    fallback_count=$((fallback_count + 1))
    if [ "$fallback_count" -gt 1 ]; then
      break
    fi
  done

  if [ "$fallback_count" -eq 1 ]; then
    printf '%s/%s\n' "$module" "$fallback_name"
    return 0
  fi

  printf 'core/general\n'
}

scope_from_component_path() {
  local component_path="${1:-}"
  local normalized_path
  local filename
  local stem

  normalized_path="$(normalize_component_path "$component_path")"
  if ! looks_like_component_path "$normalized_path"; then
    printf 'core/general\n'
    return 0
  fi

  if [[ "$normalized_path" == skills/* ]]; then
    resolve_skill_scope_from_path "$normalized_path"
    return 0
  fi

  case "$normalized_path" in
    AGENTS.md | CLAUDE.md | GEMINI.md)
      printf 'core/general\n'
      return 0
      ;;
    hooks/*)
      printf 'core/validation\n'
      return 0
      ;;
    commands/core/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${CORE_COMMAND_SCOPE_MAP[$stem]:-core/general}"
      return 0
      ;;
    agents/core/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${CORE_AGENT_SCOPE_MAP[$stem]:-core/general}"
      return 0
      ;;
    templates/core/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${CORE_TEMPLATE_SCOPE_MAP[$stem]:-core/general}"
      return 0
      ;;
    commands/swe/constrain.md | templates/swe/constraint-profile.md)
      printf 'swe/constraint\n'
      return 0
      ;;
    agents/swe/reviewer.md)
      printf 'swe/code-review\n'
      return 0
      ;;
    commands/swe/* | agents/swe/* | templates/swe/*)
      printf 'swe/methodology\n'
      return 0
      ;;
    commands/pa/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${PA_COMMAND_SCOPE_MAP[$stem]:-core/general}"
      return 0
      ;;
    commands/rnd.md)
      printf 'rnd/methodology\n'
      return 0
      ;;
    agents/pa/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${PA_AGENT_SCOPE_MAP[$stem]:-core/general}"
      return 0
      ;;
    agents/rnd/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      printf '%s\n' "${RND_AGENT_SCOPE_MAP[$stem]:-rnd/methodology}"
      return 0
      ;;
    templates/pa/*)
      filename="$(basename "$normalized_path")"
      stem="${filename%.md}"
      case "$stem" in
        daily-brief | focus-brief | follow-up-report | gardening-report)
          printf 'pa/executive-assistance\n'
          ;;
        personal-profile | profiled-note | relationship-map | vault-profile)
          printf 'pa/personal-profiling\n'
          ;;
        life-narrative | weekly-review | period-compilation)
          printf 'pa/review-and-journaling\n'
          ;;
        daily-link-hub | ingest-digest | project-dossier | soul | timestamp-note)
          printf 'pa/context-assembly\n'
          ;;
        *)
          printf 'core/general\n'
          ;;
      esac
      return 0
      ;;
    templates/rnd/*)
      printf 'rnd/methodology\n'
      return 0
      ;;
    scripts/*)
      scope_from_script_path "$normalized_path"
      return 0
      ;;
    *)
      printf 'core/general\n'
      return 0
      ;;
  esac
}

extract_component_hint() {
  local event_json="${1:?Missing event json}"
  local candidate

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="$(normalize_component_path "$candidate")"
    if looks_like_component_path "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    printf '%s' "$event_json" | jq -r '
      [
        .component?,
        .detail.component?,
        .detail.component_path?,
        .detail.path?,
        .detail.target?,
        .detail.target_path?,
        .detail.file?,
        .detail.artifact_path?,
        .detail.output_path?,
        .detail.expected_artifact.path?
      ] |
      .[] |
      select(type == "string" and length > 0)
    ' 2>/dev/null || true
  )

  printf '\n'
}

scope_from_task_key() {
  local task_key="${1:-}"
  local task_prefix
  local task_suffix

  if [ -z "$task_key" ]; then
    printf 'core/general\n'
    return 0
  fi

  task_prefix="$task_key"
  task_suffix=""
  if [[ "$task_key" == *:* ]]; then
    task_prefix="${task_key%%:*}"
    task_suffix="${task_key#*:}"
  fi

  task_suffix="$(normalize_component_path "$task_suffix")"
  if looks_like_component_path "$task_suffix"; then
    scope_from_component_path "$task_suffix"
    return 0
  fi

  scope_from_command_name "$task_prefix"
}

route_event_scope() {
  local event_json="${1:?Missing event json}"
  local component_hint
  local task_key

  component_hint="$(extract_component_hint "$event_json")"
  if [ -n "$component_hint" ]; then
    scope_from_component_path "$component_hint"
    return 0
  fi

  task_key="$(printf '%s' "$event_json" | jq -r '.task_key // empty' 2>/dev/null || true)"
  scope_from_task_key "$task_key"
}

derive_event_category() {
  local event_json="${1:?Missing event json}"
  local source_name
  local failed_count
  local level_value
  local session_pattern

  source_name="$(printf '%s' "$event_json" | jq -r '.source // empty' 2>/dev/null || true)"
  case "$source_name" in
    evaluation)
      failed_count="$(printf '%s' "$event_json" | jq -r '[.failed_criteria[]?] | length' 2>/dev/null || printf '0')"
      level_value="$(printf '%s' "$event_json" | jq -r '.level // 0' 2>/dev/null || printf '0')"
      if [ "$failed_count" -gt 0 ] || [ "$level_value" -lt 4 ]; then
        printf 'error\n'
      else
        printf 'observation\n'
      fi
      ;;
    correction)
      printf 'error\n'
      ;;
    friction)
      printf 'observation\n'
      ;;
    session-pattern)
      session_pattern="$(printf '%s' "$event_json" | jq -r '.pattern // empty' 2>/dev/null || true)"
      case "$session_pattern" in
        *feature*request* | *feature_request*)
          printf 'feature-request\n'
          ;;
        *missing* | *unfinished* | *retry* | *workaround*)
          printf 'error\n'
          ;;
        *)
          printf 'observation\n'
          ;;
      esac
      ;;
    *)
      printf 'observation\n'
      ;;
  esac
}

derive_event_polarity() {
  local event_json="${1:?Missing event json}"
  local category="${2:?Missing category}"
  local source_name
  local failed_count

  if [ "$category" = "feature-request" ]; then
    printf 'request\n'
    return 0
  fi

  source_name="$(printf '%s' "$event_json" | jq -r '.source // empty' 2>/dev/null || true)"
  if [ "$source_name" = "evaluation" ]; then
    failed_count="$(printf '%s' "$event_json" | jq -r '[.failed_criteria[]?] | length' 2>/dev/null || printf '0')"
    if [ "$failed_count" -eq 0 ]; then
      printf 'neutral\n'
      return 0
    fi
  fi

  printf 'negative\n'
}

build_topic_key() {
  local event_json="${1:?Missing event json}"
  local component_hint="${2:-}"
  local topic_key=""

  if [ -n "$component_hint" ]; then
    topic_key="$(normalize_token "$component_hint")"
  else
    topic_key="$(printf '%s' "$event_json" | jq -r '
      .signal // .correction_type // .pattern // .detail.matched_rule // .source // ""
    ' 2>/dev/null || true)"
    topic_key="$(normalize_token "$topic_key")"
  fi

  if [ -z "$topic_key" ]; then
    topic_key="$(printf '%s' "$event_json" | jq -r '.source // "general"' 2>/dev/null || printf 'general')"
    topic_key="$(normalize_token "$topic_key")"
  fi

  printf '%s\n' "$topic_key"
}

build_problem_signature() {
  local event_json="${1:?Missing event json}"
  local component_hint="${2:-}"
  local source_name
  local component_value
  local failed_criteria
  local signal_value
  local correction_type
  local pattern_value
  local pattern_hash
  local detail_rule
  local source_name

  component_value="$(normalize_token "$component_hint")"
  failed_criteria="$(printf '%s' "$event_json" | jq -r '
    (.failed_criteria // []) |
    map(tostring | ascii_downcase) |
    map(select(length > 0)) |
    unique |
    join(",")
  ' 2>/dev/null || true)"
  signal_value="$(printf '%s' "$event_json" | jq -r '.signal // ""' 2>/dev/null || true)"
  correction_type="$(printf '%s' "$event_json" | jq -r '.correction_type // ""' 2>/dev/null || true)"
  pattern_value="$(printf '%s' "$event_json" | jq -r '.pattern // ""' 2>/dev/null || true)"
  pattern_hash="$(printf '%s' "$event_json" | jq -r '.pattern_hash // ""' 2>/dev/null || true)"
  detail_rule="$(printf '%s' "$event_json" | jq -r '.detail.matched_rule // .detail.reason // ""' 2>/dev/null || true)"
  source_name="$(printf '%s' "$event_json" | jq -r '.source // ""' 2>/dev/null || true)"

  case "$source_name" in
    evaluation)
      printf 'source=%s|component=%s|criteria=%s\n' \
        "$(normalize_token "$source_name")" \
        "$component_value" \
        "$(normalize_token "$failed_criteria")"
      ;;
    friction)
      printf 'source=%s|component=%s|signal=%s|pattern_hash=%s\n' \
        "$(normalize_token "$source_name")" \
        "$component_value" \
        "$(normalize_token "$signal_value")" \
        "$(normalize_token "$pattern_hash")"
      ;;
    correction)
      printf 'source=%s|component=%s|correction=%s|detail=%s\n' \
        "$(normalize_token "$source_name")" \
        "$component_value" \
        "$(normalize_token "$correction_type")" \
        "$(normalize_token "$detail_rule")"
      ;;
    session-pattern)
      printf 'source=%s|component=%s|pattern=%s|detail=%s\n' \
        "$(normalize_token "$source_name")" \
        "$component_value" \
        "$(normalize_token "$pattern_value")" \
        "$(normalize_token "$detail_rule")"
      ;;
    *)
      printf 'source=%s|component=%s|criteria=%s|signal=%s|correction=%s|pattern=%s|detail=%s\n' \
        "$(normalize_token "$source_name")" \
        "$component_value" \
        "$(normalize_token "$failed_criteria")" \
        "$(normalize_token "$signal_value")" \
        "$(normalize_token "$correction_type")" \
        "$(normalize_token "$pattern_value")" \
        "$(normalize_token "$detail_rule")"
      ;;
  esac
}

event_already_routed() {
  local events_path="${1:?Missing events path}"
  local event_id="${2:?Missing event id}"

  if [ ! -f "$events_path" ]; then
    return 1
  fi

  grep -F "\"event_id\":\"$event_id\"" "$events_path" >/dev/null 2>&1
}

append_routed_event() {
  local skill_scope="${1:?Missing skill scope}"
  local source_file="${2:?Missing source file}"
  local event_json="${3:?Missing event json}"
  local category="${4:?Missing category}"
  local cluster_key="${5:?Missing cluster key}"
  local problem_signature="${6:?Missing problem signature}"
  local topic_key="${7:?Missing topic key}"
  local polarity="${8:?Missing polarity}"
  local component_hint="${9:-}"
  local events_path
  local event_id
  local routed_payload

  ensure_scope_dir "$skill_scope"
  events_path="$(skill_events_path "$skill_scope")"
  event_id="$(printf '%s' "$event_json" | jq -r '.event_id // empty' 2>/dev/null || true)"
  [ -n "$event_id" ] || return 1

  if event_already_routed "$events_path" "$event_id"; then
    return 1
  fi

  routed_payload="$(printf '%s' "$event_json" | jq -c \
    --arg source_file "$source_file" \
    --arg skill_scope "$skill_scope" \
    --arg category "$category" \
    --arg cluster_key "$cluster_key" \
    --arg problem_signature "$problem_signature" \
    --arg topic_key "$topic_key" \
    --arg polarity "$polarity" \
    --arg routed_component "$component_hint" \
    --arg routed_at "$(learning_timestamp_utc)" \
    '
      . + {
        source_file:$source_file,
        skill_scope:$skill_scope,
        category:$category,
        cluster_key:$cluster_key,
        problem_signature:$problem_signature,
        topic_key:$topic_key,
        polarity:$polarity,
        routed_component:$routed_component,
        routed_at:$routed_at
      }
    ' 2>/dev/null || true
  )"

  [ -n "$routed_payload" ] || return 1
  learning_append_jsonl "$events_path" "$routed_payload"
  APPENDED_EVENT_MAP["$skill_scope"]=1
  ROUTED_CURSOR_MAP["$skill_scope:$source_file"]="$event_id"
  return 0
}

route_source_file() {
  local source_path="${1:?Missing source path}"
  local source_file
  local event_json=""
  local event_id
  local skill_scope
  local category
  local component_hint
  local problem_signature
  local cluster_key
  local topic_key
  local polarity

  source_file="$(basename "$source_path" .jsonl)"
  [ -f "$source_path" ] || return 0

  while IFS= read -r event_json || [ -n "$event_json" ]; do
    [ -n "$event_json" ] || continue
    if ! printf '%s' "$event_json" | jq -e . >/dev/null 2>&1; then
      log_error "Skipping invalid JSON in $(basename "$source_path")."
      continue
    fi

    event_json="$(printf '%s' "$event_json" | jq -c '.' 2>/dev/null || true)"
    [ -n "$event_json" ] || continue
    event_id="$(printf '%s' "$event_json" | jq -r '.event_id // empty' 2>/dev/null || true)"
    [ -n "$event_id" ] || continue

    component_hint="$(extract_component_hint "$event_json")"
    skill_scope="$(route_event_scope "$event_json")"
    category="$(derive_event_category "$event_json")"
    polarity="$(derive_event_polarity "$event_json" "$category")"
    topic_key="$(build_topic_key "$event_json" "$component_hint")"
    problem_signature="$(build_problem_signature "$event_json" "$component_hint")"
    cluster_key="$(learning_sha256 "$problem_signature" 2>/dev/null || true)"
    [ -n "$cluster_key" ] || {
      log_error "Unable to hash event $event_id."
      continue
    }

    append_routed_event "$skill_scope" "$source_file" "$event_json" "$category" "$cluster_key" "$problem_signature" "$topic_key" "$polarity" "$component_hint" || true
  done <"$source_path"
}

prune_source_file() {
  local source_path="${1:?Missing source path}"
  local tmp_path
  local event_json=""
  local event_ts
  local pruned_count=0

  [ -f "$source_path" ] || return 0
  tmp_path="$(mktemp)"
  while IFS= read -r event_json || [ -n "$event_json" ]; do
    [ -n "$event_json" ] || continue
    if ! printf '%s' "$event_json" | jq -e . >/dev/null 2>&1; then
      log_error "Preserving invalid JSON while pruning $(basename "$source_path")."
      printf '%s\n' "$event_json" >>"$tmp_path"
      continue
    fi

    event_json="$(printf '%s' "$event_json" | jq -c '.' 2>/dev/null || true)"
    event_ts="$(printf '%s' "$event_json" | jq -r '.ts // empty' 2>/dev/null || true)"
    if [ -n "$event_ts" ] && learning_is_within_ttl "$event_ts" 90; then
      printf '%s\n' "$event_json" >>"$tmp_path"
    elif [ -n "$event_ts" ]; then
      pruned_count=$((pruned_count + 1))
    else
      printf '%s\n' "$event_json" >>"$tmp_path"
    fi
  done <"$source_path"

  if [ "$pruned_count" -gt 0 ]; then
    mv "$tmp_path" "$source_path"
    log_error "Pruned $pruned_count old source event(s) from $(basename "$source_path")."
  else
    rm -f "$tmp_path"
  fi
}

cluster_summaries_jsonl() {
  local skill_scope="${1:?Missing skill scope}"
  local events_path

  events_path="$(skill_events_path "$skill_scope")"
  if [ ! -f "$events_path" ] || [ ! -s "$events_path" ]; then
    return 0
  fi

  jq -cs '
    map(select(.cluster_key? != null and .cluster_key != "")) |
    sort_by(.cluster_key, .ts, .event_id) |
    group_by(.cluster_key) |
    map({
      cluster_key: .[0].cluster_key,
      skill_scope: .[0].skill_scope,
      category: .[0].category,
      source_type: (.[0].source // ""),
      topic_key: (.[0].topic_key // ""),
      polarity: (.[0].polarity // ""),
      component: ([ .[] | .routed_component // "" ] | map(select(length > 0)) | unique | .[0] // ""),
      failed_criteria: ([ .[] | (.failed_criteria // [])[]? | tostring ] | map(select(length > 0)) | unique | sort),
      signals: ([ .[] | .signal // empty | tostring ] | map(select(length > 0)) | unique | sort),
      correction_types: ([ .[] | .correction_type // empty | tostring ] | map(select(length > 0)) | unique | sort),
      patterns: ([ .[] | .pattern // empty | tostring ] | map(select(length > 0)) | unique | sort),
      pattern_hashes: ([ .[] | .pattern_hash // empty | tostring ] | map(select(length > 0)) | unique | sort),
      improvement_descriptions: ([ .[] | (.improvements // [])[]? | .description // empty | tostring ] | map(select(length > 0)) | unique),
      source_event_ids: ([ .[] | .event_id ] | unique | sort),
      task_keys: ([ .[] | .task_key // empty | tostring ] | map(select(length > 0)) | unique | sort),
      first_seen: ([ .[] | .ts ] | sort | first),
      last_seen: ([ .[] | .ts ] | sort | last),
      occurrences: length,
      independent_tasks: ([ .[] | .task_key // empty | tostring ] | map(select(length > 0)) | unique | length),
      confidence: ([ .[] | (.confidence // 0) ] | if length == 0 then 0 else add / length end)
    }) |
    sort_by(.last_seen, .occurrences) |
    reverse |
    .[]
  ' "$events_path" 2>/dev/null || true
}

pretty_list_from_json() {
  local cluster_json="${1:?Missing cluster json}"
  local field_name="${2:?Missing field name}"

  printf '%s' "$cluster_json" | jq -r --arg field_name "$field_name" '
    .[$field_name] // [] |
    map(tostring) |
    map(select(length > 0)) |
    join(", ")
  ' 2>/dev/null || true
}

build_source_context() {
  local cluster_json="${1:?Missing cluster json}"
  local source_context

  source_context="$(printf '%s' "$cluster_json" | jq -r '
    (
      (.source_event_ids[:5] // []) +
      (
        if (.component // "") != "" then
          [ .component ]
        else
          []
        end
      ) +
      (.pattern_hashes[:2] // [])
    ) |
    unique |
    join("; ")
  ' 2>/dev/null || true)"

  source_context="$(normalize_text "$source_context")"
  if [ -z "$source_context" ]; then
    source_context="events unavailable"
  fi
  printf '%s\n' "$source_context"
}

build_learning_title() {
  local cluster_json="${1:?Missing cluster json}"
  local source_type
  local component_path
  local criteria_text
  local signal_text
  local correction_text
  local pattern_text
  local title_text

  source_type="$(printf '%s' "$cluster_json" | jq -r '.source_type // empty' 2>/dev/null || true)"
  component_path="$(printf '%s' "$cluster_json" | jq -r '.component // empty' 2>/dev/null || true)"
  criteria_text="$(pretty_list_from_json "$cluster_json" "failed_criteria")"
  signal_text="$(pretty_list_from_json "$cluster_json" "signals")"
  correction_text="$(pretty_list_from_json "$cluster_json" "correction_types")"
  pattern_text="$(pretty_list_from_json "$cluster_json" "patterns")"

  case "$source_type" in
    evaluation)
      if [ -n "$component_path" ] && [ -n "$criteria_text" ]; then
        title_text="$(basename "$component_path") keeps failing $criteria_text"
      elif [ -n "$component_path" ]; then
        title_text="$(basename "$component_path") keeps showing evaluation drift"
      else
        title_text="Evaluation drift keeps repeating in this scope"
      fi
      ;;
    friction)
      if [ -n "$signal_text" ]; then
        title_text="$(normalize_text "$(printf '%s' "$signal_text" | tr '_' ' ')") keeps repeating"
      else
        title_text="Repeated friction keeps surfacing in this scope"
      fi
      ;;
    correction)
      if [ -n "$correction_text" ]; then
        title_text="User corrections keep flagging $(normalize_text "$(printf '%s' "$correction_text" | tr '_' ' ')")"
      else
        title_text="User corrections keep surfacing in this scope"
      fi
      ;;
    session-pattern)
      if [ -n "$pattern_text" ]; then
        title_text="Session end keeps surfacing $(normalize_text "$(printf '%s' "$pattern_text" | tr '_' ' ')")"
      else
        title_text="Session-end issues keep repeating in this scope"
      fi
      ;;
    *)
      title_text="Repeated learning signal in this scope"
      ;;
  esac

  printf '%s\n' "$(normalize_text "$title_text")"
}

build_learning_text() {
  local cluster_json="${1:?Missing cluster json}"
  local source_type
  local component_path
  local criteria_text
  local signal_text
  local correction_text
  local pattern_text
  local learning_text

  source_type="$(printf '%s' "$cluster_json" | jq -r '.source_type // empty' 2>/dev/null || true)"
  component_path="$(printf '%s' "$cluster_json" | jq -r '.component // empty' 2>/dev/null || true)"
  criteria_text="$(pretty_list_from_json "$cluster_json" "failed_criteria")"
  signal_text="$(pretty_list_from_json "$cluster_json" "signals")"
  correction_text="$(pretty_list_from_json "$cluster_json" "correction_types")"
  pattern_text="$(pretty_list_from_json "$cluster_json" "patterns")"

  case "$source_type" in
    evaluation)
      if [ -n "$component_path" ] && [ -n "$criteria_text" ]; then
        learning_text="Repeated evaluation evidence for $component_path clusters around failed criteria $criteria_text."
      elif [ -n "$component_path" ]; then
        learning_text="Repeated evaluation evidence shows recurring drift in $component_path."
      else
        learning_text="Repeated evaluation evidence points to a recurring quality regression."
      fi
      ;;
    friction)
      if [ -n "$signal_text" ]; then
        learning_text="Repeated friction clusters around $(normalize_text "$(printf '%s' "$signal_text" | tr '_' ' ')") across related work."
      else
        learning_text="Repeated friction indicates an execution pattern is still causing avoidable drag."
      fi
      ;;
    correction)
      if [ -n "$correction_text" ]; then
        learning_text="Explicit user corrections repeatedly point to $(normalize_text "$(printf '%s' "$correction_text" | tr '_' ' ')")."
      else
        learning_text="Explicit user corrections indicate a recurring mismatch in delivery."
      fi
      ;;
    session-pattern)
      if [ -n "$pattern_text" ]; then
        learning_text="Session-end evidence repeatedly shows $(normalize_text "$(printf '%s' "$pattern_text" | tr '_' ' ')")."
      else
        learning_text="Session-end evidence shows a recurring completion gap."
      fi
      ;;
    *)
      learning_text="Repeated evidence indicates a stable pattern worth carrying forward."
      ;;
  esac

  printf '%s\n' "$(normalize_text "$learning_text")"
}

build_action_text() {
  local cluster_json="${1:?Missing cluster json}"
  local source_type
  local component_path
  local criteria_text
  local signal_text
  local correction_text
  local pattern_text
  local improvement_text
  local action_text

  source_type="$(printf '%s' "$cluster_json" | jq -r '.source_type // empty' 2>/dev/null || true)"
  component_path="$(printf '%s' "$cluster_json" | jq -r '.component // empty' 2>/dev/null || true)"
  criteria_text="$(pretty_list_from_json "$cluster_json" "failed_criteria")"
  signal_text="$(pretty_list_from_json "$cluster_json" "signals")"
  correction_text="$(pretty_list_from_json "$cluster_json" "correction_types")"
  pattern_text="$(pretty_list_from_json "$cluster_json" "patterns")"
  improvement_text="$(printf '%s' "$cluster_json" | jq -r '
    .improvement_descriptions[:2] // [] |
    map(select(length > 0)) |
    join(" ")
  ' 2>/dev/null || true)"

  if [ -n "$improvement_text" ]; then
    printf '%s\n' "$(normalize_text "$improvement_text")"
    return 0
  fi

  case "$source_type" in
    evaluation)
      if [ -n "$component_path" ] && [ -n "$criteria_text" ]; then
        action_text="Address $criteria_text in $component_path before another evolve cycle."
      elif [ -n "$component_path" ]; then
        action_text="Review $component_path before the next related task."
      else
        action_text="Re-check this scope before the next related task."
      fi
      ;;
    friction)
      if [ -n "$signal_text" ]; then
        action_text="Add a guard or checklist that removes $(normalize_text "$(printf '%s' "$signal_text" | tr '_' ' ')") from the next run."
      else
        action_text="Add a guard that removes this friction pattern from the next run."
      fi
      ;;
    correction)
      if [ -n "$correction_text" ]; then
        action_text="Add a pre-response check that prevents $(normalize_text "$(printf '%s' "$correction_text" | tr '_' ' ')")."
      else
        action_text="Add a pre-response check that prevents this correction pattern."
      fi
      ;;
    session-pattern)
      if [ -n "$pattern_text" ]; then
        action_text="Add a completion check for $(normalize_text "$(printf '%s' "$pattern_text" | tr '_' ' ')") before closing the session."
      else
        action_text="Add a final completion check before closing the session."
      fi
      ;;
    *)
      action_text="Carry this pattern into the next related task."
      ;;
  esac

  printf '%s\n' "$(normalize_text "$action_text")"
}

render_learned_entry() {
  local learning_id="${1:?Missing learning id}"
  local title="${2:?Missing title}"
  local category="${3:?Missing category}"
  local confidence="${4:?Missing confidence}"
  local effective_confidence="${5:?Missing effective confidence}"
  local first_seen="${6:?Missing first_seen}"
  local last_seen="${7:?Missing last_seen}"
  local occurrences="${8:?Missing occurrences}"
  local independent_tasks="${9:?Missing independent_tasks}"
  local decay_weight="${10:?Missing decay_weight}"
  local source_context="${11:?Missing source_context}"
  local learning_text="${12:?Missing learning text}"
  local action_text="${13:?Missing action text}"

  sed \
    -e "s/{{LEARNING_ID}}/$(escape_sed_replacement "$learning_id")/g" \
    -e "s/{{TITLE}}/$(escape_sed_replacement "$title")/g" \
    -e "s/{{CATEGORY}}/$(escape_sed_replacement "$category")/g" \
    -e "s/{{CONFIDENCE}}/$(escape_sed_replacement "$confidence")/g" \
    -e "s/{{EFFECTIVE_CONFIDENCE}}/$(escape_sed_replacement "$effective_confidence")/g" \
    -e "s/{{FIRST_SEEN}}/$(escape_sed_replacement "$first_seen")/g" \
    -e "s/{{LAST_SEEN}}/$(escape_sed_replacement "$last_seen")/g" \
    -e "s/{{OCCURRENCES}}/$(escape_sed_replacement "$occurrences")/g" \
    -e "s/{{INDEPENDENT_TASKS}}/$(escape_sed_replacement "$independent_tasks")/g" \
    -e "s/{{DECAY_WEIGHT}}/$(escape_sed_replacement "$decay_weight")/g" \
    -e "s/{{SOURCE_CONTEXT}}/$(escape_sed_replacement "$source_context")/g" \
    -e "s/{{LEARNING}}/$(escape_sed_replacement "$learning_text")/g" \
    -e "s/{{ACTION}}/$(escape_sed_replacement "$action_text")/g" \
    "$LEARNING_TEMPLATE_PATH"
}

write_learned_document() {
  local skill_scope="${1:?Missing skill scope}"
  local half_life_days="${2:?Missing half life}"
  local active_entries_path="${3:?Missing active entries path}"
  local archived_entries_path="${4:?Missing archived entries path}"
  local learned_path

  learned_path="$(skill_learned_path "$skill_scope")"
  {
    printf '# Learned — %s\n\n' "$skill_scope"
    printf -- '- generated_at: %s\n' "$(learning_timestamp_utc)"
    printf -- '- half_life_days: %s\n\n' "$half_life_days"
    printf '## Active\n\n'
    if [ -s "$active_entries_path" ]; then
      cat "$active_entries_path"
    else
      printf '_None._\n'
    fi
    printf '\n## Archived\n\n'
    if [ -s "$archived_entries_path" ]; then
      cat "$archived_entries_path"
    else
      printf '_None._\n'
    fi
  } >"$learned_path"
}

distill_scope() {
  local skill_scope="${1:?Missing skill scope}"
  local active_entries_path
  local archived_entries_path
  local cluster_json=""
  local half_life_days
  local learning_id
  local title
  local category
  local topic_key
  local component_path
  local last_seen
  local confidence
  local first_seen
  local occurrences
  local independent_tasks
  local days_since
  local decay_weight
  local effective_confidence
  local archived_flag="false"
  local source_context
  local learning_text
  local action_text
  local entry_markdown
  local cluster_key

  ensure_scope_dir "$skill_scope"
  STATE_JSON="$(load_state_json "$skill_scope")"
  half_life_days="$(printf '%s' "$STATE_JSON" | jq -r '.half_life_days // 23')"
  active_entries_path="$(mktemp)"
  archived_entries_path="$(mktemp)"

  while IFS= read -r cluster_json; do
    [ -n "$cluster_json" ] || continue
    cluster_key="$(printf '%s' "$cluster_json" | jq -r '.cluster_key')"
    category="$(printf '%s' "$cluster_json" | jq -r '.category')"
    topic_key="$(printf '%s' "$cluster_json" | jq -r '.topic_key // ""')"
    component_path="$(printf '%s' "$cluster_json" | jq -r '.component // ""')"
    first_seen="$(printf '%s' "$cluster_json" | jq -r '.first_seen')"
    last_seen="$(printf '%s' "$cluster_json" | jq -r '.last_seen')"
    occurrences="$(printf '%s' "$cluster_json" | jq -r '.occurrences')"
    independent_tasks="$(printf '%s' "$cluster_json" | jq -r '.independent_tasks')"
    confidence="$(printf '%s' "$cluster_json" | jq -r '.confidence')"
    confidence="$(format_decimal "$confidence")"
    days_since="$(days_since_timestamp "$last_seen")"
    decay_weight="$(calc_decay_weight "$days_since" "$half_life_days")"
    effective_confidence="$(calc_effective_confidence "$confidence" "$decay_weight")"

    allocate_learning_id "$cluster_key"
    learning_id="$LOOKUP_ID"
    title="$(build_learning_title "$cluster_json")"
    source_context="$(build_source_context "$cluster_json")"
    learning_text="$(build_learning_text "$cluster_json")"
    action_text="$(build_action_text "$cluster_json")"

    if float_lt "$effective_confidence" "$ARCHIVE_THRESHOLD"; then
      archived_flag="true"
    else
      archived_flag="false"
    fi

    update_cluster_state_metadata "$cluster_key" "$learning_id" "$title" "$category" "$topic_key" "$component_path" "$last_seen" "$archived_flag"
    entry_markdown="$(render_learned_entry \
      "$learning_id" \
      "$title" \
      "$category" \
      "$confidence" \
      "$effective_confidence" \
      "$first_seen" \
      "$last_seen" \
      "$occurrences" \
      "$independent_tasks" \
      "$decay_weight" \
      "$source_context" \
      "$learning_text" \
      "$action_text"
    )"

    if [ "$archived_flag" = "true" ]; then
      printf '%s\n\n' "$entry_markdown" >>"$archived_entries_path"
    else
      printf '%s\n\n' "$entry_markdown" >>"$active_entries_path"
    fi
  done < <(cluster_summaries_jsonl "$skill_scope")

  update_source_cursors_from_events "$skill_scope"
  STATE_JSON="$(printf '%s' "$STATE_JSON" | jq --arg last_distilled_at "$(learning_timestamp_utc)" '.last_distilled_at = $last_distilled_at')"
  save_state_json "$skill_scope" "$STATE_JSON"
  write_learned_document "$skill_scope" "$half_life_days" "$active_entries_path" "$archived_entries_path"
  rm -f "$active_entries_path" "$archived_entries_path"
}

render_all_scopes() {
  local skills_root
  local skill_scope

  skills_root="$LEARNING_DATA_ROOT/skills"
  if [ -d "$skills_root" ]; then
    while IFS= read -r skill_scope; do
      [ -n "$skill_scope" ] || continue
      distill_scope "$skill_scope"
    done < <(find "$skills_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#^$skills_root/##" | sort)
  fi
}

build_gotcha_rule() {
  local cluster_json="${1:?Missing cluster json}"
  local rule_text

  rule_text="$(build_action_text "$cluster_json")"
  printf '%s\n' "$rule_text"
}

build_gotcha_applies_to() {
  local cluster_json="${1:?Missing cluster json}"
  local component_path

  component_path="$(printf '%s' "$cluster_json" | jq -r '.component // empty' 2>/dev/null || true)"
  if [ -n "$component_path" ]; then
    printf '%s\n' "$component_path"
  else
    printf '%s\n' "$(printf '%s' "$cluster_json" | jq -r '.skill_scope // "general"' 2>/dev/null || printf 'general')"
  fi
}

build_gotcha_verify_with() {
  local cluster_json="${1:?Missing cluster json}"
  local verify_text

  verify_text="$(pretty_list_from_json "$cluster_json" "failed_criteria")"
  if [ -z "$verify_text" ]; then
    verify_text="$(pretty_list_from_json "$cluster_json" "signals")"
  fi
  if [ -z "$verify_text" ]; then
    verify_text="$(pretty_list_from_json "$cluster_json" "correction_types")"
  fi
  if [ -z "$verify_text" ]; then
    verify_text="$(pretty_list_from_json "$cluster_json" "patterns")"
  fi
  if [ -z "$verify_text" ]; then
    verify_text="next related task"
  fi
  printf '%s\n' "$(normalize_text "$(printf '%s' "$verify_text" | tr '_' ' ')")"
}

has_higher_confidence_contradiction() {
  local summary_file="${1:?Missing summary file}"
  local current_cluster_key="${2:?Missing cluster key}"
  local current_topic_key="${3:-}"
  local current_polarity="${4:-negative}"
  local current_effective_confidence="${5:-0}"

  if [ -z "$current_topic_key" ] || [ "$current_polarity" = "neutral" ]; then
    return 1
  fi

  jq -e -s \
    --arg current_cluster_key "$current_cluster_key" \
    --arg current_topic_key "$current_topic_key" \
    --arg current_polarity "$current_polarity" \
    --argjson current_effective_confidence "$current_effective_confidence" \
    '
      map(
        select(
          .cluster_key != $current_cluster_key and
          (.topic_key // "") == $current_topic_key and
          (.polarity // "neutral") != $current_polarity and
          (.effective_confidence // 0) > $current_effective_confidence
        )
      ) |
      length > 0
    ' "$summary_file" >/dev/null 2>&1
}

promote_scope() {
  local skill_scope="${1:?Missing skill scope}"
  local gotchas_path
  local promoted_entries_path
  local summary_file
  local cluster_json=""
  local cluster_key
  local category
  local occurrences
  local independent_tasks
  local first_seen
  local last_seen
  local span_days
  local confidence
  local half_life_days
  local decay_weight
  local effective_confidence
  local learning_id
  local gotcha_id
  local promoted_at
  local evidence_text
  local rule_text
  local applies_to
  local verify_with
  local title
  local topic_key
  local polarity
  local existing_gotcha_id
  local should_emit=false

  ensure_scope_dir "$skill_scope"
  STATE_JSON="$(load_state_json "$skill_scope")"
  half_life_days="$(printf '%s' "$STATE_JSON" | jq -r '.half_life_days // 23')"
  gotchas_path="$(skill_gotchas_path "$skill_scope")"
  promoted_entries_path="$(mktemp)"
  summary_file="$(mktemp)"

  while IFS= read -r cluster_json; do
    [ -n "$cluster_json" ] || continue
    last_seen="$(printf '%s' "$cluster_json" | jq -r '.last_seen')"
    confidence="$(printf '%s' "$cluster_json" | jq -r '.confidence')"
    confidence="$(format_decimal "$confidence")"
    decay_weight="$(calc_decay_weight "$(days_since_timestamp "$last_seen")" "$half_life_days")"
    effective_confidence="$(calc_effective_confidence "$confidence" "$decay_weight")"
    printf '%s' "$cluster_json" | jq -c \
      --argjson effective_confidence "$effective_confidence" \
      '. + {effective_confidence:$effective_confidence}' >>"$summary_file"
    printf '\n' >>"$summary_file"
  done < <(cluster_summaries_jsonl "$skill_scope")

  while IFS= read -r cluster_json; do
    [ -n "$cluster_json" ] || continue
    cluster_key="$(printf '%s' "$cluster_json" | jq -r '.cluster_key')"
    category="$(printf '%s' "$cluster_json" | jq -r '.category')"
    occurrences="$(printf '%s' "$cluster_json" | jq -r '.occurrences')"
    independent_tasks="$(printf '%s' "$cluster_json" | jq -r '.independent_tasks')"
    first_seen="$(printf '%s' "$cluster_json" | jq -r '.first_seen')"
    last_seen="$(printf '%s' "$cluster_json" | jq -r '.last_seen')"
    topic_key="$(printf '%s' "$cluster_json" | jq -r '.topic_key // ""')"
    polarity="$(printf '%s' "$cluster_json" | jq -r '.polarity // "negative"')"
    confidence="$(printf '%s' "$cluster_json" | jq -r '.confidence')"
    confidence="$(format_decimal "$confidence")"
    decay_weight="$(calc_decay_weight "$(days_since_timestamp "$last_seen")" "$half_life_days")"
    effective_confidence="$(calc_effective_confidence "$confidence" "$decay_weight")"
    span_days="$(days_between_timestamps "$first_seen" "$last_seen")"
    existing_gotcha_id="$(printf '%s' "$STATE_JSON" | jq -r --arg key "$cluster_key" '.learning_index[$key].gotcha_id // empty')"
    should_emit=false

    if [ -n "$existing_gotcha_id" ]; then
      should_emit=true
    else
      if [ "$occurrences" -lt "$PROMOTION_MIN_OCCURRENCES" ]; then
        continue
      fi
      if [ "$independent_tasks" -lt "$PROMOTION_MIN_TASKS" ]; then
        continue
      fi
      if ! float_ge "$span_days" "$PROMOTION_MIN_SPAN_DAYS"; then
        continue
      fi
      if ! float_ge "$effective_confidence" "$PROMOTION_THRESHOLD"; then
        continue
      fi
      if has_higher_confidence_contradiction "$summary_file" "$cluster_key" "$topic_key" "$polarity" "$effective_confidence"; then
        continue
      fi
      should_emit=true
    fi

    if [ "$should_emit" != "true" ]; then
      continue
    fi

    allocate_learning_id "$cluster_key"
    learning_id="$LOOKUP_ID"
    allocate_gotcha_id "$cluster_key"
    gotcha_id="$LOOKUP_ID"
    promoted_at="$(printf '%s' "$STATE_JSON" | jq -r --arg key "$cluster_key" '.learning_index[$key].promoted_at // empty')"
    if [ -z "$promoted_at" ]; then
      promoted_at="$(learning_timestamp_utc)"
      STATE_JSON="$(printf '%s' "$STATE_JSON" | jq --arg key "$cluster_key" --arg promoted_at "$promoted_at" '.learning_index[$key].promoted_at = $promoted_at')"
    fi

    title="$(build_learning_title "$cluster_json")"
    rule_text="$(build_gotcha_rule "$cluster_json")"
    applies_to="$(build_gotcha_applies_to "$cluster_json")"
    verify_with="$(build_gotcha_verify_with "$cluster_json")"
    evidence_text="$(printf '%s occurrences / %s tasks / %.0f days' "$occurrences" "$independent_tasks" "$span_days")"

    {
      printf '## %s — %s\n' "$gotcha_id" "$title"
      printf -- '- promoted_from: %s:%s\n' "$skill_scope" "$learning_id"
      printf -- '- promoted_at: %s\n' "$promoted_at"
      printf -- '- confidence: %s\n' "$effective_confidence"
      printf -- '- evidence: %s\n' "$evidence_text"
      printf -- '- rule: %s\n' "$rule_text"
      printf -- '- applies_to: %s\n' "$applies_to"
      printf -- '- verify_with: %s\n\n' "$verify_with"
    } >>"$promoted_entries_path"

    STATE_JSON="$(printf '%s' "$STATE_JSON" | jq \
      --arg key "$cluster_key" \
      --arg gotcha_id "$gotcha_id" \
      --arg promoted_at "$promoted_at" \
      '.learning_index[$key] = ((.learning_index[$key] // {}) + {gotcha_id:$gotcha_id,promoted_at:$promoted_at})'
    )"
    update_cluster_state_metadata "$cluster_key" "$learning_id" "$title" "$category" "$topic_key" "$(printf '%s' "$cluster_json" | jq -r '.component // ""')" "$last_seen" "false"
  done <"$summary_file"

  {
    printf '# Gotchas — %s\n\n' "$skill_scope"
    printf -- '- generated_at: %s\n\n' "$(learning_timestamp_utc)"
    if [ -s "$promoted_entries_path" ]; then
      cat "$promoted_entries_path"
    else
      printf '_None._\n'
    fi
  } >"$gotchas_path"

  save_state_json "$skill_scope" "$STATE_JSON"
  rm -f "$promoted_entries_path" "$summary_file"
}

route_all_sources() {
  local sources_dir
  local source_path

  sources_dir="$(learning_sources_dir)"
  [ -d "$sources_dir" ] || return 0

  while IFS= read -r source_path; do
    [ -n "$source_path" ] || continue
    route_source_file "$source_path"
  done < <(find "$sources_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | sort)
}

prune_all_sources() {
  local sources_dir
  local source_path

  sources_dir="$(learning_sources_dir)"
  [ -d "$sources_dir" ] || return 0

  while IFS= read -r source_path; do
    [ -n "$source_path" ] || continue
    prune_source_file "$source_path"
  done < <(find "$sources_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | sort)
}

action_distill() {
  require_jq
  if [ ! -f "$LEARNING_TEMPLATE_PATH" ]; then
    log_error "Missing learned entry template: $LEARNING_TEMPLATE_PATH"
    exit 1
  fi

  mkdir -p "$LEARNING_DATA_ROOT"
  route_all_sources
  render_all_scopes
  prune_all_sources
}

action_promote() {
  local skills_root
  local skill_scope

  action_distill
  skills_root="$LEARNING_DATA_ROOT/skills"
  [ -d "$skills_root" ] || return 0

  while IFS= read -r skill_scope; do
    [ -n "$skill_scope" ] || continue
    promote_scope "$skill_scope"
  done < <(find "$skills_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sed "s#^$skills_root/##" | sort)
}

action_scope() {
  local raw_input="${1:-}"

  [ -n "$raw_input" ] || {
    usage
    exit 1
  }

  resolve_scope_input "$raw_input"
}

case "$ACTION" in
  distill)
    action_distill
    ;;
  promote)
    action_promote
    ;;
  scope)
    action_scope "${1:-}"
    ;;
esac
