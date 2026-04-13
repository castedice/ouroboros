#!/usr/bin/env bash
# Logs evaluation completion or abort after result persistence.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVENT="${1:-}"
COMPONENT="${2:-}"
LEVEL="${3:-}"
MODE="${4:-}"
DETAIL='{}'

[ -n "$EVENT" ] || exit 0
[ -n "$COMPONENT" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  DETAIL="$(jq -cn --arg component "$COMPONENT" --arg level "$LEVEL" --arg mode "$MODE" '{component:$component,level:$level,mode:$mode}')" || DETAIL='{}'
fi

bash "$SCRIPT_DIR/skill-analytics.sh" "$EVENT" evaluation-methodology --detail "$DETAIL" >/dev/null 2>&1 || true
exit 0
