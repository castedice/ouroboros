#!/usr/bin/env bash
# Friction report — aggregate user messages and choice log for LLM batch analysis
#
# Usage:
#   friction-report.sh [--since "1 day ago"] [--json] [--limit N]
#
# Data sources:
#   1. ~/.claude/user-messages.jsonl  (UserPromptSubmit hook output)
#   2. ~/.claude/choice-log.jsonl     (PermissionRequest hook output)
#
# This script does NOT classify friction signals — it aggregates raw data
# for Claude to analyze in conversation. LLM classification is more accurate
# than regex matching and avoids false positives.
#
# Exit codes:
#   0 — messages found
#   1 — no messages
#   2 — input error
#
# Part of ouroboros session intelligence (v0.18.5)

set -euo pipefail

# ─── Parse Args ───

SINCE=""
OUTPUT_JSON=false
LIMIT=50

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      SINCE="${2:-}"
      shift 2
      ;;
    --json)
      OUTPUT_JSON=true
      shift
      ;;
    --limit)
      LIMIT="${2:-50}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required" >&2
  exit 2
fi

MSG_LOG="${HOME}/.claude/user-messages.jsonl"
CHOICE_LOG="${HOME}/.claude/choice-log.jsonl"

# ─── Collect Messages ───

MESSAGES="[]"

if [[ -f "$MSG_LOG" ]] && [[ -s "$MSG_LOG" ]]; then
  if [[ -n "$SINCE" ]]; then
    # Filter by timestamp
    SINCE_TS=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$(date -u -v-1d +%Y-%m-%dT%H:%M:%SZ)" +%s 2>/dev/null || date -d "$SINCE" +%s 2>/dev/null || echo "0")
    MESSAGES=$(jq -sc --argjson limit "$LIMIT" '
      [.[] | select(.timestamp != null)] | sort_by(.timestamp) | .[-$limit:]
    ' "$MSG_LOG" 2>/dev/null || echo "[]")
  else
    MESSAGES=$(tail -"$LIMIT" "$MSG_LOG" | jq -sc '.' 2>/dev/null || echo "[]")
  fi
fi

# ─── Collect Choice Denials ───

DENIALS="[]"

if [[ -f "$CHOICE_LOG" ]] && [[ -s "$CHOICE_LOG" ]]; then
  DENIALS=$(jq -sc '[.[] | select(.action == "deny" or .action == "denied")]' "$CHOICE_LOG" 2>/dev/null || echo "[]")
fi

MSG_COUNT=$(echo "$MESSAGES" | jq 'length')
DENIAL_COUNT=$(echo "$DENIALS" | jq 'length')
TOTAL=$((MSG_COUNT + DENIAL_COUNT))

if [[ "$TOTAL" -eq 0 ]]; then
  if [[ "$OUTPUT_JSON" == true ]]; then
    echo '{"messages":[],"denials":[],"total":0}'
  else
    echo "No accumulated data. Ensure UserPromptSubmit hook is active."
  fi
  exit 1
fi

# ─── Output ───

if [[ "$OUTPUT_JSON" == true ]]; then
  jq -nc \
    --argjson messages "$MESSAGES" \
    --argjson denials "$DENIALS" \
    --argjson total "$TOTAL" \
    '{ messages: $messages, denials: $denials, total: $total }'
  exit 0
fi

echo "=== Friction Report Data ==="
echo ""
echo "Messages: $MSG_COUNT (last $LIMIT)"
echo "Permission denials: $DENIAL_COUNT"
echo ""

if [[ "$MSG_COUNT" -gt 0 ]]; then
  echo "### User Messages"
  echo ""
  echo "$MESSAGES" | jq -r '.[] | "  [\(.timestamp // "?")] \(.text // .raw // "?" | if length > 150 then .[0:150] + "..." else . end)"'
  echo ""
fi

if [[ "$DENIAL_COUNT" -gt 0 ]]; then
  echo "### Permission Denials"
  echo ""
  echo "$DENIALS" | jq -r '.[] | "  [\(.logged_at // "?")] \(.tool // .command // "unknown")"'
  echo ""
fi

echo "---"
echo "Run this in Claude conversation for LLM-based friction classification."
echo "=== End ==="
exit 0
