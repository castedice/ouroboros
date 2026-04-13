#!/usr/bin/env bash
# Logs routing decisions after target selection.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_MODEL="${1:-}"
INTEGRATION_MODE="${2:-}"
STAKE_LEVEL="${3:-}"
DETAIL='{}'

[ -n "$TARGET_MODEL" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  DETAIL="$(jq -cn --arg target_model "$TARGET_MODEL" --arg integration_mode "$INTEGRATION_MODE" --arg stake_level "$STAKE_LEVEL" '{target_model:$target_model,integration_mode:$integration_mode,stake_level:$stake_level}')" || DETAIL='{}'
fi

bash "$SCRIPT_DIR/skill-analytics.sh" hook_fired routing-methodology --detail "$DETAIL" >/dev/null 2>&1 || true
exit 0
