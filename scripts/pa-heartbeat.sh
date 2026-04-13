#!/usr/bin/env bash
# pa-heartbeat.sh - lightweight shell-based PA health checker.
#
# Actions:
#   check [vault-path]
#   status [vault-path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PA_RELATIONSHIP_SCRIPT="$SCRIPT_DIR/pa-relationship.sh"

QMD_STALE_SECONDS=$((24 * 60 * 60))
WEEK_REVIEW_STALE_SECONDS=$((10 * 24 * 60 * 60))
MONTH_REVIEW_STALE_SECONDS=$((45 * 24 * 60 * 60))
SURVEY_STALE_SECONDS=$((7 * 24 * 60 * 60))
CALENDAR_STALE_SECONDS=$((30 * 60 * 60))

VAULT_PATH=""
PA_DIR=""
SETTINGS_PATH=""
DERIVATION_STATE_PATH=""
REVIEW_STATE_PATH=""
INTEGRATIONS_STATE_PATH=""
MEMORY_STATE_PATH=""
PENDING_MEMORY_PATH=""
ENTITIES_PATH=""
ENTITY_REVISIONS_PATH=""
MEMORIES_PATH=""
MEMORY_HEADS_PATH=""
SESSIONS_DIR=""
MASK_MAP_PATH=""
HASH_INDEX_PATH=""
HEARTBEAT_PATH=""

CHECK_QMD_STATUS=""
CHECK_QMD_DETAIL=""
CHECK_SHADOW_STATUS=""
CHECK_SHADOW_DETAIL=""
CHECK_ONTOLOGY_STATUS=""
CHECK_ONTOLOGY_DETAIL=""
CHECK_MEMORY_STATUS=""
CHECK_MEMORY_DETAIL=""
CHECK_REVIEW_STATUS=""
CHECK_REVIEW_DETAIL=""
CHECK_SURVEY_STATUS=""
CHECK_SURVEY_DETAIL=""
CHECK_PRIVACY_STATUS=""
CHECK_PRIVACY_DETAIL=""
CHECK_RELATIONSHIPS_STATUS=""
CHECK_RELATIONSHIPS_DETAIL=""
CHECK_CALENDAR_STATUS=""
CHECK_CALENDAR_DETAIL=""

SUMMARY_ITEMS=()
RECOMMENDED_ACTIONS=()

usage() {
  cat <<'EOF'
pa-heartbeat.sh <action> [vault-path]

Actions:
  check [vault-path]   - Run PA health checks and save .pa/heartbeat.json
  status [vault-path]  - Show the latest heartbeat summary
EOF
}

die_user() {
  echo "Error: $1" >&2
  exit 1
}

die_system() {
  echo "Error: $1" >&2
  exit 2
}

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die_system "jq is required."
}

expand_home_path() {
  local path="${1:-}"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path#\~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

resolve_absolute_dir() {
  local path="$1"

  [[ -n "$path" ]] || die_user "vault path is required"
  [[ -d "$path" ]] || die_user "vault path is not a directory: $path"

  (
    cd "$path" && pwd -P
  ) || die_system "Failed to resolve vault path: $path"
}

detect_default_vault_path() {
  local env_path=""
  local collections=""
  local coll=""
  local vault_path=""
  local settings_path=""
  local vault_root=""

  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    env_path="$(expand_home_path "$PA_VAULT_PATH")"
    if [[ -d "$env_path" ]] && [[ -d "$env_path/.pa" ]]; then
      resolve_absolute_dir "$env_path"
      return
    fi
  fi

  if command -v qmd >/dev/null 2>&1; then
    collections=$(qmd collection list 2>/dev/null | sed -n 's/^\([a-zA-Z0-9_-]*\) (qmd:.*/\1/p' || true)
    for coll in $collections; do
      vault_path=$(qmd collection show "$coll" 2>/dev/null | awk '/Path:/{print $2}' || true)
      [[ -n "$vault_path" ]] || continue
      settings_path="$vault_path/.pa/settings.json"
      [[ -f "$settings_path" ]] || continue
      vault_root=$(jq -r '.vault_root // empty' "$settings_path" 2>/dev/null || true)
      if [[ -n "$vault_root" ]] && [[ -d "$vault_root/.pa" ]]; then
        resolve_absolute_dir "$vault_root"
        return
      fi
      if [[ -d "$vault_path/.pa" ]]; then
        resolve_absolute_dir "$vault_path"
        return
      fi
    done
  fi

  if [[ -d ".pa" || -d ".obsidian" ]]; then
    pwd -P
    return
  fi

  printf '\n'
}

resolve_vault_path() {
  local explicit_path="${1:-}"
  local detected_path=""

  if [[ -n "$explicit_path" ]]; then
    resolve_absolute_dir "$explicit_path"
    return
  fi

  detected_path="$(detect_default_vault_path)"
  [[ -n "$detected_path" ]] || die_user "vault path required. Set PA_VAULT_PATH, rely on QMD collection discovery, or run from the vault root."
  printf '%s\n' "$detected_path"
}

set_vault_context() {
  VAULT_PATH="$1"
  PA_DIR="$VAULT_PATH/.pa"
  SETTINGS_PATH="$PA_DIR/settings.json"
  DERIVATION_STATE_PATH="$PA_DIR/derivation-state.json"
  REVIEW_STATE_PATH="$PA_DIR/review-state.json"
  INTEGRATIONS_STATE_PATH="$PA_DIR/integrations-state.json"
  MEMORY_STATE_PATH="$PA_DIR/memory/state.json"
  PENDING_MEMORY_PATH="$PA_DIR/memory/.pending-flush.jsonl"
  ENTITIES_PATH="$PA_DIR/entities.json"
  ENTITY_REVISIONS_PATH="$PA_DIR/entity-revisions.jsonl"
  MEMORIES_PATH="$PA_DIR/memories.jsonl"
  MEMORY_HEADS_PATH="$PA_DIR/memory-heads.json"
  SESSIONS_DIR="$PA_DIR/sessions"
  MASK_MAP_PATH="$PA_DIR/mask-map.json"
  HASH_INDEX_PATH="$PA_DIR/hash-index.json"
  HEARTBEAT_PATH="$PA_DIR/heartbeat.json"
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die_user ".pa directory not found: $PA_DIR"
}

json_file_valid() {
  local path="$1"

  [[ -f "$path" ]] || return 1
  jq empty "$path" >/dev/null 2>&1
}

jsonl_file_valid() {
  local path="$1"

  [[ -f "$path" ]] || return 1
  jq -s '.' "$path" >/dev/null 2>&1
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

normalize_iso_input() {
  printf '%s' "$1" | sed -E 's/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/'
}

iso_to_epoch() {
  local input="$1"
  local normalized=""
  local epoch=""

  [[ -n "$input" ]] || return 1
  normalized="$(normalize_iso_input "$input")"

  if [[ "$normalized" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    epoch=$(date -j -f '%Y-%m-%d' "$normalized" '+%s' 2>/dev/null || true)
    if [[ -z "$epoch" ]]; then
      epoch=$(date -d "$normalized" '+%s' 2>/dev/null || true)
    fi
  else
    epoch=$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' 2>/dev/null || true)
    if [[ -z "$epoch" ]]; then
      epoch=$(date -d "$input" '+%s' 2>/dev/null || true)
    fi
  fi

  [[ -n "$epoch" ]] || return 1
  printf '%s\n' "$epoch"
}

now_epoch() {
  date '+%s'
}

humanize_age() {
  local seconds="${1:-0}"

  if [[ "$seconds" -lt 60 ]]; then
    printf '%ss\n' "$seconds"
  elif [[ "$seconds" -lt 3600 ]]; then
    printf '%sm\n' $((seconds / 60))
  elif [[ "$seconds" -lt 86400 ]]; then
    printf '%sh\n' $((seconds / 3600))
  elif [[ "$seconds" -lt 604800 ]]; then
    printf '%sd\n' $((seconds / 86400))
  elif [[ "$seconds" -lt 2592000 ]]; then
    printf '%sw\n' $((seconds / 604800))
  else
    printf '%smo\n' $((seconds / 2592000))
  fi
}

relative_age_to_seconds() {
  local text="$1"
  local value=""
  local unit=""

  case "$text" in
    "just now")
      printf '0\n'
      return 0
      ;;
  esac

  if [[ "$text" =~ ^([0-9]+)(s|m|h|d|w|mo|y)[[:space:]]+ago$ ]]; then
    value="${BASH_REMATCH[1]}"
    unit="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  case "$unit" in
    s)
      printf '%s\n' "$value"
      ;;
    m)
      printf '%s\n' $((value * 60))
      ;;
    h)
      printf '%s\n' $((value * 3600))
      ;;
    d)
      printf '%s\n' $((value * 86400))
      ;;
    w)
      printf '%s\n' $((value * 604800))
      ;;
    mo)
      printf '%s\n' $((value * 2592000))
      ;;
    y)
      printf '%s\n' $((value * 31536000))
      ;;
    *)
      return 1
      ;;
  esac
}

count_vault_markdown_files() {
  find "$VAULT_PATH" \
    \( \
    -path "$VAULT_PATH/.obsidian" -o \
    -path "$VAULT_PATH/.trash" -o \
    -path "$VAULT_PATH/.git" -o \
    -path "$VAULT_PATH/.pa" \
    \) -prune -o \
    -type f -name '*.md' -print | wc -l | awk '{$1=$1; print}'
}

count_shadow_markdown_files() {
  local shadow_root="$1"
  find "$shadow_root" -type f -name '*.md' -print | wc -l | awk '{$1=$1; print}'
}

line_count_or_zero() {
  local path="$1"

  [[ -f "$path" ]] || {
    printf '0\n'
    return
  }

  wc -l <"$path" | awk '{$1=$1; print}'
}

join_with_semicolon() {
  local result=""
  local part=""

  for part in "$@"; do
    [[ -n "$part" ]] || continue
    if [[ -z "$result" ]]; then
      result="$part"
    else
      result="$result; $part"
    fi
  done

  printf '%s\n' "$result"
}

latest_review_timestamp() {
  if ! json_file_valid "$REVIEW_STATE_PATH"; then
    printf '\n'
    return
  fi

  jq -r '
    [.last_review[]?.timestamp | select(type == "string" and length > 0)]
    | sort
    | last // empty
  ' "$REVIEW_STATE_PATH" 2>/dev/null || printf '\n'
}

count_pending_coreference_candidates() {
  local file=""
  local file_count="0"
  local pending="0"

  [[ -d "$SESSIONS_DIR" ]] || {
    printf '0\n'
    return
  }

  while IFS= read -r -d '' file; do
    file_count=$((file_count + 1))
    if jq empty "$file" >/dev/null 2>&1; then
      pending=$((pending + $(jq '
        (.unresolved_entities // [])
        | map(
            select(
              ((.status // .review_status // "pending") as $state
              | $state == "pending"
              or $state == "needs_review"
              or $state == "unresolved"
              or $state == "proposed"
              or $state == "deferred")
            )
          )
        | length
      ' "$file" 2>/dev/null || printf '0')))
    fi
  done < <(find "$SESSIONS_DIR" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

  if [[ "$file_count" -eq 0 ]]; then
    printf '0\n'
    return
  fi

  printf '%s\n' "$pending"
}

count_unsurfaced_contested_groups() {
  local newest_signal=""
  local newest_epoch=""
  local latest_review=""
  local latest_review_epoch=""
  local count="0"
  local age_seconds="0"

  jsonl_file_valid "$MEMORIES_PATH" || {
    printf '0\n'
    return
  }

  latest_review="$(latest_review_timestamp)"
  if [[ -n "$latest_review" ]]; then
    latest_review_epoch="$(iso_to_epoch "$latest_review" 2>/dev/null || true)"
  fi

  while IFS= read -r newest_signal; do
    [[ -n "$newest_signal" ]] || continue
    newest_epoch="$(iso_to_epoch "$newest_signal" 2>/dev/null || true)"
    [[ -n "$newest_epoch" ]] || continue
    age_seconds=$(( $(now_epoch) - newest_epoch ))
    if [[ "$age_seconds" -lt 0 ]]; then
      age_seconds="0"
    fi
    if [[ "$age_seconds" -lt 1209600 ]]; then
      continue
    fi
    if [[ -z "$latest_review_epoch" ]] || [[ "$latest_review_epoch" -lt "$newest_epoch" ]]; then
      count=$((count + 1))
    fi
  done < <(
    jq -rs '
      def signal_ts:
        ([.event_dates[]?.end?, .event_dates[]?.start?, .document_date?]
        | map(select(type == "string" and length > 0))
        | sort
        | last // "");
      map(select(.state == "contested") | . + {signal_ts: signal_ts})
      | group_by((.subject_id // "") + "|" + (.predicate // ""))
      | map([.[].signal_ts] | map(select(length > 0)) | sort | last // "")
      | .[]
    ' "$MEMORIES_PATH" 2>/dev/null
  )

  printf '%s\n' "$count"
}

set_check_result() {
  local name="$1"
  local status="$2"
  local detail="$3"

  case "$name" in
    qmd)
      CHECK_QMD_STATUS="$status"
      CHECK_QMD_DETAIL="$detail"
      ;;
    shadow)
      CHECK_SHADOW_STATUS="$status"
      CHECK_SHADOW_DETAIL="$detail"
      ;;
    ontology)
      CHECK_ONTOLOGY_STATUS="$status"
      CHECK_ONTOLOGY_DETAIL="$detail"
      ;;
    memory)
      CHECK_MEMORY_STATUS="$status"
      CHECK_MEMORY_DETAIL="$detail"
      ;;
    review)
      CHECK_REVIEW_STATUS="$status"
      CHECK_REVIEW_DETAIL="$detail"
      ;;
    survey)
      CHECK_SURVEY_STATUS="$status"
      CHECK_SURVEY_DETAIL="$detail"
      ;;
    privacy)
      CHECK_PRIVACY_STATUS="$status"
      CHECK_PRIVACY_DETAIL="$detail"
      ;;
    relationships)
      CHECK_RELATIONSHIPS_STATUS="$status"
      CHECK_RELATIONSHIPS_DETAIL="$detail"
      ;;
    calendar)
      CHECK_CALENDAR_STATUS="$status"
      CHECK_CALENDAR_DETAIL="$detail"
      ;;
    *)
      die_system "Unknown check name: $name"
      ;;
  esac
}

add_summary() {
  SUMMARY_ITEMS+=("$1")
}

add_action() {
  RECOMMENDED_ACTIONS+=("$1")
}

extract_qmd_collection_age() {
  local qmd_output="$1"
  local collection_name="$2"

  awk -v target="$collection_name" '
    $1 == target && $2 ~ /^\(qmd:\/\// { in_target = 1; next }
    in_target && /Files:/ {
      line = $0
      sub(/^.*\(updated /, "", line)
      sub(/\).*$/, "", line)
      print line
      exit
    }
    in_target && /^[^[:space:]]/ { in_target = 0 }
  ' <<<"$qmd_output"
}

extract_qmd_global_age() {
  local qmd_output="$1"

  awk '
    /^[[:space:]]*Updated:/ {
      line = $0
      sub(/^.*Updated:[[:space:]]*/, "", line)
      print line
      exit
    }
  ' <<<"$qmd_output"
}

check_qmd() {
  local qmd_output=""
  local collection_name=""
  local relative_age=""
  local age_seconds=""

  if ! command -v qmd >/dev/null 2>&1; then
    set_check_result "qmd" "error" "qmd is not installed"
    add_summary "QMD CLI is unavailable."
    add_action "Install qmd and refresh the PA index."
    return
  fi

  qmd_output="$(qmd status 2>/dev/null || true)"
  if [[ -z "$qmd_output" ]]; then
    set_check_result "qmd" "error" "qmd status returned no output"
    add_summary "QMD status could not be read."
    add_action "Run qmd status manually and repair the index."
    return
  fi

  if json_file_valid "$SETTINGS_PATH"; then
    collection_name="$(jq -r '.qmd_collection_name // empty' "$SETTINGS_PATH" 2>/dev/null || true)"
  fi

  if [[ -n "$collection_name" ]]; then
    relative_age="$(extract_qmd_collection_age "$qmd_output" "$collection_name")"
  fi

  if [[ -z "$relative_age" ]]; then
    relative_age="$(extract_qmd_global_age "$qmd_output")"
  fi

  if [[ -z "$relative_age" ]] || ! age_seconds="$(relative_age_to_seconds "$relative_age" 2>/dev/null)"; then
    set_check_result "qmd" "warning" "Unable to parse qmd freshness from qmd status"
    add_summary "QMD freshness is unknown."
    add_action "Run qmd status and verify the index was updated recently."
    return
  fi

  if [[ "$age_seconds" -le "$QMD_STALE_SECONDS" ]]; then
    if [[ -n "$collection_name" ]]; then
      set_check_result "qmd" "ok" "Collection $collection_name updated $relative_age"
    else
      set_check_result "qmd" "ok" "QMD index updated $relative_age"
    fi
    return
  fi

  if [[ -n "$collection_name" ]]; then
    set_check_result "qmd" "warning" "Collection $collection_name updated $relative_age"
  else
    set_check_result "qmd" "warning" "QMD index updated $relative_age"
  fi
  add_summary "QMD index is stale ($relative_age)."
  add_action "Run qmd update and qmd embed for the PA collection."
}

check_shadow() {
  local shadow_root=""
  local vault_count="0"
  local shadow_count="0"

  if ! json_file_valid "$SETTINGS_PATH"; then
    set_check_result "shadow" "error" "settings.json is missing or malformed"
    add_summary "Shadow vault settings are unavailable."
    add_action "Repair .pa/settings.json and rerun pa-shadow.sh."
    return
  fi

  shadow_root="$(jq -r '.shadow_root // empty' "$SETTINGS_PATH" 2>/dev/null || true)"
  shadow_root="$(expand_home_path "$shadow_root")"

  if [[ -z "$shadow_root" ]]; then
    set_check_result "shadow" "error" "shadow_root is not configured"
    add_summary "Shadow vault is not configured."
    add_action "Run bash scripts/pa-shadow.sh sync \"$VAULT_PATH\"."
    return
  fi

  if [[ ! -d "$shadow_root" ]]; then
    set_check_result "shadow" "error" "shadow_root not found: $shadow_root"
    add_summary "Shadow vault directory is missing."
    add_action "Run bash scripts/pa-shadow.sh sync \"$VAULT_PATH\"."
    return
  fi

  vault_count="$(count_vault_markdown_files)"
  shadow_count="$(count_shadow_markdown_files "$shadow_root")"

  if [[ "$vault_count" -eq "$shadow_count" ]]; then
    set_check_result "shadow" "ok" "Shadow file count matches vault ($shadow_count markdown files)"
    return
  fi

  set_check_result "shadow" "warning" "Shadow file count mismatch: vault=$vault_count shadow=$shadow_count"
  add_summary "Shadow vault is out of sync with the vault."
  add_action "Run bash scripts/pa-shadow.sh sync \"$VAULT_PATH\" --incremental."
}

check_ontology() {
  local pending_count="0"
  local last_updated=""
  local updated_epoch=""
  local age_seconds=""
  local detail=""
  local entity_count="0"
  local revision_count="0"
  local unresolved_coref_count="0"
  local revision_detail="entity revisions not tracked"
  local detail_parts=()
  local has_warning="false"

  if ! json_file_valid "$DERIVATION_STATE_PATH"; then
    set_check_result "ontology" "error" "derivation-state.json is missing or malformed"
    add_summary "Ontology derivation state is unavailable."
    add_action "Repair .pa/derivation-state.json and rerun a PA survey or steward pass."
    return
  fi

  pending_count=$(jq '
    (.dirty_paths // [])
    | map(
        if type == "string" then
          .
        elif type == "object" and ((.ontology_status // "pending") != "refreshed") then
          .
        else
          empty
        end
      )
    | length
  ' "$DERIVATION_STATE_PATH" 2>/dev/null || printf '0')
  last_updated="$(jq -r '.last_updated // empty' "$DERIVATION_STATE_PATH" 2>/dev/null || true)"
  detail_parts+=("pending dirty paths=$pending_count")
  if [[ -n "$last_updated" ]] && updated_epoch="$(iso_to_epoch "$last_updated" 2>/dev/null)"; then
    age_seconds=$(( $(now_epoch) - updated_epoch ))
    detail_parts+=("derivation updated $(humanize_age "$age_seconds") ago")
  fi

  if json_file_valid "$ENTITIES_PATH"; then
    entity_count="$(jq 'length' "$ENTITIES_PATH" 2>/dev/null || printf '0')"
    if [[ "$entity_count" -gt 0 ]]; then
      if jsonl_file_valid "$ENTITY_REVISIONS_PATH"; then
        revision_count="$(line_count_or_zero "$ENTITY_REVISIONS_PATH")"
        revision_detail="entity revisions=$revision_count"
      else
        revision_detail="entity revisions missing"
        has_warning="true"
        add_summary "Entity revision history is unavailable."
        add_action "Restore .pa/entity-revisions.jsonl or rerun /pa survey to rebuild revision state."
      fi
    fi
  fi
  detail_parts+=("$revision_detail")

  unresolved_coref_count="$(count_pending_coreference_candidates)"
  detail_parts+=("pending coreference candidates=$unresolved_coref_count")

  if [[ "$pending_count" -gt 0 ]]; then
    has_warning="true"
    add_summary "Ontology refresh is pending for $pending_count paths."
    add_action "Run /pa steward, /pa review, or the next ontology refresh pass."
  fi

  if [[ "$unresolved_coref_count" -gt 0 ]]; then
    has_warning="true"
    add_summary "Unresolved coreference candidates are awaiting review."
    add_action "Run /pa steward to confirm or reject pending merge proposals."
  fi

  detail="$(join_with_semicolon "${detail_parts[@]}")"

  if [[ "$has_warning" == "true" ]]; then
    set_check_result "ontology" "warning" "$detail"
    return
  fi

  set_check_result "ontology" "ok" "$detail"
}

check_memory() {
  local flush_requested="false"
  local pending_count="0"
  local fact_count="0"
  local head_count="0"
  local unsurfaced_contested="0"
  local detail=""
  local detail_parts=()
  local has_warning="false"
  local has_error="false"

  if json_file_valid "$MEMORY_STATE_PATH"; then
    flush_requested="$(jq -r 'if .flush_requested == true then "true" else "false" end' "$MEMORY_STATE_PATH" 2>/dev/null || printf 'false')"
    pending_count="$(line_count_or_zero "$PENDING_MEMORY_PATH")"
    detail_parts+=("flush_requested=$flush_requested")
    detail_parts+=("pending_messages=$pending_count")
    if [[ "$flush_requested" != "false" ]] || [[ "$pending_count" -gt 0 ]]; then
      has_warning="true"
      add_summary "Memory flush is pending."
      add_action "Run a PA command to process .pa/memory/.pending-flush.jsonl."
    fi
  else
    detail_parts+=("flush state unavailable")
    has_warning="true"
    add_summary "Memory flush state is unavailable."
    add_action "Run a PA command to recreate memory state."
  fi

  if [[ -f "$MEMORIES_PATH" ]]; then
    if jsonl_file_valid "$MEMORIES_PATH"; then
      fact_count="$(line_count_or_zero "$MEMORIES_PATH")"
      detail_parts+=("facts=$fact_count")
      if json_file_valid "$MEMORY_HEADS_PATH"; then
        head_count="$(jq 'length' "$MEMORY_HEADS_PATH" 2>/dev/null || printf '0')"
        detail_parts+=("memory_heads=$head_count")
      else
        detail_parts+=("memory_heads missing")
        has_error="true"
        add_summary "Memory heads are missing while fact history exists."
        add_action "Rebuild .pa/memory-heads.json from .pa/memories.jsonl before fact consumers rely on it."
      fi

      unsurfaced_contested="$(count_unsurfaced_contested_groups)"
      detail_parts+=("unsurfaced_contested=$unsurfaced_contested")
      if [[ "$unsurfaced_contested" -gt 0 ]]; then
        has_warning="true"
        add_summary "Contested facts have not been surfaced in review."
        add_action "Run /pa review --horizon month to surface contested facts."
      fi
    else
      detail_parts+=("fact log malformed")
      has_error="true"
      add_summary "Memory fact history is malformed."
      add_action "Repair .pa/memories.jsonl before memory consumers rely on it."
    fi
  else
    detail_parts+=("facts=0")
  fi

  detail="$(join_with_semicolon "${detail_parts[@]}")"

  if [[ "$has_error" == "true" ]]; then
    set_check_result "memory" "error" "$detail"
    return
  fi

  if [[ "$has_warning" == "true" ]]; then
    set_check_result "memory" "warning" "$detail"
    return
  fi

  set_check_result "memory" "ok" "$detail"
}

review_age_detail() {
  local label="$1"
  local timestamp="$2"
  local epoch=""
  local age_seconds=""

  if [[ -z "$timestamp" ]]; then
    printf '%s review missing' "$label"
    return
  fi

  if ! epoch="$(iso_to_epoch "$timestamp" 2>/dev/null)"; then
    printf '%s review timestamp is invalid' "$label"
    return
  fi

  age_seconds=$(( $(now_epoch) - epoch ))
  printf '%s review %s ago' "$label" "$(humanize_age "$age_seconds")"
}

check_review() {
  local week_timestamp=""
  local month_timestamp=""
  local week_epoch=""
  local month_epoch=""
  local week_age="0"
  local month_age="0"
  local detail=""
  local warning_flag="false"

  if ! json_file_valid "$REVIEW_STATE_PATH"; then
    set_check_result "review" "warning" "review-state.json is missing or malformed"
    add_summary "Review checkpoints are unavailable."
    add_action "Run /pa reset --horizon week and /pa review --horizon month."
    return
  fi

  week_timestamp="$(jq -r '.last_review.week.timestamp // empty' "$REVIEW_STATE_PATH" 2>/dev/null || true)"
  month_timestamp="$(jq -r '.last_review.month.timestamp // empty' "$REVIEW_STATE_PATH" 2>/dev/null || true)"

  if [[ -n "$week_timestamp" ]] && week_epoch="$(iso_to_epoch "$week_timestamp" 2>/dev/null)"; then
    week_age=$(( $(now_epoch) - week_epoch ))
    [[ "$week_age" -le "$WEEK_REVIEW_STALE_SECONDS" ]] || warning_flag="true"
  else
    warning_flag="true"
  fi

  if [[ -n "$month_timestamp" ]] && month_epoch="$(iso_to_epoch "$month_timestamp" 2>/dev/null)"; then
    month_age=$(( $(now_epoch) - month_epoch ))
    [[ "$month_age" -le "$MONTH_REVIEW_STALE_SECONDS" ]] || warning_flag="true"
  else
    warning_flag="true"
  fi

  detail="$(printf '%s; %s' "$(review_age_detail "Week" "$week_timestamp")" "$(review_age_detail "Month" "$month_timestamp")")"

  if [[ "$warning_flag" == "false" ]]; then
    set_check_result "review" "ok" "$detail"
    return
  fi

  set_check_result "review" "warning" "$detail"
  add_summary "Review cadence is stale or incomplete."
  add_action "Run /pa reset --horizon week and /pa review --horizon month."
}

check_survey() {
  local last_updated=""
  local updated_epoch=""
  local age_seconds="0"

  if ! json_file_valid "$DERIVATION_STATE_PATH"; then
    set_check_result "survey" "warning" "derivation-state.json is missing or malformed"
    add_summary "Survey freshness cannot be determined."
    add_action "Run /pa survey or /pa steward."
    return
  fi

  last_updated="$(jq -r '.last_updated // empty' "$DERIVATION_STATE_PATH" 2>/dev/null || true)"
  if [[ -z "$last_updated" ]] || ! updated_epoch="$(iso_to_epoch "$last_updated" 2>/dev/null)"; then
    set_check_result "survey" "warning" "Survey timestamp is missing or invalid"
    add_summary "Survey freshness cannot be determined."
    add_action "Run /pa survey or /pa steward."
    return
  fi

  age_seconds=$(( $(now_epoch) - updated_epoch ))
  if [[ "$age_seconds" -le "$SURVEY_STALE_SECONDS" ]]; then
    set_check_result "survey" "ok" "Survey state updated $(humanize_age "$age_seconds") ago"
    return
  fi

  set_check_result "survey" "warning" "Survey state updated $(humanize_age "$age_seconds") ago"
  add_summary "Survey state is stale."
  add_action "Run /pa survey or /pa steward."
}

check_privacy() {
  local entry_count="0"
  local indexed_mask_count="0"

  if ! json_file_valid "$MASK_MAP_PATH"; then
    set_check_result "privacy" "error" "mask-map.json is missing or malformed"
    add_summary "Privacy registry is unavailable."
    add_action "Repair .pa/mask-map.json and rerun bash scripts/pa-mask.sh hash-index."
    return
  fi

  if ! json_file_valid "$HASH_INDEX_PATH"; then
    set_check_result "privacy" "error" "hash-index.json is missing or malformed"
    add_summary "Privacy hash index is unavailable."
    add_action "Run bash scripts/pa-mask.sh hash-index."
    return
  fi

  entry_count="$(jq '.entries | length' "$MASK_MAP_PATH" 2>/dev/null || printf '0')"
  indexed_mask_count="$(jq '[.[][]?] | unique | length' "$HASH_INDEX_PATH" 2>/dev/null || printf '0')"

  if [[ "$entry_count" -eq "$indexed_mask_count" ]]; then
    set_check_result "privacy" "ok" "mask-map entries match hash-index coverage ($entry_count entries)"
    return
  fi

  set_check_result "privacy" "error" "mask-map entries=$entry_count, hash-index coverage=$indexed_mask_count"
  add_summary "Privacy registry and hash index are out of sync."
  add_action "Run bash scripts/pa-mask.sh hash-index and verify mask-map entries."
}

format_relationship_detail() {
  local stale_count="$1"
  local upcoming_count="$2"
  local first_label="$3"
  local stale_detail=""
  local upcoming_detail=""

  if [[ "$stale_count" -eq 1 ]]; then
    stale_detail="1 stale relationship"
  else
    stale_detail="$stale_count stale relationships"
  fi

  if [[ "$upcoming_count" -eq 1 ]]; then
    case "$first_label" in
      birthday | anniversary)
        upcoming_detail="1 upcoming $first_label"
        ;;
      *)
        upcoming_detail="1 upcoming date"
        ;;
    esac
  else
    upcoming_detail="$upcoming_count upcoming dates"
  fi

  printf '%s, %s\n' "$stale_detail" "$upcoming_detail"
}

check_relationships() {
  local relationship_output=""
  local stale_count="0"
  local upcoming_count="0"
  local urgent_notify_count="0"
  local first_label="date"
  local detail=""

  if [[ ! -f "$PA_RELATIONSHIP_SCRIPT" ]]; then
    set_check_result "relationships" "warning" "pa-relationship.sh is missing"
    add_summary "Relationship status could not be checked."
    add_action "Restore scripts/pa-relationship.sh."
    return
  fi

  relationship_output="$(bash "$PA_RELATIONSHIP_SCRIPT" check "$VAULT_PATH" 2>/dev/null || true)"
  if [[ -z "$relationship_output" ]] || ! printf '%s\n' "$relationship_output" | jq empty >/dev/null 2>&1; then
    set_check_result "relationships" "warning" "relationship check returned no valid JSON"
    add_summary "Relationship status could not be read."
    add_action "Run bash scripts/pa-relationship.sh check \"$VAULT_PATH\"."
    return
  fi

  stale_count="$(printf '%s\n' "$relationship_output" | jq '.stale_relationships | length' 2>/dev/null || printf '0')"
  upcoming_count="$(printf '%s\n' "$relationship_output" | jq '.upcoming_dates | length' 2>/dev/null || printf '0')"
  urgent_notify_count="$(printf '%s\n' "$relationship_output" | jq '[.upcoming_dates[]? | select(.notify == true and (.days_until <= 1))] | length' 2>/dev/null || printf '0')"
  first_label="$(printf '%s\n' "$relationship_output" | jq -r '.upcoming_dates[0].label // "date"' 2>/dev/null || printf 'date')"
  detail="$(format_relationship_detail "$stale_count" "$upcoming_count" "$first_label")"

  if [[ "$stale_count" -gt 0 ]] || [[ "$urgent_notify_count" -gt 0 ]]; then
    set_check_result "relationships" "warning" "$detail"
    add_summary "Relationships need attention."
    add_action "Run bash scripts/pa-relationship.sh check \"$VAULT_PATH\"."
    return
  fi

  set_check_result "relationships" "ok" "$detail"
}

check_calendar() {
  local calendar_events_path="$PA_DIR/calendar-events.jsonl"
  local last_sync_at=""
  local sync_epoch=""
  local age_seconds="0"
  local age_human=""

  if ! command -v gws >/dev/null 2>&1; then
    set_check_result "calendar" "warning" "gws CLI not installed"
    add_summary "Calendar sync is unavailable because gws CLI is not installed."
    add_action "Install gws and run bash scripts/pa-calendar.sh sync."
    return
  fi

  if [[ ! -f "$calendar_events_path" ]]; then
    set_check_result "calendar" "warning" "No calendar events file. Run: bash scripts/pa-calendar.sh sync"
    add_summary "Calendar events have not been synced yet."
    add_action "Run bash scripts/pa-calendar.sh sync."
    return
  fi

  if ! json_file_valid "$INTEGRATIONS_STATE_PATH"; then
    set_check_result "calendar" "warning" "Calendar last_sync_at missing"
    add_summary "Calendar sync state is unavailable."
    add_action "Run bash scripts/pa-calendar.sh sync."
    return
  fi

  last_sync_at="$(jq -r '.calendar.last_sync_at // empty' "$INTEGRATIONS_STATE_PATH" 2>/dev/null || true)"
  if [[ -z "$last_sync_at" ]]; then
    set_check_result "calendar" "warning" "Calendar last_sync_at missing"
    add_summary "Calendar sync timestamp is missing."
    add_action "Run bash scripts/pa-calendar.sh sync."
    return
  fi

  if ! sync_epoch="$(iso_to_epoch "$last_sync_at" 2>/dev/null)"; then
    set_check_result "calendar" "warning" "Calendar last_sync_at invalid"
    add_summary "Calendar sync timestamp is invalid."
    add_action "Run bash scripts/pa-calendar.sh sync."
    return
  fi

  age_seconds=$(( $(now_epoch) - sync_epoch ))
  if [[ "$age_seconds" -lt 0 ]]; then
    age_seconds="0"
  fi

  if [[ "$age_seconds" -gt "$CALENDAR_STALE_SECONDS" ]]; then
    set_check_result "calendar" "warning" "Calendar sync stale"
    add_summary "Calendar sync is stale."
    add_action "Run bash scripts/pa-calendar.sh sync."
    return
  fi

  age_human="$(humanize_age "$age_seconds")"
  set_check_result "calendar" "ok" "Calendar synced $age_human ago"
}

json_array_from_values() {
  local -a values=("$@")

  if [[ "${#values[@]}" -eq 0 ]]; then
    printf '[]\n'
    return
  fi

  printf '%s\n' "${values[@]}" | jq -R . | jq -s .
}

overall_status() {
  local status=""
  local has_warning="false"

  for status in \
    "$CHECK_QMD_STATUS" \
    "$CHECK_SHADOW_STATUS" \
    "$CHECK_ONTOLOGY_STATUS" \
    "$CHECK_MEMORY_STATUS" \
    "$CHECK_REVIEW_STATUS" \
    "$CHECK_SURVEY_STATUS" \
    "$CHECK_PRIVACY_STATUS" \
    "$CHECK_RELATIONSHIPS_STATUS" \
    "$CHECK_CALENDAR_STATUS"; do
    case "$status" in
      error)
        printf 'errors\n'
        return
        ;;
      warning)
        has_warning="true"
        ;;
    esac
  done

  if [[ "$has_warning" == "true" ]]; then
    printf 'warnings\n'
  else
    printf 'healthy\n'
  fi
}

highest_severity() {
  local status="$1"

  case "$status" in
    healthy)
      printf 'info\n'
      ;;
    warnings)
      printf 'warning\n'
      ;;
    errors)
      printf 'critical\n'
      ;;
    *)
      die_system "Unknown overall status: $status"
      ;;
  esac
}

build_heartbeat_json() {
  local overall="$1"
  local highest="$2"
  local checked_at="$3"
  local summary_json=""
  local actions_json=""

  if [[ "${#SUMMARY_ITEMS[@]}" -eq 0 ]]; then
    SUMMARY_ITEMS=("All checks healthy")
  fi

  summary_json="$(json_array_from_values "${SUMMARY_ITEMS[@]}")"
  actions_json="$(json_array_from_values "${RECOMMENDED_ACTIONS[@]}")"

  jq -n \
    --arg checked_at "$checked_at" \
    --arg status "$overall" \
    --arg highest_severity "$highest" \
    --arg qmd_status "$CHECK_QMD_STATUS" \
    --arg qmd_detail "$CHECK_QMD_DETAIL" \
    --arg shadow_status "$CHECK_SHADOW_STATUS" \
    --arg shadow_detail "$CHECK_SHADOW_DETAIL" \
    --arg ontology_status "$CHECK_ONTOLOGY_STATUS" \
    --arg ontology_detail "$CHECK_ONTOLOGY_DETAIL" \
    --arg memory_status "$CHECK_MEMORY_STATUS" \
    --arg memory_detail "$CHECK_MEMORY_DETAIL" \
    --arg review_status "$CHECK_REVIEW_STATUS" \
    --arg review_detail "$CHECK_REVIEW_DETAIL" \
    --arg survey_status "$CHECK_SURVEY_STATUS" \
    --arg survey_detail "$CHECK_SURVEY_DETAIL" \
    --arg privacy_status "$CHECK_PRIVACY_STATUS" \
    --arg privacy_detail "$CHECK_PRIVACY_DETAIL" \
    --arg relationships_status "$CHECK_RELATIONSHIPS_STATUS" \
    --arg relationships_detail "$CHECK_RELATIONSHIPS_DETAIL" \
    --arg calendar_status "$CHECK_CALENDAR_STATUS" \
    --arg calendar_detail "$CHECK_CALENDAR_DETAIL" \
    --argjson summary "$summary_json" \
    --argjson recommended_actions "$actions_json" \
    '{
      version: 1,
      checked_at: $checked_at,
      status: $status,
      highest_severity: $highest_severity,
      relationships: {
        status: $relationships_status,
        detail: $relationships_detail
      },
      checks: {
        qmd: {status: $qmd_status, detail: $qmd_detail},
        shadow: {status: $shadow_status, detail: $shadow_detail},
        ontology: {status: $ontology_status, detail: $ontology_detail},
        memory: {status: $memory_status, detail: $memory_detail},
        review: {status: $review_status, detail: $review_detail},
        survey: {status: $survey_status, detail: $survey_detail},
        privacy: {status: $privacy_status, detail: $privacy_detail},
        calendar: {status: $calendar_status, detail: $calendar_detail}
      },
      summary: $summary,
      recommended_actions: $recommended_actions
    }'
}

action_check() {
  local overall=""
  local highest=""
  local checked_at=""
  local json_output=""

  [[ $# -le 1 ]] || die_user "Usage: pa-heartbeat.sh check [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root

  check_qmd
  check_shadow
  check_ontology
  check_memory
  check_review
  check_survey
  check_privacy
  check_relationships
  check_calendar

  overall="$(overall_status)"
  highest="$(highest_severity "$overall")"
  checked_at="$(iso_timestamp)"
  json_output="$(build_heartbeat_json "$overall" "$highest" "$checked_at")"

  printf '%s\n' "$json_output" >"$HEARTBEAT_PATH" || die_system "Failed to write heartbeat: $HEARTBEAT_PATH"
  printf '%s\n' "$json_output"

  case "$overall" in
    healthy)
      return 0
      ;;
    warnings)
      return 1
      ;;
    errors)
      return 2
      ;;
    *)
      die_system "Unknown heartbeat status: $overall"
      ;;
  esac
}

action_status() {
  local check_name=""
  local check_status=""
  local check_detail=""

  [[ $# -le 1 ]] || die_user "Usage: pa-heartbeat.sh status [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root
  json_file_valid "$HEARTBEAT_PATH" || die_user "heartbeat.json not found or malformed: $HEARTBEAT_PATH"

  printf 'PA Heartbeat\n'
  printf 'Vault: %s\n' "$VAULT_PATH"
  printf 'Checked: %s\n' "$(jq -r '.checked_at' "$HEARTBEAT_PATH")"
  printf 'Status: %s (%s)\n' "$(jq -r '.status' "$HEARTBEAT_PATH")" "$(jq -r '.highest_severity' "$HEARTBEAT_PATH")"
  printf '\n'

  for check_name in qmd shadow ontology memory review survey privacy; do
    check_status="$(jq -r --arg key "$check_name" '.checks[$key].status' "$HEARTBEAT_PATH")"
    check_detail="$(jq -r --arg key "$check_name" '.checks[$key].detail' "$HEARTBEAT_PATH")"
    printf -- '- %s: %s | %s\n' "$check_name" "$check_status" "$check_detail"
  done

  printf -- '- relationships: %s | %s\n' "$(jq -r '.relationships.status' "$HEARTBEAT_PATH")" "$(jq -r '.relationships.detail' "$HEARTBEAT_PATH")"
  printf -- '- calendar: %s | %s\n' "$(jq -r '.checks.calendar.status' "$HEARTBEAT_PATH")" "$(jq -r '.checks.calendar.detail' "$HEARTBEAT_PATH")"

  if [[ "$(jq '.summary | length' "$HEARTBEAT_PATH")" -gt 0 ]]; then
    printf '\nSummary\n'
    jq -r '.summary[] | "- " + .' "$HEARTBEAT_PATH"
  fi

  if [[ "$(jq '.recommended_actions | length' "$HEARTBEAT_PATH")" -gt 0 ]]; then
    printf '\nRecommended Actions\n'
    jq -r '.recommended_actions[] | "- " + .' "$HEARTBEAT_PATH"
  fi
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  check)
    action_check "$@"
    ;;
  status)
    action_status "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die_user "Unknown action: $ACTION"
    ;;
esac
