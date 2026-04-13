#!/usr/bin/env bash
# sim-run.sh - deterministic state and event loop for multi-agent simulations.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_ROOT="$ROOT/.tmp"
ACTION="${1:-status}"
if [[ $# -gt 0 ]]; then
  shift || true
fi

usage() {
  cat >&2 <<'EOF'
Usage:
  sim-run.sh init <scenario-path> <session-id> [--agents N] [--ticks N] [--budget N] [--dry-run]
  sim-run.sh tick <session-id> <tick-number>
  sim-run.sh record <session-id> <tick-number> <agent-id> <decision-json|@decision-file>
  sim-run.sh report <session-id>
  sim-run.sh status <session-id>

Environment overrides for init:
  SIM_AGENTS    Active persona count
  SIM_TICKS     Tick count
  SIM_BUDGET    Maximum total tokens recorded from agent decisions
EOF
}

err() { printf '[sim-run] %s\n' "$*" >&2; }
die() { err "Error: $*"; exit 1; }
die_usage() { err "Error: $*"; usage; exit 2; }
need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required."; }
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

need_positive_int() {
  [[ "${1:-}" =~ ^[1-9][0-9]*$ ]] || die_usage "$2 must be a positive integer."
}

need_nonnegative_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || die_usage "$2 must be a non-negative integer."
}

check_session_id() {
  [[ "${1:-}" =~ ^[A-Za-z0-9._-]+$ ]] || die_usage "session-id must match [A-Za-z0-9._-]+."
}

rel() {
  case "$1" in
    "$ROOT"/*) printf '%s\n' "${1#"$ROOT"/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

dir() { printf '%s/%s_sim\n' "$TMP_ROOT" "$1"; }
path() { printf '%s/%s\n' "$(dir "$1")" "$2"; }
scenario() { path "$1" scenario.json; }
personas() { path "$1" personas.json; }
events() { path "$1" event_queue.json; }
state() { path "$1" shared_state.json; }
budget() { path "$1" budget.json; }
history() { path "$1" tick_history.json; }
trajectory() { path "$1" state_trajectory.json; }
tick_events() { path "$1" "tick_${2}_events.json"; }
tick_decisions() { path "$1" "tick_${2}_decisions.json"; }
obs_dir() { path "$1" observations; }
decision_dir() { path "$1" decisions; }

jwrite() {
  local file="${1:?Missing file path}"
  shift || true
  local tmp="${file}.tmp"
  jq "$@" "$file" >"$tmp"
  mv "$tmp" "$file"
}

ensure_session() {
  check_session_id "$1"
  [[ -d "$(dir "$1")" ]] || die "simulation session not found: $1"
}

validate_scenario() {
  jq -e '
    type == "object"
    and (.name | type == "string" and length > 0)
    and ((.description // "") | type == "string")
    and (.ticks | type == "number" and . >= 1)
    and (.personas | type == "array" and length > 0)
    and all(.personas[];
      (.id | type == "string" and test("^[A-Za-z0-9._-]+$"))
      and (.name | type == "string" and length > 0)
      and (.traits | type == "object")
      and (.private_info | type == "string")
      and (.goals | type == "array" and all(.[]; type == "string"))
      and ((.constraints // []) | type == "array" and all(.[]; type == "string"))
      and ((.initial_resources // {}) | type == "object")
    )
    and (([.personas[].id] | length) == ([.personas[].id] | unique | length))
    and (.shared_state | type == "object")
    and (.events | type == "array")
    and ((.rules // {}) | type == "object")
    and all(.events[];
      (.tick | type == "number" and . >= 1)
      and (.type | type == "string" and length > 0)
      and (.content | type == "string")
      and ((.visibility == "all") or (.visibility | type == "array" and all(.[]; type == "string")))
    )
    and ([.personas[].id] as $ids | all(.events[];
      if .visibility == "all" then true else all(.visibility[]; . as $id | $ids | index($id)) end
    ))
  ' "$1" >/dev/null
}

snapshot() {
  local sid="$1" tick="$2" phase="$3"
  jwrite "$(trajectory "$sid")" \
    --argjson tick "$tick" \
    --arg phase "$phase" \
    --arg at "$(ts)" \
    --slurpfile st "$(state "$sid")" \
    '. + [{tick: $tick, phase: $phase, recorded_at: $at, shared_state: $st[0]}]'
}

read_decision() {
  case "${1:-}" in
    @*)
      local f="${1#@}"
      [[ -f "$f" ]] || die "decision file not found: $f"
      cat "$f"
      ;;
    *) printf '%s\n' "$1" ;;
  esac
}

action_init() {
  local src="${1:-}" sid="${2:-}" agents="${SIM_AGENTS:-}" ticks="${SIM_TICKS:-}" max="${SIM_BUDGET:-}" dry=0
  [[ -n "$src" ]] || die_usage "init requires <scenario-path>."
  [[ -n "$sid" ]] || die_usage "init requires <session-id>."
  shift 2 || true
  check_session_id "$sid"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --agents) [[ $# -ge 2 ]] || die_usage "--agents requires a value."; agents="$2"; shift 2 ;;
      --ticks) [[ $# -ge 2 ]] || die_usage "--ticks requires a value."; ticks="$2"; shift 2 ;;
      --budget) [[ $# -ge 2 ]] || die_usage "--budget requires a value."; max="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) die_usage "Unknown init option: $1" ;;
    esac
  done

  [[ -f "$src" ]] || die "scenario not found: $src"
  need_jq
  validate_scenario "$src"

  local scenario_ticks persona_count active_agents active_ticks
  scenario_ticks="$(jq -r '.ticks | floor' "$src")"
  persona_count="$(jq -r '.personas | length' "$src")"
  active_agents="${agents:-$persona_count}"
  active_ticks="${ticks:-$scenario_ticks}"
  need_positive_int "$active_agents" "--agents"
  need_positive_int "$active_ticks" "--ticks"
  [[ -z "$max" ]] || need_nonnegative_int "$max" "--budget"
  ((active_agents <= persona_count)) || die "--agents cannot exceed scenario persona count ($persona_count)."

  if ((dry == 1)); then
    jq -n --arg p "$src" --arg n "$(jq -r '.name' "$src")" --argjson ticks "$active_ticks" --argjson agents "$active_agents" --argjson event_count "$(jq '.events | length' "$src")" \
      '{ok: true, action: "dry-run", scenario_path: $p, name: $n, ticks: $ticks, agents: $agents, events: $event_count, valid: true}'
    return
  fi

  [[ ! -e "$(dir "$sid")" ]] || die "state directory already exists: $(rel "$(dir "$sid")")"
  mkdir -p "$(dir "$sid")" "$(obs_dir "$sid")" "$(decision_dir "$sid")"
  jq --argjson agents "$active_agents" --argjson ticks "$active_ticks" '.ticks = $ticks | .personas = (.personas[:$agents]) | .rules = (.rules // {})' "$src" >"$(scenario "$sid")"
  jq '.personas' "$(scenario "$sid")" >"$(personas "$sid")"
  jq '.events | sort_by(.tick)' "$(scenario "$sid")" >"$(events "$sid")"
  jq -n --arg sid "$sid" --arg at "$(ts)" --slurpfile sc "$(scenario "$sid")" \
    '($sc[0].shared_state // {}) + {_sim: {session_id: $sid, current_tick: 0, started_at: $at, events_applied: [], decision_counts: {}, last_decisions: []}}' >"$(state "$sid")"
  jq -n --arg sid "$sid" --arg at "$(ts)" --arg max "$max" \
    '{session_id: $sid, created_at: $at, max_tokens: (if $max == "" then null else ($max | tonumber) end), used_tokens: 0, ticks: {}}' >"$(budget "$sid")"
  printf '[]\n' >"$(history "$sid")"
  printf '[]\n' >"$(trajectory "$sid")"

  jq -n --arg sid "$sid" --arg d "$(rel "$(dir "$sid")")" --arg sp "$(rel "$(scenario "$sid")")" --arg st "$(rel "$(state "$sid")")" --arg bp "$(rel "$(budget "$sid")")" --argjson ticks "$active_ticks" --argjson agents "$active_agents" \
    '{ok: true, action: "init", session_id: $sid, state_dir: $d, scenario_path: $sp, shared_state_path: $st, budget_path: $bp, ticks: $ticks, agents: $agents}'
}

action_tick() {
  local sid="${1:-}" tick="${2:-}"
  [[ -n "$sid" ]] || die_usage "tick requires <session-id>."
  [[ -n "$tick" ]] || die_usage "tick requires <tick-number>."
  need_positive_int "$tick" "tick-number"
  ensure_session "$sid"

  local total max used ev dec obs_index
  total="$(jq -r '.ticks | floor' "$(scenario "$sid")")"
  ((tick <= total)) || die "tick $tick exceeds configured tick count $total."
  max="$(jq -r '.max_tokens // empty' "$(budget "$sid")")"
  used="$(jq -r '.used_tokens // 0' "$(budget "$sid")")"
  if [[ -n "$max" ]] && ((used >= max)); then
    jq -n --arg sid "$sid" --argjson used "$used" --argjson max "$max" '{ok: false, action: "tick", session_id: $sid, reason: "budget_exhausted", used_tokens: $used, max_tokens: $max}'
    exit 3
  fi

  ev="$(tick_events "$sid" "$tick")"
  dec="$(tick_decisions "$sid" "$tick")"
  obs_index="$(path "$sid" "tick_${tick}_observations.json")"
  jq --argjson tick "$tick" '[.events[] | select((.tick | floor) == $tick)]' "$(scenario "$sid")" >"$ev"
  [[ -f "$dec" ]] || printf '[]\n' >"$dec"
  jwrite "$(state "$sid")" --argjson tick "$tick" --slurpfile ev "$ev" \
    '._sim.current_tick = $tick | ._sim.events_applied = ((._sim.events_applied // []) + ($ev[0] | map(select(.visibility == "all"))))'

  jq -n \
    --arg sid "$sid" \
    --argjson tick "$tick" \
    --arg obs_prefix "$(rel "$(obs_dir "$sid")")/tick_${tick}_" \
    --arg dec_prefix "$(rel "$(decision_dir "$sid")")/tick_${tick}_" \
    --slurpfile sc "$(scenario "$sid")" \
    --slurpfile st "$(state "$sid")" \
    --slurpfile ev "$ev" '
      def visible_to($id): (.visibility == "all") or ((.visibility | type == "array") and ((.visibility | index($id)) != null));
      $sc[0].personas | map(. as $p | {
        session_id: $sid,
        tick: $tick,
        scenario: {name: $sc[0].name, description: ($sc[0].description // ""), rules: ($sc[0].rules // {})},
        agent: {id: $p.id, name: $p.name, traits: $p.traits, private_info: $p.private_info, goals: $p.goals, constraints: ($p.constraints // []), initial_resources: ($p.initial_resources // {})},
        observation: {shared_state: $st[0], visible_events: ($ev[0] | map(select(visible_to($p.id))))},
        output_contract: {required: ["action", "rationale"], optional: ["public_summary", "state_delta", "usage.total_tokens"], boundary: "Return JSON only. Do not use or infer other agents private information."},
        observation_path: ($obs_prefix + $p.id + ".json"),
        decision_path: ($dec_prefix + $p.id + ".json")
      })' >"$obs_index"

  jq -c '.[]' "$obs_index" | while IFS= read -r packet; do
    printf '%s\n' "$packet" | jq '.' >"$ROOT/$(printf '%s\n' "$packet" | jq -r '.observation_path')"
  done

  jwrite "$(history "$sid")" \
    --argjson tick "$tick" \
    --arg at "$(ts)" \
    --arg ep "$(rel "$ev")" \
    --arg dp "$(rel "$dec")" \
    --arg sp "$(rel "$(state "$sid")")" \
    --slurpfile obs "$obs_index" \
    'map(select(.tick != $tick)) + [{tick: $tick, started_at: $at, events_path: $ep, decisions_path: $dp, shared_state_path: $sp, observations: $obs[0]}]'
  snapshot "$sid" "$tick" events_injected

  jq -n --arg sid "$sid" --argjson tick "$tick" --arg d "$(rel "$(dir "$sid")")" --arg sp "$(rel "$(state "$sid")")" --arg ep "$(rel "$ev")" --arg dp "$(rel "$dec")" --slurpfile obs "$obs_index" \
    '{ok: true, action: "tick", session_id: $sid, tick: $tick, state_dir: $d, shared_state_path: $sp, events_path: $ep, decisions_path: $dp, observations: $obs[0], parallel_manifest: ($obs[0] | to_entries | map({idx: .key, model: "agent", agent_id: .value.agent.id, file: .value.decision_path, observation_path: .value.observation_path}))}'
}

action_record() {
  local sid="${1:-}" tick="${2:-}" agent="${3:-}" raw="${4:-}"
  [[ -n "$sid" ]] || die_usage "record requires <session-id>."
  [[ -n "$tick" ]] || die_usage "record requires <tick-number>."
  [[ -n "$agent" ]] || die_usage "record requires <agent-id>."
  [[ -n "$raw" ]] || die_usage "record requires <decision-json|@decision-file>."
  need_positive_int "$tick" "tick-number"
  ensure_session "$sid"
  jq -e --arg a "$agent" 'any(.personas[]; .id == $a)' "$(scenario "$sid")" >/dev/null || die "unknown agent id: $agent"

  local dec decision_tmp record_tmp new old used max projected policy
  dec="$(tick_decisions "$sid" "$tick")"
  [[ -f "$dec" ]] || printf '[]\n' >"$dec"
  decision_tmp="$(mktemp)"
  record_tmp="$(mktemp)"
  read_decision "$raw" >"$decision_tmp"
  jq -e 'type == "object" and (.action | type == "string" and length > 0) and (.rationale | type == "string" and length > 0)' "$decision_tmp" >/dev/null || die "decision must be a JSON object with string action and rationale."

  new="$(jq -r '(.usage.total_tokens // .tokens // .token_count // 0) | tonumber? // 0 | floor' "$decision_tmp")"
  old="$(jq -r --arg a "$agent" '[.[] | select(.agent_id == $a) | .token_count] | add // 0' "$dec")"
  used="$(jq -r '.used_tokens // 0' "$(budget "$sid")")"
  max="$(jq -r '.max_tokens // empty' "$(budget "$sid")")"
  projected=$((used - old + new))
  if [[ -n "$max" ]] && ((projected > max)); then
    rm -f "$decision_tmp" "$record_tmp"
    jq -n --arg sid "$sid" --argjson tick "$tick" --arg a "$agent" --argjson used "$used" --argjson attempted "$new" --argjson max "$max" \
      '{ok: false, action: "record", session_id: $sid, tick: $tick, agent_id: $a, reason: "budget_exceeded", used_tokens: $used, attempted_tokens: $attempted, max_tokens: $max}'
    exit 3
  fi

  jq -n --argjson tick "$tick" --arg a "$agent" --arg at "$(ts)" --argjson tokens "$new" --slurpfile d "$decision_tmp" \
    '{tick: $tick, agent_id: $a, recorded_at: $at, token_count: $tokens, decision: $d[0]}' >"$record_tmp"
  jwrite "$dec" --arg a "$agent" --slurpfile r "$record_tmp" '[.[] | select(.agent_id != $a)] + [$r[0]] | sort_by(.agent_id)'
  jwrite "$(budget "$sid")" --argjson tick "$tick" --argjson projected "$projected" --argjson delta "$((new - old))" \
    '.used_tokens = $projected | .ticks[($tick | tostring)] = ((.ticks[($tick | tostring)] // 0) + $delta)'

  policy="$(jq -r '.rules.state_delta_policy // "append-only"' "$(scenario "$sid")")"
  jwrite "$(state "$sid")" --argjson tick "$tick" --arg a "$agent" --arg at "$(ts)" --arg policy "$policy" --slurpfile d "$decision_tmp" '
    (if $policy == "merge" and (($d[0].state_delta // null) | type == "object") then . * ($d[0].state_delta | del(._sim)) else . end)
    | ._sim.last_decisions = (((._sim.last_decisions // []) | map(select((.tick != $tick) or (.agent_id != $a)))) + [{tick: $tick, agent_id: $a, action: $d[0].action, public_summary: ($d[0].public_summary // ""), recorded_at: $at}])
    | ._sim.decision_counts = ((._sim.last_decisions // []) | group_by(.agent_id) | map({key: .[0].agent_id, value: length}) | from_entries)'
  snapshot "$sid" "$tick" decision_recorded
  rm -f "$decision_tmp" "$record_tmp"
  jq -n --arg sid "$sid" --argjson tick "$tick" --arg a "$agent" --argjson tokens "$new" --argjson used "$projected" \
    '{ok: true, action: "record", session_id: $sid, tick: $tick, agent_id: $a, token_count: $tokens, used_tokens: $used}'
}

collect_decisions() {
  local sid="$1" out="$2" total i file
  total="$(jq -r '.ticks | floor' "$(scenario "$sid")")"
  printf '[]\n' >"$out"
  for i in $(seq 1 "$total"); do
    file="$(tick_decisions "$sid" "$i")"
    if [[ -f "$file" ]]; then
      jwrite "$out" --slurpfile d "$file" '. + $d[0]'
    fi
  done
  return 0
}

write_md_report() {
  local sid="$1" json="$2" md="$3" patterns
  patterns="$(jq -r '.emergent_patterns[]? | "- " + .' "$json")"
  {
    printf '# Simulation Report\n\n'
    printf 'Session: `%s`\n\n' "$sid"
    printf 'Scenario: %s\n\n' "$(jq -r '.scenario.name' "$json")"
    printf 'Ticks configured: %s\n\n' "$(jq -r '.ticks_configured' "$json")"
    printf 'Agents: %s\n\n' "$(jq -r '.agents | length' "$json")"
    printf 'Recorded decisions: %s\n\n' "$(jq -r '.decisions | length' "$json")"
    printf 'Budget used: %s / %s tokens\n\n' "$(jq -r '.budget.used_tokens // 0' "$json")" "$(jq -r '.budget.max_tokens // "unbounded"' "$json")"
    printf '## Emergent Patterns\n\n'
    [[ -n "$patterns" ]] && printf '%s\n\n' "$patterns" || printf '%s\n\n' '- No repeated action pattern detected from recorded decisions.'
    printf '## Boundary\n\nThis report is hypothesis generation, not prediction truth.\n'
  } >"$md"
}

action_report() {
  local sid="${1:-}" dec_tmp report_json report_md
  [[ -n "$sid" ]] || die_usage "report requires <session-id>."
  ensure_session "$sid"
  dec_tmp="$(mktemp)"
  report_json="$(path "$sid" report.json)"
  report_md="$(path "$sid" report.md)"
  collect_decisions "$sid" "$dec_tmp"
  jq -n --arg sid "$sid" --arg at "$(ts)" --arg md "$(rel "$report_md")" --slurpfile sc "$(scenario "$sid")" --slurpfile b "$(budget "$sid")" --slurpfile h "$(history "$sid")" --slurpfile tr "$(trajectory "$sid")" --slurpfile d "$dec_tmp" \
    '{ok: true, action: "report", session_id: $sid, generated_at: $at, scenario: {name: $sc[0].name, description: ($sc[0].description // ""), rules: ($sc[0].rules // {})}, ticks_configured: $sc[0].ticks, agents: ($sc[0].personas | map({id, name, traits, goals, constraints: (.constraints // [])})), tick_history: $h[0], decisions: $d[0], state_trajectory: $tr[0], budget: $b[0], emergent_patterns: ($d[0] | group_by(.decision.action) | map(select(length > 1) | "\(length) decisions used action `\(.[0].decision.action)`")), interpretation_boundary: "hypothesis generation, not prediction truth", report_md_path: $md}' >"$report_json"
  write_md_report "$sid" "$report_json" "$report_md"
  rm -f "$dec_tmp"
  jq -n --arg sid "$sid" --arg rj "$(rel "$report_json")" --arg rm "$(rel "$report_md")" --slurpfile r "$report_json" \
    '{ok: true, action: "report", session_id: $sid, report_json_path: $rj, report_md_path: $rm, decisions: ($r[0].decisions | length), emergent_patterns: $r[0].emergent_patterns}'
}

action_status() {
  local sid="${1:-}" dec_tmp
  [[ -n "$sid" ]] || die_usage "status requires <session-id>."
  ensure_session "$sid"
  dec_tmp="$(mktemp)"
  collect_decisions "$sid" "$dec_tmp"
  jq -n --arg sid "$sid" --arg d "$(rel "$(dir "$sid")")" --slurpfile sc "$(scenario "$sid")" --slurpfile b "$(budget "$sid")" --slurpfile h "$(history "$sid")" --slurpfile tr "$(trajectory "$sid")" --slurpfile de "$dec_tmp" \
    '{ok: true, action: "status", session_id: $sid, state_dir: $d, scenario: {name: $sc[0].name, ticks: $sc[0].ticks, agents: ($sc[0].personas | length), events: ($sc[0].events | length)}, ticks_started: ($h[0] | length), decisions_recorded: ($de[0] | length), state_snapshots: ($tr[0] | length), budget: $b[0]}'
  rm -f "$dec_tmp"
}

case "$ACTION" in
  init) action_init "$@" ;;
  tick) action_tick "$@" ;;
  record) action_record "$@" ;;
  report) action_report "$@" ;;
  status) action_status "$@" ;;
  -h|--help|help) usage ;;
  *) die_usage "Unknown action: $ACTION" ;;
esac
