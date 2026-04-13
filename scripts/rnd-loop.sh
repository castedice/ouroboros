#!/usr/bin/env bash
# External autonomous driver loop for RnD studies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_SCRIPT="$SCRIPT_DIR/rnd-session.sh"
BUDGET_SCRIPT="$SCRIPT_DIR/rnd-budget.sh"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <study|status|stop> ..." >&2
  exit 1
fi
shift || true

SESSION_ID=""

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-loop.sh study <question> [--budget <minutes>] [--single]
  rnd-loop.sh status <session-id>
  rnd-loop.sh stop <session-id>
EOF
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 2
  fi
}

require_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: claude is required." >&2
    exit 2
  fi
}

session_state_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/.rnd/sessions/%s/state.json\n' "$PROJECT_ROOT" "$session_id"
}

budget_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/.rnd/sessions/%s/budget.json\n' "$PROJECT_ROOT" "$session_id"
}

queue_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/.rnd/sessions/%s/queue.json\n' "$PROJECT_ROOT" "$session_id"
}

latest_session_id() {
  local latest=""
  latest="$(find "$PROJECT_ROOT/.rnd/sessions" -mindepth 1 -maxdepth 1 -type d -name 'rnd-*' -print 2>/dev/null | sort | tail -1)"
  if [[ -z "$latest" ]]; then
    return 1
  fi
  basename "$latest"
}

parse_session_id() {
  local raw_output="${1:-}"
  printf '%s\n' "$raw_output" | grep -Eo 'rnd-[0-9]{8}-[0-9]{6}' | head -1
}

state_value() {
  local session_id="${1:?Missing session id}"
  local filter="${2:?Missing jq filter}"
  local file_path
  file_path="$(session_state_file "$session_id")"
  if [[ -f "$file_path" ]]; then
    jq -r "$filter" "$file_path"
  fi
}

branch_search_enabled() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(session_state_file "$session_id")"
  if [[ -f "$file_path" ]]; then
    jq -r '.branch_search.enabled // false' "$file_path"
  fi
}

branch_summary_line() {
  local session_id="${1:?Missing session id}"
  local state_path
  local queue_path
  local active_count
  local pruned_count
  local merged_count
  local current_wave
  local total_waves

  state_path="$(session_state_file "$session_id")"
  queue_path="$(queue_file "$session_id")"
  if [[ ! -f "$state_path" || ! -f "$queue_path" ]]; then
    return 0
  fi

  if [[ "$(branch_search_enabled "$session_id")" != "true" ]]; then
    return 0
  fi

  active_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "proposed") == "active")] | length' "$queue_path")"
  pruned_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "pruned")] | length' "$queue_path")"
  merged_count="$(jq -r '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "merged")] | length' "$queue_path")"
  current_wave="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  total_waves="$(jq -r '(.waves // []) | length' "$queue_path")"

  printf 'Branch summary: active=%s pruned=%s merged=%s wave=%s/%s\n' "$active_count" "$pruned_count" "$merged_count" "$current_wave" "$total_waves"
}

branch_wave_context_line() {
  local session_id="${1:?Missing session id}"
  local state_path
  local queue_path
  local current_wave
  local total_waves
  local wave_id=""
  local wave_status=""

  state_path="$(session_state_file "$session_id")"
  queue_path="$(queue_file "$session_id")"
  if [[ ! -f "$state_path" || ! -f "$queue_path" ]]; then
    return 0
  fi

  if [[ "$(branch_search_enabled "$session_id")" != "true" ]]; then
    return 0
  fi

  current_wave="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  total_waves="$(jq -r '(.waves // []) | length' "$queue_path")"
  if [[ "$current_wave" =~ ^[0-9]+$ ]] && (( current_wave > 0 )); then
    wave_id="$(printf 'wave-%03d' "$current_wave")"
    wave_status="$(jq -r --arg wave_id "$wave_id" '((.waves // []) | map(select(.wave_id == $wave_id)) | .[0].status) // empty' "$queue_path")"
  fi

  if [[ -n "$wave_id" && -n "$wave_status" ]]; then
    printf 'Wave context: %s/%s (%s, %s)\n' "$current_wave" "$total_waves" "$wave_id" "$wave_status"
    return 0
  fi

  if [[ -n "$wave_id" ]]; then
    printf 'Wave context: %s/%s (%s)\n' "$current_wave" "$total_waves" "$wave_id"
    return 0
  fi

  printf 'Wave context: %s/%s\n' "$current_wave" "$total_waves"
}

working_branches_line() {
  local session_id="${1:?Missing session id}"
  local state_path
  local queue_path
  local current_wave
  local wave_id=""
  local working_branches=""

  state_path="$(session_state_file "$session_id")"
  queue_path="$(queue_file "$session_id")"
  if [[ ! -f "$state_path" || ! -f "$queue_path" ]]; then
    return 0
  fi

  if [[ "$(branch_search_enabled "$session_id")" != "true" ]]; then
    return 0
  fi

  working_branches="$(jq -r '(.branch_search.active_ids // []) | join(", ")' "$state_path")"
  if [[ -z "$working_branches" ]]; then
    current_wave="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
    if [[ "$current_wave" =~ ^[0-9]+$ ]] && (( current_wave > 0 )); then
      wave_id="$(printf 'wave-%03d' "$current_wave")"
      working_branches="$(jq -r --arg wave_id "$wave_id" '((.waves // []) | map(select(.wave_id == $wave_id)) | .[0].branch_ids // []) | join(", ")' "$queue_path")"
    fi
  fi

  if [[ -n "$working_branches" ]]; then
    printf 'Working branches: %s\n' "$working_branches"
  fi
}

max_phases() {
  local session_id="${1:?Missing session id}"
  local file_path
  local max_loops=2

  file_path="$(budget_file "$session_id")"
  if [[ -f "$file_path" ]]; then
    max_loops="$(jq -r '.limits.max_loops // 2' "$file_path")"
  fi
  echo $((10 + (max_loops * 3)))
}

infer_status() {
  local session_id="${1:?Missing session id}"
  local raw_output="${2:-}"
  local persisted_status=""
  local status="active"
  local branch_summary=""

  persisted_status="$(state_value "$session_id" '.run_status // empty')"
  case "$persisted_status" in
    active | "") ;;
    *)
      status="$persisted_status"
      branch_summary="$(branch_summary_line "$session_id")"
      if [[ -n "$branch_summary" ]]; then
        printf '%s\t%s\n' "$status" "$branch_summary"
      else
        printf '%s\n' "$status"
      fi
      return 0
      ;;
  esac

  if printf '%s' "$raw_output" | grep -qi 'needs_user'; then
    status="needs_user"
  elif printf '%s' "$raw_output" | grep -qi 'blocked_escalation'; then
    status="blocked_escalation"
  elif printf '%s' "$raw_output" | grep -Eqi 'study completed|run_status[[:space:]]*:[[:space:]]*completed|status[[:space:]]*:[[:space:]]*completed'; then
    status="completed"
  fi

  branch_summary="$(branch_summary_line "$session_id")"
  if [[ -n "$branch_summary" ]]; then
    printf '%s\t%s\n' "$status" "$branch_summary"
  else
    printf '%s\n' "$status"
  fi
}

print_checkpoint_info() {
  local session_id="${1:?Missing session id}"
  local file_path

  file_path="$(session_state_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    return 0
  fi

  jq -r '
    [
      "Session: \(.session_id // "")",
      "Current stage: \(.current_stage // "")",
      (if (.pending_checkpoint // "") != "" then "Checkpoint: \(.pending_checkpoint)" else empty end),
      (if (.checkpoint_artifact // "") != "" then "Artifact: \(.checkpoint_artifact)" else empty end),
      (if (.checkpoint_prompt // "") != "" then "Prompt: \(.checkpoint_prompt)" else empty end),
      (if (.checkpoint_options | type) == "array" and (.checkpoint_options | length) > 0 then "Options: \(.checkpoint_options | map(tostring) | join(", "))" else empty end),
      (if (.blocked_reason // "") != "" then "Reason: \(.blocked_reason)" else empty end),
      "Resume: /rnd --resume \(.session_id // "")"
    ]
    | .[]
  ' "$file_path"

  branch_wave_context_line "$session_id"
  working_branches_line "$session_id"
}

run_claude() {
  local prompt="${1:?Missing prompt}"
  (
    cd "$PROJECT_ROOT"
    claude -p --plugin-dir "$PROJECT_ROOT" "$prompt" 2>&1
  )
}

graceful_stop() {
  local reason="${1:-interrupted}"
  if [[ -n "$SESSION_ID" ]]; then
    bash "$SESSION_SCRIPT" stop "$SESSION_ID" --reason "$reason" >/dev/null 2>&1 || true
  fi
}

handle_signal() {
  local signal_name="${1:-INT}"
  trap - INT TERM
  graceful_stop "signal:${signal_name}"
  echo "Stopped RnD loop on $signal_name." >&2
  exit 1
}

action_study() {
  local budget_minutes=90
  local single_mode=0
  local question_parts=()
  local question=""
  local phase_count=1
  local phase_limit=0
  local raw_output=""
  local current_status=""
  local current_status_report=""
  local branch_status_summary=""
  local user_input=""
  local prompt=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --budget | --single)
        break
        ;;
      *)
        question_parts+=("$1")
        shift
        ;;
    esac
  done

  question="${question_parts[*]}"
  if [[ -z "$question" ]]; then
    usage
    exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --budget)
        budget_minutes="${2:?Missing value after --budget}"
        shift 2
        ;;
      --single)
        single_mode=1
        shift
        ;;
      *)
        echo "Error: Unknown flag '$1'." >&2
        usage
        exit 1
        ;;
    esac
  done

  if ! is_positive_integer "$budget_minutes"; then
    echo "Error: Budget minutes must be a non-negative integer." >&2
    exit 1
  fi

  require_claude

  prompt="/rnd $question --budget $budget_minutes"
  if [[ "$single_mode" -eq 1 ]]; then
    prompt="$prompt --single"
  fi

  raw_output="$(run_claude "$prompt")"
  printf '%s\n' "$raw_output"

  SESSION_ID="$(parse_session_id "$raw_output")"
  if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="$(latest_session_id || true)"
  fi
  if [[ -z "$SESSION_ID" ]]; then
    echo "Error: Failed to parse an RnD session id from Claude output." >&2
    exit 2
  fi

  phase_limit="$(max_phases "$SESSION_ID")"

  while true; do
    echo ""
    bash "$SESSION_SCRIPT" status "$SESSION_ID"
    echo ""
    if ! bash "$BUDGET_SCRIPT" check "$SESSION_ID"; then
      graceful_stop "budget_exceeded"
      echo "Stopped because a budget limit was hit."
      return 1
    fi

    current_status_report="$(infer_status "$SESSION_ID" "$raw_output")"
    current_status="${current_status_report%%$'\t'*}"
    branch_status_summary=""
    if [[ "$current_status_report" == *$'\t'* ]]; then
      branch_status_summary="${current_status_report#*$'\t'}"
    fi
    if [[ -n "$branch_status_summary" ]]; then
      echo "Loop status: $current_status | ${branch_status_summary#Branch summary: }"
    fi
    case "$current_status" in
      completed)
        echo "Study completed for $SESSION_ID."
        return 0
        ;;
      stopped)
        echo "Study already stopped for $SESSION_ID."
        return 0
        ;;
      blocked_escalation)
        graceful_stop "blocked_escalation"
        echo "Stopped because the study requires escalation approval."
        return 1
        ;;
      needs_user)
        if { exec 3<> /dev/tty; } 2>/dev/null; then
          printf 'Study %s needs user input.\n' "$SESSION_ID" >&3
          print_checkpoint_info "$SESSION_ID" >&3
          printf 'Enter the checkpoint response: ' >&3
          IFS= read -r user_input <&3
          exec 3<&- 3>&-
        else
          echo "Error: Study needs user input but no TTY is available." >&2
          print_checkpoint_info "$SESSION_ID" >&2
          graceful_stop "needs_user_no_tty"
          return 1
        fi
        raw_output="$(run_claude "/rnd --resume $SESSION_ID"$'\n\n'"User checkpoint input:"$'\n'"$user_input")"
        printf '%s\n' "$raw_output"
        phase_count=$((phase_count + 1))
        ;;
      active)
        if ((phase_count >= phase_limit)); then
          graceful_stop "max_phases_reached"
          echo "Stopped because the phase limit was reached for $SESSION_ID."
          return 1
        fi
        raw_output="$(run_claude "/rnd --resume $SESSION_ID")"
        printf '%s\n' "$raw_output"
        phase_count=$((phase_count + 1))
        ;;
      *)
        graceful_stop "unknown_status"
        echo "Stopped because the loop could not classify the current study status."
        return 1
        ;;
    esac
  done
}

action_status() {
  local session_id="${1:-}"
  local current_status_report=""
  local current_status=""
  local branch_status_summary=""
  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi

  bash "$SESSION_SCRIPT" status "$session_id"
  echo ""
  current_status_report="$(infer_status "$session_id" "")"
  current_status="${current_status_report%%$'\t'*}"
  branch_status_summary=""
  if [[ "$current_status_report" == *$'\t'* ]]; then
    branch_status_summary="${current_status_report#*$'\t'}"
  fi
  if [[ -n "$branch_status_summary" ]]; then
    echo "Loop status: $current_status | ${branch_status_summary#Branch summary: }"
  fi
  if bash "$BUDGET_SCRIPT" check "$session_id" >/dev/null 2>&1; then
    echo "Loop status: budget OK"
  else
    echo "Loop status: budget limit hit"
  fi
}

action_stop() {
  local session_id="${1:-}"
  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi

  bash "$SESSION_SCRIPT" stop "$session_id" --reason "loop_stop"
}

require_jq
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM

case "$ACTION" in
  study) action_study "$@" ;;
  status) action_status "$@" ;;
  stop) action_stop "$@" ;;
  *)
    echo "Error: Unknown action '$ACTION'." >&2
    usage
    exit 1
    ;;
esac
