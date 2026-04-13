#!/usr/bin/env bash
# PostToolUseFailure hook for privacy-safe tool failure logging.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

fail_open() {
  echo "[learning-log-tool-failure] fail-open: $1" >&2
  exit 0
}

trap 'fail_open "unexpected error at line ${LINENO}"' ERR

STDIN_DATA=""
if ! [ -t 0 ]; then
  STDIN_DATA="$(cat)"
fi

[ -n "$STDIN_DATA" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

tool_name="$(printf '%s' "$STDIN_DATA" | jq -r '.tool_name // .tool // .name // "unknown"' 2>/dev/null || printf 'unknown')"
raw_error_message="$(printf '%s' "$STDIN_DATA" | jq -r '.error // .error_message // .message // .stderr // "unknown"' 2>/dev/null || printf 'unknown')"
session_id="$(printf '%s' "$STDIN_DATA" | jq -r '.session_id // .session // "unknown"' 2>/dev/null || printf 'unknown')"
tool_input_command="$(printf '%s' "$STDIN_DATA" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
route_text="$raw_error_message"
if [ -n "$tool_input_command" ]; then
  route_text="${route_text}"$'\n'"$tool_input_command"
fi
route_hint="$(learning_extract_route_hint "$route_text" "$STDIN_DATA" "$session_id" 2>/dev/null || true)"
route_component="$(printf '%s' "$route_hint" | jq -r '.component // empty' 2>/dev/null || true)"
route_task_key="$(printf '%s' "$route_hint" | jq -r '.task_key // empty' 2>/dev/null || true)"
project_root="$(learning_project_root)"
error_message="$raw_error_message"

error_message="${error_message//$'\n'/ }"
error_message="${error_message//$'\r'/ }"
error_message="${error_message//$HOME/<home>}"
error_message="${error_message//$project_root/<repo>}"
error_message="$(printf '%s' "$error_message" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

pattern_hash="$(learning_sha256 "$error_message" 2>/dev/null || true)"
[ -n "$pattern_hash" ] || exit 0

payload="$(
  jq -cn \
    --arg event_id "$(learning_next_event_id "FRC" 2>/dev/null || printf 'FRC-%s-000' "$(date -u +%Y%m%d)")" \
    --arg ts "$(learning_timestamp_utc)" \
    --arg source "friction" \
    --arg session_id "$session_id" \
    --arg task_key "${route_task_key:-session:${session_id}}" \
    --arg signal "tool_failure" \
    --arg pattern_hash "$pattern_hash" \
    --arg tool_name "$tool_name" \
    --arg component "$route_component" \
    '{
      event_id:$event_id,
      ts:$ts,
      source:$source,
      session_id:$session_id,
      task_key:$task_key,
      signal:$signal,
      pattern_hash:$pattern_hash,
      evidence_count:1,
      confidence:0.50,
      tool_name:$tool_name
    } + (if $component != "" then {component:$component} else {} end)'
)" || exit 0

learning_append_jsonl "$(learning_source_path "friction")" "$payload"
exit 0
