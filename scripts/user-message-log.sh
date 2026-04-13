#!/usr/bin/env bash
# UserPromptSubmit hook — log every user message for batch friction analysis
#
# Reads hook stdin JSON, extracts user message text, appends to log.
# Runs async — does not block conversation.
#
# Output: .claude/user-messages.jsonl (append-only)
# Idempotency: append-only by design — duplicate entries from re-execution are
# acceptable for telemetry. Deduplication happens at analysis time via timestamp+session_id.
#
# Part of ouroboros session intelligence (v0.18.5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${HOME}/.claude/user-messages.jsonl"

detect_pattern_feedback() {
  local text="${1:-}"
  local action=""
  local pattern_id=""

  if [[ "$text" =~ ^[[:space:]]*(approve|dismiss)[[:space:]]+(PAT-[0-9]{8}-[0-9]{3})[[:space:]]*$ ]]; then
    action="${BASH_REMATCH[1]}"
    pattern_id="${BASH_REMATCH[2]}"
    bash "$SCRIPT_DIR/session-patterns.sh" feedback "$action" "$pattern_id" 2>/dev/null || true
  fi
}

# Read stdin (hook provides JSON context)
STDIN_DATA=""
if ! [ -t 0 ]; then
  STDIN_DATA=$(cat)
fi

if [[ -z "$STDIN_DATA" ]]; then
  exit 0
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Hook stdin confirmed fields (UserPromptSubmit):
#   session_id, transcript_path, cwd, permission_mode, hook_event_name, prompt
if command -v jq &>/dev/null; then
  TEXT=$(printf '%s' "$STDIN_DATA" | jq -r '.prompt // empty' 2>/dev/null || true)
  SESSION_ID=$(printf '%s' "$STDIN_DATA" | jq -r '.session_id // empty' 2>/dev/null || true)
  TRANSCRIPT=$(printf '%s' "$STDIN_DATA" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  CWD_FIELD=$(printf '%s' "$STDIN_DATA" | jq -r '.cwd // empty' 2>/dev/null || true)
  PROJECT_KEY=""

  if [[ -n "$CWD_FIELD" ]] && command -v shasum &>/dev/null; then
    PROJECT_KEY="$(printf '%s' "$CWD_FIELD" | shasum -a 256 | cut -c1-12)"
  fi

  # Skip empty or very short messages (likely accidental)
  if [[ -z "$TEXT" ]] || [[ ${#TEXT} -lt 2 ]]; then
    exit 0
  fi

  jq -nc \
    --arg ts "$TIMESTAMP" \
    --arg text "$TEXT" \
    --argjson len "${#TEXT}" \
    --arg session "${SESSION_ID:-unknown}" \
    --arg transcript "${TRANSCRIPT:-unknown}" \
    --arg project_key "$PROJECT_KEY" \
    '{ timestamp: $ts, text: $text, length: $len, session: $session, transcript: $transcript, project_key: $project_key }' \
    >>"$LOG_FILE" 2>/dev/null || true

  detect_pattern_feedback "$TEXT" || true
fi

exit 0
