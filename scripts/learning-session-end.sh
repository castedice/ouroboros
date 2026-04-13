#!/usr/bin/env bash
# SessionEnd hook for lightweight learning-source capture.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

STDIN_DATA=""
SESSION_ID="unknown"
TRANSCRIPT_PATH=""
HAS_WRITE_EVENTS=0

_learning_session_fail_open() {
  echo "[learning-session-end] fail-open: $1" >&2
  exit 0
}

trap '_learning_session_fail_open "unexpected error at line ${LINENO}"' ERR

read_hook_context() {
  if ! [ -t 0 ]; then
    STDIN_DATA="$(cat)"
  fi

  [ -n "$STDIN_DATA" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  SESSION_ID="$(printf '%s' "$STDIN_DATA" | jq -r '.session_id // .session // "unknown"' 2>/dev/null || printf 'unknown')"
  TRANSCRIPT_PATH="$(printf '%s' "$STDIN_DATA" | jq -r '.transcript_path // .transcript // empty' 2>/dev/null || printf '')"
}

transcript_has_write_events() {
  [ -n "$TRANSCRIPT_PATH" ] || return 1
  [ -f "$TRANSCRIPT_PATH" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  tail -400 "$TRANSCRIPT_PATH" 2>/dev/null | jq -er '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use" and (.name == "Edit" or .name == "Write")) |
    .name
  ' >/dev/null 2>&1
}

log_session_pattern() {
  local pattern="${1:?Missing pattern}"
  local confidence="${2:?Missing confidence}"
  local task_key="${3-}"
  local detail_json="${4:-{}}"
  local payload
  local event_id

  command -v jq >/dev/null 2>&1 || return 0

  event_id="$(learning_next_event_id "SES" 2>/dev/null || printf 'SES-%s-000' "$(date -u +%Y%m%d)")"
  payload="$(jq -cn \
    --arg event_id "$event_id" \
    --arg ts "$(learning_timestamp_utc)" \
    --arg source "session-pattern" \
    --arg pattern "$pattern" \
    --arg session_id "$SESSION_ID" \
    --arg task_key "$task_key" \
    --argjson confidence "$confidence" \
    --argjson detail "$detail_json" \
    '{
      event_id:$event_id,
      ts:$ts,
      source:$source,
      pattern:$pattern,
      session_id:$session_id,
      task_key:$task_key,
      confidence:$confidence,
      detail:$detail
    }'
  )" || return 0

  learning_append_jsonl "$(learning_source_path "session-patterns")" "$payload"
}

expected_artifact_paths() {
  local promise_file="${1:?Missing promise file}"

  jq -r '
    [
      .expected_artifact.path?,
      .expected_artifact_path?,
      .artifact.path?,
      .artifact_path?,
      .output.path?,
      .output_path?,
      (.expected_artifacts[]? | if type == "string" then . else .path // empty end),
      (.artifact_paths[]?),
      (.artifacts[]? | if type == "string" then . else .path // empty end)
    ] |
    .[] |
    select(type == "string" and length > 0)
  ' "$promise_file" 2>/dev/null || true
}

log_active_promise() {
  local promise_file="${1:?Missing promise file}"
  local promise_id
  local promise_status
  local target_name
  local task_key
  local detail_json
  local artifact_path
  local missing_logged=0

  promise_id="$(jq -r '.promise_id // .id // .loop_id // empty' "$promise_file" 2>/dev/null || true)"
  promise_status="$(jq -r '.status // .state // empty' "$promise_file" 2>/dev/null || true)"
  target_name="$(jq -r '.target // .component // .component_path // .scope // empty' "$promise_file" 2>/dev/null || true)"
  task_key="$(jq -r '.task_key // empty' "$promise_file" 2>/dev/null || true)"

  [ -n "$promise_id" ] || promise_id="$(basename "$promise_file" .json)"

  detail_json="$(jq -cn \
    --arg promise_id "$promise_id" \
    --arg status "$promise_status" \
    --arg target "$target_name" \
    --arg promise_file "$promise_file" \
    '{
      promise_id:$promise_id,
      status:$status,
      target:$target,
      promise_file:$promise_file
    }'
  )" || detail_json='{}'

  log_session_pattern "unfinished_completion_promise" "0.60" "$task_key" "$detail_json"

  while IFS= read -r artifact_path; do
    [ -n "$artifact_path" ] || continue
    if [ ! -e "$artifact_path" ]; then
      missing_logged=1
      detail_json="$(jq -cn \
        --arg promise_id "$promise_id" \
        --arg status "$promise_status" \
        --arg target "$target_name" \
        --arg artifact_path "$artifact_path" \
        --arg reason "expected_artifact_missing" \
        '{
          promise_id:$promise_id,
          status:$status,
          target:$target,
          artifact_path:$artifact_path,
          reason:$reason
        }'
      )" || detail_json='{}'
      log_session_pattern "missing_final_artifact" "0.65" "$task_key" "$detail_json"
    fi
  done < <(expected_artifact_paths "$promise_file")

  if [ "$missing_logged" -eq 0 ] && [ "$HAS_WRITE_EVENTS" -eq 0 ]; then
    detail_json="$(jq -cn \
      --arg promise_id "$promise_id" \
      --arg status "$promise_status" \
      --arg target "$target_name" \
      --arg reason "no_write_events_detected" \
      '{
        promise_id:$promise_id,
        status:$status,
        target:$target,
        reason:$reason
      }'
    )" || detail_json='{}'
    log_session_pattern "missing_final_artifact" "0.55" "$task_key" "$detail_json"
  fi
}

scan_active_promises() {
  local promises_dir
  local promise_file
  local promise_status
  local promise_session_id

  promises_dir="$(learning_promises_dir)"
  [ -d "$promises_dir" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  while IFS= read -r promise_file; do
    [ -n "$promise_file" ] || continue
    promise_status="$(jq -r '.status // .state // empty' "$promise_file" 2>/dev/null || true)"
    promise_session_id="$(jq -r '.session_id // .session // empty' "$promise_file" 2>/dev/null || true)"
    if [ "$promise_status" = "active" ]; then
      if [ "$SESSION_ID" != "unknown" ] && [ -n "$promise_session_id" ] && [ "$promise_session_id" != "$SESSION_ID" ]; then
        continue
      fi
      log_active_promise "$promise_file"
    fi
  done < <(find "$promises_dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort)
}

main() {
  read_hook_context

  if transcript_has_write_events; then
    HAS_WRITE_EVENTS=1
  fi

  scan_active_promises
}

main "$@"
exit 0
