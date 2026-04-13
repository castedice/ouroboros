#!/usr/bin/env bash
# Spiral state machine manager for SWE pipeline (DR-058)
#
# Manages the spiral execution state file (.swe/active/spiral-state.json).
# Tracks composite and gate statuses, transitions, checkpoints, and regressions.
#
# Usage:
#   spiral-state.sh init <task> [--policy <name>] [--depths S:L D:L H:L N:L]
#   spiral-state.sh update <stage> <status>
#   spiral-state.sh read [--field <jq-path>]
#   spiral-state.sh status
#   spiral-state.sh checkpoint <after_stage>
#   spiral-state.sh restore <checkpoint_id>
#   spiral-state.sh cascade <stage-artifact>
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — operation failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_FILE=".swe/active/spiral-state.json"
TEMPLATE="${SCRIPT_DIR}/../templates/swe/spiral-state.json"
VERSIONS_DIR=".swe/active/.versions"

ACTION="${1:?Usage: spiral-state.sh <action> [args...]}"
shift

# ─── JSON helper ───
# Uses jq if available, falls back to python3

_json_read() {
  local file="$1"
  local filter="$2"
  if command -v jq &>/dev/null; then
    jq -r "$filter" "$file"
  else
    python3 -c "import json,sys; d=json.load(open('$file')); exec(\"
v=$filter
print(v if isinstance(v, str) else json.dumps(v))
\")" 2>/dev/null
  fi
}

_json_write() {
  local file="$1"
  shift
  if command -v jq &>/dev/null; then
    local tmp="${file}.tmp"
    jq "$@" "$file" >"$tmp" && mv "$tmp" "$file"
  else
    echo "Error: jq is required for state file operations. Install with: brew install jq" >&2
    exit 2
  fi
}

_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_check_state_file() {
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "Error: State file not found at $STATE_FILE. Run 'spiral-state.sh init' first." >&2
    exit 2
  fi
}

# ─── Valid values ───

VALID_STAGES="spec_composite spec_dev_gate dev_composite dev_ship_gate ship_composite ship_tune_gate tune_composite"
VALID_STATUSES="pending running completed invalidated stale"
VALID_POLICIES="linear probe team team+probe"
VALID_SPECIALISTS="shaper builder critic"
VALID_SPECIALIST_STATUSES="idle active reviewing"
VALID_CROSS_REVIEW_STATUSES="pending running completed"
VALID_PRIMITIVE_STAGES="understand constrain design interface test implement verify optimize"
VALID_PRIMITIVE_STATUSES="pending running completed"

_validate_stage() {
  local stage="$1"
  for valid in $VALID_STAGES; do
    [[ "$stage" == "$valid" ]] && return 0
  done
  echo "Error: Invalid stage '$stage'. Valid: $VALID_STAGES" >&2
  exit 1
}

_validate_status() {
  local status="$1"
  for valid in $VALID_STATUSES; do
    [[ "$status" == "$valid" ]] && return 0
  done
  echo "Error: Invalid status '$status'. Valid: $VALID_STATUSES" >&2
  exit 1
}

# ─── Action: init ───
#   Args: <task> [--policy <name>] [--depths S:L D:L H:L N:L]
#   Creates state file from template with task and options.

action_init() {
  local task="${1:?Missing task. Usage: spiral-state.sh init <task> [--policy <name>] [--depths S:L D:L H:L N:L]}"
  shift

  local policy="linear"
  local depth_spec=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --policy)
        policy="${2:?Missing policy name after --policy}"
        shift 2
        ;;
      --depths)
        depth_spec="${2:?Missing depth specification after --depths}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Validate policy
  local valid=0
  for p in $VALID_POLICIES; do
    [[ "$policy" == "$p" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Unknown policy '$policy'. Available: $VALID_POLICIES" >&2
    exit 1
  fi

  # Ensure directory exists
  mkdir -p .swe/active

  # Check if state file already exists
  if [[ -f "$STATE_FILE" ]]; then
    echo "Error: State file already exists at $STATE_FILE. Archive or remove it first." >&2
    exit 2
  fi

  # Copy template
  if [[ ! -f "$TEMPLATE" ]]; then
    echo "Error: Template not found at $TEMPLATE" >&2
    exit 2
  fi
  cp "$TEMPLATE" "$STATE_FILE"

  # Set task, policy, timestamps
  local ts
  ts=$(_timestamp)
  _json_write "$STATE_FILE" \
    --arg task "$task" \
    --arg policy "$policy" \
    --arg ts "$ts" \
    '.task = $task | .policy = $policy | .started_at = $ts | .updated_at = $ts'

  # Parse and set depths if provided
  if [[ -n "$depth_spec" ]]; then
    # Parse format: "S:Deep D:Std H:Light N:Light" or "Standard" (global)
    if [[ "$depth_spec" == *":"* ]]; then
      # Per-composite format
      for pair in $depth_spec; do
        local key="${pair%%:*}"
        local val="${pair#*:}"
        case "$key" in
          S) _json_write "$STATE_FILE" --arg v "$val" '.depths.spec = $v' ;;
          D) _json_write "$STATE_FILE" --arg v "$val" '.depths.dev = $v' ;;
          H) _json_write "$STATE_FILE" --arg v "$val" '.depths.ship = $v' ;;
          N) _json_write "$STATE_FILE" --arg v "$val" '.depths.tune = $v' ;;
          *) echo "Warning: Unknown depth key '$key', ignoring." >&2 ;;
        esac
      done
    else
      # Global format: single depth for all
      _json_write "$STATE_FILE" --arg v "$depth_spec" \
        '.depths.spec = $v | .depths.dev = $v | .depths.ship = $v | .depths.tune = $v'
    fi
  fi

  # Initialize team section for team policy (includes team+probe)
  if [[ "$policy" == "team" || "$policy" == "team+probe" ]]; then
    local team_name="spiral-$(date +%s)"
    _json_write "$STATE_FILE" \
      --arg tn "$team_name" \
      '.version = 2 | .team = {"team_name": $tn, "specialists": {"shaper": {"status": "idle", "current_task": null}, "builder": {"status": "idle", "current_task": null}, "critic": {"status": "idle", "current_task": null}}, "cross_reviews": []}'
  fi

  echo "State initialized: policy=$policy, task=\"$(echo "$task" | head -c 60)...\""
}

# ─── Action: update ───
#   Args: <stage> <status>
#   Updates a stage's status and appends a transition log entry.

action_update() {
  local stage="${1:?Missing stage. Usage: spiral-state.sh update <stage> <status> [--type <forward|regression|escalate>]}"
  local status="${2:?Missing status. Usage: spiral-state.sh update <stage> <status> [--type <forward|regression|escalate>]}"
  shift 2

  # Parse optional --type flag
  local explicit_type=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)
        explicit_type="${2:?Missing type after --type. Valid: forward, regression, escalate}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  _check_state_file
  _validate_stage "$stage"
  _validate_status "$status"

  local ts
  ts=$(_timestamp)

  # Get previous stage and status for transition log
  local prev_stage prev_status
  prev_stage=$(_json_read "$STATE_FILE" '.current_stage // "none"')
  prev_status=$(_json_read "$STATE_FILE" ".stages.${stage}")

  # Determine transition type (explicit --type overrides auto-detection)
  local trans_type="forward"
  if [[ -n "$explicit_type" ]]; then
    trans_type="$explicit_type"
  elif [[ ("$status" == "pending" || "$status" == "running") && ("$prev_status" == "completed" || "$prev_status" == "invalidated") ]]; then
    trans_type="regression"
  fi

  # Update state
  _json_write "$STATE_FILE" \
    --arg stage "$stage" \
    --arg status "$status" \
    --arg ts "$ts" \
    --arg from "$prev_stage" \
    --arg type "$trans_type" \
    '.stages[$stage] = $status | .current_stage = $stage | .updated_at = $ts | .transitions += [{"from": $from, "to": $stage, "type": $type, "status": $status, "timestamp": $ts}]'

  echo "Updated: $stage → $status"
}

# ─── Action: read ───
#   Args: [--field <jq-path>]
#   Reads state file. --field for specific jq path.

action_read() {
  _check_state_file

  local field=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --field)
        field="${2:?Missing jq path after --field}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  if [[ -n "$field" ]]; then
    _json_read "$STATE_FILE" "$field"
  else
    cat "$STATE_FILE"
  fi
}

# ─── Action: status ───
#   Args: none
#   Human-readable status summary.

action_status() {
  _check_state_file

  local policy task regression_count max_regressions current escalation_count
  policy=$(_json_read "$STATE_FILE" '.policy')
  task=$(_json_read "$STATE_FILE" '.task' | head -c 70)
  regression_count=$(_json_read "$STATE_FILE" '.regression_count')
  max_regressions=$(_json_read "$STATE_FILE" '.max_regressions')
  current=$(_json_read "$STATE_FILE" '.current_stage // "none"')
  escalation_count=$(_json_read "$STATE_FILE" '[.transitions[] | select(.type == "escalate")] | length')

  echo "=== Spiral State ==="
  echo "Task: $task"
  echo "Policy: $policy | Current: $current | Regressions: $regression_count/$max_regressions | Escalations: $escalation_count"
  echo ""
  printf "%-20s %s\n" "STAGE" "STATUS"
  printf "%-20s %s\n" "────────────────────" "──────────"

  for stage in $VALID_STAGES; do
    local st
    st=$(_json_read "$STATE_FILE" ".stages.${stage}")
    local marker=""
    [[ "$stage" == "$current" ]] && marker=" ←"
    printf "%-20s %s%s\n" "$stage" "$st" "$marker"
  done

  # Show team info if team policy
  if [[ "$policy" == "team" || "$policy" == "team+probe" ]]; then
    echo ""
    echo "=== Team ==="
    local team_name
    team_name=$(_json_read "$STATE_FILE" '.team.team_name')
    echo "Team: $team_name"
    echo ""
    printf "%-12s %-10s %-14s %s\n" "SPECIALIST" "STATUS" "STAGE" "TASK"
    printf "%-12s %-10s %-14s %s\n" "────────────" "──────────" "──────────────" "────────────────────"
    for sp in $VALID_SPECIALISTS; do
      local sp_exists
      sp_exists=$(_json_read "$STATE_FILE" ".team.specialists.${sp} // empty")
      [[ -z "$sp_exists" ]] && continue
      local sp_status sp_task sp_stage sp_stage_st
      sp_status=$(_json_read "$STATE_FILE" ".team.specialists.${sp}.status")
      sp_task=$(_json_read "$STATE_FILE" ".team.specialists.${sp}.current_task // \"-\"")
      sp_stage=$(_json_read "$STATE_FILE" ".team.specialists.${sp}.current_stage // \"-\"")
      sp_stage_st=$(_json_read "$STATE_FILE" ".team.specialists.${sp}.stage_status // \"-\"")
      local stage_display="-"
      [[ "$sp_stage" != "-" && "$sp_stage" != "null" ]] && stage_display="${sp_stage}(${sp_stage_st})"
      printf "%-12s %-10s %-14s %s\n" "$sp" "$sp_status" "$stage_display" "$sp_task"
    done

    # Show cross-reviews
    local cr_count
    cr_count=$(_json_read "$STATE_FILE" '.team.cross_reviews | length')
    if [[ "$cr_count" -gt 0 ]]; then
      echo ""
      echo "Cross-reviews:"
      _json_read "$STATE_FILE" '.team.cross_reviews[] | "  \(.reviewer) → \(.target): \(.status)"'
    fi
  fi
}

# ─── Action: checkpoint ───
#   Args: <after_stage>
#   Creates a checkpoint: copies artifacts to .versions/, adds checkpoint entry.

action_checkpoint() {
  local after_stage="${1:?Missing stage. Usage: spiral-state.sh checkpoint <after_stage>}"

  _check_state_file

  # Create versions directory
  mkdir -p "$VERSIONS_DIR"

  # Determine checkpoint ID
  local cp_count
  cp_count=$(_json_read "$STATE_FILE" '.checkpoints | length')
  local cp_id
  cp_id=$(printf "cp-%03d" $((cp_count + 1)))

  # Get parent checkpoint (last one, if any)
  local parent
  parent=$(_json_read "$STATE_FILE" '.checkpoints[-1].id // null')
  [[ "$parent" == "null" ]] && parent="null" || parent="\"$parent\""

  # Build artifact_versions object and copy files
  local artifact_versions="{"
  local first=1
  for f in .swe/active/[0-9][0-9]-*.md; do
    [[ -e "$f" ]] || continue
    local basename
    basename=$(basename "$f" .md)

    # Determine next version number for this artifact
    local ver=1
    while [[ -f "${VERSIONS_DIR}/${basename}.v${ver}.md" ]]; do
      ver=$((ver + 1))
    done

    # Copy artifact to versions
    cp "$f" "${VERSIONS_DIR}/${basename}.v${ver}.md"

    # Build JSON
    if [[ "$first" -eq 0 ]]; then
      artifact_versions="${artifact_versions},"
    fi
    first=0
    artifact_versions="${artifact_versions}\"${basename}\":${ver}"
  done
  artifact_versions="${artifact_versions}}"

  # Add checkpoint entry to state file
  local ts
  ts=$(_timestamp)
  _json_write "$STATE_FILE" \
    --arg id "$cp_id" \
    --arg after "$after_stage" \
    --argjson versions "$artifact_versions" \
    --argjson parent "$parent" \
    --arg ts "$ts" \
    '.checkpoints += [{"id": $id, "after_stage": $after, "artifact_versions": $versions, "parent_checkpoint": $parent, "created_at": $ts}]'

  echo "Checkpoint $cp_id created after $after_stage."
}

# ─── Action: restore ───
#   Args: <checkpoint_id>
#   Restores artifacts from checkpoint, resets downstream stages, increments regression count.

action_restore() {
  local cp_id="${1:?Missing checkpoint ID. Usage: spiral-state.sh restore <checkpoint_id>}"

  _check_state_file

  # Check circuit breaker
  local reg_count max_reg
  reg_count=$(_json_read "$STATE_FILE" '.regression_count')
  max_reg=$(_json_read "$STATE_FILE" '.max_regressions')
  if [[ "$reg_count" -ge "$max_reg" ]]; then
    echo "Error: Circuit breaker — $reg_count/$max_reg regressions reached. Abort spiral or override." >&2
    exit 2
  fi

  # Find checkpoint
  local cp_json
  cp_json=$(_json_read "$STATE_FILE" ".checkpoints[] | select(.id == \"$cp_id\")")
  if [[ -z "$cp_json" ]]; then
    echo "Error: Checkpoint '$cp_id' not found." >&2
    exit 2
  fi

  # Restore artifacts from .versions/
  local after_stage
  after_stage=$(echo "$cp_json" | jq -r '.after_stage')
  local versions
  versions=$(echo "$cp_json" | jq -r '.artifact_versions | to_entries[] | "\(.key) \(.value)"')

  while IFS=' ' read -r artifact ver; do
    local src="${VERSIONS_DIR}/${artifact}.v${ver}.md"
    local dst=".swe/active/${artifact}.md"
    if [[ -f "$src" ]]; then
      cp "$src" "$dst"
    else
      echo "Warning: Version file $src not found, skipping." >&2
    fi
  done <<<"$versions"

  # Determine which stages come after the checkpoint's after_stage
  local found=0
  for stage in $VALID_STAGES; do
    if [[ "$found" -eq 1 ]]; then
      # Reset downstream stages to pending
      _json_write "$STATE_FILE" \
        --arg stage "$stage" \
        '.stages[$stage] = "pending"'
    fi
    [[ "$stage" == "$after_stage" ]] && found=1
  done

  # Increment regression count
  local ts
  ts=$(_timestamp)
  _json_write "$STATE_FILE" \
    --arg ts "$ts" \
    '.regression_count += 1 | .updated_at = $ts'

  local new_count=$((reg_count + 1))
  echo "Checkpoint $cp_id restored. Regressions: $new_count/$max_reg."
}

# ─── Action: cascade ───
#   Args: <stage-artifact>
#   Computes cascade invalidation from Selective Load Matrix.
#   Output: JSON with invalidated and stale stage lists.

action_cascade() {
  local artifact="${1:?Missing artifact. Usage: spiral-state.sh cascade <stage-artifact> (e.g., 01-understand)}"

  # Cascade invalidation map derived from artifact-contracts.md Selective Load Matrix.
  # Required dependency → invalidated (must re-execute)
  # Optional dependency → stale (may preserve)
  case "$artifact" in
    01-understand)
      echo '{"invalidated":["02-constrain"],"stale":["03-design","04-interface","06-implement","07-verify","08-optimize"]}'
      ;;
    02-constrain)
      echo '{"invalidated":["03-design","08-optimize"],"stale":["04-interface","06-implement","07-verify"]}'
      ;;
    03-design)
      echo '{"invalidated":["04-interface","08-optimize"],"stale":["06-implement","07-verify"]}'
      ;;
    04-interface)
      echo '{"invalidated":["05-test","06-implement","07-verify"],"stale":["08-optimize"]}'
      ;;
    05-test)
      echo '{"invalidated":["06-implement"],"stale":["07-verify","08-optimize"]}'
      ;;
    06-implement)
      echo '{"invalidated":["07-verify"],"stale":["08-optimize"]}'
      ;;
    07-verify)
      echo '{"invalidated":["08-optimize"],"stale":[]}'
      ;;
    08-optimize)
      echo '{"invalidated":[],"stale":[]}'
      ;;
    *)
      echo "Error: Unknown artifact '$artifact'. Use: 01-understand through 08-optimize." >&2
      exit 1
      ;;
  esac
}

# ─── Action: team-update ───
#   Args: <specialist> <status> [--task <description>]
#   Updates a specialist's status and current task.

action_team_update() {
  local specialist="${1:?Missing specialist. Usage: spiral-state.sh team-update <specialist> <status> [--task <desc>]}"
  local status="${2:?Missing status. Usage: spiral-state.sh team-update <specialist> <status> [--task <desc>]}"
  shift 2

  _check_state_file

  # Validate specialist
  local valid=0
  for s in $VALID_SPECIALISTS; do
    [[ "$specialist" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid specialist '$specialist'. Valid: $VALID_SPECIALISTS" >&2
    exit 1
  fi

  # Validate status
  valid=0
  for s in $VALID_SPECIALIST_STATUSES; do
    [[ "$status" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid status '$status'. Valid: $VALID_SPECIALIST_STATUSES" >&2
    exit 1
  fi

  # Parse optional --task
  local task_desc="null"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)
        task_desc="${2:?Missing description after --task}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  local ts
  ts=$(_timestamp)

  if [[ "$task_desc" == "null" ]]; then
    _json_write "$STATE_FILE" \
      --arg sp "$specialist" \
      --arg st "$status" \
      --arg ts "$ts" \
      '.team.specialists[$sp].status = $st | .team.specialists[$sp].current_task = null | .updated_at = $ts'
  else
    _json_write "$STATE_FILE" \
      --arg sp "$specialist" \
      --arg st "$status" \
      --arg task "$task_desc" \
      --arg ts "$ts" \
      '.team.specialists[$sp].status = $st | .team.specialists[$sp].current_task = $task | .updated_at = $ts'
  fi

  echo "Team: $specialist → $status"
}

# ─── Action: cross-review ───
#   Args: <reviewer> <target> <status>
#   Adds or updates a cross-review entry.

action_cross_review() {
  local reviewer="${1:?Missing reviewer. Usage: spiral-state.sh cross-review <reviewer> <target> <status>}"
  local target="${2:?Missing target. Usage: spiral-state.sh cross-review <reviewer> <target> <status>}"
  local status="${3:?Missing status. Usage: spiral-state.sh cross-review <reviewer> <target> <status>}"

  _check_state_file

  # Validate status
  local valid=0
  for s in $VALID_CROSS_REVIEW_STATUSES; do
    [[ "$status" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid cross-review status '$status'. Valid: $VALID_CROSS_REVIEW_STATUSES" >&2
    exit 1
  fi

  local ts
  ts=$(_timestamp)

  # Check if this cross-review already exists
  local existing
  existing=$(_json_read "$STATE_FILE" "[.team.cross_reviews[] | select(.reviewer == \"$reviewer\" and .target == \"$target\")] | length")

  if [[ "$existing" -gt 0 ]]; then
    # Update existing
    _json_write "$STATE_FILE" \
      --arg rev "$reviewer" \
      --arg tgt "$target" \
      --arg st "$status" \
      --arg ts "$ts" \
      '(.team.cross_reviews[] | select(.reviewer == $rev and .target == $tgt)) |= (.status = $st | .updated_at = $ts) | .updated_at = $ts'
  else
    # Add new
    _json_write "$STATE_FILE" \
      --arg rev "$reviewer" \
      --arg tgt "$target" \
      --arg st "$status" \
      --arg ts "$ts" \
      '.team.cross_reviews += [{"reviewer": $rev, "target": $tgt, "status": $st, "created_at": $ts, "updated_at": $ts}] | .updated_at = $ts'
  fi

  echo "Cross-review: $reviewer reviewing $target → $status"
}

# ─── Action: learning-delta ───
#   Args: save | load
#   save: reads learning delta from stdin JSON and writes to .swe/active/learning-delta.json
#   load: reads and outputs previous turn's learning delta from docs/specs/record/

action_learning_delta() {
  local subaction="${1:?Missing subaction. Usage: spiral-state.sh learning-delta <save|load>}"

  case "$subaction" in
    save)
      local delta_file=".swe/active/learning-delta.json"
      # Read JSON from stdin
      local json
      json=$(cat)
      if [[ -z "$json" ]]; then
        echo "Error: No JSON provided on stdin. Pipe learning delta JSON." >&2
        exit 1
      fi
      # Validate JSON
      if ! echo "$json" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON provided." >&2
        exit 1
      fi
      echo "$json" >"$delta_file"
      echo "Learning delta saved to $delta_file"
      ;;
    load)
      # Search for the most recent learning-delta.json in docs/specs/record/
      local latest=""
      if [[ -d "docs/specs/record" ]]; then
        latest=$(find docs/specs/record -name "learning-delta.json" -type f 2>/dev/null | sort -r | head -1)
      fi
      # Also check .swe/active/ (current turn, for testing)
      if [[ -z "$latest" && -f ".swe/active/learning-delta.json" ]]; then
        latest=".swe/active/learning-delta.json"
      fi
      if [[ -z "$latest" ]]; then
        echo "No previous learning delta found."
        exit 0
      fi
      cat "$latest"
      ;;
    *)
      echo "Error: Unknown subaction '$subaction'. Use: save|load" >&2
      exit 1
      ;;
  esac
}

# ─── Action: stage-update ───
#   Args: <specialist> <primitive-stage> <status>
#   Updates a specialist's current primitive stage progress.
#   Requires team or team+probe policy.

action_stage_update() {
  local specialist="${1:?Missing specialist. Usage: spiral-state.sh stage-update <specialist> <stage> <status>}"
  local stage="${2:?Missing stage. Usage: spiral-state.sh stage-update <specialist> <stage> <status>}"
  local status="${3:?Missing status. Usage: spiral-state.sh stage-update <specialist> <stage> <status>}"

  _check_state_file

  # Validate specialist
  local valid=0
  for s in $VALID_SPECIALISTS; do
    [[ "$specialist" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid specialist '$specialist'. Valid: $VALID_SPECIALISTS" >&2
    exit 1
  fi

  # Validate primitive stage
  valid=0
  for s in $VALID_PRIMITIVE_STAGES; do
    [[ "$stage" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid primitive stage '$stage'. Valid: $VALID_PRIMITIVE_STAGES" >&2
    exit 1
  fi

  # Validate status
  valid=0
  for s in $VALID_PRIMITIVE_STATUSES; do
    [[ "$status" == "$s" ]] && valid=1
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Error: Invalid status '$status'. Valid: $VALID_PRIMITIVE_STATUSES" >&2
    exit 1
  fi

  local ts
  ts=$(_timestamp)

  _json_write "$STATE_FILE" \
    --arg sp "$specialist" \
    --arg stage "$stage" \
    --arg st "$status" \
    --arg ts "$ts" \
    '.team.specialists[$sp].current_stage = $stage | .team.specialists[$sp].stage_status = $st | .updated_at = $ts'

  echo "Stage: $specialist/$stage → $status"
}

# ─── Dispatch ───

case "$ACTION" in
  init) action_init "$@" ;;
  update) action_update "$@" ;;
  read) action_read "$@" ;;
  status) action_status ;;
  checkpoint) action_checkpoint "$@" ;;
  restore) action_restore "$@" ;;
  cascade) action_cascade "$@" ;;
  team-update) action_team_update "$@" ;;
  cross-review) action_cross_review "$@" ;;
  stage-update) action_stage_update "$@" ;;
  learning-delta) action_learning_delta "$@" ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: init|update|read|status|checkpoint|restore|cascade|team-update|cross-review|stage-update|learning-delta" >&2
    exit 1
    ;;
esac
