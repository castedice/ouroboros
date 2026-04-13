---
name: sim-methodology
description: This skill provides multi-agent simulation methodology. It should be activated when an agent needs to 'design a simulation scenario', 'define agent personas', 'model shared state', 'inject events into simulation', 'handle information asymmetry', or 'evaluate simulation outcomes'.
summary: Governs persona-driven multi-agent simulations with shared state, event injection, and information asymmetry.
version: 1
tags: [sim, simulation, multi-agent, personas, events]
preamble_tier: 3
---

# Simulation Methodology

## Core Rule

**"The script owns the deterministic state and event loop. Agents only decide actions within their persona constraints. Output is hypothesis generation, not prediction truth."**

Use simulations to explore plausible interaction patterns, stress-test assumptions, and surface surprising dynamics.
Do not treat a simulated trajectory as a forecast, evaluation benchmark, or validated model of real people.
Keep the environment deterministic enough to audit, and keep agent reasoning bounded by persona, observation, rules, and budget.

## Gotchas

| Pitfall | Prevention |
|---------|------------|
| Cost blowup from `agents x ticks` fan-out | Set a total budget before tick 1 and stop launching agents once the script reports exhaustion |
| Persona stereotyping | Define behaviorally relevant traits, goals, constraints, and resources instead of demographic caricatures |
| Validity overclaiming | Label outputs as hypotheses and list scenario assumptions before interpreting patterns |
| Information leakage | Build per-agent observation packets from shared state plus that agent's private info only |
| Agent-owned state mutation | Let agents propose actions, then let the script record or reject state updates deterministically |
| Event visibility drift | Make every event visibility either `all` or an explicit persona id list |
| Hidden scenario edits mid-run | Version scenario inputs at init and treat manual state edits as invalidating the run |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The personas are realistic enough, so the result predicts behavior" | Presenting the simulation as a forecast | Reframe the output as hypothesis generation and name the scenario assumptions |
| "The agents need the full persona list to coordinate" | Sharing other agents' private information | Send only shared state, visible events, and the current agent's private fields |
| "One more tick is cheap" | Continuing after the budget cap or missing usage accounting | Stop at the cap or revise the budget before relaunching |
| "The agent knows the right state change" | Allowing agent text to directly overwrite shared state | Record the action and apply only deterministic script-owned transitions |

## Workflow

| Stage | Action | Output |
|-------|--------|--------|
| Scenario design | Define name, description, tick horizon, personas, shared state, events, and rules | Scenario JSON |
| Persona definition | Give each agent goals, constraints, traits, resources, and private information | Persona array |
| State initialization | Normalize scenario input and create a session state directory | `.tmp/{session}_sim/` |
| Event injection | Select events for the current tick and apply public events to shared state metadata | `tick_N_events.json` |
| Observation build | Create one packet per agent from shared state, visible events, and private info | `observations/tick_N_{agent}.json` |
| Agent decision | Fan out persona-constrained decisions in parallel | Raw decision JSON files |
| State recording | Validate decisions, charge budget, record actions, and update script-owned shared metadata | `tick_N_decisions.json` |
| Pattern review | Compare decisions and state trajectory across ticks | `report.json` and `report.md` |

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Determinism owner | The script owns state files, tick order, event visibility, and budget accounting |
| Agent role | Agents choose actions from their persona and observation packet, not from hidden scenario data |
| Shared state | Treat `shared_state.json` as the only shared world model that agents may observe |
| Private information | Never include another persona's `private_info`, hidden events, or hidden resources in an observation packet |
| Event visibility | Use `all` for public events and an explicit persona id array for private events |
| State deltas | Ignore agent-proposed `state_delta` unless scenario rules explicitly set a deterministic merge policy |
| Budget | Track total and per-tick token usage and abort before exceeding the cap. Default budget is 500K tokens total or 50K per tick, whichever is reached first |
| Persona count | Support 2 to 8 personas per scenario. Abort if fewer than 2 or more than 8 after overrides |
| Tick horizon | Default maximum 20 ticks. Scenarios requesting more require explicit `--ticks N` override |
| Scenario overrides | `--agents` may reduce the active persona set, but it must not invent personas without an explicit scenario source |
| Outcome interpretation | Report emergent patterns as candidates for follow-up, not as validated conclusions |
| Run invalidation | If a human manually edits state files during a run, mark the run invalid or restart from init |

## Reference Map

| Need | Reference |
|------|-----------|
| Scenario structure, persona design, event queue, and information asymmetry patterns | `${CLAUDE_SKILL_DIR}/references/scenario-design.md` |
| Public simulation command | `commands/sim.md` |
| Deterministic state and event loop | `scripts/sim-run.sh` |
| Per-tick fan-out collection pattern | `scripts/parallel.sh` |
| Scenario template | `templates/sim/scenario.json` |
| Persona template | `templates/sim/persona.json` |

## See Also

| Component | Relationship |
|-----------|--------------|
| `commands/rnd.md` | Uses budgeted multi-agent work for hypothesis generation and review |
| `skills/rnd/methodology/SKILL.md` | Defines evidence boundaries and hypothesis-grade interpretation posture |
| `skills/core/collaboration/SKILL.md` | Provides coordination patterns for fan-out and bounded review |
| `skills/core/evaluation/SKILL.md` | Useful when judging scenario quality or report usefulness after a run |

Extension points: future `${CLAUDE_SKILL_DIR}/learned.md` can capture scenario design patterns observed during simulation runs. Future `${CLAUDE_SKILL_DIR}/gotchas.md` can accumulate persona design pitfalls discovered through dogfooding.
