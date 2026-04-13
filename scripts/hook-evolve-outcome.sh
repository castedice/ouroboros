#!/usr/bin/env bash
# Logs evolution cycle outcomes after verdict resolution.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVENT="${1:-}"
COMPONENT="${2:-}"
VERDICT="${3:-}"
RETRY_COUNT="${4:-}"
DETAIL='{}'

[ -n "$EVENT" ] || exit 0
[ -n "$COMPONENT" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  DETAIL="$(jq -cn --arg component "$COMPONENT" --arg verdict "$VERDICT" --arg retry_count "$RETRY_COUNT" '{component:$component,verdict:$verdict,retry_count:$retry_count}')" || DETAIL='{}'
fi

bash "$SCRIPT_DIR/skill-analytics.sh" "$EVENT" evolution-methodology --detail "$DETAIL" >/dev/null 2>&1 || true
exit 0
