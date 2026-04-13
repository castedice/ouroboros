#!/usr/bin/env bash
# Session pattern store: append raw pattern events, prune stale state, and materialize suggestions.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

PATTERN_STORE_DIR="$(learning_base_dir)/patterns"
PATTERN_EVENTS_PATH="$PATTERN_STORE_DIR/events.jsonl"
PATTERN_FEEDBACK_PATH="$PATTERN_STORE_DIR/feedback.jsonl"
PATTERN_CATALOG_PATH="$PATTERN_STORE_DIR/catalog.json"
PATTERN_STATE_PATH="$PATTERN_STORE_DIR/state.json"
CURRENT_PROJECT_KEY="$(learning_project_key)"

fail_open() {
  echo "[session-patterns] fail-open: $1" >&2
  exit 0
}

trap 'fail_open "unexpected error at line ${LINENO}"' ERR

usage() {
  cat >&2 <<'EOF'
Usage:
  session-patterns.sh extract <pattern_type> <pattern_key> <detail_json> [--confidence N] [--session-id ID]
  session-patterns.sh prune [--ttl-days 30]
  session-patterns.sh materialize [--max-suggestions 2] [--min-occurrences 3] [--min-days 2] [--min-confidence 0.55]
  session-patterns.sh feedback <approve|dismiss> <pattern_id>
EOF
}

require_jq() {
  command -v jq >/dev/null 2>&1 || fail_open "jq is required"
}

ensure_pattern_store_dir() {
  mkdir -p "$PATTERN_STORE_DIR" 2>/dev/null || true
}

default_state_json() {
  printf '%s\n' '{"ttl_days":30,"dismiss_cooldown_days":14,"next_pattern_seq":1,"last_prune_at":null,"last_materialize_at":null}'
}

ensure_state_file() {
  ensure_pattern_store_dir

  if [ ! -f "$PATTERN_STATE_PATH" ]; then
    write_json_file "$PATTERN_STATE_PATH" "$(default_state_json)"
    return 0
  fi

  jq -e '.' "$PATTERN_STATE_PATH" >/dev/null 2>&1 || write_json_file "$PATTERN_STATE_PATH" "$(default_state_json)"
}

ensure_jsonl_file() {
  local target_path="${1:?Missing target path}"

  ensure_pattern_store_dir
  touch "$target_path" 2>/dev/null || true
}

read_state_json() {
  ensure_state_file
  jq -c '.' "$PATTERN_STATE_PATH" 2>/dev/null || default_state_json
}

write_json_file() {
  local target_path="${1:?Missing target path}"
  local payload="${2:?Missing payload}"
  local target_dir=""
  local temp_path=""

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir" 2>/dev/null || true
  temp_path="$(mktemp "$target_dir/.session-patterns.XXXXXX")"
  printf '%s\n' "$payload" >"$temp_path"
  mv "$temp_path" "$target_path"
}

jsonl_length() {
  local target_path="${1:?Missing target path}"

  if [ ! -s "$target_path" ]; then
    printf '0\n'
    return 0
  fi

  jq -s 'length' "$target_path" 2>/dev/null || printf '0\n'
}

catalog_pattern_id() {
  local pattern_key="${1:?Missing pattern key}"
  local existing_id=""
  local day_key=""
  local sequence=""

  if [ -f "$PATTERN_CATALOG_PATH" ]; then
    existing_id="$(jq -r \
      --arg project_key "$CURRENT_PROJECT_KEY" \
      --arg pattern_key "$pattern_key" \
      '(.entries // [])
       | map(select(.project_key == $project_key and .pattern_key == $pattern_key and (.pattern_id // "" | test("^PAT-[0-9]{8}-[0-9]{3}$"))))
       | first
       | .pattern_id // empty' "$PATTERN_CATALOG_PATH" 2>/dev/null || true)"
  fi

  if [ -z "$existing_id" ] && [ -f "$PATTERN_EVENTS_PATH" ]; then
    existing_id="$(jq -r \
      --arg project_key "$CURRENT_PROJECT_KEY" \
      --arg pattern_key "$pattern_key" \
      'select(.project_key == $project_key and .pattern_key == $pattern_key and (.pattern_id // "" | test("^PAT-[0-9]{8}-[0-9]{3}$"))) | .pattern_id' \
      "$PATTERN_EVENTS_PATH" 2>/dev/null | head -n 1 || true)"
  fi

  if [ -n "$existing_id" ]; then
    printf '%s\n' "$existing_id"
    return 0
  fi

  day_key="$(date -u +%Y%m%d)"
  sequence="$(next_pattern_sequence)"
  printf 'PAT-%s-%03d\n' "$day_key" "$sequence"
}

next_pattern_sequence() {
  local lock_dir=""
  local attempt=0
  local state_json=""
  local next_pattern_seq=""
  local updated_state=""

  ensure_state_file
  lock_dir="${PATTERN_STATE_PATH}.lock"

  while [ "$attempt" -lt 20 ]; do
    if mkdir "$lock_dir" 2>/dev/null; then
      state_json="$(read_state_json)"
      next_pattern_seq="$(printf '%s' "$state_json" | jq -r '.next_pattern_seq // 1' 2>/dev/null || printf '1')"
      if ! [[ "$next_pattern_seq" =~ ^[0-9]+$ ]]; then
        next_pattern_seq=1
      fi

      updated_state="$(printf '%s' "$state_json" | jq -c --argjson next_pattern_seq "$((next_pattern_seq + 1))" '.next_pattern_seq = $next_pattern_seq')" || updated_state="$(default_state_json)"
      write_json_file "$PATTERN_STATE_PATH" "$updated_state"
      rmdir "$lock_dir" 2>/dev/null || true
      printf '%s\n' "$next_pattern_seq"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  printf '%s\n' "$(( (10#$(date -u +%H%M%S) + $$) % 1000 ))"
}

next_pattern_event_id() {
  local day_key=""
  local sequence=""

  day_key="$(date -u +%Y%m%d)"
  sequence="$(next_pattern_sequence)"
  printf 'SPT-%s-%03d\n' "$day_key" "$sequence"
}

rewrite_jsonl_from_array() {
  local target_path="${1:?Missing target path}"
  local array_json="${2:?Missing array json}"
  local temp_path=""
  local target_dir=""

  target_dir="$(dirname "$target_path")"
  mkdir -p "$target_dir" 2>/dev/null || true
  temp_path="$(mktemp "$target_dir/.session-patterns-jsonl.XXXXXX")"
  printf '%s' "$array_json" | jq -c '.[]' >"$temp_path"
  mv "$temp_path" "$target_path"
}

cmd_extract() {
  local pattern_type="${1:?Missing pattern type}"
  local pattern_key="${2:?Missing pattern key}"
  local raw_detail_json="${3:?Missing detail json}"
  local confidence="0.65"
  local session_id=""
  local detail_json=""
  local event_id=""
  local pattern_id=""
  local payload=""

  shift 3 || true

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --confidence)
        confidence="${2:?Missing value for --confidence}"
        shift 2
        ;;
      --session-id)
        session_id="${2:?Missing value for --session-id}"
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  require_jq
  ensure_jsonl_file "$PATTERN_EVENTS_PATH"
  detail_json="$(printf '%s' "$raw_detail_json" | jq -c '.' 2>/dev/null)" || fail_open "invalid detail_json"
  event_id="$(next_pattern_event_id)"
  pattern_id="$(catalog_pattern_id "$pattern_key")"

  payload="$(jq -cn \
    --arg event_id "$event_id" \
    --arg pattern_id "$pattern_id" \
    --arg ts "$(learning_timestamp_utc)" \
    --arg project_key "$CURRENT_PROJECT_KEY" \
    --arg pattern_type "$pattern_type" \
    --arg pattern_key "$pattern_key" \
    --arg session_id "$session_id" \
    --argjson base_confidence "$confidence" \
    --argjson detail "$detail_json" \
    '{
      event_id:$event_id,
      pattern_id:$pattern_id,
      ts:$ts,
      project_key:$project_key,
      pattern_type:$pattern_type,
      pattern_key:$pattern_key,
      session_id:$session_id,
      base_confidence:$base_confidence,
      detail:$detail
    }'
  )" || fail_open "failed to build event payload"

  learning_append_jsonl "$PATTERN_EVENTS_PATH" "$payload"
  printf '%s\n' "$payload"
}

cmd_prune() {
  local ttl_days=""
  local state_json=""
  local dismiss_cooldown_days=""
  local cutoff_epoch=0
  local dismiss_cutoff_epoch=0
  local events_before=0
  local events_after=0
  local feedback_before=0
  local feedback_after=0
  local filtered_events_json='[]'
  local filtered_feedback_json='[]'
  local updated_state=""

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --ttl-days)
        ttl_days="${2:?Missing value for --ttl-days}"
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  require_jq
  ensure_jsonl_file "$PATTERN_EVENTS_PATH"
  ensure_jsonl_file "$PATTERN_FEEDBACK_PATH"

  state_json="$(read_state_json)"
  if [ -z "$ttl_days" ]; then
    ttl_days="$(printf '%s' "$state_json" | jq -r '.ttl_days // 30' 2>/dev/null || printf '30')"
  fi
  dismiss_cooldown_days="$(printf '%s' "$state_json" | jq -r '.dismiss_cooldown_days // 14' 2>/dev/null || printf '14')"
  cutoff_epoch=$(( $(date -u +%s) - (ttl_days * 86400) ))
  dismiss_cutoff_epoch=$(( $(date -u +%s) - (dismiss_cooldown_days * 86400) ))

  events_before="$(jsonl_length "$PATTERN_EVENTS_PATH")"
  filtered_events_json="$(jq -cs --argjson cutoff_epoch "$cutoff_epoch" '
    map(select((((.ts // "" | fromdateiso8601?) // now) >= $cutoff_epoch)))
  ' "$PATTERN_EVENTS_PATH" 2>/dev/null || printf '[]')"
  rewrite_jsonl_from_array "$PATTERN_EVENTS_PATH" "$filtered_events_json"
  events_after="$(jsonl_length "$PATTERN_EVENTS_PATH")"

  feedback_before="$(jsonl_length "$PATTERN_FEEDBACK_PATH")"
  filtered_feedback_json="$(jq -cs --argjson dismiss_cutoff_epoch "$dismiss_cutoff_epoch" '
    map(
      select(
        (.action // "") != "dismiss"
        or ((((.ts // "" | fromdateiso8601?) // now) >= $dismiss_cutoff_epoch))
      )
    )
  ' "$PATTERN_FEEDBACK_PATH" 2>/dev/null || printf '[]')"
  rewrite_jsonl_from_array "$PATTERN_FEEDBACK_PATH" "$filtered_feedback_json"
  feedback_after="$(jsonl_length "$PATTERN_FEEDBACK_PATH")"

  updated_state="$(printf '%s' "$state_json" | jq -c \
    --arg ts "$(learning_timestamp_utc)" \
    --argjson ttl_days "$ttl_days" \
    --argjson dismiss_cooldown_days "$dismiss_cooldown_days" \
    '.ttl_days = $ttl_days
     | .dismiss_cooldown_days = $dismiss_cooldown_days
     | .last_prune_at = $ts'
  )" || updated_state="$(default_state_json)"
  write_json_file "$PATTERN_STATE_PATH" "$updated_state"

  jq -cn \
    --arg ts "$(learning_timestamp_utc)" \
    --argjson ttl_days "$ttl_days" \
    --argjson dismiss_cooldown_days "$dismiss_cooldown_days" \
    --argjson events_pruned "$((events_before - events_after))" \
    --argjson feedback_pruned "$((feedback_before - feedback_after))" \
    '{
      ok:true,
      ts:$ts,
      ttl_days:$ttl_days,
      dismiss_cooldown_days:$dismiss_cooldown_days,
      events_pruned:$events_pruned,
      feedback_pruned:$feedback_pruned
    }'
}

cmd_materialize() {
  local max_suggestions=2
  local min_occurrences=3
  local min_days=2
  local min_confidence="0.55"
  local catalog_json=""
  local state_json=""
  local updated_state=""

  while [ "$#" -gt 0 ]; do
    case "${1:-}" in
      --max-suggestions)
        max_suggestions="${2:?Missing value for --max-suggestions}"
        shift 2
        ;;
      --min-occurrences)
        min_occurrences="${2:?Missing value for --min-occurrences}"
        shift 2
        ;;
      --min-days)
        min_days="${2:?Missing value for --min-days}"
        shift 2
        ;;
      --min-confidence)
        min_confidence="${2:?Missing value for --min-confidence}"
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  require_jq
  ensure_jsonl_file "$PATTERN_EVENTS_PATH"
  ensure_jsonl_file "$PATTERN_FEEDBACK_PATH"

  catalog_json="$(jq -n \
    --slurpfile events "$PATTERN_EVENTS_PATH" \
    --slurpfile feedback "$PATTERN_FEEDBACK_PATH" \
    --arg generated_at "$(learning_timestamp_utc)" \
    --arg project_key "$CURRENT_PROJECT_KEY" \
    --argjson max_suggestions "$max_suggestions" \
    --argjson min_occurrences "$min_occurrences" \
    --argjson min_days "$min_days" \
    --argjson min_confidence "$min_confidence" '
    def round3:
      ((. * 1000) | round) / 1000;
    def dominant_type($items):
      (($items | map(.pattern_type) | sort | group_by(.) | max_by(length)) // []) as $group
      | if ($group | length) > 0 then $group[0] else "" end;
    def dominant_ratio($items):
      (($items | map(.pattern_type) | sort | group_by(.) | map(length) | max) // 0) as $dominant
      | if ($items | length) == 0 then 0 else ($dominant / ($items | length)) end;
    def latest_feedback($pattern_id):
      (($feedback
        | map(select(.project_key == $project_key and .pattern_id == $pattern_id))
        | sort_by(.ts // "")) | last?);
    ($events
      | map(select(.project_key == $project_key))
      | sort_by(.pattern_key, .ts // "")
      | group_by(.pattern_key)
      | map({
          project_key: $project_key,
          pattern_id: (.[0].pattern_id // ""),
          pattern_key: (.[0].pattern_key // ""),
          pattern_type: dominant_type(.),
          occurrences: length,
          day_count: (map((.ts // "")[0:10]) | map(select(length > 0)) | unique | length),
          first_seen: (map(.ts // "") | map(select(length > 0)) | sort | first // null),
          last_seen: (map(.ts // "") | map(select(length > 0)) | sort | last // null),
          avg_base_confidence: ((map(.base_confidence // 0.65) | add) / length),
          dominant_ratio: dominant_ratio(.),
          session_ids: (map(.session_id // "") | map(select(length > 0)) | unique),
          detail: ((sort_by(.ts // "") | last).detail // {})
        })
      | map(. + {
          days_since_last: (
            if .last_seen == null then 0
            else ((now - ((.last_seen | fromdateiso8601?) // now)) / 86400)
            end
          )
        })
      | map(. + {
          confidence: (
            .avg_base_confidence
            * (pow((if .occurrences < 5 then (.occurrences / 5) else 1 end); 0.45))
            * (pow(0.5; ((.days_since_last / 10) * 0.30)))
            * (pow(.dominant_ratio; 0.25))
          )
        })
      | map(. + {
          avg_base_confidence: (.avg_base_confidence | round3),
          dominant_ratio: (.dominant_ratio | round3),
          days_since_last: (.days_since_last | round3),
          confidence: (.confidence | round3)
        })
      | map(. as $entry |
          (latest_feedback($entry.pattern_id)) as $fb |
          . + {
            feedback: $fb,
            status: (
              if $fb == null then "candidate"
              elif ($fb.action == "approve") then "approved"
              elif ($fb.action == "dismiss") then "dismissed"
              else "candidate"
              end
            ),
            eligible: (
              (.occurrences >= $min_occurrences)
              and (.day_count >= $min_days)
              and (.confidence >= $min_confidence)
            )
          }
      )
    ) as $entries
    | {
        generated_at: $generated_at,
        project_key: $project_key,
        thresholds: {
          max_suggestions: $max_suggestions,
          min_occurrences: $min_occurrences,
          min_days: $min_days,
          min_confidence: $min_confidence
        },
        entries: ($entries | sort_by(-.confidence, -.occurrences, .pattern_key)),
        suggestions: (
          $entries
          | map(select(.eligible and .status == "candidate"))
          | sort_by(-.confidence, -.occurrences, .pattern_key)
          | .[:$max_suggestions]
        )
      }'
  )" || fail_open "failed to materialize catalog"

  write_json_file "$PATTERN_CATALOG_PATH" "$catalog_json"

  state_json="$(read_state_json)"
  updated_state="$(printf '%s' "$state_json" | jq -c --arg ts "$(learning_timestamp_utc)" '.last_materialize_at = $ts')" || updated_state="$state_json"
  write_json_file "$PATTERN_STATE_PATH" "$updated_state"

  printf '%s' "$catalog_json" | jq -c '.suggestions'
}

cmd_feedback() {
  local action="${1:?Missing feedback action}"
  local pattern_id="${2:?Missing pattern id}"
  local payload=""
  local catalog_json=""
  local updated_entry=""
  local feedback_ts=""

  case "$action" in
    approve | dismiss) ;;
    *)
      usage
      exit 1
      ;;
  esac

  require_jq
  ensure_jsonl_file "$PATTERN_FEEDBACK_PATH"
  feedback_ts="$(learning_timestamp_utc)"

  payload="$(jq -cn \
    --arg ts "$feedback_ts" \
    --arg project_key "$CURRENT_PROJECT_KEY" \
    --arg pattern_id "$pattern_id" \
    --arg action "$action" \
    '{
      ts:$ts,
      project_key:$project_key,
      pattern_id:$pattern_id,
      action:$action
    }'
  )" || fail_open "failed to build feedback payload"

  learning_append_jsonl "$PATTERN_FEEDBACK_PATH" "$payload"

  if [ -f "$PATTERN_CATALOG_PATH" ] && jq -e '.' "$PATTERN_CATALOG_PATH" >/dev/null 2>&1; then
    catalog_json="$(jq -c \
      --arg project_key "$CURRENT_PROJECT_KEY" \
      --arg pattern_id "$pattern_id" \
      --arg action "$action" \
      --arg ts "$feedback_ts" \
      '.entries = (
         (.entries // [])
         | map(
             if .pattern_id == $pattern_id and .project_key == $project_key then
               .status = (if $action == "dismiss" then "dismissed" else "approved" end)
               | .feedback = { action: $action, ts: $ts, project_key: $project_key, pattern_id: $pattern_id }
             else
               .
             end
           )
       )
       | .suggestions = (
           (.suggestions // [])
           | map(select(.pattern_id != $pattern_id))
         )' "$PATTERN_CATALOG_PATH" 2>/dev/null)" || catalog_json=""

    if [ -n "$catalog_json" ]; then
      write_json_file "$PATTERN_CATALOG_PATH" "$catalog_json"
      updated_entry="$(printf '%s' "$catalog_json" | jq -c --arg pattern_id "$pattern_id" '(.entries // [] | map(select(.pattern_id == $pattern_id)) | first) // empty' 2>/dev/null || true)"
    fi
  fi

  if [ -n "$updated_entry" ]; then
    printf '%s\n' "$updated_entry"
  else
    printf '%s\n' "$payload"
  fi
}

main() {
  local action="${1:-}"

  case "$action" in
    extract)
      shift || true
      cmd_extract "$@"
      ;;
    prune)
      shift || true
      cmd_prune "$@"
      ;;
    materialize)
      shift || true
      cmd_materialize "$@"
      ;;
    feedback)
      shift || true
      cmd_feedback "$@"
      ;;
    "" | -h | --help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
