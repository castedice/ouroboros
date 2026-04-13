#!/usr/bin/env bash
# Session lifecycle manager for the RnD workflow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"
ARCHIVE_ROOT="$PROJECT_ROOT/docs/research"
TEMPLATE="$PROJECT_ROOT/templates/rnd/state.json"
BUDGET_SCRIPT="$SCRIPT_DIR/rnd-budget.sh"
BRANCH_SCRIPT="$SCRIPT_DIR/rnd-branch.sh"

STAGES=(
  "scope"
  "prior-work"
  "perspectives"
  "hypotheses"
  "experiment-design"
  "probes"
  "analyze-prune"
  "report"
  "review"
  "meta-learn"
)

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <init|advance|status|list|resume|stop> ..." >&2
  exit 1
fi
shift || true

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-session.sh init <question> [--slug <slug>] [--budget <minutes>] [--branch-search]
  rnd-session.sh advance <session-id> <next-stage>
  rnd-session.sh status [session-id]
  rnd-session.sh list
  rnd-session.sh resume <session-id>
  rnd-session.sh stop <session-id> [--reason <reason>]
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 2
  fi
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

timestamp_local_id() {
  date +"%Y%m%d-%H%M%S"
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

slugify() {
  local raw="${1:-}"
  local slug=""
  slug="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')"
  if [[ -z "$slug" ]]; then
    slug="study"
  fi
  printf '%.80s\n' "$slug"
}

session_dir_rel() {
  local session_id="${1:?Missing session id}"
  printf '.rnd/sessions/%s\n' "$session_id"
}

session_dir_abs() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$PROJECT_ROOT" "$(session_dir_rel "$session_id")"
}

state_file_rel() {
  local session_id="${1:?Missing session id}"
  printf '%s/state.json\n' "$(session_dir_rel "$session_id")"
}

state_file_abs() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$PROJECT_ROOT" "$(state_file_rel "$session_id")"
}

budget_file_rel() {
  local session_id="${1:?Missing session id}"
  printf '%s/budget.json\n' "$(session_dir_rel "$session_id")"
}

budget_file_abs() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$PROJECT_ROOT" "$(budget_file_rel "$session_id")"
}

queue_file_rel() {
  local session_id="${1:?Missing session id}"
  printf '%s/queue.json\n' "$(session_dir_rel "$session_id")"
}

queue_file_abs() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$PROJECT_ROOT" "$(queue_file_rel "$session_id")"
}

handoff_dir_rel() {
  local session_id="${1:?Missing session id}"
  printf '%s/handoff\n' "$(session_dir_rel "$session_id")"
}

handoff_dir_abs() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$PROJECT_ROOT" "$(handoff_dir_rel "$session_id")"
}

archive_dir_rel() {
  local year="${1:?Missing year}"
  local slug="${2:?Missing slug}"
  printf 'docs/research/%s/%s\n' "$year" "$slug"
}

json_write() {
  local file_path="${1:?Missing file path}"
  shift
  local tmp_path="${file_path}.tmp"
  jq "$@" "$file_path" >"$tmp_path"
  mv "$tmp_path" "$file_path"
}

ensure_session_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(state_file_abs "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: Session state not found for '$session_id'." >&2
    exit 2
  fi
}

branch_search_enabled() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(state_file_abs "$session_id")"
  if [[ -f "$file_path" ]]; then
    jq -r '.branch_search.enabled // false' "$file_path"
  fi
}

stage_index() {
  local stage="${1:?Missing stage}"
  local i=0
  for candidate in "${STAGES[@]}"; do
    if [[ "$candidate" == "$stage" ]]; then
      printf '%s\n' "$i"
      return 0
    fi
    i=$((i + 1))
  done
  echo "Error: Invalid stage '$stage'." >&2
  exit 1
}

stage_exists() {
  local stage="${1:?Missing stage}"
  local candidate=""
  for candidate in "${STAGES[@]}"; do
    if [[ "$candidate" == "$stage" ]]; then
      return 0
    fi
  done
  return 1
}

latest_session_id() {
  local latest=""
  if [[ ! -d "$SESSION_ROOT" ]]; then
    return 1
  fi

  latest="$(find "$SESSION_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'rnd-*' -print 2>/dev/null | sort | tail -1)"
  if [[ -z "$latest" ]]; then
    return 1
  fi
  basename "$latest"
}

allowed_next_states_json() {
  local stage="${1:?Missing stage}"
  case "$stage" in
    scope) printf '["prior-work","stop"]\n' ;;
    prior-work) printf '["perspectives","stop"]\n' ;;
    perspectives) printf '["hypotheses","stop"]\n' ;;
    hypotheses) printf '["experiment-design","stop"]\n' ;;
    experiment-design) printf '["probes","stop"]\n' ;;
    probes) printf '["analyze-prune","stop"]\n' ;;
    analyze-prune) printf '["experiment-design","report","stop"]\n' ;;
    report) printf '["review","stop"]\n' ;;
    review) printf '["meta-learn","stop"]\n' ;;
    meta-learn) printf '["stop"]\n' ;;
    *)
      echo "Error: Invalid stage '$stage'." >&2
      exit 1
      ;;
  esac
}

artifact_paths_json() {
  local session_id="${1:?Missing session id}"
  local stage="${2:?Missing stage}"
  local archive_dir="${3:?Missing archive dir}"
  local state_path
  local budget_path

  state_path="$(state_file_rel "$session_id")"
  budget_path="$(budget_file_rel "$session_id")"

  case "$stage" in
    scope)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $state, $budget]'
      ;;
    prior-work)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $state, $budget]'
      ;;
    perspectives | hypotheses)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg backlog "$archive_dir/hypothesis-backlog.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $backlog, $state, $budget]'
      ;;
    experiment-design | probes)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg backlog "$archive_dir/hypothesis-backlog.md" \
        --arg ledger "$archive_dir/experiment-ledger.jsonl" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $backlog, $ledger, $state, $budget]'
      ;;
    analyze-prune | report)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg backlog "$archive_dir/hypothesis-backlog.md" \
        --arg ledger "$archive_dir/experiment-ledger.jsonl" \
        --arg report "$archive_dir/report.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $backlog, $ledger, $report, $state, $budget]'
      ;;
    review)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg backlog "$archive_dir/hypothesis-backlog.md" \
        --arg ledger "$archive_dir/experiment-ledger.jsonl" \
        --arg report "$archive_dir/report.md" \
        --arg review "$archive_dir/review.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $backlog, $ledger, $report, $review, $state, $budget]'
      ;;
    meta-learn)
      jq -cn \
        --arg brief "$archive_dir/brief.md" \
        --arg prior "$archive_dir/prior-work-map.md" \
        --arg backlog "$archive_dir/hypothesis-backlog.md" \
        --arg ledger "$archive_dir/experiment-ledger.jsonl" \
        --arg report "$archive_dir/report.md" \
        --arg review "$archive_dir/review.md" \
        --arg meta "$archive_dir/meta-learning.md" \
        --arg state "$state_path" \
        --arg budget "$budget_path" \
        '[$brief, $prior, $backlog, $ledger, $report, $review, $meta, $state, $budget]'
      ;;
    *)
      echo "Error: Invalid stage '$stage'." >&2
      exit 1
      ;;
  esac
}

write_handoff_files() {
  local session_id="${1:?Missing session id}"
  local file_path
  local handoff_dir
  local current_stage_name
  local archive_dir
  local budget_path
  local handoff_json
  local ts
  local unresolved_json='[]'
  local next_states_json
  local artifact_paths
  local run_status
  local stop_reason

  ensure_session_file "$session_id"
  file_path="$(state_file_abs "$session_id")"
  handoff_dir="$(handoff_dir_abs "$session_id")"
  mkdir -p "$handoff_dir"

  current_stage_name="$(jq -r '.current_stage // "scope"' "$file_path")"
  archive_dir="$(jq -r '.archive_dir' "$file_path")"
  budget_path="$(budget_file_rel "$session_id")"
  run_status="$(jq -r '.run_status // "active"' "$file_path")"
  stop_reason="$(jq -r '.stop_reason // empty' "$file_path")"
  next_states_json="$(allowed_next_states_json "$current_stage_name")"
  artifact_paths="$(artifact_paths_json "$session_id" "$current_stage_name" "$archive_dir")"
  if [[ "$(branch_search_enabled "$session_id")" == "true" && -f "$(queue_file_abs "$session_id")" ]]; then
    artifact_paths="$(
      jq -cn \
        --argjson artifact_paths "$artifact_paths" \
        --arg queue_path "$(queue_file_rel "$session_id")" \
        '$artifact_paths + [$queue_path]'
    )"
  fi
  ts="$(timestamp_utc)"

  if [[ "$run_status" == "stopped" && -n "$stop_reason" ]]; then
    unresolved_json="$(jq -cn --arg reason "$stop_reason" '[$reason]')"
  fi

  handoff_json="$(
    jq -cn \
      --arg stage_name "$current_stage_name" \
      --arg generated_at "$ts" \
      --arg budget_snapshot_path "$budget_path" \
      --argjson artifact_paths "$artifact_paths" \
      --argjson next_allowed_states "$next_states_json" \
      --argjson unresolved_questions "$unresolved_json" \
      '{
        "stage_name": $stage_name,
        "artifact_paths": $artifact_paths,
        "unresolved_questions": $unresolved_questions,
        "next_allowed_states": $next_allowed_states,
        "generated_at": $generated_at,
        "budget_snapshot_path": $budget_snapshot_path
      }'
  )"

  printf '%s\n' "$handoff_json" >"$handoff_dir/latest.json"
  printf '%s\n' "$handoff_json" >"$handoff_dir/${current_stage_name}.json"

  json_write "$file_path" \
    --argjson handoff "$handoff_json" \
    --arg ts "$ts" \
    '.latest_handoff = $handoff | .updated_at = $ts'
}

increment_loopback_usage() {
  local session_id="${1:?Missing session id}"
  local file_path
  local ts

  file_path="$(budget_file_abs "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  ts="$(timestamp_utc)"
  json_write "$file_path" \
    --arg ts "$ts" \
    '.usage.loopbacks += 1 | .updated_at = $ts'
}

sync_branch_state_from_queue() {
  local session_id="${1:?Missing session id}"
  local wave_index="${2:-}"
  local state_path
  local budget_path
  local queue_path
  local active_ids
  local pruned_ids
  local merged_ids
  local max_parallel
  local ts

  if [[ "$(branch_search_enabled "$session_id")" != "true" ]]; then
    return 0
  fi

  state_path="$(state_file_abs "$session_id")"
  budget_path="$(budget_file_abs "$session_id")"
  queue_path="$(queue_file_abs "$session_id")"

  if [[ ! -f "$queue_path" ]]; then
    return 0
  fi

  active_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "proposed") == "active") | .key]' "$queue_path")"
  pruned_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "pruned") | .key]' "$queue_path")"
  merged_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "merged") | .key]' "$queue_path")"
  max_parallel="$(jq -r '.limits.max_parallel // 0' "$budget_path")"
  if [[ -z "$wave_index" ]]; then
    wave_index="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  fi
  ts="$(timestamp_utc)"

  json_write "$state_path" \
    --argjson active_ids "$active_ids" \
    --argjson pruned_ids "$pruned_ids" \
    --argjson merged_ids "$merged_ids" \
    --argjson wave_index "$wave_index" \
    --argjson max_parallel "$max_parallel" \
    --arg ts "$ts" \
    '
      (.branch_search // {}) as $branch_search
      | .branch_search = (
          {
            "enabled": true,
            "strategy": ($branch_search.strategy // "wave"),
            "wave_index": $wave_index,
            "max_parallel": $max_parallel,
            "active_ids": $active_ids,
            "pruned_ids": $pruned_ids,
            "merged_ids": $merged_ids
          }
          + (if ($branch_search.final_summary // null) == null then {} else {"final_summary": $branch_search.final_summary} end)
        )
      | .updated_at = $ts
    '
}

activate_next_branch_wave() {
  local session_id="${1:?Missing session id}"
  local state_path
  local queue_path
  local current_wave
  local next_wave_index
  local current_wave_id
  local next_wave_id

  if [[ "$(branch_search_enabled "$session_id")" != "true" ]]; then
    printf '0\n'
    return 0
  fi

  state_path="$(state_file_abs "$session_id")"
  queue_path="$(queue_file_abs "$session_id")"
  if [[ ! -f "$queue_path" ]]; then
    printf '%s\n' "$(jq -r '.branch_search.wave_index // 0' "$state_path")"
    return 0
  fi

  current_wave="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  if (( current_wave > 0 )); then
    current_wave_id="$(printf 'wave-%03d' "$current_wave")"
    json_write "$queue_path" \
      --arg wave_id "$current_wave_id" \
      '
        .waves = [
          (.waves // [])[]
          | if .wave_id == $wave_id and (.status // "planned") == "active"
            then .status = "resolved"
            else .
            end
        ]
      '
  fi

  next_wave_index="$(jq -r --argjson current_wave "$current_wave" '
    (.waves // []) as $waves
    | [range($current_wave; ($waves | length)) | select(($waves[.].status // "planned") == "planned")] | .[0] // -1
  ' "$queue_path")"

  if (( next_wave_index >= 0 )); then
    next_wave_index=$((next_wave_index + 1))
    next_wave_id="$(printf 'wave-%03d' "$next_wave_index")"
    json_write "$queue_path" \
      --arg wave_id "$next_wave_id" \
      '
        .waves = [
          (.waves // [])[]
          | if .wave_id == $wave_id and (.status // "planned") == "planned"
            then .status = "active"
            else .
            end
        ]
      '
    printf '%s\n' "$next_wave_index"
    return 0
  fi

  printf '%s\n' "$current_wave"
}

action_init() {
  local budget_minutes=90
  local slug_override=""
  local enable_branch_search=0
  local question_parts=()
  local question=""
  local session_id=""
  local session_dir=""
  local archive_dir=""
  local year=""
  local slug=""
  local ts=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slug|--budget)
        break
        ;;
      --branch-search)
        break
        ;;
      *)
        question_parts+=("$1")
        shift
        ;;
    esac
  done

  question="${question_parts[*]}"
  if [[ -z "$question" ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slug)
        slug_override="${2:?Missing value after --slug}"
        shift 2
        ;;
      --budget)
        budget_minutes="${2:?Missing value after --budget}"
        shift 2
        ;;
      --branch-search)
        enable_branch_search=1
        shift
        ;;
      *)
        echo "Error: Unknown flag '$1'." >&2
        usage
        exit 1
        ;;
    esac
  done

  if ! is_positive_integer "$budget_minutes"; then
    echo "Error: Budget minutes must be a non-negative integer." >&2
    exit 1
  fi

  year="$(date +%Y)"
  slug="$(slugify "${slug_override:-$question}")"
  session_id="rnd-$(timestamp_local_id)"
  session_dir="$(session_dir_abs "$session_id")"
  archive_dir="$(archive_dir_rel "$year" "$slug")"
  ts="$(timestamp_utc)"

  if [[ -d "$session_dir" ]]; then
    echo "Error: Session directory already exists for '$session_id'." >&2
    exit 2
  fi

  mkdir -p "$session_dir"
  mkdir -p "$(handoff_dir_abs "$session_id")"
  mkdir -p "$session_dir/probe-runs"
  mkdir -p "$PROJECT_ROOT/$archive_dir"

  cp "$TEMPLATE" "$(state_file_abs "$session_id")"

  json_write "$(state_file_abs "$session_id")" \
    --arg session_id "$session_id" \
    --arg question "$question" \
    --arg slug "$slug" \
    --arg year "$year" \
    --arg session_dir "$(session_dir_rel "$session_id")" \
    --arg archive_dir "$archive_dir" \
    --arg handoff_dir "$(handoff_dir_rel "$session_id")" \
    --arg ts "$ts" \
    '
      .schema_version = "rnd-session-state.v1"
      | .session_id = $session_id
      | .question = $question
      | .slug = $slug
      | .year = $year
      | .run_status = "active"
      | .current_stage = "scope"
      | .loop_count = 0
      | .session_dir = $session_dir
      | .archive_dir = $archive_dir
      | .handoff_dir = $handoff_dir
      | .artifacts = {
          "brief": ($archive_dir + "/brief.md"),
          "prior_work_map": ($archive_dir + "/prior-work-map.md"),
          "hypothesis_backlog": ($archive_dir + "/hypothesis-backlog.md"),
          "experiment_ledger": ($archive_dir + "/experiment-ledger.jsonl"),
          "report": ($archive_dir + "/report.md"),
          "review": ($archive_dir + "/review.md"),
          "meta_learning": ($archive_dir + "/meta-learning.md")
        }
      | .latest_handoff = {
          "stage_name": "scope",
          "artifact_paths": [],
          "unresolved_questions": [],
          "next_allowed_states": ["prior-work", "stop"],
          "generated_at": $ts,
          "budget_snapshot_path": ""
        }
      | .transitions = [
          {
            "from": null,
            "to": "scope",
            "type": "init",
            "timestamp": $ts
          }
        ]
      | .stop_reason = null
      | .started_at = $ts
      | .updated_at = $ts
      | .stopped_at = null
      | .completed_at = null
    '

  bash "$BUDGET_SCRIPT" init "$session_id" --wall-clock $((budget_minutes * 60)) >/dev/null
  if [[ "$enable_branch_search" -eq 1 ]]; then
    bash "$BRANCH_SCRIPT" init "$session_id" '[]' >/dev/null
  fi
  write_handoff_files "$session_id"

  echo "Session ID: $session_id"
  echo "Question: $question"
  echo "Archive: $archive_dir"
  echo "State: $(state_file_rel "$session_id")"
  echo "Budget: $(budget_file_rel "$session_id")"
  if [[ "$enable_branch_search" -eq 1 ]]; then
    echo "Queue: $(queue_file_rel "$session_id")"
  fi
  echo "Current stage: scope"
}

action_advance() {
  local session_id="${1:-}"
  local next_stage="${2:-}"
  local file_path
  local current_stage_name
  local current_index
  local next_index
  local run_status
  local ts
  local loop_count
  local max_loops
  local budget_path
  local branch_wave_index=""
  local transition_type="forward"

  if [[ -z "$session_id" || -z "$next_stage" ]]; then
    usage
    exit 1
  fi

  if ! stage_exists "$next_stage"; then
    echo "Error: Invalid stage '$next_stage'." >&2
    exit 1
  fi

  ensure_session_file "$session_id"
  file_path="$(state_file_abs "$session_id")"
  current_stage_name="$(jq -r '.current_stage // empty' "$file_path")"
  run_status="$(jq -r '.run_status // "active"' "$file_path")"
  ts="$(timestamp_utc)"

  if [[ "$run_status" == "stopped" || "$run_status" == "completed" ]]; then
    echo "Error: Session '$session_id' is not advanceable because run_status is '$run_status'." >&2
    exit 2
  fi

  if [[ -z "$current_stage_name" ]]; then
    echo "Error: Session '$session_id' has no current stage." >&2
    exit 2
  fi

  current_index="$(stage_index "$current_stage_name")"
  next_index="$(stage_index "$next_stage")"

  if [[ "$current_stage_name" == "analyze-prune" && "$next_stage" == "experiment-design" ]]; then
    transition_type="loopback"
    budget_path="$(budget_file_abs "$session_id")"
    loop_count="$(jq -r '.usage.loopbacks // 0' "$budget_path")"
    max_loops="$(jq -r '.limits.max_loops // 0' "$budget_path")"
    if (( loop_count >= max_loops )); then
      echo "Error: Loopback cap reached for '$session_id' ($loop_count/$max_loops)." >&2
      exit 2
    fi

    json_write "$file_path" \
      --arg current_stage "$current_stage_name" \
      --arg next_stage "$next_stage" \
      --arg ts "$ts" \
      '
        .stages[$current_stage] = "completed"
        | .stages["experiment-design"] = "running"
        | .stages["probes"] = "pending"
        | .stages["analyze-prune"] = "pending"
        | .stages["report"] = "pending"
        | .stages["review"] = "pending"
        | .stages["meta-learn"] = "pending"
        | .current_stage = $next_stage
        | .run_status = "active"
        | .pending_checkpoint = null
        | .checkpoint_prompt = null
        | .checkpoint_options = null
        | .checkpoint_artifact = null
        | .blocked_reason = null
        | .loop_count += 1
        | .updated_at = $ts
        | .transitions += [
            {
              "from": $current_stage,
              "to": $next_stage,
              "type": "loopback",
              "timestamp": $ts
            }
          ]
      '
    increment_loopback_usage "$session_id"
    if [[ "$(branch_search_enabled "$session_id")" == "true" ]]; then
      branch_wave_index="$(activate_next_branch_wave "$session_id")"
    fi
  elif (( next_index == current_index + 1 )); then
    json_write "$file_path" \
      --arg current_stage "$current_stage_name" \
      --arg next_stage "$next_stage" \
      --arg ts "$ts" \
      '
        .stages[$current_stage] = "completed"
        | .stages[$next_stage] = "running"
        | .current_stage = $next_stage
        | .run_status = "active"
        | .pending_checkpoint = null
        | .checkpoint_prompt = null
        | .checkpoint_options = null
        | .checkpoint_artifact = null
        | .blocked_reason = null
        | .updated_at = $ts
        | .transitions += [
            {
              "from": $current_stage,
              "to": $next_stage,
              "type": "forward",
              "timestamp": $ts
            }
          ]
      '
  else
    echo "Error: Invalid transition '$current_stage_name' -> '$next_stage'." >&2
    exit 1
  fi

  if [[ "$(branch_search_enabled "$session_id")" == "true" ]]; then
    sync_branch_state_from_queue "$session_id" "${branch_wave_index:-}"
  fi

  write_handoff_files "$session_id"
  echo "Advanced $session_id: $current_stage_name -> $next_stage ($transition_type)"
}

action_status() {
  local session_id="${1:-}"
  local file_path
  local question
  local archive_dir
  local run_status
  local current_stage_name
  local loop_count
  local updated_at
  local branch_enabled
  local active_count
  local pruned_count
  local merged_count
  local current_wave
  local total_waves
  local stage_name

  if [[ -z "$session_id" ]]; then
    session_id="$(latest_session_id || true)"
  fi

  if [[ -z "$session_id" ]]; then
    echo "Error: No RnD sessions found." >&2
    exit 2
  fi

  ensure_session_file "$session_id"
  file_path="$(state_file_abs "$session_id")"
  question="$(jq -r '.question' "$file_path" | head -c 80)"
  archive_dir="$(jq -r '.archive_dir' "$file_path")"
  run_status="$(jq -r '.run_status' "$file_path")"
  current_stage_name="$(jq -r '.current_stage // "none"' "$file_path")"
  loop_count="$(jq -r '.loop_count // 0' "$file_path")"
  updated_at="$(jq -r '.updated_at' "$file_path")"
  branch_enabled="$(jq -r '.branch_search.enabled // false' "$file_path")"

  echo "=== RnD Session ==="
  echo "Session: $session_id"
  echo "Question: $question"
  echo "Archive: $archive_dir"
  echo "Run status: $run_status"
  echo "Current stage: $current_stage_name | Loops: $loop_count | Updated: $updated_at"
  if [[ "$branch_enabled" == "true" && -f "$(queue_file_abs "$session_id")" ]]; then
    active_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "proposed") == "active")] | length' "$(queue_file_abs "$session_id")")"
    pruned_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "pruned")] | length' "$(queue_file_abs "$session_id")")"
    merged_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "merged")] | length' "$(queue_file_abs "$session_id")")"
    current_wave="$(jq -r '.branch_search.wave_index // 0' "$file_path")"
    total_waves="$(jq -r '(.waves // []) | length' "$(queue_file_abs "$session_id")")"
    echo "Branch summary: active=$active_count pruned=$pruned_count merged=$merged_count wave=$current_wave/$total_waves"
  fi
  echo ""
  printf '%-20s %s\n' "STAGE" "STATUS"
  printf '%-20s %s\n' "────────────────────" "──────────"
  for stage_name in "${STAGES[@]}"; do
    local marker=""
    local stage_status
    stage_status="$(jq -r --arg stage_name "$stage_name" '.stages[$stage_name]' "$file_path")"
    if [[ "$stage_name" == "$current_stage_name" ]]; then
      marker=" ←"
    fi
    printf '%-20s %s%s\n' "$stage_name" "$stage_status" "$marker"
  done
  echo ""
  bash "$BUDGET_SCRIPT" status "$session_id"
}

action_list() {
  local session_path
  local session_id
  local file_path

  if [[ ! -d "$SESSION_ROOT" ]]; then
    echo "No RnD sessions found."
    return 0
  fi

  printf '%-20s %-18s %-20s %-8s %s\n' "SESSION" "STATUS" "CURRENT_STAGE" "LOOPS" "UPDATED_AT"
  printf '%-20s %-18s %-20s %-8s %s\n' "────────────────────" "──────────────────" "────────────────────" "────────" "────────────────────"
  while IFS= read -r session_path; do
    [[ -n "$session_path" ]] || continue
    session_id="$(basename "$session_path")"
    file_path="$session_path/state.json"
    if [[ ! -f "$file_path" ]]; then
      continue
    fi
    printf '%-20s %-18s %-20s %-8s %s\n' \
      "$session_id" \
      "$(jq -r '.run_status // "unknown"' "$file_path")" \
      "$(jq -r '.current_stage // "none"' "$file_path")" \
      "$(jq -r '.loop_count // 0' "$file_path")" \
      "$(jq -r '.updated_at // ""' "$file_path")"
  done < <(find "$SESSION_ROOT" -mindepth 1 -maxdepth 1 -type d -name 'rnd-*' -print 2>/dev/null | sort)
}

action_resume() {
  local session_id="${1:-}"
  local file_path
  local run_status
  local current_stage_name
  local handoff_file

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi

  ensure_session_file "$session_id"
  file_path="$(state_file_abs "$session_id")"
  run_status="$(jq -r '.run_status // "active"' "$file_path")"
  current_stage_name="$(jq -r '.current_stage // "scope"' "$file_path")"

  if [[ "$run_status" == "stopped" || "$run_status" == "completed" ]]; then
    echo "Error: Session '$session_id' is not resumable because run_status is '$run_status'." >&2
    exit 2
  fi

  write_handoff_files "$session_id"
  handoff_file="$(handoff_dir_rel "$session_id")/latest.json"

  echo "Session: $session_id"
  echo "Run status: $run_status"
  echo "Resume stage: $current_stage_name"
  echo "Handoff: $handoff_file"
  echo "Artifact paths:"
  jq -r '.latest_handoff.artifact_paths[] | "- " + .' "$file_path"
}

action_stop() {
  local session_id="${1:-}"
  local reason="user_stop"
  local file_path
  local current_stage_name
  local ts

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason)
        reason="${2:?Missing value after --reason}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag '$1'." >&2
        usage
        exit 1
        ;;
    esac
  done

  ensure_session_file "$session_id"
  file_path="$(state_file_abs "$session_id")"
  current_stage_name="$(jq -r '.current_stage // "scope"' "$file_path")"
  ts="$(timestamp_utc)"

  json_write "$file_path" \
    --arg stage_name "$current_stage_name" \
    --arg reason "$reason" \
    --arg ts "$ts" \
    '
      .run_status = "stopped"
      | .stages[$stage_name] = "stopped"
      | .stop_reason = $reason
      | .stopped_at = $ts
      | .updated_at = $ts
      | .transitions += [
          {
            "from": $stage_name,
            "to": "stop",
            "type": "stop",
            "timestamp": $ts,
            "reason": $reason
          }
        ]
    '

  write_handoff_files "$session_id"
  echo "Stopped $session_id"
  echo "Reason: $reason"
}

require_jq

case "$ACTION" in
  init) action_init "$@" ;;
  advance) action_advance "$@" ;;
  status) action_status "$@" ;;
  list) action_list "$@" ;;
  resume) action_resume "$@" ;;
  stop) action_stop "$@" ;;
  *)
    echo "Error: Unknown action '$ACTION'." >&2
    usage
    exit 1
    ;;
esac
