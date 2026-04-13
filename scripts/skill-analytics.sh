#!/usr/bin/env bash
# Shared append-only writer for skill usage analytics.
# Usage: skill-analytics.sh <event> <skill> [--command <cmd>] [--detail <json>].
# Valid events are hook_fired, completed, aborted, red_flag, selected, and reference_loaded.
# This script fails open and exits 0 even when validation or writes fail.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_DIR="${CLAUDE_PLUGIN_DATA:-$PROJECT_ROOT/.tmp}"
TARGET="$BASE_DIR/analytics/skill-usage.jsonl"
DETAIL='{}'
COMMAND_NAME=""

[ $# -ge 2 ] || exit 0
EVENT="$1"
SKILL="$2"
shift 2

case "$EVENT" in
  hook_fired | completed | aborted | red_flag | selected | reference_loaded) ;;
  *) exit 0 ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    --command) [ $# -ge 2 ] || exit 0; COMMAND_NAME="$2"; shift 2 ;;
    --detail) [ $# -ge 2 ] || exit 0; DETAIL="$2"; shift 2 ;;
    *) exit 0 ;;
  esac
done

command -v jq >/dev/null 2>&1 || exit 0
DETAIL_JSON="$(printf '%s' "$DETAIL" | jq -c '.' 2>/dev/null)" || DETAIL_JSON='{}'
PAYLOAD="$(jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg event "$EVENT" \
  --arg skill "$SKILL" \
  --arg command "$COMMAND_NAME" \
  --argjson detail "$DETAIL_JSON" \
  '{ts:$ts,event:$event,skill:$skill,command:$command,detail:$detail}')" || exit 0

mkdir -p "$(dirname "$TARGET")" 2>/dev/null || exit 0
printf '%s\n' "$PAYLOAD" >>"$TARGET" 2>/dev/null || true
exit 0
