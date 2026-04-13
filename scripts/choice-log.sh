#!/usr/bin/env bash
# PermissionRequest hook — log user tool permission choices
#
# Reads hook stdin JSON (tool_name, action, etc.) and appends to choice log.
# Installed via hooks.json PermissionRequest matcher.
#
# Output: .claude/choice-log.jsonl (append-only)
# Idempotency: append-only by design — duplicate entries from re-execution are
# acceptable for telemetry. Deduplication happens at analysis time via logged_at timestamp.
#
# Part of ouroboros session intelligence (v0.18.5)

set -euo pipefail

LOG_FILE="${HOME}/.claude/choice-log.jsonl"

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

# Extract fields and append entry
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CWD_FIELD=""
PROJECT_KEY=""

if command -v jq &>/dev/null; then
  CWD_FIELD="$(printf '%s' "$STDIN_DATA" | jq -r '.cwd // empty' 2>/dev/null || true)"
  if [[ -n "$CWD_FIELD" ]] && command -v shasum &>/dev/null; then
    PROJECT_KEY="$(printf '%s' "$CWD_FIELD" | shasum -a 256 | cut -c1-12)"
  fi
fi

# Merge timestamp into the hook data and append
printf '%s' "$STDIN_DATA" | jq -c --arg ts "$TIMESTAMP" --arg project_key "$PROJECT_KEY" '. + { logged_at: $ts, project_key: $project_key }' >>"$LOG_FILE" 2>/dev/null || true

exit 0
