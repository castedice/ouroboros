#!/usr/bin/env bash
# Budget tracker for RnD sessions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"
TEMPLATE="$PROJECT_ROOT/templates/rnd/budget.json"
BRANCH_SCRIPT="$SCRIPT_DIR/rnd-branch.sh"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <init|charge|branch-allocate|branch-charge|check|status> ..." >&2
  exit 1
fi
shift || true

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-budget.sh init <session-id> [--wall-clock <seconds>] [--web-search <n>] [--web-fetch <n>] [--model-route <n>] [--probes <n>]
  rnd-budget.sh charge <session-id> <wall_clock|web_search|web_fetch|model_route|probe> [<amount>]
  rnd-budget.sh branch-allocate <session-id>
  rnd-budget.sh branch-charge <session-id> <branch-id> <wall_clock|web_search|web_fetch|probe> [<amount>]
  rnd-budget.sh check <session-id> [--branch <branch-id>]
  rnd-budget.sh status <session-id>
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required." >&2
    exit 2
  fi
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

session_dir() {
  local session_id="${1:?Missing session id}"
  printf '%s\n' "$SESSION_ROOT/$session_id"
}

budget_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/budget.json\n' "$(session_dir "$session_id")"
}

state_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/state.json\n' "$(session_dir "$session_id")"
}

queue_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/queue.json\n' "$(session_dir "$session_id")"
}

ensure_session_dir() {
  local session_id="${1:?Missing session id}"
  local dir_path
  dir_path="$(session_dir "$session_id")"
  if [[ ! -d "$dir_path" ]]; then
    echo "Error: Session directory not found for '$session_id'." >&2
    exit 2
  fi
}

ensure_budget_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(budget_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: Budget file not found for '$session_id'." >&2
    exit 2
  fi
}

ensure_queue_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(queue_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    echo "Error: Queue file not found for '$session_id'." >&2
    exit 2
  fi
}

ensure_branch_exists() {
  local session_id="${1:?Missing session id}"
  local branch_id="${2:?Missing branch id}"
  local file_path
  file_path="$(queue_file "$session_id")"
  if [[ "$(jq -r --arg branch_id "$branch_id" 'has("branches") and ((.branches // {}) | has($branch_id))' "$file_path")" != "true" ]]; then
    echo "Error: Branch '$branch_id' not found in '$session_id'." >&2
    exit 1
  fi
}

json_write() {
  local file_path="${1:?Missing file path}"
  shift
  local tmp_path="${file_path}.tmp"
  jq "$@" "$file_path" >"$tmp_path"
  mv "$tmp_path" "$file_path"
}

current_stage() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(state_file "$session_id")"
  if [[ -f "$file_path" ]]; then
    jq -r '.current_stage // empty' "$file_path"
  fi
}

metric_keys() {
  local charge_type="${1:?Missing charge type}"
  case "$charge_type" in
    wall_clock) printf 'wall_clock_seconds\n' ;;
    web_search) printf 'web_search_calls\n' ;;
    web_fetch) printf 'web_fetch_calls\n' ;;
    model_route) printf 'model_route_calls\n' ;;
    probe) printf 'probe_calls\n' ;;
    *)
      echo "Error: Invalid charge type '$charge_type'." >&2
      exit 1
      ;;
  esac
}

branch_budget_counter_key() {
  local charge_type="${1:?Missing charge type}"
  case "$charge_type" in
    wall_clock) printf 'spent_wall_clock_seconds\n' ;;
    web_search) printf 'spent_web_search_calls\n' ;;
    web_fetch) printf 'spent_web_fetch_calls\n' ;;
    probe) printf 'spent_probes\n' ;;
    *)
      echo "Error: Invalid branch charge type '$charge_type'." >&2
      exit 1
      ;;
  esac
}

metric_label() {
  local key="${1:?Missing metric key}"
  case "$key" in
    wall_clock_seconds) printf 'Wall clock\n' ;;
    web_search_calls) printf 'Web search\n' ;;
    web_fetch_calls) printf 'Web fetch\n' ;;
    model_route_calls) printf 'Model route\n' ;;
    probe_calls) printf 'Probes\n' ;;
    loopbacks) printf 'Loopbacks\n' ;;
    *)
      printf '%s\n' "$key"
      ;;
  esac
}

charge_budget_metric() {
  local session_id="${1:?Missing session id}"
  local charge_type="${2:?Missing charge type}"
  local amount="${3:?Missing amount}"
  local metric_key
  local file_path
  local stage_name
  local ts

  metric_key="$(metric_keys "$charge_type")"
  file_path="$(budget_file "$session_id")"
  stage_name="$(current_stage "$session_id")"
  ts="$(timestamp_utc)"

  if [[ -n "$stage_name" ]]; then
    json_write "$file_path" \
      --arg metric_key "$metric_key" \
      --arg stage_name "$stage_name" \
      --arg charge_type "$charge_type" \
      --arg ts "$ts" \
      --argjson amount "$amount" \
      '
        .usage[$metric_key] += $amount
        | .phases[$stage_name][$metric_key] += $amount
        | .last_charge = {
            "type": $charge_type,
            "amount": $amount,
            "stage": $stage_name,
            "at": $ts
          }
        | .updated_at = $ts
      '
  else
    json_write "$file_path" \
      --arg metric_key "$metric_key" \
      --arg charge_type "$charge_type" \
      --arg ts "$ts" \
      --argjson amount "$amount" \
      '
        .usage[$metric_key] += $amount
        | .last_charge = {
            "type": $charge_type,
            "amount": $amount,
            "stage": null,
            "at": $ts
          }
        | .updated_at = $ts
      '
  fi
}

action_init() {
  local session_id="${1:-}"
  local wall_clock_seconds=5400
  local web_search_calls=15
  local web_fetch_calls=30
  local model_route_calls=2
  local probe_calls=9

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --wall-clock)
        wall_clock_seconds="${2:?Missing value after --wall-clock}"
        shift 2
        ;;
      --web-search)
        web_search_calls="${2:?Missing value after --web-search}"
        shift 2
        ;;
      --web-fetch)
        web_fetch_calls="${2:?Missing value after --web-fetch}"
        shift 2
        ;;
      --model-route)
        model_route_calls="${2:?Missing value after --model-route}"
        shift 2
        ;;
      --probes)
        probe_calls="${2:?Missing value after --probes}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag '$1'." >&2
        usage
        exit 1
        ;;
    esac
  done

  for value in "$wall_clock_seconds" "$web_search_calls" "$web_fetch_calls" "$model_route_calls" "$probe_calls"; do
    if ! is_positive_integer "$value"; then
      echo "Error: Budget values must be non-negative integers." >&2
      exit 1
    fi
  done

  ensure_session_dir "$session_id"

  local file_path
  local source_path
  local ts

  file_path="$(budget_file "$session_id")"
  source_path="$TEMPLATE"
  ts="$(timestamp_utc)"

  if [[ -f "$file_path" ]]; then
    source_path="$file_path"
  else
    cp "$TEMPLATE" "$file_path"
  fi

  local tmp_path="${file_path}.tmp"
  jq \
    --arg session_id "$session_id" \
    --arg ts "$ts" \
    --argjson wall_clock_seconds "$wall_clock_seconds" \
    --argjson web_search_calls "$web_search_calls" \
    --argjson web_fetch_calls "$web_fetch_calls" \
    --argjson model_route_calls "$model_route_calls" \
    --argjson probe_calls "$probe_calls" \
    '
      .schema_version = "rnd-budget.v1"
      | .session_id = $session_id
      | .limits.wall_clock_seconds = $wall_clock_seconds
      | .limits.web_search_calls = $web_search_calls
      | .limits.web_fetch_calls = $web_fetch_calls
      | .limits.model_route_calls = $model_route_calls
      | .limits.probe_calls = $probe_calls
      | .started_at = (if (.started_at // "") == "" then $ts else .started_at end)
      | .updated_at = $ts
    ' \
    "$source_path" >"$tmp_path"
  mv "$tmp_path" "$file_path"

  echo "Budget initialized for $session_id"
  echo "  wall_clock_seconds=$wall_clock_seconds"
  echo "  web_search_calls=$web_search_calls"
  echo "  web_fetch_calls=$web_fetch_calls"
  echo "  model_route_calls=$model_route_calls"
  echo "  probe_calls=$probe_calls"
}

action_charge() {
  local session_id="${1:-}"
  local charge_type="${2:-}"
  local amount="${3:-1}"

  if [[ -z "$session_id" || -z "$charge_type" ]]; then
    usage
    exit 1
  fi

  if ! is_positive_integer "$amount"; then
    echo "Error: Charge amount must be a non-negative integer." >&2
    exit 1
  fi

  ensure_budget_file "$session_id"
  charge_budget_metric "$session_id" "$charge_type" "$amount"

  echo "Charged $session_id: $charge_type +$amount"
}

action_branch_allocate() {
  local session_id="${1:-}"
  local queue_path
  local file_path
  local allocated_total
  local reserve_probes
  local probe_limit

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi

  ensure_budget_file "$session_id"
  ensure_queue_file "$session_id"

  bash "$BRANCH_SCRIPT" allocate "$session_id"

  queue_path="$(queue_file "$session_id")"
  file_path="$(budget_file "$session_id")"
  allocated_total="$(jq -r '[((.branches // {}) | to_entries[]? | (.value.budget.allocated_probes // 0))] | add // 0' "$queue_path")"
  reserve_probes="$(jq -r '.reserve_probes // 0' "$queue_path")"
  probe_limit="$(jq -r '.limits.probe_calls // 0' "$file_path")"

  if (( allocated_total + reserve_probes > probe_limit )); then
    echo "Error: Planned branch probes exceed session limit ($((allocated_total + reserve_probes))/$probe_limit)." >&2
    exit 1
  fi

  echo "Branch allocation validated for $session_id: $((allocated_total + reserve_probes))/$probe_limit planned"
}

action_branch_charge() {
  local session_id="${1:-}"
  local branch_id="${2:-}"
  local charge_type="${3:-}"
  local amount="${4:-1}"
  local queue_path
  local counter_key

  if [[ -z "$session_id" || -z "$branch_id" || -z "$charge_type" ]]; then
    usage
    exit 1
  fi

  if ! is_positive_integer "$amount"; then
    echo "Error: Charge amount must be a non-negative integer." >&2
    exit 1
  fi

  ensure_budget_file "$session_id"
  ensure_queue_file "$session_id"
  ensure_branch_exists "$session_id" "$branch_id"

  charge_budget_metric "$session_id" "$charge_type" "$amount"

  queue_path="$(queue_file "$session_id")"
  counter_key="$(branch_budget_counter_key "$charge_type")"
  json_write "$queue_path" \
    --arg branch_id "$branch_id" \
    --arg counter_key "$counter_key" \
    --argjson amount "$amount" \
    '
      .branches[$branch_id].budget[$counter_key] = ((.branches[$branch_id].budget[$counter_key] // 0) + $amount)
    '

  echo "Charged $session_id/$branch_id: $charge_type +$amount"
}

action_check() {
  local session_id="${1:-}"
  local branch_id=""
  local file_path
  local queue_path
  local stage_name=""
  local report

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch)
        branch_id="${2:?Missing value after --branch}"
        shift 2
        ;;
      *)
        echo "Error: Unknown flag '$1'." >&2
        usage
        exit 1
        ;;
    esac
  done

  ensure_budget_file "$session_id"
  file_path="$(budget_file "$session_id")"
  stage_name="$(current_stage "$session_id")"

  if [[ -n "$branch_id" ]]; then
    local used_probes
    local branch_limit

    ensure_queue_file "$session_id"
    ensure_branch_exists "$session_id" "$branch_id"
    queue_path="$(queue_file "$session_id")"
    used_probes="$(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].budget.spent_probes // 0' "$queue_path")"
    branch_limit="$(jq -r --arg branch_id "$branch_id" '((.branches[$branch_id].budget.allocated_probes // 0) + (.branches[$branch_id].budget.reserve_probes_awarded // 0) - (.branches[$branch_id].budget.reclaimed_probes // 0))' "$queue_path")"

    if (( branch_limit < 0 )); then
      branch_limit=0
    fi

    if (( used_probes > branch_limit || (branch_limit > 0 && used_probes >= branch_limit) )); then
      echo "Branch budget limit hit: $branch_id probes $used_probes/$branch_limit"
      exit 1
    fi

    echo "Branch budget OK for $session_id/$branch_id"
    return 0
  fi

  report="$(
    jq -r --arg stage_name "$stage_name" '
      [
        {
          "name": "wall_clock",
          "label": "Wall clock",
          "used": .usage.wall_clock_seconds,
          "limit": .limits.wall_clock_seconds
        },
        {
          "name": "web_search",
          "label": "Web search",
          "used": .usage.web_search_calls,
          "limit": .limits.web_search_calls
        },
        {
          "name": "web_fetch",
          "label": "Web fetch",
          "used": .usage.web_fetch_calls,
          "limit": .limits.web_fetch_calls
        },
        {
          "name": "model_route",
          "label": "Model route",
          "used": .usage.model_route_calls,
          "limit": .limits.model_route_calls
        },
        {
          "name": "probe",
          "label": "Probes",
          "used": .usage.probe_calls,
          "limit": .limits.probe_calls
        },
        {
          "name": "loopback",
          "label": "Loopbacks",
          "used": .usage.loopbacks,
          "limit": .limits.max_loops
        }
      ]
      | if ($stage_name == "report" or $stage_name == "review" or $stage_name == "meta-learn")
        then map(select(.name == "wall_clock"))
        else .
        end
      | map(. + {"hit": ((.limit > 0) and (.used >= .limit))})
      | .[]
      | "\(.label)|\(.used)|\(.limit)|\(.hit)"
    ' "$file_path"
  )"

  local has_hit=0
  while IFS='|' read -r label used limit hit; do
    [[ -n "$label" ]] || continue
    if [[ "$hit" == "true" ]]; then
      echo "Budget limit hit: $label $used/$limit"
      has_hit=1
    fi
  done <<<"$report"

  if [[ "$has_hit" -eq 1 ]]; then
    exit 1
  fi

  echo "Budget OK for $session_id"
}

action_status() {
  local session_id="${1:-}"
  local file_path
  local current_stage_name=""
  local last_charge_line=""

  if [[ -z "$session_id" ]]; then
    usage
    exit 1
  fi

  ensure_budget_file "$session_id"
  file_path="$(budget_file "$session_id")"
  current_stage_name="$(current_stage "$session_id")"
  last_charge_line="$(jq -r '.last_charge | if .type == null then "" else "\(.type) +\(.amount) @ \(.at)" + (if .stage == null then "" else " [" + .stage + "]" end) end' "$file_path")"

  echo "=== Budget ==="
  echo "Session: $session_id"
  if [[ -n "$current_stage_name" ]]; then
    echo "Current stage: $current_stage_name"
  fi
  printf '%-14s %s/%s\n' "Wall clock:" "$(jq -r '.usage.wall_clock_seconds' "$file_path")s" "$(jq -r '.limits.wall_clock_seconds' "$file_path")s"
  printf '%-14s %s/%s\n' "Web search:" "$(jq -r '.usage.web_search_calls' "$file_path")" "$(jq -r '.limits.web_search_calls' "$file_path")"
  printf '%-14s %s/%s\n' "Web fetch:" "$(jq -r '.usage.web_fetch_calls' "$file_path")" "$(jq -r '.limits.web_fetch_calls' "$file_path")"
  printf '%-14s %s/%s\n' "Model route:" "$(jq -r '.usage.model_route_calls' "$file_path")" "$(jq -r '.limits.model_route_calls' "$file_path")"
  printf '%-14s %s/%s\n' "Probes:" "$(jq -r '.usage.probe_calls' "$file_path")" "$(jq -r '.limits.probe_calls' "$file_path")"
  printf '%-14s %s/%s\n' "Loopbacks:" "$(jq -r '.usage.loopbacks' "$file_path")" "$(jq -r '.limits.max_loops' "$file_path")"
  if [[ -n "$last_charge_line" ]]; then
    echo "Last charge: $last_charge_line"
  fi
}

require_jq

case "$ACTION" in
  init) action_init "$@" ;;
  charge) action_charge "$@" ;;
  branch-allocate) action_branch_allocate "$@" ;;
  branch-charge) action_branch_charge "$@" ;;
  check) action_check "$@" ;;
  status) action_status "$@" ;;
  *)
    echo "Error: Unknown action '$ACTION'." >&2
    usage
    exit 1
    ;;
esac
