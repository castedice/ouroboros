#!/usr/bin/env bash
# Evolve loop state tracker for convergence detection.

set -euo pipefail

ACTION="${1:?Usage: evolve-loop.sh <init|record|similarity|status|trace|select-best> ...}"
shift

_state_file() {
  echo ".tmp/${1}_evolve-loop.json"
}

_trace_dir() {
  echo ".tmp/${1}_evolve-traces/"
}

_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_require_jq() {
  command -v jq >/dev/null || { echo "Error: jq is required." >&2; exit 2; }
}

_require_state() {
  local file
  file=$(_state_file "$1")
  [[ -f "$file" ]] || { echo "Error: loop state not found: $file" >&2; exit 2; }
}

_detect_stop_reason() {
  local file="$1"
  local count i
  count=$(jq '.iterations | length' "$file")
  (( count == 0 )) && { echo "continue"; return; }

  mapfile -t fingerprints < <(jq -r '.iterations[].fingerprint' "$file")
  mapfile -t scores < <(jq -r '.iterations[].score' "$file")

  if (( count >= 3 )) && [[ "${fingerprints[count-1]}" == "${fingerprints[count-3]}" && "${fingerprints[count-2]}" != "${fingerprints[count-1]}" ]]; then
    echo "oscillation"
    return
  fi

  for (( i = 0; i < count - 1; i++ )); do
    [[ "${fingerprints[i]}" == "${fingerprints[count-1]}" ]] && { echo "spinning"; return; }
  done

  if (( count >= 2 )); then
    awk -v a="${scores[count-1]}" -v b="${scores[count-2]}" 'BEGIN { exit !(sqrt((a-b)*(a-b)) < 0.01) }' && { echo "no-drift"; return; }
  fi

  if (( count >= 3 )); then
    awk -v a="${scores[count-3]}" -v b="${scores[count-2]}" -v c="${scores[count-1]}" 'BEGIN { d1=b-a; d2=c-b; exit !(d1 > 0 && d2 > 0 && d2 < d1) }' && { echo "diminishing-returns"; return; }
  fi

  (( count >= 3 )) && { echo "cap"; return; }
  echo "continue"
}

action_init() {
  local session_id="${1:?Missing session_id}"
  local component_path="${2:?Missing component_path}"
  local file trace_dir
  file=$(_state_file "$session_id")
  trace_dir=$(_trace_dir "$session_id")
  mkdir -p .tmp "$trace_dir"
  jq -n --arg session_id "$session_id" --arg component_path "$component_path" --arg trace_dir "$trace_dir" --arg ts "$(_timestamp)" \
    '{schema_version:2,session_id:$session_id,component_path:$component_path,trace_dir:$trace_dir,iteration:0,created_at:$ts,updated_at:$ts,iterations:[]}' >"$file"
  echo "$file"
}

action_record() {
  local session_id="${1:?Missing session_id}"
  local fingerprint="${2:?Missing fingerprint}"
  local verdict="${3:?Missing verdict}"
  local score="${4:?Missing score}"
  local file tmp iteration stop_reason trace_path

  trace_path=""
  shift 4
  while (( $# > 0 )); do
    case "$1" in
      --trace-path)
        shift
        trace_path="${1:?Missing trace_path}"
        shift
        ;;
      *)
        echo "Error: unknown record option '$1'. Use: --trace-path <dir>" >&2
        exit 1
        ;;
    esac
  done

  _require_state "$session_id"
  [[ "$score" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || { echo "Error: score must be numeric." >&2; exit 1; }
  file=$(_state_file "$session_id")
  tmp="${file}.tmp"
  iteration=$(jq '.iteration + 1' "$file")

  jq --arg fingerprint "$fingerprint" --arg verdict "$verdict" --argjson score "$score" --arg trace_path "$trace_path" --arg ts "$(_timestamp)" --argjson iteration "$iteration" \
    '.iteration = $iteration | .updated_at = $ts | .iterations += [({"iteration":$iteration,"fingerprint":$fingerprint,"verdict":$verdict,"score":$score,"stop_reason":null,"ts":$ts} + (if $trace_path == "" then {} else {"trace_path":$trace_path} end))]' \
    "$file" >"$tmp"

  stop_reason=$(_detect_stop_reason "$tmp")
  jq --arg stop_reason "$stop_reason" '.iterations[-1].stop_reason = $stop_reason' "$tmp" >"$file"
  rm -f "$tmp"
  echo "$stop_reason"
}

action_trace() {
  local session_id="${1:?Missing session_id}"
  local file trace_dir strategy_excerpt trace_path iteration verdict score
  local -a entries

  _require_state "$session_id"
  file=$(_state_file "$session_id")
  trace_dir=$(jq -r --arg fallback "$(_trace_dir "$session_id")" '.trace_dir // $fallback' "$file")
  entries=()

  while IFS=$'\t' read -r iteration verdict score trace_path; do
    strategy_excerpt=""
    if [[ -f "$trace_path/strategy.md" ]]; then
      IFS= read -r strategy_excerpt <"$trace_path/strategy.md" || strategy_excerpt=""
    fi
    entries+=("$(jq -cn --argjson iteration "$iteration" --arg verdict "$verdict" --argjson score "$score" --arg trace_path "$trace_path" --arg strategy_excerpt "$strategy_excerpt" \
      '{iteration:$iteration,verdict:$verdict,score:$score,trace_path:$trace_path,strategy_excerpt:$strategy_excerpt}')")
  done < <(jq -r '.iterations[] | select(.trace_path? != null and .trace_path != "") | [.iteration,.verdict,.score,.trace_path] | @tsv' "$file")

  if (( ${#entries[@]} == 0 )); then
    jq -n --arg session_id "$session_id" --arg trace_dir "$trace_dir" '{session_id:$session_id,trace_dir:$trace_dir,traces:[]}'
  else
    printf '%s\n' "${entries[@]}" | jq -s --arg session_id "$session_id" --arg trace_dir "$trace_dir" '{session_id:$session_id,trace_dir:$trace_dir,traces:.}'
  fi
}

action_select_best() {
  local session_id="${1:?Missing session_id}"
  local file
  _require_state "$session_id"
  file=$(_state_file "$session_id")

  jq -r '
    [
      .iterations[]
      | select(.trace_path? != null and .trace_path != "")
      | . + {
          verdict_rank: (
            if .verdict == "improved" then 2
            elif .verdict == "lateral" then 1
            elif .verdict == "degraded" then 0
            else 0
            end
          ),
          negative_score: -(.score // 0)
        }
    ]
    | sort_by(-.verdict_rank, .negative_score, .iteration)
    | map(select(.verdict != "degraded"))[0].trace_path // ""
  ' "$file"
}

action_similarity() {
  local session_id="${1:?Missing session_id}"
  _require_state "$session_id"
  _detect_stop_reason "$(_state_file "$session_id")"
}

action_status() {
  local session_id="${1:?Missing session_id}"
  local file count stop_reason
  _require_state "$session_id"
  file=$(_state_file "$session_id")
  count=$(jq '.iterations | length' "$file")
  stop_reason=$(_detect_stop_reason "$file")

  echo "=== Evolve Loop ==="
  echo "Session: $session_id"
  echo "Component: $(jq -r '.component_path' "$file")"
  echo "Attempts: $count/3 | Iteration: $(jq -r '.iteration' "$file") | Stop: $stop_reason"
  if (( count > 0 )); then
    jq -r '.iterations[-1] | "Latest: verdict=\(.verdict) score=\(.score) fingerprint=\(.fingerprint) stop_reason=\(.stop_reason)"' "$file"
  fi
}

_require_jq

case "$ACTION" in
  init) action_init "$@" ;;
  record) action_record "$@" ;;
  similarity) action_similarity "$@" ;;
  status) action_status "$@" ;;
  trace) action_trace "$@" ;;
  select-best) action_select_best "$@" ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: init|record|similarity|status|trace|select-best" >&2
    exit 1
    ;;
esac
