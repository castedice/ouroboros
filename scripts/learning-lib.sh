#!/usr/bin/env bash
# Shared helpers for learning pipeline scripts.

set -euo pipefail

LEARNING_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LEARNING_PROJECT_ROOT="$(cd "$LEARNING_LIB_DIR/.." && pwd)"
LEARNING_BASE_DIR="${CLAUDE_PLUGIN_DATA:-$LEARNING_PROJECT_ROOT/.tmp}"
LEARNING_ID_DIR="$LEARNING_BASE_DIR/.learning-ids"

learning_project_root() {
  printf '%s\n' "$LEARNING_PROJECT_ROOT"
}

learning_project_key() {
  local root=""
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  printf '%s' "$root" | shasum -a 256 | cut -c1-12
}

learning_base_dir() {
  printf '%s\n' "$LEARNING_BASE_DIR"
}

learning_sources_dir() {
  printf '%s\n' "$LEARNING_BASE_DIR/sources"
}

learning_source_path() {
  local source_name="${1:?Missing source name}"
  printf '%s\n' "$(learning_sources_dir)/${source_name}.jsonl"
}

learning_skill_dir() {
  local scope="${1:?Missing skill scope}"
  printf '%s\n' "$LEARNING_BASE_DIR/skills/$scope"
}

learning_promises_dir() {
  printf '%s\n' "$LEARNING_BASE_DIR/evolve/promises"
}

learning_timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

learning_sha256() {
  local raw_text="${1-}"
  local hash_value=""

  if command -v sha256sum >/dev/null 2>&1; then
    hash_value="$(printf '%s' "$raw_text" | sha256sum 2>/dev/null | awk '{print $1}')" || return 1
  elif command -v shasum >/dev/null 2>&1; then
    hash_value="$(printf '%s' "$raw_text" | shasum -a 256 2>/dev/null | awk '{print $1}')" || return 1
  else
    return 1
  fi

  printf '%s\n' "$hash_value"
}

learning_append_jsonl() {
  local target_path="${1:?Missing target path}"
  local payload="${2:?Missing JSON payload}"
  local canonical_payload="$payload"
  local lock_dir="${target_path}.lock"
  local attempt=0
  local lock_acquired=0

  if command -v jq >/dev/null 2>&1; then
    canonical_payload="$(printf '%s' "$payload" | jq -c '.' 2>/dev/null)" || return 0
  fi

  mkdir -p "$(dirname "$target_path")" 2>/dev/null || return 0

  while [ "$attempt" -lt 5 ]; do
    if mkdir "$lock_dir" 2>/dev/null; then
      lock_acquired=1
      break
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  printf '%s\n' "$canonical_payload" >>"$target_path" 2>/dev/null || true

  if [ "$lock_acquired" -eq 1 ]; then
    rmdir "$lock_dir" 2>/dev/null || true
  fi

  return 0
}

learning_next_event_id() {
  local prefix="${1:?Missing event prefix}"
  local day_key
  local counter_file
  local lock_dir
  local counter_value=0
  local attempt=0
  local fallback_value

  case "$prefix" in
    EVL | FRC | COR | SES) ;;
    *) return 1 ;;
  esac

  day_key="$(date -u +%Y%m%d)"
  mkdir -p "$LEARNING_ID_DIR" 2>/dev/null || return 1

  counter_file="$LEARNING_ID_DIR/${prefix}-${day_key}.count"
  lock_dir="${counter_file}.lock"

  while [ "$attempt" -lt 20 ]; do
    if mkdir "$lock_dir" 2>/dev/null; then
      if [ -f "$counter_file" ]; then
        counter_value="$(cat "$counter_file" 2>/dev/null || printf '0')"
      fi
      if ! [[ "$counter_value" =~ ^[0-9]+$ ]]; then
        counter_value=0
      fi
      counter_value=$((counter_value + 1))
      printf '%s\n' "$counter_value" >"$counter_file" 2>/dev/null || true
      rmdir "$lock_dir" 2>/dev/null || true
      printf '%s-%s-%03d\n' "$prefix" "$day_key" "$counter_value"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  fallback_value=$(( (10#$(date -u +%H%M%S) + $$) % 1000 ))
  printf '%s-%s-%03d\n' "$prefix" "$day_key" "$fallback_value"
}

learning_looks_like_component_path() {
  local candidate="${1:-}"

  case "$candidate" in
    AGENTS.md | CLAUDE.md | GEMINI.md | hooks/* | commands/* | agents/* | skills/* | templates/* | scripts/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

learning_normalize_component_path() {
  local raw_path="${1:-}"
  local normalized_path=""
  local project_root=""

  [ -n "$raw_path" ] || return 1

  project_root="$(learning_project_root)"
  normalized_path="${raw_path//$'\n'/ }"
  normalized_path="${normalized_path//$'\r'/ }"
  normalized_path="$(printf '%s' "$normalized_path" | sed -E "s/^[[:space:]\"'(){}\\[\\]<>]+//; s/[[:space:]\"'(){}\\[\\]<>.,:;!?]+$//")"

  while [[ "$normalized_path" == ./* ]]; do
    normalized_path="${normalized_path#./}"
  done

  if [[ "$normalized_path" == "$project_root/"* ]]; then
    normalized_path="${normalized_path#"$project_root"/}"
  fi

  if [[ "$normalized_path" == "<repo>/"* ]]; then
    normalized_path="${normalized_path#<repo>/}"
  fi

  printf '%s\n' "$normalized_path"
}

learning_build_task_key() {
  local component="${1:-}"
  local command_name="${2:-}"
  local fallback_session_id="${3:-}"

  if [ -n "$component" ] && [ -n "$command_name" ]; then
    printf '%s:%s\n' "$command_name" "$component"
    return 0
  fi

  if [ -n "$command_name" ] && [ -n "$fallback_session_id" ]; then
    printf '%s:session:%s\n' "$command_name" "$fallback_session_id"
    return 0
  fi

  if [ -n "$component" ]; then
    printf 'component:%s\n' "$component"
    return 0
  fi

  printf '\n'
}

_learning_extract_component_from_json() {
  local structured_json="${1:-}"
  local candidate=""
  local command_text=""

  [ -n "$structured_json" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="$(learning_normalize_component_path "$candidate" 2>/dev/null || true)"
    if learning_looks_like_component_path "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    printf '%s' "$structured_json" | jq -r '
      [
        .tool_input.file_path?,
        .tool_input.path?,
        .file_path?,
        .path?
      ] |
      .[] |
      select(type == "string" and length > 0)
    ' 2>/dev/null || true
  )

  while IFS= read -r command_text; do
    [ -n "$command_text" ] || continue
    candidate="$(_learning_extract_component_from_text "$command_text" 2>/dev/null || true)"
    if [ -n "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    printf '%s' "$structured_json" | jq -r '
      [
        .tool_input.command?
      ] |
      .[] |
      select(type == "string" and length > 0)
    ' 2>/dev/null || true
  )

  return 1
}

_learning_extract_component_from_text() {
  local raw_text="${1:-}"
  local candidate=""

  [ -n "$raw_text" ] || return 1

  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    candidate="$(learning_normalize_component_path "$candidate" 2>/dev/null || true)"
    if learning_looks_like_component_path "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(
    printf '%s' "$raw_text" | grep -Eo '(AGENTS\.md|CLAUDE\.md|commands/[[:alnum:]_.\/-]+|agents/[[:alnum:]_.\/-]+|skills/[[:alnum:]_.\/-]+|templates/[[:alnum:]_.\/-]+|hooks/[[:alnum:]_.\/-]+|scripts/[[:alnum:]_.\/-]+)' 2>/dev/null || true
  )

  return 1
}

_learning_extract_command_from_text() {
  local raw_text="${1:-}"
  local normalized_text=""
  local suffix=""
  local suffix_char=""

  [ -n "$raw_text" ] || return 1

  normalized_text="${raw_text//$'\n'/ }"
  normalized_text="${normalized_text//$'\r'/ }"
  normalized_text="$(printf '%s' "$normalized_text" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  [ -n "$normalized_text" ] || return 1

  case "$normalized_text" in
    평가)
      printf 'evaluate\n'
      return 0
      ;;
    진화)
      printf 'evolve\n'
      return 0
      ;;
    연구)
      printf 'research\n'
      return 0
      ;;
    생성)
      printf 'generate\n'
      return 0
      ;;
    흡수)
      printf 'absorb\n'
      return 0
      ;;
  esac

  if [[ "$normalized_text" =~ (^|[[:space:][:punct:]])/(core|swe|pa)[[:space:]]+([a-z][a-z0-9_-]+) ]]; then
    suffix="${normalized_text:${#BASH_REMATCH[0]}}"
    suffix_char="${suffix:0:1}"
    case "$suffix_char" in
      "" | [[:space:]] | "," | "." | ";" | ":" | "!" | "?" | ")" | "]")
        printf '%s\n' "${BASH_REMATCH[3]}"
        return 0
        ;;
    esac
  fi

  if [[ "$normalized_text" =~ (^|[[:space:][:punct:]])/([a-z][a-z0-9_-]+) ]]; then
    suffix="${normalized_text:${#BASH_REMATCH[0]}}"
    suffix_char="${suffix:0:1}"
    case "$suffix_char" in
      "" | [[:space:]] | "," | "." | ";" | ":" | "!" | "?" | ")" | "]")
        case "${BASH_REMATCH[2]}" in
          rnd | absorb | brainstorm | doctor | evaluate | evolve | generate | research | agenda | ask | brief | capture | compile | day | draft | focus | heartbeat | ingest | init | link | reset | review | specialist | steward | survey | constrain | design | dev | implement | interface | optimize | reverse | ship | spec | spiral | test | tune | understand | verify)
            printf '%s\n' "${BASH_REMATCH[2]}"
            return 0
            ;;
          *)
            return 1
            ;;
        esac
        ;;
    esac
  fi

  return 1
}

learning_extract_route_hint() {
  local raw_text="${1:-}"
  local structured_json="${2:-}"
  local fallback_session_id="${3:-}"
  local component=""
  local command_name=""
  local task_key=""

  command -v jq >/dev/null 2>&1 || return 0

  if [ -n "$structured_json" ] && [ -z "$fallback_session_id" ]; then
    fallback_session_id="$(printf '%s' "$structured_json" | jq -r '.session_id // .session // empty' 2>/dev/null || true)"
  fi

  if [ -n "$structured_json" ]; then
    component="$(_learning_extract_component_from_json "$structured_json" 2>/dev/null || true)"
  fi

  if [ -z "$component" ] && [ -n "$raw_text" ]; then
    component="$(_learning_extract_component_from_text "$raw_text" 2>/dev/null || true)"
  fi

  if [ -n "$raw_text" ]; then
    command_name="$(_learning_extract_command_from_text "$raw_text" 2>/dev/null || true)"
  fi

  task_key="$(learning_build_task_key "$component" "$command_name" "$fallback_session_id")"

  if [ -z "$component" ] && [ -z "$command_name" ] && [ -z "$task_key" ]; then
    return 0
  fi

  jq -cn \
    --arg component "$component" \
    --arg command "$command_name" \
    --arg task_key "$task_key" \
    '{component:$component,command:$command,task_key:$task_key}'
}

_learning_epoch_from_iso() {
  local iso_ts="${1:?Missing timestamp}"

  if date -u -d "$iso_ts" +%s >/dev/null 2>&1; then
    date -u -d "$iso_ts" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s
    return 0
  fi

  return 1
}

learning_is_within_ttl() {
  local iso_ts="${1:?Missing timestamp}"
  local ttl_days="${2:-90}"
  local now_epoch
  local event_epoch
  local ttl_seconds

  now_epoch="$(date -u +%s)"
  event_epoch="$(_learning_epoch_from_iso "$iso_ts")" || return 1
  ttl_seconds=$((ttl_days * 86400))

  (( now_epoch - event_epoch <= ttl_seconds ))
}
