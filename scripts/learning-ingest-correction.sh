#!/usr/bin/env bash
# Detect explicit user corrections and append privacy-safe learning events.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

USER_MESSAGE_LOG="${HOME}/.claude/user-messages.jsonl"
CHECKPOINT_PATH="$(learning_sources_dir)/.correction-checkpoint.json"
MESSAGE_CHECKPOINT=0
MESSAGE_TOTAL=0

_learning_correction_fail_open() {
  echo "[learning-ingest-correction] fail-open: $1" >&2
  exit 0
}

trap '_learning_correction_fail_open "unexpected error at line ${LINENO}"' ERR

detect_correction() {
  local raw_text="${1:-}"
  local lowered=""

  [ -n "$raw_text" ] || return 1
  lowered="$(printf '%s' "$raw_text" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lowered" =~ ^no,[[:space:]]+use[[:space:]]+.+[[:space:]]instead[[:space:]]*$|^use[[:space:]]+.+[[:space:]]instead[[:space:]]*$ ]]; then
    printf 'replacement|use_instead\n'
    return 0
  fi

  if [[ "$raw_text" =~ 대신[[:space:]]|말고[[:space:]] ]]; then
    printf 'replacement|ko_use_instead\n'
    return 0
  fi

  if [[ "$lowered" =~ you[[:space:]]+forgot|you[[:space:]]+missed|forgot[[:space:]]+to|left[[:space:]]+out|missed[[:space:]]+the ]]; then
    printf 'omission|missing_content\n'
    return 0
  fi

  if [[ "$raw_text" =~ 빠뜨렸|빠뜨린|빼먹|잊었 ]]; then
    printf 'omission|ko_missing_content\n'
    return 0
  fi

  if [[ "$lowered" =~ that.s[[:space:]]+not[[:space:]]+what[[:space:]]+i[[:space:]]+asked|not[[:space:]]+what[[:space:]]+i[[:space:]]+asked|i[[:space:]]+said|i[[:space:]]+asked[[:space:]]+for ]]; then
    printf 'wrong-target|wrong_target\n'
    return 0
  fi

  if [[ "$raw_text" =~ 그게[[:space:]]아니라|아까[[:space:]]말한|내가[[:space:]]말한|원한[[:space:]]건 ]]; then
    printf 'wrong-target|ko_wrong_target\n'
    return 0
  fi

  if [[ "$lowered" =~ ^wrong[[:space:][:punct:]]*$|^incorrect[[:space:][:punct:]]*$|that.s[[:space:]]+wrong|that.s[[:space:]]+incorrect|this[[:space:]]+is[[:space:]]+wrong|this[[:space:]]+is[[:space:]]+incorrect ]]; then
    printf 'general|general_negative\n'
    return 0
  fi

  if [[ "$raw_text" =~ 틀렸|잘못(했|됐)|다시[[:space:]](해|해줘|해주세요|돌려|시도|진행|작성|보내)|제대로[[:space:]]해줘 ]]; then
    printf 'general|ko_general_negative\n'
    return 0
  fi

  return 1
}

load_checkpoint() {
  if [ -f "$CHECKPOINT_PATH" ] && command -v jq >/dev/null 2>&1; then
    MESSAGE_CHECKPOINT="$(jq -r '.user_messages.last_line // 0' "$CHECKPOINT_PATH" 2>/dev/null || printf '0')"
  fi

  [[ "$MESSAGE_CHECKPOINT" =~ ^[0-9]+$ ]] || MESSAGE_CHECKPOINT=0
}

save_checkpoint() {
  local checkpoint_json=""

  checkpoint_json="$(jq -cn \
    --arg version "1" \
    --arg updated_at "$(learning_timestamp_utc)" \
    --argjson message_last "$MESSAGE_TOTAL" \
    '{
      version:$version,
      updated_at:$updated_at,
      user_messages:{last_line:$message_last}
    }'
  )" || return 0

  mkdir -p "$(dirname "$CHECKPOINT_PATH")" 2>/dev/null || return 0
  printf '%s\n' "$checkpoint_json" >"$CHECKPOINT_PATH" 2>/dev/null || true
}

emit_correction_event() {
  local ts="${1:?Missing timestamp}"
  local session_id="${2:-unknown}"
  local message_hash="${3:?Missing message hash}"
  local correction_type="${4:?Missing correction type}"
  local matched_rule="${5:-unknown}"
  local message_length="${6:-0}"
  local task_key="${7:-session:${session_id}}"
  local component="${8:-}"
  local event_id=""
  local payload=""

  event_id="$(learning_next_event_id "COR" 2>/dev/null || printf 'COR-%s-000' "$(date -u +%Y%m%d)")"
  payload="$(jq -cn \
    --arg event_id "$event_id" \
    --arg ts "$ts" \
    --arg source "correction" \
    --arg session_id "$session_id" \
    --arg task_key "$task_key" \
    --arg correction_type "$correction_type" \
    --arg pattern_hash "$message_hash" \
    --arg matched_rule "$matched_rule" \
    --arg message_length "$message_length" \
    --arg component "$component" \
    --argjson confidence '0.90' \
    '{
      event_id:$event_id,
      ts:$ts,
      source:$source,
      session_id:$session_id,
      task_key:$task_key,
      correction_type:$correction_type,
      pattern_hash:$pattern_hash,
      confidence:$confidence,
      detail:{
        matched_rule:$matched_rule,
        message_length:($message_length | tonumber? // 0)
      }
    } + (if $component != "" then {component:$component} else {} end)'
  )" || return 0

  learning_append_jsonl "$(learning_source_path "corrections")" "$payload"
}

process_user_messages() {
  local entry_json=""
  local message_text=""
  local session_id=""
  local ts=""
  local message_length=0
  local message_hash=""
  local detection=""
  local correction_type=""
  local matched_rule=""
  local route_hint=""
  local route_component=""
  local route_task_key=""

  [ -f "$USER_MESSAGE_LOG" ] || return 0

  if [ "$(wc -l <"$USER_MESSAGE_LOG" | tr -d ' ')" -lt "$MESSAGE_CHECKPOINT" ]; then
    MESSAGE_CHECKPOINT=0
  fi

  while IFS= read -r entry_json || [ -n "$entry_json" ]; do
    MESSAGE_TOTAL=$((MESSAGE_TOTAL + 1))
    [ "$MESSAGE_TOTAL" -gt "$MESSAGE_CHECKPOINT" ] || continue
    [ -n "$entry_json" ] || continue

    message_text="$(printf '%s' "$entry_json" | jq -r '.text // empty' 2>/dev/null || true)"
    [ -n "$message_text" ] || continue

    detection="$(detect_correction "$message_text" 2>/dev/null || true)"
    [ -n "$detection" ] || continue

    correction_type="${detection%%|*}"
    matched_rule="${detection#*|}"
    ts="$(printf '%s' "$entry_json" | jq -r '.timestamp // empty' 2>/dev/null || true)"
    session_id="$(printf '%s' "$entry_json" | jq -r '.session // "unknown"' 2>/dev/null || printf 'unknown')"
    message_length="$(printf '%s' "$entry_json" | jq -r '.length // 0' 2>/dev/null || printf '0')"
    if [ "${message_length:-0}" -gt 1000 ]; then
      continue
    fi
    route_hint="$(learning_extract_route_hint "$message_text" "$entry_json" "$session_id" 2>/dev/null || true)"
    route_component="$(printf '%s' "$route_hint" | jq -r '.component // empty' 2>/dev/null || true)"
    route_task_key="$(printf '%s' "$route_hint" | jq -r '.task_key // empty' 2>/dev/null || true)"
    message_hash="$(learning_sha256 "$message_text" 2>/dev/null || true)"
    [ -n "$message_hash" ] || continue
    [ -n "$ts" ] || ts="$(learning_timestamp_utc)"

    emit_correction_event "$ts" "$session_id" "$message_hash" "$correction_type" "$matched_rule" "$message_length" "$route_task_key" "$route_component"
  done <"$USER_MESSAGE_LOG"
}

main() {
  command -v jq >/dev/null 2>&1 || exit 0
  load_checkpoint
  process_user_messages
  save_checkpoint
}

main "$@"
exit 0
