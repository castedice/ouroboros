# Spiral State Schema — State File, Statuses, and Policy Tables

The spiral meta-composite uses a state file to track execution progress, manage transitions between composites, and support backward transitions (regression).
The state machine is the orchestration layer — composites remain pure executors unaware of state.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For artifact dependencies, see `artifact-contracts.md`.
For depth levels, see `depth-system.md`.

## State File

Location: `.swe/active/spiral-state.json`.
Created at spiral start, updated at each phase boundary, archived with other artifacts after completion.
Template: `templates/swe/spiral-state.json`.

### Schema

| Field | Type | Description |
|-------|------|-------------|
| `version` | integer | Schema version (currently 1) |
| `task` | string | Task description from user input |
| `policy` | string | Transition policy name (`linear`) |
| `depths` | object | Per-composite depth plan: `spec`, `dev`, `ship`, `tune` |
| `stages` | object | 7 stage entries with status values (see Stage Status Enum) |
| `current_stage` | string or null | Currently executing stage key |
| `regression_count` | integer | Number of backward transitions this turn |
| `max_regressions` | integer | Circuit breaker limit (default: 3) |
| `checkpoints` | array | Checkpoint entries for rewind support |
| `transitions` | array | Append-only event log of all state transitions |
| `started_at` | string | ISO 8601 timestamp of spiral initialization |
| `updated_at` | string | ISO 8601 timestamp of last state update |

### Stage Keys

The state machine tracks 7 stages — 4 composites and 3 inter-composite gates:

| Key | Phase | Role |
|-----|-------|------|
| `spec_composite` | Phase 3 | Specification composite (Stages 1-4) |
| `spec_dev_gate` | Phase 4 | Spec → Dev transition checkpoint |
| `dev_composite` | Phase 5 | Development composite (Stages 5-8) |
| `dev_ship_gate` | Phase 6 | Dev → Ship transition checkpoint |
| `ship_composite` | Phase 7 | Ship composite |
| `ship_tune_gate` | Phase 8 | Ship → Tune transition checkpoint |
| `tune_composite` | Phase 9 | Tune composite |

## Stage Status Enum

| Status | Meaning | Transition From |
|--------|---------|-----------------|
| `pending` | Not yet started | (initial), or reset by regression |
| `running` | Currently executing | pending |
| `completed` | Successfully finished | running |
| `invalidated` | Must re-execute due to upstream regression | completed → (cascade invalidation) |
| `stale` | May need re-evaluation due to upstream change | completed → (cascade invalidation) |

Valid transitions:

```text
pending → running → completed
completed → invalidated (cascade: Required dependency changed)
completed → stale (cascade: Optional dependency changed)
completed → running (escalate: probe re-execution at higher depth)
invalidated → pending (regression restore)
stale → pending (user decides to re-execute)
stale → completed (user decides to keep)
```

## Linear Policy Transition Table

The linear policy formalizes the current forward-only behavior with explicit regression paths.
This table maps directly to spiral.md's Decision Matrix — the spiral command reads these rules and executes them.

| Current Stage | Condition | Next Stage | Alternative Paths |
|---------------|-----------|------------|-------------------|
| `spec_composite` | success | `spec_dev_gate` | retry: re-run spec; abort: terminate spiral |
| `spec_dev_gate` | artifacts present | `dev_composite` | abort: terminate spiral |
| `dev_composite` | success | `dev_ship_gate` | retry: re-run dev; regress(spec): checkpoint + cascade + rewind to spec; abort: terminate |
| `dev_ship_gate` | Green state | `ship_composite` | fix: run `/swe implement` to fix; override: proceed anyway; abort: terminate |
| `ship_composite` | success | `ship_tune_gate` | retry: re-run ship; regress(dev): checkpoint + cascade + rewind to dev; abort: terminate |
| `ship_tune_gate` | no P1 findings | `tune_composite` | fix+rerun: fix P1 + re-run ship; override: proceed to tune; abort: terminate |
| `tune_composite` | success or fail | report | (tune failure = warning only, always proceeds to report) |

## Probe Policy Transition Table

The probe policy wraps each composite in a Light-first exploration.
Each composite runs at Light depth, then the user decides whether the result is sufficient or needs escalation to the target depth.
Gates are unchanged — they verify the final artifact regardless of how it was produced.

| Current Stage | Probe Run | Confidence Check | Escalate Path |
|---------------|-----------|------------------|---------------|
| `spec_composite` | Light depth | User reviews artifacts, decides keep or escalate | Re-run at target depth (checkpoint preserves Light version) |
| `dev_composite` | Light depth | User reviews artifacts, decides keep or escalate | Re-run at target depth |
| `ship_composite` | Light depth | User reviews artifacts, decides keep or escalate | Re-run at target depth |
| `tune_composite` | Light depth | User reviews artifacts, decides keep or escalate | Re-run at target depth |

When target depth equals Light (e.g., `--fast`), the probe wrapper is skipped — escalation would be redundant.

Escalation is not regression: it does not increment `regression_count`, does not trigger cascade invalidation, and does not affect the circuit breaker.
The same composite re-runs at a higher depth, producing a deeper result that overwrites the Light artifacts.

All linear policy paths (retry, regress, abort) remain available after escalation — if the escalated run fails, the Decision Matrix applies normally.

## team+probe Policy

The `team+probe` policy composes team pipelining with probe's adaptive depth.
The Team Policy Transition Table applies with one modification: each composite runs at Light depth first (probe), then the user decides whether to escalate to target depth.

Escalation in team context: Director instructs the Specialist to re-run at target depth.
Cross-review findings (if available) are included in the escalation context to inform the user's decision.
All escalation rules from the Probe Policy Transition Table apply (not regression, no cascade, no circuit breaker).

The `team+probe` policy initializes the same team schema as `team` (version 2, specialists, cross_reviews).
The state file records escalation transitions with `type: "escalate"`.

## Team Policy Transition Table

The team policy (DR-061) introduces pipelined composite execution with cross-review.
Director + 3 specialists (Shaper, Builder, Critic) work concurrently.
Key differences from linear/probe: auto-gates (non-blocking except P1), cross-review between composites, and dynamic backtracking triggered by cross-review findings.

| Current Stage | Primary Specialist | Cross-Review | Auto-Gate Condition | Backtrack Trigger |
|---------------|-------------------|--------------|--------------------|--------------------|
| `spec_composite` | Shaper | Builder: codebase prep (background) | — | — |
| `spec_dev_gate` | Director (auto) | Critic: cross-review spec (parallel with Dev) | Interface Contracts artifact exists | Critic P1 finding → invalidate spec |
| `dev_composite` | Builder | Critic: early security scan (background) | — | — |
| `dev_ship_gate` | Director (auto) | Shaper: cross-review dev (parallel with Ship) | Green state (tests pass) | Shaper P1 finding → invalidate dev |
| `ship_composite` | Critic | Shaper: next-turn prep (background) | — | — |
| `ship_tune_gate` | Director (**blocking**) | — | No P1 findings in Ship Report | fix+rerun / override / abort |
| `tune_composite` | All (collaborative) | — | — | — |

### Auto-Gate vs Blocking Gate

In team policy, gates at Phase 4 (`spec_dev_gate`) and Phase 6 (`dev_ship_gate`) are **non-blocking auto-gates**: Director checks artifact existence, then simultaneously starts the next composite and assigns a cross-review.
User approval is not required at these gates — the cross-review provides quality assurance in parallel.

The Phase 8 gate (`ship_tune_gate`) remains **blocking**: P1 findings must be resolved before proceeding to Tune.
This is the only user-facing gate in team policy.

### Cross-Review Backtracking Protocol

When a cross-reviewer reports findings, Director evaluates severity and downstream progress:

| Finding Severity | Next Composite Progress | Director Action |
|-----------------|------------------------|-----------------|
| P1 (contract-breaking) | Not started | Halt next, revise current, restart |
| P1 (contract-breaking) | Early stage (Test) | Halt Builder, Shaper revises, restart Dev |
| P1 (contract-breaking) | Late stage (Implement+) | Continue, flag for urgent fix in Tune |
| P2/P3 (non-blocking) | Any | Record in `.swe/active/.team/`, defer to Tune |

Cross-review backtracking reuses the existing regression protocol: checkpoint → cascade → restore.
The trigger differs — gate failure vs cross-review finding — but the state machine mechanics are identical.

### Team Schema Extension

When `--policy team`, the state file uses schema version 2 with an additional `team` section:

| Field | Type | Description |
|-------|------|-------------|
| `team.team_name` | string | Team identifier (`spiral-{timestamp}`) |
| `team.specialists.{role}` | object | Per-specialist status: `status` (idle/active/reviewing) and `current_task` (string or null). Roles: `shaper`, `builder`, and `critic` |
| `team.cross_reviews` | array | Cross-review entries: `reviewer`, `target`, `status` (pending/running/completed), timestamps |

### Stage-Level State Fields (v0.16.5)

When specialists use stage-level execution (primitive commands instead of composites), two additional fields track primitive stage progress:

| Field | Type | Description |
|-------|------|-------------|
| `team.specialists.{role}.current_stage` | string or null | Currently executing primitive stage (`understand`, `constrain`, ..., `optimize`) |
| `team.specialists.{role}.stage_status` | string or null | Status of the current primitive stage (`pending`, `running`, `completed`) |

These fields provide granular progress tracking — Director knows exactly which stage each specialist is executing.
The composite-level `current_task` field remains for high-level tracking.

Script commands for team state management:

```bash
spiral-state.sh team-update <specialist> <status> [--task <description>]
spiral-state.sh cross-review <reviewer> <target> <status>
spiral-state.sh stage-update <specialist> <primitive-stage> <status>
```

Cross-review findings are stored as markdown in `.swe/active/.team/{reviewer}-{target}-review.md`, not in the state JSON.
The state file tracks review status; the markdown file holds the actual findings content.

### Transition Log Entry Format

Each state change appends an entry to the `transitions` array:

```json
{
  "from": "spec_composite",
  "to": "spec_dev_gate",
  "type": "forward",
  "result": "success",
  "timestamp": "2026-03-02T10:30:00Z"
}
```

Regression entries include a `reason` field:

```json
{
  "from": "dev_composite",
  "to": "spec_composite",
  "type": "regression",
  "reason": "Interface Contracts missing error handling for edge case",
  "timestamp": "2026-03-02T11:15:00Z"
}
```

Escalation entries record the depth change (probe policy):

```json
{
  "from": "spec_composite",
  "to": "spec_composite",
  "type": "escalate",
  "status": "running",
  "timestamp": "2026-03-02T10:45:00Z"
}
```
