#!/usr/bin/env bash
# Normalize saved evaluation JSON into learning source events.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

EVALUATION_FILE="${1:-}"

_learning_eval_fail_open() {
  echo "[learning-ingest-eval] fail-open: $1" >&2
  exit 0
}

trap '_learning_eval_fail_open "unexpected error at line ${LINENO}"' ERR

normalize_timestamp_utc() {
  local raw_ts="${1:-}"
  local normalized="$raw_ts"
  local compact_ts=""

  if [ -z "$raw_ts" ]; then
    learning_timestamp_utc
    return 0
  fi

  compact_ts="$(printf '%s' "$raw_ts" | sed -E 's/\.([0-9]+)(Z|[+-][0-9]{2}:[0-9]{2})$/\2/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"

  if date -u -d "$raw_ts" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -u -d "$raw_ts" +"%Y-%m-%dT%H:%M:%SZ"
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%S%z" "$compact_ts" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%S%z" "$compact_ts" +"%Y-%m-%dT%H:%M:%SZ"
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$compact_ts" +"%Y-%m-%dT%H:%M:%SZ" >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$compact_ts" +"%Y-%m-%dT%H:%M:%SZ"
    return 0
  fi

  printf '%s\n' "$normalized"
}

resolve_path() {
  local raw_path="${1:-}"
  local project_root

  [ -n "$raw_path" ] || return 1
  project_root="$(learning_project_root)"

  if [ -f "$raw_path" ]; then
    printf '%s\n' "$raw_path"
    return 0
  fi

  if [ -f "$project_root/$raw_path" ]; then
    printf '%s\n' "$project_root/$raw_path"
    return 0
  fi

  return 1
}

file_sha256() {
  local target_path="${1:-}"
  local file_content=""

  [ -f "$target_path" ] || return 1
  file_content="$(cat "$target_path" 2>/dev/null || true)"
  learning_sha256 "$file_content" 2>/dev/null
}

append_component_event() {
  local event_ts="${1:?Missing timestamp}"
  local eval_hash="${2:?Missing eval hash}"
  local component_json="${3:?Missing component json}"
  local component_path=""
  local component_file=""
  local content_hash=""
  local level=0
  local score=0
  local max_score=0
  local failed_criteria_json="[]"
  local improvements_json="[]"
  local event_id=""
  local payload=""

  component_path="$(printf '%s' "$component_json" | jq -r '.path // empty' 2>/dev/null || true)"
  [ -n "$component_path" ] || return 0

  level="$(printf '%s' "$component_json" | jq -r '.level // 0' 2>/dev/null || printf '0')"
  score="$(printf '%s' "$component_json" | jq -r 'reduce ((.scores // {}) | to_entries[]) as $entry (0; . + ($entry.value[0] // 0))' 2>/dev/null || printf '0')"
  max_score="$(printf '%s' "$component_json" | jq -r 'reduce ((.scores // {}) | to_entries[]) as $entry (0; . + ($entry.value[1] // 0))' 2>/dev/null || printf '0')"
  failed_criteria_json="$(printf '%s' "$component_json" | jq -c '[.criteria[]? | select((.score // 0) == 0) | .id]' 2>/dev/null || printf '[]')"
  improvements_json="$(printf '%s' "$component_json" | jq -c '[.improvements[]? | {priority:(.priority // ""), criterion:(.criterion // ""), description:(.description // "")}]' 2>/dev/null || printf '[]')"

  if component_file="$(resolve_path "$component_path" 2>/dev/null || true)"; then
    content_hash="$(file_sha256 "$component_file" 2>/dev/null || true)"
  fi

  event_id="$(learning_next_event_id "EVL" 2>/dev/null || printf 'EVL-%s-000' "$(date -u +%Y%m%d)")"
  payload="$(jq -cn \
    --arg event_id "$event_id" \
    --arg ts "$event_ts" \
    --arg source "evaluation" \
    --arg component "$component_path" \
    --arg task_key "evaluate:${component_path}" \
    --argjson level "$level" \
    --argjson score "$score" \
    --argjson max_score "$max_score" \
    --argjson failed_criteria "$failed_criteria_json" \
    --argjson improvements "$improvements_json" \
    --arg content_hash "$content_hash" \
    --arg eval_hash "$eval_hash" \
    --argjson confidence '0.80' \
    '{
      event_id:$event_id,
      ts:$ts,
      source:$source,
      component:$component,
      task_key:$task_key,
      level:$level,
      score:$score,
      max_score:$max_score,
      failed_criteria:$failed_criteria,
      improvements:$improvements,
      content_hash:$content_hash,
      eval_hash:$eval_hash,
      confidence:$confidence
    }'
  )" || return 0

  learning_append_jsonl "$(learning_source_path "evaluations")" "$payload"
}

main() {
  local evaluation_path=""
  local evaluation_content=""
  local evaluation_hash=""
  local event_ts=""
  local component_json=""

  [ -n "$EVALUATION_FILE" ] || exit 0
  command -v jq >/dev/null 2>&1 || exit 0

  evaluation_path="$(resolve_path "$EVALUATION_FILE" 2>/dev/null || true)"
  [ -n "$evaluation_path" ] || exit 0
  [ -f "$evaluation_path" ] || exit 0

  evaluation_content="$(cat "$evaluation_path" 2>/dev/null || true)"
  evaluation_hash="$(learning_sha256 "$evaluation_content" 2>/dev/null || true)"
  event_ts="$(jq -r '.timestamp // empty' "$evaluation_path" 2>/dev/null || true)"
  event_ts="$(normalize_timestamp_utc "$event_ts")"

  while IFS= read -r component_json; do
    [ -n "$component_json" ] || continue
    append_component_event "$event_ts" "$evaluation_hash" "$component_json"
  done < <(jq -c '.components[]?' "$evaluation_path" 2>/dev/null || true)
}

main "$@"
exit 0
