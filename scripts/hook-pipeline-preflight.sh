#!/usr/bin/env bash
# Logs content-pipeline extractor selection before ingestion.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FORMAT="${1:-}"
SELECTED_EXTRACTOR="${2:-}"
AVAILABLE_FALLBACKS="${3:-}"
DETAIL='{}'

[ -n "$FORMAT" ] || exit 0

if command -v jq >/dev/null 2>&1; then
  DETAIL="$(jq -cn --arg format "$FORMAT" --arg selected_extractor "$SELECTED_EXTRACTOR" --arg available_fallbacks "$AVAILABLE_FALLBACKS" '{format:$format,selected_extractor:$selected_extractor,available_fallbacks:$available_fallbacks}')" || DETAIL='{}'
fi

bash "$SCRIPT_DIR/skill-analytics.sh" hook_fired content-pipeline --detail "$DETAIL" >/dev/null 2>&1 || true
exit 0
