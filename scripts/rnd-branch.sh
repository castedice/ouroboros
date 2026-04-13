#!/usr/bin/env bash
# Branch lifecycle manager for the RnD workflow.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"
QUEUE_TEMPLATE="$PROJECT_ROOT/templates/rnd/queue.json"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <init|allocate|schedule|score|prune|merge|expand|status|wave-status|finalize> ..." >&2
  exit 2
fi
shift || true

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-branch.sh init <session-id> <branches_json>
  rnd-branch.sh allocate <session-id>
  rnd-branch.sh schedule <session-id>
  rnd-branch.sh score <session-id> <branch-id> <scores_json>
  rnd-branch.sh prune <session-id> <branch-id> <reason>
  rnd-branch.sh merge <session-id> <source-branch-id> <target-branch-id>
  rnd-branch.sh expand <session-id> <branch-id> <contracts_json>
  rnd-branch.sh status <session-id> [branch-id]
  rnd-branch.sh wave-status <session-id> <wave-id>
  rnd-branch.sh finalize <session-id>
EOF
}

die_usage() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  usage
  exit 2
}

die_validation() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  exit 1
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    die_validation "jq is required."
  fi
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

is_positive_integer() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

format_wave_id() {
  local wave_number="${1:?Missing wave number}"
  printf 'wave-%03d\n' "$wave_number"
}

session_dir() {
  local session_id="${1:?Missing session id}"
  printf '%s\n' "$SESSION_ROOT/$session_id"
}

state_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/state.json\n' "$(session_dir "$session_id")"
}

budget_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/budget.json\n' "$(session_dir "$session_id")"
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
    die_validation "Session directory not found for '$session_id'."
  fi
}

ensure_state_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(state_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    die_validation "State file not found for '$session_id'."
  fi
}

ensure_budget_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(budget_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    die_validation "Budget file not found for '$session_id'."
  fi
}

ensure_queue_file() {
  local session_id="${1:?Missing session id}"
  local file_path
  file_path="$(queue_file "$session_id")"
  if [[ ! -f "$file_path" ]]; then
    die_validation "Queue file not found for '$session_id'."
  fi
}

ensure_branch_exists() {
  local session_id="${1:?Missing session id}"
  local branch_id="${2:?Missing branch id}"
  local file_path
  file_path="$(queue_file "$session_id")"
  if [[ "$(jq -r --arg branch_id "$branch_id" 'has("branches") and ((.branches // {}) | has($branch_id))' "$file_path")" != "true" ]]; then
    die_validation "Branch '$branch_id' not found in '$session_id'."
  fi
}

json_write() {
  local file_path="${1:?Missing file path}"
  shift
  local tmp_path="${file_path}.tmp"
  jq "$@" "$file_path" >"$tmp_path"
  mv "$tmp_path" "$file_path"
}

refresh_wave_statuses() {
  local file_path="${1:?Missing queue file}"
  json_write "$file_path" '
    def branch_resolved($branches; $branch_id):
      (($branches[$branch_id] // {}) | (.status // "")) as $status
      | if ($status == "pruned" or $status == "merged" or $status == "survived") then true
        else (((($branches[$branch_id] // {}).scores.decision // "") != ""))
        end;
    (.branches // {}) as $branches
    | .waves = [
        (.waves // [])[]
        | .status = (
            if ((.branch_ids // []) | length) == 0 then (.status // "planned")
            elif all((.branch_ids // [])[]; branch_resolved($branches; .)) then "resolved"
            else (.status // "planned")
            end
          )
      ]
  '
}

sync_state_from_queue() {
  local session_id="${1:?Missing session id}"
  local wave_index="${2:-}"
  local state_path
  local budget_path
  local queue_path
  local active_ids
  local pruned_ids
  local merged_ids
  local max_parallel
  local ts

  state_path="$(state_file "$session_id")"
  budget_path="$(budget_file "$session_id")"
  queue_path="$(queue_file "$session_id")"

  if [[ ! -f "$state_path" || ! -f "$queue_path" ]]; then
    return 0
  fi

  active_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "proposed") == "active") | .key]' "$queue_path")"
  pruned_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "pruned") | .key]' "$queue_path")"
  merged_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "merged") | .key]' "$queue_path")"
  max_parallel="$(jq -r '.limits.max_parallel // 0' "$budget_path")"
  if [[ -z "$wave_index" ]]; then
    wave_index="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  fi
  ts="$(timestamp_utc)"

  json_write "$state_path" \
    --argjson active_ids "$active_ids" \
    --argjson pruned_ids "$pruned_ids" \
    --argjson merged_ids "$merged_ids" \
    --argjson wave_index "$wave_index" \
    --argjson max_parallel "$max_parallel" \
    --arg ts "$ts" \
    '
      (.branch_search // {}) as $branch_search
      | .branch_search = (
          {
            "enabled": true,
            "strategy": ($branch_search.strategy // "wave"),
            "wave_index": $wave_index,
            "max_parallel": $max_parallel,
            "active_ids": $active_ids,
            "pruned_ids": $pruned_ids,
            "merged_ids": $merged_ids
          }
          + (if ($branch_search.final_summary // null) == null then {} else {"final_summary": $branch_search.final_summary} end)
        )
      | .updated_at = $ts
    '
}

validate_branches_json() {
  local branches_json="${1:?Missing branches json}"
  if ! printf '%s\n' "$branches_json" | jq -e '
    type == "array"
    and all(.[]?; (type == "object") and ((.branch_id // "") != ""))
    and ((map(.branch_id) | unique | length) == length)
  ' >/dev/null 2>&1; then
    die_validation "branches_json must be a JSON array of unique branch objects with branch_id."
  fi
}

validate_scores_json() {
  local scores_json="${1:?Missing scores json}"
  if ! printf '%s\n' "$scores_json" | jq -e '
    type == "object"
    and ((.B1 // null) | type) == "number"
    and ((.B2 // null) | type) == "number"
    and ((.B3 // null) | type) == "number"
    and ((.B4 // null) | type) == "number"
    and (.B1 >= 0 and .B1 <= 2)
    and (.B2 >= 0 and .B2 <= 2)
    and (.B3 >= 0 and .B3 <= 2)
    and (.B4 >= 0 and .B4 <= 2)
    and (((.decision // "") == "prune") or ((.decision // "") == "survive") or ((.decision // "") == "merge") or ((.decision // "") == "expand"))
    and ((.reason // null) | type) == "string"
  ' >/dev/null 2>&1; then
    die_validation "scores_json must contain B1-B4 in 0..2 plus decision and reason."
  fi
}

validate_contracts_json() {
  local contracts_json="${1:?Missing contracts json}"
  if ! printf '%s\n' "$contracts_json" | jq -e 'type == "array"' >/dev/null 2>&1; then
    die_validation "contracts_json must be a JSON array."
  fi
}

action_init() {
  local session_id="${1:-}"
  local branches_json="${2:-}"
  local queue_path
  local budget_path
  local max_parallel
  local branches_object

  if [[ -z "$session_id" || -z "${branches_json:-}" ]]; then
    die_usage "init requires <session-id> and <branches_json>."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_budget_file "$session_id"
  validate_branches_json "$branches_json"

  queue_path="$(queue_file "$session_id")"
  budget_path="$(budget_file "$session_id")"
  max_parallel="$(jq -r '.limits.max_parallel // 0' "$budget_path")"
  cp "$QUEUE_TEMPLATE" "$queue_path"

  branches_object="$(
    jq -cn --argjson branches "$branches_json" '
      reduce ($branches // [])[] as $branch ({};
        .[$branch.branch_id] = {
          "branch_id": $branch.branch_id,
          "label": ($branch.label // ""),
          "lead_hypothesis": ($branch.lead_hypothesis // ""),
          "hypothesis_ids": ($branch.hypothesis_ids // []),
          "tension_points": ($branch.tension_points // []),
          "status": "proposed",
          "sub_stage": "hypotheses",
          "contracts": {
            "planned": [],
            "active": [],
            "completed": []
          },
          "scores": {
            "B1": 0,
            "B2": 0,
            "B3": 0,
            "B4": 0,
            "composite": 0,
            "decision": "",
            "reason": "",
            "scored_at": ""
          },
          "budget": {
            "allocated_probes": 0,
            "spent_probes": 0,
            "reserve_probes_awarded": 0,
            "reclaimed_probes": 0
          },
          "evidence_refs": ($branch.evidence_refs // []),
          "merge_target": null
        }
      )
    '
  )"

  json_write "$queue_path" \
    --argjson branches "$branches_object" \
    '
      .schema_version = "rnd-queue.v1"
      | .reserve_probes = 0
      | .branches = $branches
      | .waves = []
    '

  sync_state_from_queue "$session_id" 0
  json_write "$(state_file "$session_id")" \
    --argjson max_parallel "$max_parallel" \
    '
      .branch_search.enabled = true
      | .branch_search.max_parallel = $max_parallel
    '

  echo "Branch queue initialized for $session_id"
  echo "  branches=$(jq -r '(.branches // {}) | length' "$queue_path")"
  echo "  reserve_probes=0"
}

action_allocate() {
  local session_id="${1:-}"
  local queue_path
  local budget_path
  local total_probe_budget
  local configured_reserve=""
  local reserve_probes
  local default_reserve
  local allocatable_probes
  local total_weight=0
  local base_sum=0
  local remaining=0
  local row
  local branch_id
  local hypothesis_count
  local rank
  local weight
  local numerator
  local base
  local remainder
  local allocation_json
  local line
  local -a branch_rows=()
  local -a branch_ids=()
  local -a remainder_rows=()
  local -a allocation_lines=()
  local -a sorted_remainders=()
  declare -A weights=()
  declare -A allocations=()

  if [[ -z "$session_id" ]]; then
    die_usage "allocate requires <session-id>."
  fi

  ensure_session_dir "$session_id"
  ensure_budget_file "$session_id"
  ensure_queue_file "$session_id"

  queue_path="$(queue_file "$session_id")"
  budget_path="$(budget_file "$session_id")"
  total_probe_budget="$(jq -r '.limits.probe_calls // 0' "$budget_path")"
  configured_reserve="$(jq -r '.limits.reserve_probes // empty' "$budget_path")"

  if ! is_positive_integer "$total_probe_budget"; then
    die_validation "Session probe budget must be a non-negative integer."
  fi

  default_reserve=$(((total_probe_budget * 15 + 99) / 100))
  if (( default_reserve < 2 )); then
    default_reserve=2
  fi

  reserve_probes="$default_reserve"
  if [[ -n "$configured_reserve" ]]; then
    if ! is_positive_integer "$configured_reserve"; then
      die_validation "Configured reserve probes must be a non-negative integer."
    fi
    reserve_probes="$configured_reserve"
  fi
  if (( reserve_probes > total_probe_budget )); then
    reserve_probes="$total_probe_budget"
  fi

  allocatable_probes=$((total_probe_budget - reserve_probes))

  mapfile -t branch_rows < <(
    jq -r '
      def lead_rank:
        ((. // "") | (match("[0-9]+$")?.string // "999999") | tonumber);
      ((.branches // {}) | to_entries[])?
      | "\(.key)|\(((.value.hypothesis_ids // []) | length))|\(((.value.lead_hypothesis // "") | lead_rank))"
    ' "$queue_path"
  )

  if [[ "${#branch_rows[@]}" -eq 0 ]]; then
    die_validation "Queue has no branches to allocate."
  fi

  for row in "${branch_rows[@]}"; do
    IFS='|' read -r branch_id hypothesis_count rank <<<"$row"
    weight="$hypothesis_count"
    if (( weight < 1 )); then
      weight=1
    fi
    branch_ids+=("$branch_id")
    weights["$branch_id"]="$weight"
    total_weight=$((total_weight + weight))
  done

  for branch_id in "${branch_ids[@]}"; do
    numerator=$((allocatable_probes * weights["$branch_id"]))
    base=$((numerator / total_weight))
    remainder=$((numerator % total_weight))
    allocations["$branch_id"]="$base"
    base_sum=$((base_sum + base))
    rank="$(jq -r --arg branch_id "$branch_id" '
      def lead_rank:
        ((. // "") | (match("[0-9]+$")?.string // "999999") | tonumber);
      ((.branches[$branch_id].lead_hypothesis // "") | lead_rank)
    ' "$queue_path")"
    remainder_rows+=("$remainder|${weights["$branch_id"]}|$rank|$branch_id")
  done

  remaining=$((allocatable_probes - base_sum))
  if (( remaining > 0 )); then
    mapfile -t sorted_remainders < <(printf '%s\n' "${remainder_rows[@]}" | sort -t'|' -k1,1nr -k2,2nr -k3,3n -k4,4)
    for ((i = 0; i < remaining && i < ${#sorted_remainders[@]}; i++)); do
      IFS='|' read -r _ _ _ branch_id <<<"${sorted_remainders[$i]}"
      allocations["$branch_id"]=$((allocations["$branch_id"] + 1))
    done
  fi

  for branch_id in "${branch_ids[@]}"; do
    allocation_lines+=("$branch_id|${allocations["$branch_id"]}")
  done

  allocation_json="$(
    printf '%s\n' "${allocation_lines[@]}" \
      | jq -Rn '
          [inputs | select(length > 0) | split("|")]
          | reduce .[] as $row ({}; .[$row[0]] = ($row[1] | tonumber))
        '
  )"

  json_write "$queue_path" \
    --argjson reserve_probes "$reserve_probes" \
    --argjson allocations "$allocation_json" \
    '
      .reserve_probes = $reserve_probes
      | .branches = (
          (.branches // {})
          | with_entries(
              .value.budget.allocated_probes = ($allocations[.key] // 0)
              | .value.budget.spent_probes = (.value.budget.spent_probes // 0)
              | .value.budget.reserve_probes_awarded = (.value.budget.reserve_probes_awarded // 0)
              | .value.budget.reclaimed_probes = (.value.budget.reclaimed_probes // 0)
            )
        )
    '

  sync_state_from_queue "$session_id" 0

  echo "Branch probe budget allocated for $session_id"
  echo "  total_probe_calls=$total_probe_budget"
  echo "  reserve_probes=$reserve_probes"
  for branch_id in "${branch_ids[@]}"; do
    echo "  $branch_id=${allocations["$branch_id"]}"
  done
}

action_schedule() {
  local session_id="${1:-}"
  local queue_path
  local budget_path
  local max_parallel
  local sorted_branch_ids_json
  local waves_json

  if [[ -z "$session_id" ]]; then
    die_usage "schedule requires <session-id>."
  fi

  ensure_session_dir "$session_id"
  ensure_budget_file "$session_id"
  ensure_queue_file "$session_id"

  queue_path="$(queue_file "$session_id")"
  budget_path="$(budget_file "$session_id")"
  max_parallel="$(jq -r '.limits.max_parallel // 0' "$budget_path")"

  if ! is_positive_integer "$max_parallel" || (( max_parallel <= 0 )); then
    die_validation "max_parallel must be a positive integer to schedule branch waves."
  fi

  sorted_branch_ids_json="$(
    jq -c '
      def lead_rank:
        ((. // "") | (match("[0-9]+$")?.string // "999999") | tonumber);
      (.branches // {})
      | to_entries
      | map({
          "branch_id": .key,
          "lead_hypothesis": (.value.lead_hypothesis // ""),
          "rank": ((.value.lead_hypothesis // "") | lead_rank)
        })
      | sort_by(.rank, .lead_hypothesis, .branch_id)
      | map(.branch_id)
    ' "$queue_path"
  )"

  if [[ "$(printf '%s\n' "$sorted_branch_ids_json" | jq -r 'length')" -eq 0 ]]; then
    die_validation "Queue has no branches to schedule."
  fi

  waves_json="$(
    jq -cn --argjson branch_ids "$sorted_branch_ids_json" --argjson max_parallel "$max_parallel" '
      def wave_id($n):
        if $n < 10 then "wave-00\($n)"
        elif $n < 100 then "wave-0\($n)"
        else "wave-\($n)"
        end;
      [
        range(0; ($branch_ids | length); $max_parallel) as $offset
        | (($offset / $max_parallel | floor) + 1) as $wave_number
        | {
            "wave_id": wave_id($wave_number),
            "branch_ids": ($branch_ids[$offset:($offset + $max_parallel)]),
            "status": (if $wave_number == 1 then "active" else "planned" end)
          }
      ]
    '
  )"

  json_write "$queue_path" \
    --argjson waves "$waves_json" \
    '
      .waves = $waves
      | .branches = (
          (.branches // {})
          | with_entries(
              .value.status = (
                if (.value.status // "") == "pruned" or (.value.status // "") == "merged" or (.value.status // "") == "survived"
                then (.value.status // "proposed")
                else "active"
                end
              )
              | .value.sub_stage = (
                  if (.value.status // "") == "pruned" or (.value.status // "") == "merged" or (.value.status // "") == "survived"
                  then (.value.sub_stage // "hypotheses")
                  else "experiment-design"
                  end
                )
            )
        )
    '

  refresh_wave_statuses "$queue_path"
  sync_state_from_queue "$session_id" 1

  echo "Branch waves scheduled for $session_id"
  echo "  max_parallel=$max_parallel"
  jq -r '.waves[] | "  " + .wave_id + ": " + (.branch_ids | join(", ")) + " [" + (.status // "planned") + "]"' "$queue_path"
}

action_score() {
  local session_id="${1:-}"
  local branch_id="${2:-}"
  local scores_json="${3:-}"
  local queue_path
  local ts
  local composite

  if [[ -z "$session_id" || -z "$branch_id" || -z "${scores_json:-}" ]]; then
    die_usage "score requires <session-id> <branch-id> <scores_json>."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"
  ensure_branch_exists "$session_id" "$branch_id"
  validate_scores_json "$scores_json"

  queue_path="$(queue_file "$session_id")"
  ts="$(timestamp_utc)"
  composite="$(printf '%s\n' "$scores_json" | jq -r '(.B1 // 0) + (.B2 // 0) + (.B3 // 0) + (.B4 // 0)')"

  json_write "$queue_path" \
    --arg branch_id "$branch_id" \
    --argjson scores "$scores_json" \
    --argjson composite "$composite" \
    --arg ts "$ts" \
    '
      .branches[$branch_id].scores.B1 = ($scores.B1 // 0)
      | .branches[$branch_id].scores.B2 = ($scores.B2 // 0)
      | .branches[$branch_id].scores.B3 = ($scores.B3 // 0)
      | .branches[$branch_id].scores.B4 = ($scores.B4 // 0)
      | .branches[$branch_id].scores.composite = $composite
      | .branches[$branch_id].scores.decision = ($scores.decision // "")
      | .branches[$branch_id].scores.reason = ($scores.reason // "")
      | .branches[$branch_id].scores.scored_at = $ts
      | .branches[$branch_id].status = (
          if ($scores.decision // "") == "prune" then "pruned"
          elif ($scores.decision // "") == "merge" then "merged"
          else "active"
          end
        )
      | .branches[$branch_id].sub_stage = (
          if ($scores.decision // "") == "prune" or ($scores.decision // "") == "merge"
          then "analyze-prune"
          else "experiment-design"
          end
        )
    '

  refresh_wave_statuses "$queue_path"
  sync_state_from_queue "$session_id"

  echo "Branch scored for $session_id"
  echo "  branch_id=$branch_id"
  echo "  composite=$composite"
  echo "  decision=$(printf '%s\n' "$scores_json" | jq -r '.decision')"
}

action_prune() {
  local session_id="${1:-}"
  local branch_id="${2:-}"
  local reason="${3:-}"
  local queue_path
  local reclaimable

  if [[ -z "$session_id" || -z "$branch_id" || -z "$reason" ]]; then
    die_usage "prune requires <session-id> <branch-id> <reason>."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"
  ensure_branch_exists "$session_id" "$branch_id"

  queue_path="$(queue_file "$session_id")"
  reclaimable="$(jq -r --arg branch_id "$branch_id" '
    ((.branches[$branch_id].budget.allocated_probes // 0)
      + (.branches[$branch_id].budget.reserve_probes_awarded // 0)
      - (.branches[$branch_id].budget.spent_probes // 0)
      - (.branches[$branch_id].budget.reclaimed_probes // 0))
    | if . < 0 then 0 else . end
  ' "$queue_path")"

  json_write "$queue_path" \
    --arg branch_id "$branch_id" \
    --arg reason "$reason" \
    --argjson reclaimable "$reclaimable" \
    '
      .reserve_probes += $reclaimable
      | .branches[$branch_id].status = "pruned"
      | .branches[$branch_id].sub_stage = "analyze-prune"
      | .branches[$branch_id].scores.decision = "prune"
      | .branches[$branch_id].scores.reason = $reason
      | .branches[$branch_id].budget.reclaimed_probes = ((.branches[$branch_id].budget.reclaimed_probes // 0) + $reclaimable)
    '

  refresh_wave_statuses "$queue_path"
  sync_state_from_queue "$session_id"

  echo "Branch pruned for $session_id"
  echo "  branch_id=$branch_id"
  echo "  reclaimed_probes=$reclaimable"
}

action_merge() {
  local session_id="${1:-}"
  local source_branch_id="${2:-}"
  local target_branch_id="${3:-}"
  local queue_path

  if [[ -z "$session_id" || -z "$source_branch_id" || -z "$target_branch_id" ]]; then
    die_usage "merge requires <session-id> <source-branch-id> <target-branch-id>."
  fi

  if [[ "$source_branch_id" == "$target_branch_id" ]]; then
    die_validation "Source and target branches must differ."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"
  ensure_branch_exists "$session_id" "$source_branch_id"
  ensure_branch_exists "$session_id" "$target_branch_id"

  queue_path="$(queue_file "$session_id")"

  json_write "$queue_path" \
    --arg source_branch_id "$source_branch_id" \
    --arg target_branch_id "$target_branch_id" \
    '
      .branches[$target_branch_id].evidence_refs = (
        ((.branches[$target_branch_id].evidence_refs // []) + (.branches[$source_branch_id].evidence_refs // []))
        | unique
      )
      | .branches[$source_branch_id].status = "merged"
      | .branches[$source_branch_id].sub_stage = "analyze-prune"
      | .branches[$source_branch_id].scores.decision = "merge"
      | .branches[$source_branch_id].merge_target = $target_branch_id
    '

  refresh_wave_statuses "$queue_path"
  sync_state_from_queue "$session_id"

  echo "Branch merged for $session_id"
  echo "  source=$source_branch_id"
  echo "  target=$target_branch_id"
}

action_expand() {
  local session_id="${1:-}"
  local branch_id="${2:-}"
  local contracts_json="${3:-}"
  local queue_path
  local reserve_probes
  local requested_probes

  if [[ -z "$session_id" || -z "$branch_id" || -z "${contracts_json:-}" ]]; then
    die_usage "expand requires <session-id> <branch-id> <contracts_json>."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"
  ensure_branch_exists "$session_id" "$branch_id"
  validate_contracts_json "$contracts_json"

  queue_path="$(queue_file "$session_id")"
  reserve_probes="$(jq -r '.reserve_probes // 0' "$queue_path")"
  requested_probes="$(printf '%s\n' "$contracts_json" | jq -r 'length')"

  if (( requested_probes <= 0 )); then
    die_validation "expand requires at least one contract."
  fi
  if (( requested_probes > reserve_probes )); then
    die_validation "Not enough reserve probes for '$branch_id' ($requested_probes requested, $reserve_probes available)."
  fi

  json_write "$queue_path" \
    --arg branch_id "$branch_id" \
    --argjson contracts "$contracts_json" \
    --argjson requested_probes "$requested_probes" \
    '
      .reserve_probes -= $requested_probes
      | .branches[$branch_id].status = "active"
      | .branches[$branch_id].sub_stage = "experiment-design"
      | .branches[$branch_id].scores.decision = "expand"
      | .branches[$branch_id].contracts.planned = ((.branches[$branch_id].contracts.planned // []) + $contracts)
      | .branches[$branch_id].budget.reserve_probes_awarded = ((.branches[$branch_id].budget.reserve_probes_awarded // 0) + $requested_probes)
    '

  refresh_wave_statuses "$queue_path"
  sync_state_from_queue "$session_id"

  echo "Branch expanded for $session_id"
  echo "  branch_id=$branch_id"
  echo "  reserve_awarded=$requested_probes"
}

action_status() {
  local session_id="${1:-}"
  local branch_id="${2:-}"
  local queue_path
  local state_path
  local current_wave
  local total_waves

  if [[ -z "$session_id" ]]; then
    die_usage "status requires <session-id> [branch-id]."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"

  queue_path="$(queue_file "$session_id")"
  state_path="$(state_file "$session_id")"
  current_wave="$(jq -r '.branch_search.wave_index // 0' "$state_path")"
  total_waves="$(jq -r '(.waves // []) | length' "$queue_path")"

  echo "=== Branch Queue ==="
  echo "Session: $session_id"
  echo "Current wave: $current_wave/$total_waves"
  echo "Reserve probes: $(jq -r '.reserve_probes // 0' "$queue_path")"

  if [[ -z "$branch_id" ]]; then
    echo ""
    printf '%-12s %-10s %-18s %-8s %-8s %-8s %s\n' "BRANCH" "STATUS" "SUB_STAGE" "ALLOC" "SPENT" "SCORE" "DECISION"
    printf '%-12s %-10s %-18s %-8s %-8s %-8s %s\n' "────────────" "──────────" "──────────────────" "────────" "────────" "────────" "────────"
    jq -r '
      (.branches // {})
      | to_entries
      | sort_by(.key)
      | .[]
      | [
          .key,
          (.value.status // "proposed"),
          (.value.sub_stage // ""),
          ((.value.budget.allocated_probes // 0) + (.value.budget.reserve_probes_awarded // 0) - (.value.budget.reclaimed_probes // 0) | tostring),
          (.value.budget.spent_probes // 0 | tostring),
          (.value.scores.composite // 0 | tostring),
          (.value.scores.decision // "")
        ]
      | @tsv
    ' "$queue_path" | while IFS=$'\t' read -r branch status sub_stage alloc spent score decision; do
      printf '%-12s %-10s %-18s %-8s %-8s %-8s %s\n' "$branch" "$status" "$sub_stage" "$alloc" "$spent" "$score" "$decision"
    done
    return 0
  fi

  ensure_branch_exists "$session_id" "$branch_id"
  echo ""
  echo "Branch: $branch_id"
  echo "Label: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].label // ""' "$queue_path")"
  echo "Lead hypothesis: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].lead_hypothesis // ""' "$queue_path")"
  echo "Status: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].status // "proposed"' "$queue_path")"
  echo "Sub-stage: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].sub_stage // ""' "$queue_path")"
  echo "Hypotheses: $(jq -r --arg branch_id "$branch_id" '(.branches[$branch_id].hypothesis_ids // []) | join(", ")' "$queue_path")"
  echo "Tension points: $(jq -r --arg branch_id "$branch_id" '(.branches[$branch_id].tension_points // []) | join(" | ")' "$queue_path")"
  echo "Scores: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].scores | "B1=\(.B1 // 0) B2=\(.B2 // 0) B3=\(.B3 // 0) B4=\(.B4 // 0) composite=\(.composite // 0) decision=\(.decision // "")"' "$queue_path")"
  echo "Budget: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].budget | "allocated=\(.allocated_probes // 0) reserve_awarded=\(.reserve_probes_awarded // 0) spent=\(.spent_probes // 0) reclaimed=\(.reclaimed_probes // 0)"' "$queue_path")"
  echo "Contracts: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].contracts | "planned=\((.planned // []) | length) active=\((.active // []) | length) completed=\((.completed // []) | length)"' "$queue_path")"
  echo "Merge target: $(jq -r --arg branch_id "$branch_id" '.branches[$branch_id].merge_target // ""' "$queue_path")"
}

action_wave_status() {
  local session_id="${1:-}"
  local wave_id="${2:-}"
  local queue_path

  if [[ -z "$session_id" || -z "$wave_id" ]]; then
    die_usage "wave-status requires <session-id> <wave-id>."
  fi

  ensure_session_dir "$session_id"
  ensure_queue_file "$session_id"
  queue_path="$(queue_file "$session_id")"

  if [[ "$(jq -r --arg wave_id "$wave_id" '((.waves // []) | map(select(.wave_id == $wave_id)) | length)' "$queue_path")" -eq 0 ]]; then
    die_validation "Wave '$wave_id' not found in '$session_id'."
  fi

  echo "=== Wave Status ==="
  echo "Session: $session_id"
  echo "Wave: $wave_id"
  echo "Status: $(jq -r --arg wave_id "$wave_id" '((.waves // []) | map(select(.wave_id == $wave_id)) | .[0].status) // "planned"' "$queue_path")"
  echo "All resolved: $(jq -r --arg wave_id "$wave_id" '
    . as $root
    | ((.waves // []) | map(select(.wave_id == $wave_id)) | .[0]) as $wave
    | [
        ($wave.branch_ids // [])[]
        | . as $branch_id
        | (($root.branches[$branch_id]?.status // "") as $status
          | if ($status == "pruned" or $status == "merged" or $status == "survived") then true
            else (($root.branches[$branch_id]?.scores.decision // "") != "")
            end)
      ]
    | if length == 0 then false else all end
  ' "$queue_path")"
  echo ""
  printf '%-12s %-10s %-8s %s\n' "BRANCH" "STATUS" "SCORE" "DECISION"
  printf '%-12s %-10s %-8s %s\n' "────────────" "──────────" "────────" "────────"
  jq -r --arg wave_id "$wave_id" '
    . as $root
    | ((.waves // []) | map(select(.wave_id == $wave_id)) | .[0]) as $wave
    | ($wave.branch_ids // [])[]
    | . as $branch_id
    | [
        $branch_id,
        ($root.branches[$branch_id].status // "proposed"),
        ($root.branches[$branch_id].scores.composite // 0 | tostring),
        ($root.branches[$branch_id].scores.decision // "")
      ]
    | @tsv
  ' "$queue_path" | while IFS=$'\t' read -r branch status score decision; do
    printf '%-12s %-10s %-8s %s\n' "$branch" "$status" "$score" "$decision"
  done
}

action_finalize() {
  local session_id="${1:-}"
  local queue_path
  local state_path
  local ts
  local survived_ids
  local pruned_ids
  local merged_ids
  local summary_json

  if [[ -z "$session_id" ]]; then
    die_usage "finalize requires <session-id>."
  fi

  ensure_session_dir "$session_id"
  ensure_state_file "$session_id"
  ensure_queue_file "$session_id"

  queue_path="$(queue_file "$session_id")"
  state_path="$(state_file "$session_id")"
  ts="$(timestamp_utc)"

  json_write "$queue_path" \
    --arg ts "$ts" \
    '
      .branches = (
        (.branches // {})
        | with_entries(
            (.value.status // "proposed") as $status
            | .value.status = (
                if $status == "pruned" or $status == "merged" then $status
                else "survived"
                end
              )
            | .value.sub_stage = "report"
            | .value.scores.decision = (
                if $status == "pruned" then "prune"
                elif $status == "merged" then "merge"
                else "survive"
                end
              )
            | .value.scores.reason = (
                if ($status == "pruned" or $status == "merged") then (.value.scores.reason // "")
                elif (.value.scores.reason // "") == "" then "Survived to report stage."
                else (.value.scores.reason // "")
                end
              )
            | .value.scores.scored_at = (
                if (.value.scores.scored_at // "") == "" then $ts else (.value.scores.scored_at // "") end
              )
          )
      )
    '

  refresh_wave_statuses "$queue_path"

  survived_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "survived") | .key]' "$queue_path")"
  pruned_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "pruned") | .key]' "$queue_path")"
  merged_ids="$(jq -c '[((.branches // {}) | to_entries[]?) | select((.value.status // "") == "merged") | .key]' "$queue_path")"

  summary_json="$(
    jq -cn \
      --arg finalized_at "$ts" \
      --argjson survived_ids "$survived_ids" \
      --argjson pruned_ids "$pruned_ids" \
      --argjson merged_ids "$merged_ids" \
      --argjson reserve_probes "$(jq -r '.reserve_probes // 0' "$queue_path")" \
      --argjson total_waves "$(jq -r '(.waves // []) | length' "$queue_path")" \
      --argjson total_branches "$(jq -r '(.branches // {}) | length' "$queue_path")" \
      '{
        "finalized_at": $finalized_at,
        "total_branches": $total_branches,
        "total_waves": $total_waves,
        "reserve_probes_remaining": $reserve_probes,
        "survived_ids": $survived_ids,
        "pruned_ids": $pruned_ids,
        "merged_ids": $merged_ids
      }'
  )"

  json_write "$state_path" \
    --argjson survived_ids "$survived_ids" \
    --argjson pruned_ids "$pruned_ids" \
    --argjson merged_ids "$merged_ids" \
    --argjson summary "$summary_json" \
    --argjson total_waves "$(jq -r '(.waves // []) | length' "$queue_path")" \
    --arg ts "$ts" \
    '
      (.branch_search // {}) as $branch_search
      | .branch_search = (
          {
            "enabled": true,
            "strategy": ($branch_search.strategy // "wave"),
            "wave_index": $total_waves,
            "max_parallel": ($branch_search.max_parallel // 0),
            "active_ids": [],
            "pruned_ids": $pruned_ids,
            "merged_ids": $merged_ids,
            "final_summary": $summary
          }
        )
      | .updated_at = $ts
    '

  echo "Branch search finalized for $session_id"
  echo "  survived=$(printf '%s\n' "$survived_ids" | jq -r 'length')"
  echo "  pruned=$(printf '%s\n' "$pruned_ids" | jq -r 'length')"
  echo "  merged=$(printf '%s\n' "$merged_ids" | jq -r 'length')"
}

require_jq

case "$ACTION" in
  init) action_init "$@" ;;
  allocate) action_allocate "$@" ;;
  schedule) action_schedule "$@" ;;
  score) action_score "$@" ;;
  prune) action_prune "$@" ;;
  merge) action_merge "$@" ;;
  expand) action_expand "$@" ;;
  status) action_status "$@" ;;
  wave-status) action_wave_status "$@" ;;
  finalize) action_finalize "$@" ;;
  *)
    die_usage "Unknown action '$ACTION'."
    ;;
esac
