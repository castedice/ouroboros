#!/usr/bin/env bash
# Load the highest-signal local learnings for a component or skill scope.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

DEFAULT_MAX=3

usage() {
  echo "Usage: learning-load-context.sh <component-path-or-skill-scope> [--max N] [--format text|json]" >&2
}

trim_text() {
  printf '%s' "${1-}" |
    tr '\r' ' ' |
    tr '\t' ' ' |
    sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

file_mtime_epoch() {
  local target_path="${1:?Missing target path}"

  if stat -f %m "$target_path" >/dev/null 2>&1; then
    stat -f %m "$target_path"
    return 0
  fi

  if stat -c %Y "$target_path" >/dev/null 2>&1; then
    stat -c %Y "$target_path"
    return 0
  fi

  return 1
}

resolve_scope() {
  local raw_input="${1:?Missing target}"

  bash "$SCRIPT_DIR/learning-distill.sh" scope "$raw_input" 2>/dev/null || true
}

read_last_distilled_at() {
  local state_path="${1:?Missing state path}"

  [ -f "$state_path" ] || return 0

  if command -v jq >/dev/null 2>&1; then
    jq -r '.last_distilled_at // empty' "$state_path" 2>/dev/null || true
    return 0
  fi

  sed -nE 's/.*"last_distilled_at"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$state_path" 2>/dev/null | head -n 1
}

scope_has_undistilled_sources() {
  local skill_scope="${1:?Missing skill scope}"
  local sources_dir
  local state_path
  local last_distilled_at
  local last_distilled_epoch
  local source_path
  local source_epoch

  sources_dir="$(learning_sources_dir)"
  [ -d "$sources_dir" ] || return 1
  find "$sources_dir" -maxdepth 1 -type f -name '*.jsonl' | grep -q . 2>/dev/null || return 1

  state_path="$(learning_skill_dir "$skill_scope")/state.json"
  last_distilled_at="$(read_last_distilled_at "$state_path")"

  if [ -z "$last_distilled_at" ]; then
    return 0
  fi

  last_distilled_epoch="$(_learning_epoch_from_iso "$last_distilled_at" 2>/dev/null)" || return 0

  while IFS= read -r source_path; do
    [ -n "$source_path" ] || continue
    source_epoch="$(file_mtime_epoch "$source_path" 2>/dev/null || printf '0')"
    if [ "$source_epoch" -gt "$last_distilled_epoch" ]; then
      return 0
    fi
  done < <(find "$sources_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | sort)

  return 1
}

maybe_distill() {
  local skill_scope="${1:?Missing skill scope}"

  if scope_has_undistilled_sources "$skill_scope"; then
    bash "$SCRIPT_DIR/learning-distill.sh" distill >/dev/null 2>&1 || true
  fi
}

parse_gotcha_entries() {
  local gotchas_path="${1:?Missing gotchas path}"

  [ -s "$gotchas_path" ] || return 0

  awk '
    function clean(value) {
      gsub(/\r/, " ", value)
      gsub(/\t/, " ", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function flush() {
      if (entry_id == "") {
        return
      }
      printf "gotcha\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", confidence, entry_id, title, rule, applies_to, verify_with, promoted_from
    }
    /^## GOTCHA-/ {
      flush()
      line = $0
      sub(/^##[[:space:]]+/, "", line)
      split(line, parts, /[[:space:]]+/)
      entry_id = clean(parts[1])
      title = line
      sub(/^[^[:space:]]+[[:space:]]+/, "", title)
      sub(/^[^[:alnum:]]+/, "", title)
      title = clean(title)
      confidence = "0"
      promoted_from = ""
      rule = ""
      applies_to = ""
      verify_with = ""
      next
    }
    /^- promoted_from: / {
      value = $0
      sub(/^- promoted_from: /, "", value)
      promoted_from = clean(value)
      next
    }
    /^- confidence: / {
      value = $0
      sub(/^- confidence: /, "", value)
      confidence = clean(value)
      next
    }
    /^- rule: / {
      value = $0
      sub(/^- rule: /, "", value)
      rule = clean(value)
      next
    }
    /^- applies_to: / {
      value = $0
      sub(/^- applies_to: /, "", value)
      applies_to = clean(value)
      next
    }
    /^- verify_with: / {
      value = $0
      sub(/^- verify_with: /, "", value)
      verify_with = clean(value)
      next
    }
    END {
      flush()
    }
  ' "$gotchas_path" 2>/dev/null | LC_ALL=C sort -t $'\t' -k2,2nr
}

parse_active_learned_entries() {
  local learned_path="${1:?Missing learned path}"

  [ -s "$learned_path" ] || return 0

  awk '
    function clean(value) {
      gsub(/\r/, " ", value)
      gsub(/\t/, " ", value)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    function flush() {
      if (entry_id == "") {
        return
      }
      printf "learning\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", effective_confidence, entry_id, title, category, confidence, learning, action, source_context
    }
    /^## Active$/ {
      section = "active"
      next
    }
    /^## Archived$/ {
      section = "archived"
      flush()
      entry_id = ""
      next
    }
    section != "active" {
      next
    }
    /^### LRN-/ {
      flush()
      line = $0
      sub(/^###[[:space:]]+/, "", line)
      split(line, parts, /[[:space:]]+/)
      entry_id = clean(parts[1])
      title = line
      sub(/^[^[:space:]]+[[:space:]]+/, "", title)
      sub(/^[^[:alnum:]]+/, "", title)
      title = clean(title)
      category = ""
      confidence = "0"
      effective_confidence = "0"
      learning = ""
      action = ""
      source_context = ""
      next
    }
    /^- category: / {
      value = $0
      sub(/^- category: /, "", value)
      category = clean(value)
      next
    }
    /^- confidence: / {
      value = $0
      sub(/^- confidence: /, "", value)
      confidence = clean(value)
      next
    }
    /^- effective_confidence: / {
      value = $0
      sub(/^- effective_confidence: /, "", value)
      effective_confidence = clean(value)
      next
    }
    /^- source_context: / {
      value = $0
      sub(/^- source_context: /, "", value)
      source_context = clean(value)
      next
    }
    /^- learning: / {
      value = $0
      sub(/^- learning: /, "", value)
      learning = clean(value)
      next
    }
    /^- action: / {
      value = $0
      sub(/^- action: /, "", value)
      action = clean(value)
      next
    }
    END {
      flush()
    }
  ' "$learned_path" 2>/dev/null | LC_ALL=C sort -t $'\t' -k2,2nr
}

render_text_output() {
  local skill_scope="${1:?Missing skill scope}"
  shift
  local records=("$@")
  local index=1
  local record
  local kind
  local score
  local entry_id
  local title
  local field_a
  local field_b
  local field_c
  local field_d
  local field_e
  local field_f

  printf 'Prior Learnings — %s\n\n' "$skill_scope"

  for record in "${records[@]}"; do
    IFS=$'\t' read -r kind score entry_id title field_a field_b field_c field_d field_e field_f <<<"$record"
    if [ "$kind" = "gotcha" ]; then
      printf '%s. %s — %s\n' "$index" "$entry_id" "$title"
      printf '   confidence: %s\n' "$(trim_text "$score")"
      printf '   rule: %s\n' "$(trim_text "$field_a")"
      if [ -n "$(trim_text "$field_b")" ]; then
        printf '   applies_to: %s\n' "$(trim_text "$field_b")"
      fi
      if [ -n "$(trim_text "$field_c")" ]; then
        printf '   verify_with: %s\n' "$(trim_text "$field_c")"
      fi
    else
      printf '%s. %s — %s\n' "$index" "$entry_id" "$title"
      printf '   category: %s\n' "$(trim_text "$field_a")"
      printf '   effective_confidence: %s\n' "$(trim_text "$score")"
      printf '   learning: %s\n' "$(trim_text "$field_c")"
      if [ -n "$(trim_text "$field_d")" ]; then
        printf '   action: %s\n' "$(trim_text "$field_d")"
      fi
      if [ -n "$(trim_text "$field_e")" ]; then
        printf '   source_context: %s\n' "$(trim_text "$field_e")"
      fi
    fi
    if [ "$index" -lt "${#records[@]}" ]; then
      printf '\n'
    fi
    index=$((index + 1))
  done
}

render_json_output() {
  local skill_scope="${1:?Missing skill scope}"
  shift
  local records=("$@")
  local temp_jsonl
  local record
  local kind
  local score
  local entry_id
  local title
  local field_a
  local field_b
  local field_c
  local field_d
  local field_e
  local field_f

  command -v jq >/dev/null 2>&1 || return 0

  temp_jsonl="$(mktemp)"
  for record in "${records[@]}"; do
    IFS=$'\t' read -r kind score entry_id title field_a field_b field_c field_d field_e field_f <<<"$record"
    if [ "$kind" = "gotcha" ]; then
      jq -cn \
        --arg kind "gotcha" \
        --arg scope "$skill_scope" \
        --arg id "$entry_id" \
        --arg title "$title" \
        --arg confidence "$score" \
        --arg rule "$field_a" \
        --arg applies_to "$field_b" \
        --arg verify_with "$field_c" \
        --arg promoted_from "$field_d" \
        '{
          kind:$kind,
          scope:$scope,
          id:$id,
          title:$title,
          confidence:($confidence | tonumber),
          rule:$rule,
          applies_to:$applies_to,
          verify_with:$verify_with,
          promoted_from:$promoted_from
        }' >>"$temp_jsonl"
    else
      jq -cn \
        --arg kind "learning" \
        --arg scope "$skill_scope" \
        --arg id "$entry_id" \
        --arg title "$title" \
        --arg category "$field_a" \
        --arg confidence "$field_b" \
        --arg effective_confidence "$score" \
        --arg learning "$field_c" \
        --arg action "$field_d" \
        --arg source_context "$field_e" \
        '{
          kind:$kind,
          scope:$scope,
          id:$id,
          title:$title,
          category:$category,
          confidence:($confidence | tonumber),
          effective_confidence:($effective_confidence | tonumber),
          learning:$learning,
          action:$action,
          source_context:$source_context
        }' >>"$temp_jsonl"
    fi
    printf '\n' >>"$temp_jsonl"
  done

  jq -s '.' "$temp_jsonl"
  rm -f "$temp_jsonl"
}

TARGET_INPUT="${1:-}"
[ -n "$TARGET_INPUT" ] || {
  usage
  exit 1
}
shift || true

MAX_ENTRIES="$DEFAULT_MAX"
OUTPUT_FORMAT="text"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --max)
      shift || {
        usage
        exit 1
      }
      MAX_ENTRIES="${1:-}"
      ;;
    --format)
      shift || {
        usage
        exit 1
      }
      OUTPUT_FORMAT="${1:-}"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift || true
done

[[ "$MAX_ENTRIES" =~ ^[1-9][0-9]*$ ]] || {
  usage
  exit 1
}

case "$OUTPUT_FORMAT" in
  text | json) ;;
  *)
    usage
    exit 1
    ;;
esac

SKILL_SCOPE="$(trim_text "$(resolve_scope "$TARGET_INPUT")")"
[ -n "$SKILL_SCOPE" ] || exit 0

maybe_distill "$SKILL_SCOPE"

SKILL_DIR="$(learning_skill_dir "$SKILL_SCOPE")"
GOTCHAS_PATH="$SKILL_DIR/gotchas.md"
LEARNED_PATH="$SKILL_DIR/learned.md"

declare -a SELECTED_RECORDS=()
declare -A PROMOTED_LEARNING_IDS=()

remaining="$MAX_ENTRIES"

if [ -f "$GOTCHAS_PATH" ]; then
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    SELECTED_RECORDS+=("$record")
    promoted_from="$(printf '%s' "$record" | cut -f8)"
    if [ -n "$promoted_from" ]; then
      PROMOTED_LEARNING_IDS["${promoted_from##*:}"]=1
    fi
    remaining=$((remaining - 1))
    if [ "$remaining" -le 0 ]; then
      break
    fi
  done < <(parse_gotcha_entries "$GOTCHAS_PATH")
fi

if [ "$remaining" -gt 0 ] && [ -f "$LEARNED_PATH" ]; then
  while IFS= read -r record; do
    [ -n "$record" ] || continue
    learning_id="$(printf '%s' "$record" | cut -f3)"
    if [ -n "${PROMOTED_LEARNING_IDS[$learning_id]:-}" ]; then
      continue
    fi
    SELECTED_RECORDS+=("$record")
    remaining=$((remaining - 1))
    if [ "$remaining" -le 0 ]; then
      break
    fi
  done < <(parse_active_learned_entries "$LEARNED_PATH")
fi

[ "${#SELECTED_RECORDS[@]}" -gt 0 ] || exit 0

if [ "$OUTPUT_FORMAT" = "json" ]; then
  render_json_output "$SKILL_SCOPE" "${SELECTED_RECORDS[@]}"
else
  render_text_output "$SKILL_SCOPE" "${SELECTED_RECORDS[@]}"
fi
