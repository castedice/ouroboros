#!/usr/bin/env bash
# External autonomous evolution loop driver.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

PROJECT_ROOT="$(learning_project_root)"
BASE_DIR="$(learning_base_dir)"
PROMISES_DIR="$(learning_promises_dir)"
RUN_LOG_DIR="$BASE_DIR/evolve/logs"

ACTION="${1:-}"
TARGET="${2:-}"

MAX_ITERATIONS=3
REQUESTED_THRESHOLD="auto"
QUALITY_THRESHOLD=""
PROMISE_ID=""
PROMISE_FILE=""
PROMISE_CREATED=0
BASELINE_COMPONENT_JSON=""
BASELINE_EVAL_FILE=""
BASELINE_LEVEL=""
BASELINE_SCORE=""

usage() {
  echo "Usage: $(basename "$0") evolve <target> [--max-iterations <n>] [--threshold <auto|level4|no-high>]" >&2
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "[ralph] Error: jq is required." >&2
    exit 1
  fi
}

normalize_fingerprint() {
  local value="${1:-}"
  if [ -z "$value" ]; then
    return 1
  fi

  case "$value" in
    sha256:*) printf '%s\n' "$value" ;;
    *) printf 'sha256:%s\n' "$value" ;;
  esac
}

file_mtime_epoch() {
  local file_path="${1:?Missing file path}"

  if stat -f '%m' "$file_path" >/dev/null 2>&1; then
    stat -f '%m' "$file_path"
    return 0
  fi

  if stat -c '%Y' "$file_path" >/dev/null 2>&1; then
    stat -c '%Y' "$file_path"
    return 0
  fi

  return 1
}

write_file_atomic() {
  local target_path="${1:?Missing target path}"
  local content="${2-}"
  local dir_path
  local tmp_path

  dir_path="$(dirname "$target_path")"
  mkdir -p "$dir_path"
  tmp_path="$(mktemp "$dir_path/.tmp.$(basename "$target_path").XXXXXX")"
  printf '%s\n' "$content" >"$tmp_path"
  mv "$tmp_path" "$target_path"
}

update_promise_status() {
  local next_status="${1:?Missing status}"
  local stop_reason="${2:-}"
  local tmp_path

  [ "$PROMISE_CREATED" -eq 1 ] || return 0
  [ -f "$PROMISE_FILE" ] || return 0

  tmp_path="$(mktemp "$(dirname "$PROMISE_FILE")/.promise.XXXXXX")"
  jq \
    --arg status "$next_status" \
    --arg updated_at "$(learning_timestamp_utc)" \
    --arg stop_reason "$stop_reason" \
    '
      .status = $status
      | .updated_at = $updated_at
      | .stop_reason = (if $stop_reason == "" then null else $stop_reason end)
    ' \
    "$PROMISE_FILE" >"$tmp_path"
  mv "$tmp_path" "$PROMISE_FILE"
}

append_iteration_to_promise() {
  local iteration_json="${1:?Missing iteration json}"
  local next_status="${2:?Missing status}"
  local stop_reason="${3:-}"
  local tmp_path

  [ "$PROMISE_CREATED" -eq 1 ] || return 0
  [ -f "$PROMISE_FILE" ] || return 0

  tmp_path="$(mktemp "$(dirname "$PROMISE_FILE")/.promise.XXXXXX")"
  jq \
    --arg status "$next_status" \
    --arg updated_at "$(learning_timestamp_utc)" \
    --arg stop_reason "$stop_reason" \
    --argjson iteration "$iteration_json" \
    '
      .status = $status
      | .updated_at = $updated_at
      | .current_iteration = ($iteration.iteration // .current_iteration)
      | .stop_reason = (if $stop_reason == "" then null else $stop_reason end)
      | .iterations += [$iteration]
    ' \
    "$PROMISE_FILE" >"$tmp_path"
  mv "$tmp_path" "$PROMISE_FILE"
}

promise_status() {
  [ -f "$PROMISE_FILE" ] || return 1
  jq -r '.status // empty' "$PROMISE_FILE" 2>/dev/null || true
}

handle_interrupt() {
  local signal_name="${1:-INT}"

  trap - INT TERM
  update_promise_status "interrupted" "$(printf '%s' "$signal_name" | tr '[:upper:]' '[:lower:]')"
  echo "[ralph] Interrupted. Promise marked interrupted: $PROMISE_FILE" >&2
  exit 1
}

handle_exit() {
  local exit_code="${1:-0}"
  local status_now=""

  trap - EXIT

  if [ "$exit_code" -ne 0 ] && [ "$PROMISE_CREATED" -eq 1 ] && [ -f "$PROMISE_FILE" ]; then
    status_now="$(promise_status)"
    if [ "$status_now" = "active" ]; then
      update_promise_status "stalled" "error"
    fi
  fi
}

next_promise_id() {
  local day_key
  local counter_file
  local lock_dir
  local counter_value=0
  local attempt=0
  local fallback_value

  day_key="$(date -u +%Y%m%d)"
  mkdir -p "$PROMISES_DIR"

  counter_file="$PROMISES_DIR/.RLP-${day_key}.count"
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
      printf '%s\n' "$counter_value" >"$counter_file"
      rmdir "$lock_dir" 2>/dev/null || true
      printf 'RLP-%s-%03d\n' "$day_key" "$counter_value"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  fallback_value=$(((10#$(date -u +%H%M%S) + $$) % 1000))
  printf 'RLP-%s-%03d\n' "$day_key" "$fallback_value"
}

parse_args() {
  if [ "$ACTION" != "evolve" ] || [ -z "$TARGET" ]; then
    usage
    exit 1
  fi

  shift 2 || true
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --max-iterations)
        [ "$#" -ge 2 ] || { usage; exit 1; }
        MAX_ITERATIONS="$2"
        shift 2
        ;;
      --threshold)
        [ "$#" -ge 2 ] || { usage; exit 1; }
        REQUESTED_THRESHOLD="$2"
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || [ "$MAX_ITERATIONS" -lt 1 ]; then
    echo "[ralph] Error: --max-iterations must be a positive integer." >&2
    exit 1
  fi
}

select_component_from_eval() {
  local eval_file="${1:?Missing evaluation file}"
  local target_value="${2:-}"
  local allow_fallback="${3:-0}"

  jq -c \
    --arg target "$target_value" \
    --argjson allow_fallback "$allow_fallback" \
    '
      def total_score:
        if (.scores? | type) == "object" then
          reduce ((.scores // {}) | to_entries[]) as $entry (0; . + (($entry.value[0] // 0) | tonumber))
        else
          (.level // 0 | tonumber)
        end;
      def high_count:
        [.improvements[]? | select(((.priority // "") | ascii_upcase) == "HIGH")] | length;
      . as $root
      | ($root.components // []) as $components
      | ($components | map(
          . + {
            _match:
              if (.path // "") == $target then 3
              elif ($target | length) > 0 and ((.path // "") | contains("/" + $target + "/")) then 2
              elif ($target | length) > 0 and (($root.module // "") == $target) then 1
              else 0
              end,
            _score_total: total_score,
            _high_count: high_count
          }
        )) as $annotated
      | ($annotated | map(select(._match > 0)) | sort_by(-._match, .level, ._score_total, .path) | first) as $matched
      | if $matched then
          $matched
        elif $allow_fallback == 1 and ($annotated | length) == 1 then
          $annotated[0]
        elif $allow_fallback == 1 and (($root.module // "") == $target) then
          ($annotated | sort_by(.level, ._score_total, .path) | first)
        else
          empty
        end
      | {
          path: (.path // ""),
          level: (.level // 0),
          score: (._score_total // (.level // 0)),
          high_improvements: (._high_count // 0),
          fingerprint: (.content_hash // ""),
          criteria: (.criteria // []),
          improvements: (.improvements // [])
        }
    ' \
    "$eval_file" 2>/dev/null || true
}

find_latest_matching_baseline() {
  local newest_file=""
  local newest_mtime=0
  local file_path
  local file_component
  local file_mtime

  [ -d "$PROJECT_ROOT/dev/evaluations" ] || return 0

  while IFS= read -r -d '' file_path; do
    file_component="$(select_component_from_eval "$file_path" "$TARGET" 0)"
    [ -n "$file_component" ] || continue
    file_mtime="$(file_mtime_epoch "$file_path" 2>/dev/null || printf '0')"
    if [ "$file_mtime" -ge "$newest_mtime" ]; then
      newest_file="$file_path"
      newest_mtime="$file_mtime"
      BASELINE_COMPONENT_JSON="$file_component"
    fi
  done < <(find "$PROJECT_ROOT/dev/evaluations" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

  BASELINE_EVAL_FILE="$newest_file"
}

resolve_quality_threshold() {
  case "$REQUESTED_THRESHOLD" in
    auto)
      if [ -n "$BASELINE_LEVEL" ] && [ "$BASELINE_LEVEL" -ge 4 ]; then
        QUALITY_THRESHOLD="no-regressions-no-high"
      else
        QUALITY_THRESHOLD="level4"
      fi
      ;;
    level4)
      QUALITY_THRESHOLD="level4"
      ;;
    no-high | no-regressions-no-high | strict)
      QUALITY_THRESHOLD="no-regressions-no-high"
      ;;
    *)
      echo "[ralph] Error: unsupported threshold '$REQUESTED_THRESHOLD'." >&2
      exit 1
      ;;
  esac
}

create_promise() {
  local promise_json

  PROMISE_ID="$(next_promise_id)"
  PROMISE_FILE="$PROMISES_DIR/${PROMISE_ID}.json"
  mkdir -p "$PROMISES_DIR" "$RUN_LOG_DIR"

  promise_json="$(jq -n \
    --arg version "1" \
    --arg promise_id "$PROMISE_ID" \
    --arg command "evolve" \
    --arg target "$TARGET" \
    --arg status "active" \
    --arg started_at "$(learning_timestamp_utc)" \
    --arg updated_at "$(learning_timestamp_utc)" \
    --arg quality_threshold "$QUALITY_THRESHOLD" \
    --argjson max_iterations "$MAX_ITERATIONS" \
    --argjson current_iteration '0' \
    '{
      version: $version,
      promise_id: $promise_id,
      command: $command,
      target: $target,
      status: $status,
      started_at: $started_at,
      updated_at: $updated_at,
      quality_threshold: $quality_threshold,
      max_iterations: $max_iterations,
      current_iteration: $current_iteration,
      stop_reason: null,
      iterations: []
    }'
  )"

  write_file_atomic "$PROMISE_FILE" "$promise_json"
  PROMISE_CREATED=1
}

find_newest_evaluation_after() {
  local marker_path="${1:?Missing marker path}"
  local started_epoch="${2:?Missing start epoch}"
  local marker_file=""
  local marker_mtime=0
  local fallback_file=""
  local fallback_mtime=0
  local file_path
  local file_mtime

  [ -d "$PROJECT_ROOT/dev/evaluations" ] || return 0

  while IFS= read -r -d '' file_path; do
    file_mtime="$(file_mtime_epoch "$file_path" 2>/dev/null || printf '0')"
    if [ -f "$marker_path" ] && [ "$file_path" -nt "$marker_path" ]; then
      if [ "$file_mtime" -ge "$marker_mtime" ]; then
        marker_file="$file_path"
        marker_mtime="$file_mtime"
      fi
    elif [ "$file_mtime" -ge "$started_epoch" ] && [ "$file_mtime" -ge "$fallback_mtime" ]; then
      fallback_file="$file_path"
      fallback_mtime="$file_mtime"
    fi
  done < <(find "$PROJECT_ROOT/dev/evaluations" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

  if [ -n "$marker_file" ]; then
    printf '%s\n' "$marker_file"
  else
    printf '%s\n' "$fallback_file"
  fi
}

component_no_regressions() {
  local current_json="${1:?Missing current component json}"

  if [ -z "$BASELINE_COMPONENT_JSON" ]; then
    return 0
  fi

  jq -en \
    --argjson baseline "$BASELINE_COMPONENT_JSON" \
    --argjson current "$current_json" \
    '
      def total_score($component):
        if ($component.score? != null) then
          ($component.score | tonumber)
        elif (($component.scores? | type) == "object") then
          reduce (($component.scores // {}) | to_entries[]) as $entry (0; . + (($entry.value[0] // 0) | tonumber))
        else
          (($component.level // 0) | tonumber)
        end;
      def current_score($id):
        (($current.criteria // []) | map(select(.id == $id) | (.score // 0)) | first // 0);
      if (($baseline.criteria // []) | length) > 0 and (($current.criteria // []) | length) > 0 then
        all(($baseline.criteria // [])[]?; if ((.score // 0) > 0) then (current_score(.id) > 0) else true end)
      else
        (((($current.level // 0) | tonumber) >= (($baseline.level // 0) | tonumber))
          and (total_score($current) >= total_score($baseline)))
      end
    ' >/dev/null 2>&1
}

derive_fingerprint() {
  local eval_file="${1:-}"
  local component_json="${2:-}"
  local output_hash="${3:-}"
  local component_path=""
  local component_fingerprint=""
  local eval_hash=""

  if [ -n "$component_json" ]; then
    component_fingerprint="$(printf '%s' "$component_json" | jq -r '.fingerprint // empty' 2>/dev/null || true)"
    if [ -n "$component_fingerprint" ]; then
      normalize_fingerprint "$component_fingerprint"
      return 0
    fi

    component_path="$(printf '%s' "$component_json" | jq -r '.path // empty' 2>/dev/null || true)"
    if [ -n "$component_path" ] && [ -f "$PROJECT_ROOT/$component_path" ]; then
      bash "$SCRIPT_DIR/regression.sh" hash "$PROJECT_ROOT/$component_path" 2>/dev/null && return 0
    fi
  fi

  if [ -n "$eval_file" ] && [ -f "$eval_file" ]; then
    eval_hash="$(learning_sha256 "$(cat "$eval_file" 2>/dev/null || true)" 2>/dev/null || true)"
    if [ -n "$eval_hash" ]; then
      normalize_fingerprint "$eval_hash"
      return 0
    fi
  fi

  if [ -n "$output_hash" ]; then
    normalize_fingerprint "$output_hash"
    return 0
  fi

  normalize_fingerprint "$(learning_sha256 "$PROMISE_ID" 2>/dev/null || printf '%s' "$PROMISE_ID")"
}

run_iteration() {
  local iteration_number="${1:?Missing iteration number}"
  local iteration_started_epoch
  local iteration_timestamp
  local marker_path=""
  local run_output=""
  local cli_exit_code=0
  local output_hash=""
  local output_log_path
  local evaluation_file=""
  local component_json=""
  local component_level=0
  local component_score=0
  local high_improvements=0
  local fingerprint=""
  local threshold_met=0
  local no_regressions=1
  local verdict="missing-evaluation"
  local loop_reason="continue"
  local final_status="active"
  local final_stop_reason=""
  local iteration_json=""

  iteration_started_epoch="$(date -u +%s)"
  iteration_timestamp="$(learning_timestamp_utc)"
  output_log_path="$RUN_LOG_DIR/${PROMISE_ID}-iter${iteration_number}.log"
  marker_path="$(mktemp "$RUN_LOG_DIR/.ralph-marker.XXXXXX")"

  echo "[ralph] Iteration ${iteration_number}/${MAX_ITERATIONS}: /evolve ${TARGET}" >&2

  if run_output="$(cd "$PROJECT_ROOT" && claude -p "/evolve ${TARGET}" 2>&1)"; then
    cli_exit_code=0
  else
    cli_exit_code=$?
  fi

  write_file_atomic "$output_log_path" "${run_output:-}"
  output_hash="$(learning_sha256 "${run_output:-}" 2>/dev/null || true)"

  evaluation_file="$(find_newest_evaluation_after "$marker_path" "$iteration_started_epoch")"
  rm -f "$marker_path"
  if [ -n "$evaluation_file" ]; then
    component_json="$(select_component_from_eval "$evaluation_file" "$TARGET" 1)"
  fi

  if [ -n "$component_json" ]; then
    component_level="$(printf '%s' "$component_json" | jq -r '.level // 0' 2>/dev/null || printf '0')"
    component_score="$(printf '%s' "$component_json" | jq -r '.score // (.level // 0)' 2>/dev/null || printf '0')"
    high_improvements="$(printf '%s' "$component_json" | jq -r '.high_improvements // 0' 2>/dev/null || printf '0')"

    if component_no_regressions "$component_json"; then
      no_regressions=1
    else
      no_regressions=0
    fi

    case "$QUALITY_THRESHOLD" in
      level4)
        if [ "$component_level" -ge 4 ]; then
          threshold_met=1
          verdict="level4"
        else
          verdict="below-level4"
        fi
        ;;
      no-regressions-no-high)
        if [ "$no_regressions" -eq 0 ]; then
          verdict="regression"
        elif [ "$high_improvements" -gt 0 ]; then
          verdict="high-remaining"
        else
          threshold_met=1
          verdict="clear"
        fi
        ;;
    esac
  elif [ "$cli_exit_code" -ne 0 ]; then
    verdict="command-failed"
  fi

  fingerprint="$(derive_fingerprint "$evaluation_file" "$component_json" "$output_hash")"
  bash "$SCRIPT_DIR/evolve-loop.sh" record "$PROMISE_ID" "$fingerprint" "$verdict" "$component_score" >/dev/null

  if [ "$threshold_met" -eq 1 ]; then
    final_status="fulfilled"
    final_stop_reason="threshold-met"
    loop_reason="fulfilled"
  else
    loop_reason="$(bash "$SCRIPT_DIR/evolve-loop.sh" similarity "$PROMISE_ID")"
    if [ "$loop_reason" != "continue" ]; then
      final_status="stalled"
      final_stop_reason="$loop_reason"
    elif [ "$iteration_number" -ge "$MAX_ITERATIONS" ]; then
      final_status="stalled"
      final_stop_reason="cap"
      loop_reason="cap"
    fi
  fi

  iteration_json="$(jq -n \
    --argjson iteration "$iteration_number" \
    --arg verdict "$verdict" \
    --argjson score "$component_score" \
    --arg fingerprint "$fingerprint" \
    --arg stop_reason "${final_stop_reason:-continue}" \
    --arg timestamp "$iteration_timestamp" \
    --arg evaluation_file "$evaluation_file" \
    --arg output_path "$output_log_path" \
    --argjson level "$component_level" \
    --argjson high_improvements "$high_improvements" \
    --argjson cli_exit_code "$cli_exit_code" \
    --argjson threshold_met "$threshold_met" \
    --argjson no_regressions "$no_regressions" \
    '{
      iteration: $iteration,
      verdict: $verdict,
      score: $score,
      fingerprint: $fingerprint,
      stop_reason: $stop_reason,
      timestamp: $timestamp,
      evaluation_file: (if $evaluation_file == "" then null else $evaluation_file end),
      output_path: $output_path,
      level: $level,
      high_improvements: $high_improvements,
      cli_exit_code: $cli_exit_code,
      threshold_met: $threshold_met,
      no_regressions: $no_regressions
    }'
  )"

  if [ "$final_status" = "active" ]; then
    append_iteration_to_promise "$iteration_json" "active" ""
  else
    append_iteration_to_promise "$iteration_json" "$final_status" "$final_stop_reason"
  fi

  echo "[ralph] Iteration ${iteration_number}: verdict=${verdict} score=${component_score} stop=${final_stop_reason:-continue}" >&2
  if [ -n "$evaluation_file" ]; then
    echo "[ralph] Evaluation: ${evaluation_file}" >&2
  fi
  echo "[ralph] Output log: ${output_log_path}" >&2

  if [ "$final_status" = "fulfilled" ]; then
    return 0
  fi

  if [ "$final_status" = "stalled" ]; then
    return 1
  fi

  return 2
}

main() {
  local iteration_number=1
  local iteration_result=0

  require_jq
  parse_args "$@"
  cd "$PROJECT_ROOT"

  find_latest_matching_baseline
  if [ -n "$BASELINE_COMPONENT_JSON" ]; then
    BASELINE_LEVEL="$(printf '%s' "$BASELINE_COMPONENT_JSON" | jq -r '.level // 0' 2>/dev/null || printf '0')"
    BASELINE_SCORE="$(printf '%s' "$BASELINE_COMPONENT_JSON" | jq -r '.score // (.level // 0)' 2>/dev/null || printf '0')"
  fi

  resolve_quality_threshold
  create_promise

  trap 'handle_interrupt INT' INT
  trap 'handle_interrupt TERM' TERM
  trap 'handle_exit $?' EXIT

  echo "[ralph] Promise: $PROMISE_FILE" >&2
  if [ -n "$BASELINE_EVAL_FILE" ]; then
    echo "[ralph] Baseline: $BASELINE_EVAL_FILE (level=${BASELINE_LEVEL:-0} score=${BASELINE_SCORE:-0})" >&2
  else
    echo "[ralph] Baseline: none found. Using ${QUALITY_THRESHOLD} threshold." >&2
  fi
  echo "[ralph] Threshold: $QUALITY_THRESHOLD" >&2

  if ! command -v claude >/dev/null 2>&1; then
    update_promise_status "stalled" "claude-unavailable"
    echo "[ralph] Error: claude CLI not found." >&2
    exit 1
  fi

  bash "$SCRIPT_DIR/evolve-loop.sh" init "$PROMISE_ID" "$TARGET" >/dev/null

  while [ "$iteration_number" -le "$MAX_ITERATIONS" ]; do
    if run_iteration "$iteration_number"; then
      exit 0
    else
      iteration_result=$?
      if [ "$iteration_result" -eq 1 ]; then
        exit 1
      fi
    fi
    iteration_number=$((iteration_number + 1))
  done

  update_promise_status "stalled" "cap"
  exit 1
}

main "$@"
