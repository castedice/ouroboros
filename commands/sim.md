---
name: sim:sim
description: Use when you need to run a multi-agent simulation with persona-driven agents, shared state, event injection, and information asymmetry.
argument-hint: <scenario-path> [--agents N] [--ticks N] [--budget N] [--dry-run]
allowed-tools: Read, Bash(scripts/sim-run.sh *), Bash(scripts/parallel.sh *), Agent, Task
---

# Sim - Multi-Agent Simulation Orchestrator

Run a bounded multi-agent simulation from a scenario JSON file.
The deterministic script owns scenario validation, shared state, event injection, observation packets, decision recording, budget tracking, and report assembly.
Agents only decide persona-constrained actions from their own observation packet.
Treat the output as hypothesis generation, not prediction truth.

Target: $ARGUMENTS

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Simulation methodology | `skills/sim/methodology/SKILL.md` | Persona design, information asymmetry, event injection, and interpretation boundaries |
| Simulation runner | `scripts/sim-run.sh` | Deterministic state and event loop |
| Scenario template | `templates/sim/scenario.json` | Example scenario JSON |
| Persona template | `templates/sim/persona.json` | Persona shape and defaults |
| Parallel helper | `scripts/parallel.sh` | Per-tick fan-out manifest and result collection pattern |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| user-provided scenario JSON | read | Scenario definition with personas, shared state, rules, and events |
| `.tmp/{SESSION_ID}_sim/scenario.json` | read/write | Normalized scenario after `--agents` and `--ticks` overrides |
| `.tmp/{SESSION_ID}_sim/personas.json` | read/write | Active persona list |
| `.tmp/{SESSION_ID}_sim/event_queue.json` | read/write | Scenario events sorted by tick |
| `.tmp/{SESSION_ID}_sim/shared_state.json` | read/write | Current shared state plus script-owned `_sim` metadata |
| `.tmp/{SESSION_ID}_sim/tick_N_events.json` | read/write | All events scheduled for tick `N` |
| `.tmp/{SESSION_ID}_sim/tick_N_decisions.json` | read/write | Recorded agent decisions for tick `N` |
| `.tmp/{SESSION_ID}_sim/observations/tick_N_{agent}.json` | read/write | Agent-specific observation packet |
| `.tmp/{SESSION_ID}_sim/decisions/tick_N_{agent}.json` | read/write | Expected raw agent decision file for parallel collection |
| `.tmp/{SESSION_ID}_sim/budget.json` | read/write | Token budget limit and usage by tick |
| `.tmp/{SESSION_ID}_sim/state_trajectory.json` | read/write | Append-only state snapshots |
| `.tmp/{SESSION_ID}_sim/report.json` | read/write | Structured final report |
| `.tmp/{SESSION_ID}_sim/report.md` | read/write | Human-readable final report |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No scenario path | 1 | Abort and ask for `<scenario-path>` |
| Scenario path does not exist | 1 | Abort with the missing path and suggest `templates/sim/scenario.json` as a starting template |
| Scenario JSON is invalid | 1 | Abort before creating a session |
| Required scenario field is missing | 1 | Abort with schema validation failure |
| Persona ids are not unique or filename-safe | 1 | Abort before state initialization |
| Event visibility names an unknown persona | 1 | Abort before state initialization |
| `--dry-run` is present | 1 | Run `bash scripts/sim-run.sh init <scenario-path> <session-id> --dry-run` with overrides, show validation JSON, and stop |
| `--agents N` is present | 1-2 | Pass `--agents N` to `sim-run.sh init`; abort if `N` exceeds scenario personas |
| `--ticks N` is present | 1-2 | Pass `--ticks N` to `sim-run.sh init` and ignore events beyond the overridden tick horizon |
| `--budget N` is present | 1-4 | Pass `--budget N` to `sim-run.sh init`; stop launching work once `budget.json` reports exhaustion |
| Agent output is not valid JSON | 3 | Do not record it; retry once with the same observation packet if budget remains |
| Agent output exceeds total budget | 3 | `sim-run.sh record` aborts before mutating state, then stop the simulation with partial artifacts |
| Parallel collection has gaps | 3 | Retry missing agents once; if gaps remain, record only available decisions and mark the tick partial |
| Any tick completes with zero decisions | 3 | Stop and report the simulation as inconclusive |

## Delegation Contracts

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `general-purpose` (per persona) | 3 | Observation packet JSON with scenario context, agent persona, shared state, visible events, and output contract | `{action, rationale, public_summary?, state_delta?, usage?}` JSON |

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.

## System Integration

| Component | Relationship |
|-----------|-------------|
| `skills/sim/methodology/SKILL.md` | Methodology reference for persona design, asymmetry, and interpretation boundaries |
| `scripts/sim-run.sh` | Deterministic state/event loop — command never mutates state directly |
| `scripts/parallel.sh` | Fan-out/fan-in per tick for concurrent agent dispatch |
| `commands/rnd.md` | Upstream: `/rnd` may use `/sim` for hypothesis testing in future phases |
| `skills/core/collaboration/references/coordination-patterns.md` | Fan-out pattern reference for per-tick agent dispatch |

## Phase 1: Parse Input

Parse `$ARGUMENTS` into `scenario_path`, optional `--agents`, optional `--ticks`, optional `--budget`, and optional `--dry-run`.
Create a session id as `sim-YYYYMMDD-HHMMSS` unless the surrounding runner already provides one.
Run `bash scripts/sim-run.sh init "$scenario_path" "$session_id"` with any overrides.
If `--dry-run` is present, show the returned validation JSON (`{ok, action, session_id, state_dir, ticks, agents}`) and stop without dispatching agents.

## Phase 2: Initialize

Read `.tmp/{SESSION_ID}_sim/scenario.json`, `.tmp/{SESSION_ID}_sim/personas.json`, and `.tmp/{SESSION_ID}_sim/shared_state.json`.
Confirm the active persona count, tick count, event count, and budget limit from the init JSON.
Load `skills/sim/methodology/SKILL.md` for simulation interpretation boundaries and information-asymmetry rules.
Do not expose `personas.json` wholesale to agents because it contains every agent's private information.

## Phase 3: Simulate

For each tick from `1` through the configured tick count, call `bash scripts/sim-run.sh tick "$session_id" "$tick"`.
Use the returned `parallel_manifest` to initialize `scripts/parallel.sh` for fan-out tracking.
Dispatch one `Task` or `Agent` call per observation packet in parallel.
Each agent must read only its own `.tmp/{SESSION_ID}_sim/observations/tick_N_{agent}.json` packet.
Each agent must return a JSON object with `action`, `rationale`, optional `public_summary`, optional `state_delta`, and optional `usage.total_tokens`.
Write each raw agent result to the manifest `file` path.
Run `bash scripts/parallel.sh collect "$parallel_session_id"` after the fan-out returns.
For every available result, call `bash scripts/sim-run.sh record "$session_id" "$tick" "$agent_id" "@$decision_path"`.
Continue to the next tick only after the script records decisions and updates `shared_state.json`.

## Agent Decision Contract

Agents receive observation packets with this boundary.

```json
{
  "scenario": {"name": "string", "description": "string", "rules": {}},
  "agent": {"id": "string", "name": "string", "traits": {}, "private_info": "string", "goals": [], "constraints": []},
  "observation": {"shared_state": {}, "visible_events": []},
  "output_contract": {"action": "string", "rationale": "string", "public_summary": "string", "usage": {"total_tokens": 0}}
}
```

Agents must not infer, request, or mention other agents' private information.
Agents may propose `state_delta`, but the script applies it only when scenario rules explicitly set `state_delta_policy` to `merge` and never lets it overwrite `_sim` metadata.
Agents should state uncertainty and local perspective rather than asserting predictive truth.

## Phase 4: Report

After the last tick or after a budget stop, run `bash scripts/sim-run.sh report "$session_id"`.
Read the returned `report_json_path` and `report_md_path`.
Check that the report includes tick history, recorded decisions, state trajectory, budget usage, and script-detected emergent patterns.
Treat emergent patterns as hypotheses about scenario dynamics rather than claims about real-world outcomes.

## Phase 5: Present

Show the user a concise summary with scenario name, session id, tick count completed, agents simulated, budget used, major emergent patterns, and report path.
Call out any partial tick, missing agent decision, or budget stop before interpreting patterns.

Suggest follow-up actions based on outcome:

| Outcome | Suggested Next Action |
|---------|----------------------|
| Completed with patterns | "Review `.tmp/{SESSION_ID}_sim/report.md` for full analysis" |
| Partial (budget stop) | "Rerun with `--budget N` (higher) or `--ticks N` (fewer) to complete" |
| Inconclusive (zero decisions) | "Check scenario personas and rules — agents may need clearer constraints" |
| Hypothesis worth testing | "Run `/rnd` with the simulation hypothesis as a research question" |

## Recovery

| Condition | Detection | Action |
|-----------|-----------|--------|
| Session interrupted | `sim-run.sh status` shows `ticks_started > 0` with missing decisions | Resume from the next incomplete tick |
| Decision file exists but not recorded | `decisions/tick_N_{agent}.json` present, `tick_N_decisions.json` missing that agent | Record the existing decision before relaunching |
| Budget exhausted mid-run | `budget.json` shows `used_tokens >= max_tokens` | Stop simulation, run `report` with partial artifacts |
| Shared state corrupted | `shared_state.json` parse failure | Do not edit manually — the script owns state transitions. Abort and report |
