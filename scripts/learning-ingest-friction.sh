#!/usr/bin/env bash
# Distill privacy-safe friction signals from user message and permission logs.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

USER_MESSAGE_LOG="${HOME}/.claude/user-messages.jsonl"
CHOICE_LOG="${HOME}/.claude/choice-log.jsonl"
CHECKPOINT_PATH="$(learning_sources_dir)/.friction-checkpoint.json"
MESSAGE_CHECKPOINT=0
CHOICE_CHECKPOINT=0
MESSAGE_TOTAL=0
CHOICE_TOTAL=0
FRUSTRATION_WINDOW_SECONDS=300

declare -A CHOICE_COUNTS=()
declare -A CHOICE_LATEST_TS=()
declare -A CHOICE_LATEST_SESSION=()
declare -A CHOICE_LATEST_LINE=()
declare -A CHOICE_ROUTE_COMPONENT=()
declare -A CHOICE_ROUTE_TASK_KEY=()

_learning_friction_fail_open() {
  echo "[learning-ingest-friction] fail-open: $1" >&2
  exit 0
}

trap '_learning_friction_fail_open "unexpected error at line ${LINENO}"' ERR

normalize_tool_pattern() {
  local entry_json="${1:-}"
  local tool_name="unknown"
  local pattern_value=""
  local project_root=""

  tool_name="$(printf '%s' "$entry_json" | jq -r '.tool_name // "unknown"' 2>/dev/null || printf 'unknown')"

  if [ "$tool_name" = "Bash" ]; then
    pattern_value="$(printf '%s' "$entry_json" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
  elif printf '%s' "$entry_json" | jq -e '.tool_input.file_path? != null' >/dev/null 2>&1; then
    pattern_value="$(printf '%s' "$entry_json" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
  else
    pattern_value="$(printf '%s' "$entry_json" | jq -c '.tool_input // {}' 2>/dev/null || true)"
  fi

  [ -n "$pattern_value" ] || return 1

  project_root="$(learning_project_root)"
  pattern_value="${pattern_value//$'\n'/ }"
  pattern_value="${pattern_value//$'\r'/ }"
  pattern_value="${pattern_value//$HOME/<home>}"
  pattern_value="${pattern_value//$project_root/<repo>}"
  pattern_value="$(printf '%s' "$pattern_value" | sed -E \
    's/[[:space:]]+/ /g;
     s/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<uuid>/g;
     s/[0-9a-fA-F]{7,}/<hex>/g;
     s/^ //;
     s/ $//')"

  printf '%s|%s\n' "$tool_name" "$pattern_value"
}

iso_to_epoch() {
  local iso_ts="${1:-}"

  [ -n "$iso_ts" ] || return 1

  if date -u -d "$iso_ts" +%s >/dev/null 2>&1; then
    date -u -d "$iso_ts" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s
    return 0
  fi

  return 1
}

message_matches_frustration() {
  local raw_text="${1:-}"
  local lowered=""

  [ -n "$raw_text" ] || return 1
  lowered="$(printf '%s' "$raw_text" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lowered" =~ not[[:space:]]+what[[:space:]]+i[[:space:]]+asked|you[[:space:]]+forgot|wrong|incorrect|doesn.t[[:space:]]+work|not[[:space:]]+working|still[[:space:]]+wrong|again|stuck|frustrat|annoy|why[[:space:]] ]]; then
    return 0
  fi

  if [[ "$raw_text" =~ 그게[[:space:]]아니라|다시|틀렸|잘못|빠뜨|잊었|왜|이해[[:space:]]못|답답|아닌데 ]]; then
    return 0
  fi

  return 1
}

emit_friction_event() {
  local ts="${1:?Missing timestamp}"
  local session_id="${2:-unknown}"
  local signal="${3:?Missing signal}"
  local pattern_hash="${4:?Missing pattern hash}"
  local evidence_count="${5:?Missing evidence count}"
  local confidence="${6:?Missing confidence}"
  local task_key="${7:-session:${session_id}}"
  local component="${8:-}"
  local event_id=""
  local payload=""

  event_id="$(learning_next_event_id "FRC" 2>/dev/null || printf 'FRC-%s-000' "$(date -u +%Y%m%d)")"
  payload="$(jq -cn \
    --arg event_id "$event_id" \
    --arg ts "$ts" \
    --arg source "friction" \
    --arg session_id "$session_id" \
    --arg task_key "$task_key" \
    --arg signal "$signal" \
    --arg pattern_hash "$pattern_hash" \
    --arg component "$component" \
    --argjson evidence_count "$evidence_count" \
    --argjson confidence "$confidence" \
    '{
      event_id:$event_id,
      ts:$ts,
      source:$source,
      session_id:$session_id,
      task_key:$task_key,
      signal:$signal,
      pattern_hash:$pattern_hash,
      evidence_count:$evidence_count,
      confidence:$confidence
    } + (if $component != "" then {component:$component} else {} end)'
  )" || return 0

  learning_append_jsonl "$(learning_source_path "friction")" "$payload"
}

load_checkpoint() {
  if [ -f "$CHECKPOINT_PATH" ] && command -v jq >/dev/null 2>&1; then
    MESSAGE_CHECKPOINT="$(jq -r '.user_messages.last_line // 0' "$CHECKPOINT_PATH" 2>/dev/null || printf '0')"
    CHOICE_CHECKPOINT="$(jq -r '.choice_log.last_line // 0' "$CHECKPOINT_PATH" 2>/dev/null || printf '0')"
  fi

  [[ "$MESSAGE_CHECKPOINT" =~ ^[0-9]+$ ]] || MESSAGE_CHECKPOINT=0
  [[ "$CHOICE_CHECKPOINT" =~ ^[0-9]+$ ]] || CHOICE_CHECKPOINT=0
}

save_checkpoint() {
  local checkpoint_json=""

  checkpoint_json="$(jq -cn \
    --arg version "1" \
    --arg updated_at "$(learning_timestamp_utc)" \
    --argjson message_last "$MESSAGE_TOTAL" \
    --argjson choice_last "$CHOICE_TOTAL" \
    '{
      version:$version,
      updated_at:$updated_at,
      user_messages:{last_line:$message_last},
      choice_log:{last_line:$choice_last}
    }'
  )" || return 0

  mkdir -p "$(dirname "$CHECKPOINT_PATH")" 2>/dev/null || return 0
  printf '%s\n' "$checkpoint_json" >"$CHECKPOINT_PATH" 2>/dev/null || true
}

process_choice_log() {
  local entry_json=""
  local pattern=""
  local pattern_hash=""
  local ts=""
  local session_id=""
  local route_hint=""
  local route_component=""
  local route_task_key=""
  local count=0

  [ -f "$CHOICE_LOG" ] || return 0

  while IFS= read -r entry_json || [ -n "$entry_json" ]; do
    CHOICE_TOTAL=$((CHOICE_TOTAL + 1))
    [ -n "$entry_json" ] || continue
    pattern="$(normalize_tool_pattern "$entry_json" 2>/dev/null || true)"
    [ -n "$pattern" ] || continue
    pattern_hash="$(learning_sha256 "$pattern" 2>/dev/null || true)"
    [ -n "$pattern_hash" ] || continue

    CHOICE_COUNTS["$pattern_hash"]=$(( ${CHOICE_COUNTS["$pattern_hash"]:-0} + 1 ))
    ts="$(printf '%s' "$entry_json" | jq -r '.logged_at // empty' 2>/dev/null || true)"
    session_id="$(printf '%s' "$entry_json" | jq -r '.session_id // "unknown"' 2>/dev/null || printf 'unknown')"
    [ -n "$ts" ] || ts="$(learning_timestamp_utc)"
    route_hint="$(learning_extract_route_hint "$pattern" "$entry_json" "$session_id" 2>/dev/null || true)"
    route_component="$(printf '%s' "$route_hint" | jq -r '.component // empty' 2>/dev/null || true)"
    route_task_key="$(printf '%s' "$route_hint" | jq -r '.task_key // empty' 2>/dev/null || true)"
    CHOICE_LATEST_TS["$pattern_hash"]="$ts"
    CHOICE_LATEST_SESSION["$pattern_hash"]="$session_id"
    CHOICE_LATEST_LINE["$pattern_hash"]="$CHOICE_TOTAL"
    if [ -n "$route_component" ]; then
      CHOICE_ROUTE_COMPONENT["$pattern_hash"]="$route_component"
    fi
    if [ -n "$route_task_key" ]; then
      CHOICE_ROUTE_TASK_KEY["$pattern_hash"]="$route_task_key"
    fi
  done <"$CHOICE_LOG"

  if [ "$CHOICE_TOTAL" -lt "$CHOICE_CHECKPOINT" ]; then
    CHOICE_CHECKPOINT=0
  fi

  for pattern_hash in "${!CHOICE_COUNTS[@]}"; do
    count="${CHOICE_COUNTS["$pattern_hash"]}"
    [ "$count" -ge 3 ] || continue
    [ "${CHOICE_LATEST_LINE["$pattern_hash"]}" -gt "$CHOICE_CHECKPOINT" ] || continue

    if [ "$count" -ge 5 ]; then
      emit_friction_event "${CHOICE_LATEST_TS["$pattern_hash"]}" "${CHOICE_LATEST_SESSION["$pattern_hash"]}" "repeated_permission_pattern" "$pattern_hash" "$count" "0.70" "${CHOICE_ROUTE_TASK_KEY["$pattern_hash"]:-}" "${CHOICE_ROUTE_COMPONENT["$pattern_hash"]:-}"
    elif [ "$count" -eq 4 ]; then
      emit_friction_event "${CHOICE_LATEST_TS["$pattern_hash"]}" "${CHOICE_LATEST_SESSION["$pattern_hash"]}" "repeated_permission_pattern" "$pattern_hash" "$count" "0.65" "${CHOICE_ROUTE_TASK_KEY["$pattern_hash"]:-}" "${CHOICE_ROUTE_COMPONENT["$pattern_hash"]:-}"
    else
      emit_friction_event "${CHOICE_LATEST_TS["$pattern_hash"]}" "${CHOICE_LATEST_SESSION["$pattern_hash"]}" "repeated_permission_pattern" "$pattern_hash" "$count" "0.60" "${CHOICE_ROUTE_TASK_KEY["$pattern_hash"]:-}" "${CHOICE_ROUTE_COMPONENT["$pattern_hash"]:-}"
    fi
  done
}

process_user_messages() {
  local entry_json=""
  local ts=""
  local epoch=0
  local session_id=""
  local message_text=""
  local message_hash=""
  local route_hint=""
  local route_component=""
  local route_task_key=""
  local current_session=""
  local current_count=0
  local current_hashes=""
  local current_latest_ts=""
  local current_latest_line=0
  local current_latest_epoch=0
  local current_component=""
  local current_task_key=""

  finalize_burst() {
    local pattern_hash=""

    [ "$current_count" -ge 2 ] || {
      current_session=""
      current_count=0
      current_hashes=""
      current_latest_ts=""
      current_latest_line=0
      current_latest_epoch=0
      current_component=""
      current_task_key=""
      return 0
    }

    [ "$current_latest_line" -gt "$MESSAGE_CHECKPOINT" ] || {
      current_session=""
      current_count=0
      current_hashes=""
      current_latest_ts=""
      current_latest_line=0
      current_latest_epoch=0
      current_component=""
      current_task_key=""
      return 0
    }

    pattern_hash="$(learning_sha256 "$current_hashes" 2>/dev/null || true)"
    [ -n "$pattern_hash" ] || {
      current_session=""
      current_count=0
      current_hashes=""
      current_latest_ts=""
      current_latest_line=0
      current_latest_epoch=0
      current_component=""
      current_task_key=""
      return 0
    }

    if [ "$current_count" -ge 3 ]; then
      emit_friction_event "$current_latest_ts" "$current_session" "frustration_burst" "$pattern_hash" "$current_count" "0.70" "$current_task_key" "$current_component"
    else
      emit_friction_event "$current_latest_ts" "$current_session" "frustration_burst" "$pattern_hash" "$current_count" "0.60" "$current_task_key" "$current_component"
    fi

    current_session=""
    current_count=0
    current_hashes=""
    current_latest_ts=""
    current_latest_line=0
    current_latest_epoch=0
    current_component=""
    current_task_key=""
  }

  [ -f "$USER_MESSAGE_LOG" ] || return 0

  while IFS= read -r entry_json || [ -n "$entry_json" ]; do
    MESSAGE_TOTAL=$((MESSAGE_TOTAL + 1))
    [ -n "$entry_json" ] || continue
    message_text="$(printf '%s' "$entry_json" | jq -r '.text // empty' 2>/dev/null || true)"
    ts="$(printf '%s' "$entry_json" | jq -r '.timestamp // empty' 2>/dev/null || true)"
    session_id="$(printf '%s' "$entry_json" | jq -r '.session // "unknown"' 2>/dev/null || printf 'unknown')"
    [ -n "$message_text" ] || continue
    [ -n "$ts" ] || continue
    message_matches_frustration "$message_text" || continue
    epoch="$(iso_to_epoch "$ts" 2>/dev/null || true)"
    [ -n "$epoch" ] || continue
    route_hint="$(learning_extract_route_hint "$message_text" "$entry_json" "$session_id" 2>/dev/null || true)"
    route_component="$(printf '%s' "$route_hint" | jq -r '.component // empty' 2>/dev/null || true)"
    route_task_key="$(printf '%s' "$route_hint" | jq -r '.task_key // empty' 2>/dev/null || true)"
    message_hash="$(learning_sha256 "$message_text" 2>/dev/null || true)"
    [ -n "$message_hash" ] || continue

    if [ -z "$current_session" ] || [ "$current_session" != "$session_id" ] || [ $((epoch - current_latest_epoch)) -gt "$FRUSTRATION_WINDOW_SECONDS" ]; then
      finalize_burst
      current_session="$session_id"
      current_count=1
      current_hashes="$message_hash"
      current_latest_ts="$ts"
      current_latest_line="$MESSAGE_TOTAL"
      current_latest_epoch="$epoch"
      current_component="$route_component"
      current_task_key="$route_task_key"
      continue
    fi

    current_count=$((current_count + 1))
    current_hashes="${current_hashes},${message_hash}"
    current_latest_ts="$ts"
    current_latest_line="$MESSAGE_TOTAL"
    current_latest_epoch="$epoch"
    if [ -n "$route_component" ]; then
      current_component="$route_component"
    fi
    if [ -n "$route_task_key" ]; then
      current_task_key="$route_task_key"
    fi
  done <"$USER_MESSAGE_LOG"

  if [ "$MESSAGE_TOTAL" -lt "$MESSAGE_CHECKPOINT" ]; then
    MESSAGE_CHECKPOINT=0
  fi

  finalize_burst
}

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  load_checkpoint
  process_choice_log
  process_user_messages
  save_checkpoint
}

main "$@"
exit 0
