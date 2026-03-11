---
description: "Spiral meta-composite — orchestrate the full engineering cycle: spec → dev → ship → tune, with each turn's learnings feeding the next"
argument-hint: "<task-description> [--fast] [--deep] [--depth <global|per-composite>] [--policy <name>] [--single] [--route <stage=model,...>]"
allowed-tools: Read, Glob, Grep, Write, Skill, Bash, Agent, TeamCreate, SendMessage, TeamDelete
---

# Spiral — Meta-Composite (Full Engineering Cycle)

Orchestrate the 4 composites sequentially — Spec, Dev, Ship, Tune — to execute a complete engineering cycle. Each spiral turn elevates the next: tune's retrospect feeds into the next spec cycle.

Target: $ARGUMENTS

## Composites Used

| Phase | Composite | Stages | Role |
|-------|-----------|--------|------|
| 3 | `/swe spec` | 1-4 (Understand → Interface) | Specification — from problem to contracts |
| 5 | `/swe dev` | 5-8 (Test → Optimize) | Development — from contracts to working code |
| 7 | `/swe ship` | Integration → Security → Review → Deploy | Release — from code to production readiness |
| 9 | `/swe tune` | Evaluate → Improve → Retrospect | Tuning — from release to learnings |

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Depth System | `skills/swe/methodology/references/depth-system.md` | Depth level definitions, validation rules, composite defaults |
| Artifact Contracts | `skills/swe/methodology/references/artifact-contracts.md` | Artifact naming convention `.swe/active/{NN}-{stage}.md` (working) and `docs/specs/record/{package}/{NNN}-{slug}/{NN}-{stage}.md` (archived), required fields, inter-stage dependencies |
| Pipeline Stages | `skills/swe/methodology/references/pipeline-stages.md` | Stage definitions, composite boundaries, ordering constraints |
| Spiral State | `skills/swe/methodology/references/spiral-state.md` | State machine schema, transition rules, checkpoint protocol, cascade invalidation |
| Team Execution Pattern | `skills/swe/methodology/references/team-execution-pattern.md` | Team topology, specialist prompts, pipelined flow, auto-gates, cross-review protocol (team policy only) |
| Spiral Monitor | `scripts/spiral-monitor.sh` | Real-time TUI dashboard for team progress — auto-launched in tmux at init |

## Composite Execution Pattern

Each composite phase (3, 5, 7, 9) follows the same invocation sequence:

1. **State update**: `Bash: scripts/spiral-state.sh update {stage_key} running`
2. **Invoke** via Skill tool: `Skill: swe:{composite}` with `Args: "{task}" --depth {depth} [--fast] [--multi] [--artifact {path}]` (pass `--fast` when fast_mode is active, `--multi` when multi_model is active, so composites relay flags to primitive stages)
3. **Wait** for composite completion — each composite runs its internal stages, presents its Review phase to the user, and produces artifacts in `.swe/active/`
4. **State update**: `Bash: scripts/spiral-state.sh update {stage_key} completed`
5. **Log**: "{Composite} composite complete."
6. **On failure**: present options from the Decision Matrix and wait for user decision

The composite phases below specify only the Skill call and stage-specific parameters. Shared invocation mechanics are defined here.

### Probe Execution Pattern

When `--policy probe` (default) and the composite's target depth is not Light, each composite phase wraps the Composite Execution Pattern in a probe-then-decide sequence:

1. **Probe run**: Execute the Composite Execution Pattern with `--depth Light` (temporarily overriding the target depth for this first run)
2. **Confidence check**: After the composite completes at Light depth, present the result:

```markdown
## Probe Result: {Composite}

Executed at Light depth. Target depth: {target_depth}.

Artifacts produced:
- {list artifacts with paths from .swe/active/}

Options:
(A) **Keep Light result** — proceed to the next phase with these artifacts
(B) **Escalate to {target_depth}** — re-run {composite} at full depth (Light artifacts preserved in .versions/)
```

3. **Decision**:
   - **Keep (A)**: Proceed to the next transition phase. No additional state changes.
   - **Escalate (B)**:
     1. Checkpoint: `Bash: scripts/spiral-state.sh checkpoint {stage_key}` (preserves Light artifacts in `.versions/`)
     2. State update: `Bash: scripts/spiral-state.sh update {stage_key} running --type escalate`
     3. Re-invoke composite at target depth via the Composite Execution Pattern
     4. State update: `Bash: scripts/spiral-state.sh update {stage_key} completed`
     5. Log: "{Composite} escalated from Light to {target_depth}."

**Skip conditions**: When target depth is Light (e.g., `--fast`), the probe wrapper is skipped — execute the Composite Execution Pattern directly. When `--policy linear`, the probe wrapper is also skipped.

**Escalation is not regression**: it does not increment `regression_count`, does not trigger cascade invalidation, and does not affect the circuit breaker. The same composite re-runs at higher depth.

### Transition Checkpoint Pattern

Each transition phase (4, 6, 8) follows the same verification sequence:

1. **State update**: `Bash: scripts/spiral-state.sh update {gate_key} running`
2. **Verify** prerequisite artifacts exist in `.swe/active/` using Glob
3. **Gate** on critical conditions — missing artifacts or failed state checks trigger options from the Decision Matrix
4. **State update**: `Bash: scripts/spiral-state.sh update {gate_key} completed`
5. **Present** transition summary listing produced artifacts and current state
6. **Proceed** automatically unless user requests a pause

The transition phases below specify only the critical gate condition and their unique checkpoint template.

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--deep` | Shortcut for `--depth Deep` | Off |
| `--depth` | Depth specification (escalation target when probe policy is active) | Standard (global) |
| `--policy` | Transition policy preset (see `references/spiral-state.md`) | `probe` |
| `--single` | Force single-model mode in Ship and Tune (skip external CLIs). Multi-model auto-detected by default | — |
| `--route` | Per-stage model routing for team policy (e.g., `"understand=codex,implement=codex"`) | All stages → Claude |
| `--composite-level` | Force composite-level execution in team policy (v0.16.0 behavior, skip stage-level) | Off (stage-level is default at Standard+) |

**`--fast` mode**: Sets all composites to Light depth and enables relaxed skip conditions in primitive stages. If both `--fast` and `--depth` are present, `--depth` takes precedence (explicit depth overrides shortcut).

**`--deep` mode**: Sets all composites to Deep depth. If both `--deep` and `--depth` are present, `--depth` takes precedence. `--fast` and `--deep` are mutually exclusive — if both are present, abort with error.

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 composites at Deep depth |
| Per-composite | `--depth S:Deep D:Std H:Light N:Light` | Individual composite depths (S=Spec, D=Dev, H=sHip, N=tuNe) |

Depth parsing and validation is handled by `scripts/spiral-state.sh init` — it validates format, abbreviations (S=Spec, D=Dev, H=Ship, N=Tune), and depth values. Invalid input produces a descriptive error and aborts.

`--policy` accepts a policy name. Currently available: `probe` (default), `linear`, `team`, `team+probe`. Unknown policies produce an error with available options. The policy controls traversal behavior (how composites are executed), independent of depth (how deep they go). Stage-level parallelism (Security Review ‖ Code Review, Improve ‖ Retrospect) is composite-internal — see `commands/swe/ship.md` and `commands/swe/tune.md`.

When `--policy team`: Director spawns 3 Specialists (Shaper, Builder, Critic) that execute composites concurrently with cross-review. Composites overlap via auto-gates. See `references/team-execution-pattern.md` for the full protocol.

When `--policy team+probe`: Combines team pipelining with probe's adaptive depth. Specialists execute at Light depth first (probe), then Director relays probe results to the user for escalation decision. Cross-review findings inform the escalation context. See `references/team-execution-pattern.md` § Probe Composition Protocol.

`--route` accepts comma-separated `stage=model` pairs (e.g., `"understand=codex,implement=codex"`). Valid stages: `understand`, `constrain`, `design`, `interface`, `test`, `implement`, `verify`, `optimize`. Valid models: `codex`, `claude`. Unspecified stages default to Claude specialist. Requires `--policy team` or `--policy team+probe` — ignored otherwise. Ignored when `--fast` or `--composite-level` is active (composite-level execution has no per-stage routing). See `references/team-execution-pattern.md` § Selective Routing Protocol.

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe spiral <task-description> [--depth <global|S:level D:level H:level N:level>] [--policy <name>]`"
- Abort

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all composites to Light and enable `fast_mode=true` for relaxed skip conditions downstream
3. If `--deep` was provided (and no `--depth`), set all composites to Deep
4. If none of `--fast`, `--deep`, or `--depth`, apply Standard to all composites per `skills/swe/methodology/references/depth-system.md` (each composite's internal depth planning will further distribute across its stages)
5. **Load learning delta** (team/team+probe policy only): Check for previous turn's delta via `Bash: scripts/spiral-state.sh learning-delta load`. If found, adjust depth recommendations:
   - `"over"` calibration → suggest lowering one level (e.g., Deep→Standard)
   - `"under"` calibration → suggest raising one level (e.g., Light→Standard)
   - Present adjustments to user: "Previous turn learning: {composite} was {over/under}-specified. Suggesting {adjusted_depth}."
   - User decides whether to accept the suggestion — learning delta is advisory, not automatic
6. Build Depth Plan:

```text
Depth Plan: S:{level} D:{level} H:{level} N:{level}
Rationale: {key drivers}
```

Log the Depth Plan. Present to user for confirmation:

```markdown
## Spiral Depth Plan

| Composite | Depth | Stages | Rationale |
|-----------|-------|--------|-----------|
| Spec | {level} | Understand, Constrain, Design, Interface | {reason} |
| Dev | {level} | Test, Implement, Verify, Optimize | {reason} |
| Ship | {level} | Integration, Security, Review, Deploy | {reason} |
| Tune | {level} | Evaluate, Improve, Retrospect | {reason} |

Each composite will further distribute this depth across its internal stages.

Proceed with this plan, or adjust depths?
```

## Phase 2.5: Initialize State

Initialize the spiral state machine for this turn:

1. Run: `Bash: scripts/spiral-state.sh init "{task}" --policy {policy} --depths "S:{spec_depth} D:{dev_depth} H:{ship_depth} N:{tune_depth}"`
2. Log: "Spiral state initialized. Policy: {policy}."
3. State file created at `.swe/active/spiral-state.json`
4. In tmux sessions, `spiral-monitor.sh` auto-launches in a right-side pane (40% width) showing real-time pipeline and team status. Set `OUROBOROS_NO_MONITOR=1` to disable.

If state file already exists (interrupted previous spiral), present options:
- **Resume**: Keep existing state and continue from last completed stage
- **Restart**: Remove existing state file and initialize fresh

## Phase 2.7: Team Setup (team policy only)

When `--policy team`, spawn the specialist team before entering Phase 3. Follow the Specialist Spawn Protocol from `references/team-execution-pattern.md`:

1. **Create team workspace**: `Bash: mkdir -p .swe/active/.team`
2. **Create team**: `TeamCreate` with `team_name` matching the state file's `team.team_name`
3. **Spawn specialists** (3 parallel Agent calls):
   - `Agent(name: "shaper", subagent_type: "general-purpose", team_name: "{team_name}")` with Shaper system prompt
   - `Agent(name: "builder", subagent_type: "general-purpose", team_name: "{team_name}")` with Builder system prompt
   - `Agent(name: "critic", subagent_type: "general-purpose", team_name: "{team_name}")` with Critic system prompt
4. **Wait for readiness**: All 3 specialists confirm via SendMessage
5. **State**: `spiral-state.sh team-update shaper idle`, `builder idle`, `critic idle`
6. **Log**: "Team spiral ready: Shaper, Builder, Critic spawned."

System prompts are defined in `references/team-execution-pattern.md` § Specialist System Prompts.

### Bridge Agent Spawn (--route only)

When `--route` contains external model assignments (codex):

1. **MCP check**: Verify target MCP servers are accessible (Bridge Agent will check on startup)
2. **Spawn Bridge**: `Agent(name: "bridge", subagent_type: "general-purpose", team_name: "{team_name}", model: "sonnet")` with Bridge system prompt from `agents/swe/bridge.md`
3. **Wait for readiness**: Bridge confirms via SendMessage
4. **State**: `spiral-state.sh team-update bridge idle`
5. **Log**: "Bridge Agent spawned for external model routing: {models in routing table}."

If no external models in `--route` (all stages → claude): skip Bridge spawn. See `references/team-execution-pattern.md` § Selective Routing Protocol for routing logic and MCP fallback.

## Phase 3: Spec

```
Skill: swe:spec
Args: "{task}" --depth {spec_depth}
```

Runs Stages 1-4 (Understand → Constrain → Design → Interface). When probe policy is active and spec_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When policy is `team`**: Director assigns Spec to Shaper via SendMessage. Simultaneously, Builder starts codebase pre-analysis (background task → `.swe/active/.team/builder-prep.md`). Director updates state: `spiral-state.sh team-update shaper active --task "Spec composite"`. When Shaper completes, it sends the Review content to Director. Director updates state: `spiral-state.sh update spec_composite completed`, `spiral-state.sh team-update shaper idle`.

**When policy is `team+probe`**: Same as team, but Shaper executes at Light depth first. When Shaper completes, Director presents the probe result to the user with escalation option. If user keeps Light result: proceed to Phase 4. If user escalates: Shaper re-runs at target depth (checkpoint preserves Light artifacts). Cross-review findings from Critic (Phase 4.5) are included in the escalation context if available. See `references/team-execution-pattern.md` § Probe Composition Protocol.

## Phase 4: Spec → Dev Transition

Follows the Transition Checkpoint Pattern. Critical gate: Interface Contracts artifact (`interface-*.md`). If missing: see Decision Matrix.

```markdown
## Spec → Dev Transition

Spec artifacts produced:
- Context Document: {path}
- Constraint Profile: {path}
- Architecture Spec: {path}
- Interface Contracts: {path}

Proceeding to Dev phase. Continue or pause?
```

**When policy is `team`**: This gate is an **auto-gate** — no user approval required. Follow the Phase 4 Auto-Gate Protocol from `references/team-execution-pattern.md`:

1. Verify Interface Contracts artifact exists
2. `spiral-state.sh update spec_dev_gate completed`
3. **Simultaneously** (3 parallel actions):
   - Assign Dev to Builder via SendMessage (Builder invokes `Skill: ouroboros:swe:dev`)
   - Assign Spec cross-review to Critic via SendMessage
   - Relay Shaper's Review content to the user
4. State: `spiral-state.sh team-update builder active --task "Dev composite"`, `spiral-state.sh cross-review critic spec running`

## Phase 4.5: Spec Cross-Review Resolution (team policy only)

Critic reviews Spec artifacts (`.swe/active/01-understand.md` through `04-interface.md`) and sends findings to Director. This runs in parallel with Builder's Dev execution.

When Director receives Critic's findings:

1. **State**: `spiral-state.sh cross-review critic spec completed`
2. **Save**: Write findings to `.swe/active/.team/critic-spec-review.md`
3. **Evaluate severity**:
   - **P1 findings**: Follow the Backtracking Decision Tree from `references/team-execution-pattern.md` — consider Builder's progress before deciding halt vs continue
   - **P2/P3 findings**: Record in `.team/`, defer to Tune
4. **If backtracking**: Use the Regression Protocol from the Decision Matrix. Send halt to Builder if needed

## Phase 5: Dev

```
Skill: swe:dev
Args: "{task}" --depth {dev_depth} --artifact {interface_contracts_path}
```

Runs Stages 5-8 (Test → Implement → Verify → Optimize). When probe policy is active and dev_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When policy is `team`**: Builder is already executing Dev (started in Phase 4 auto-gate). Critic may perform early security scan in the background. Director monitors for messages from Builder (completion) and Critic (Phase 4.5 cross-review findings). When Builder completes, it sends the Review content to Director. Director updates state: `spiral-state.sh update dev_composite completed`, `spiral-state.sh team-update builder idle`.

**When policy is `team+probe`**: Builder executes at Light depth first. On completion, Director presents probe result with escalation option. Cross-review findings from Shaper (Phase 6.5) are included in escalation context if available.

## Phase 6: Dev → Ship Transition

Follows the Transition Checkpoint Pattern. Critical gate: Green state confirmation — run test suite via Bash after checking Implementation artifact (`implement-*.md` or `optimize-*.md`). If tests fail: see Decision Matrix.

```markdown
## Dev → Ship Transition

Dev artifacts produced:
- Test Suite: {path}
- Implementation: {path}
- Verification Report: {path}
- Optimization Report: {path}

Green state: {confirmed/warning}

Proceeding to Ship phase.
```

**When policy is `team`**: This gate is an **auto-gate**. Follow the Phase 6 Auto-Gate Protocol from `references/team-execution-pattern.md`:

1. Verify Green state (run test suite)
2. `spiral-state.sh update dev_ship_gate completed`
3. **Simultaneously** (3 parallel actions):
   - Assign Ship to Critic via SendMessage (Critic invokes `Skill: ouroboros:swe:ship`)
   - Assign Dev cross-review to Shaper via SendMessage
   - Relay Builder's Review content to the user
4. State: `spiral-state.sh team-update critic active --task "Ship composite"`, `spiral-state.sh cross-review shaper dev running`

## Phase 6.5: Dev Cross-Review Resolution (team policy only)

Shaper reviews Dev artifacts (implementation, verification) and sends findings to Director. This runs in parallel with Critic's Ship execution.

When Director receives Shaper's findings:

1. **State**: `spiral-state.sh cross-review shaper dev completed`
2. **Save**: Write findings to `.swe/active/.team/shaper-dev-review.md`
3. **Evaluate severity**: Same logic as Phase 4.5 — P1 triggers backtracking decision, P2/P3 deferred to Tune

## Phase 7: Ship

```
Skill: swe:ship
Args: "{task}" --depth {ship_depth} [--multi] --artifact {latest_dev_artifact_path}
```

Pass `--multi` when multi_model is active. Runs Integration Test → Security Review ‖ Code Review → Deploy Readiness. When probe policy is active and ship_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When policy is `team`**: Critic is already executing Ship (started in Phase 6 auto-gate). Shaper may work on next-turn domain prep if assigned. When Critic completes, it sends the Review content to Director. Director updates state: `spiral-state.sh update ship_composite completed`, `spiral-state.sh team-update critic idle`.

**When policy is `team+probe`**: Critic executes Ship at Light depth first. On completion, Director presents probe result with escalation option.

## Phase 8: Ship → Tune Transition

Follows the Transition Checkpoint Pattern. Critical gate: P1 findings in Ship Report (`ship-*.md`). If P1 exists: see Decision Matrix (override option C available).

If P1 findings exist:

```markdown
## Ship → Tune Transition: BLOCKED

Ship Report contains {n} P1 findings that must be resolved:
{list P1 findings}

Options:
(A) Fix P1 issues and re-run ship: will re-enter spiral at Phase 7
(B) Abort spiral — fix issues manually and re-run `/swe ship`
(C) Override and proceed to Tune anyway (P1 issues will be documented in retrospect)
```

If no P1 findings:

```markdown
## Ship → Tune Transition

Ship Report: {path}
Status: CLEAR — no P1 blockers

Proceeding to Tune phase.
```

## Phase 9: Tune

```
Skill: swe:tune
Args: "{task}" --depth {tune_depth} [--multi] --artifact {ship_report_path}
```

Pass `--multi` when multi_model is active. Runs Evaluate → Improve ‖ Retrospect. When probe policy is active and tune_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: log warning and proceed to Phase 10 with partial results — all prior artifacts remain valid.

**When policy is `team`**: Follow the Tune Collaboration protocol from `references/team-execution-pattern.md`. Before invoking Tune:

1. Send perspective requests to all 3 specialists simultaneously (domain insights, implementation insights, quality summary)
2. Wait for all 3 responses
3. Save perspectives to `.swe/active/.team/tune-perspectives.md`
4. Invoke Tune via Skill tool — the perspectives file is available for Retrospect to reference

## Phase 10: Report

Present the complete spiral cycle results:

```markdown
## Spiral Complete: {task summary}

### Cycle Summary

| Composite | Depth | Status | Key Output |
|-----------|-------|--------|------------|
| Spec | {level} | {done/failed} | {n} artifacts — Context, Constraints, Architecture, Interfaces |
| Dev | {level} | {done/failed} | {n} tests, Green state {confirmed/partial}, {n} optimizations |
| Ship | {level} | {done/failed} | {P1/P2/P3 counts}, ship status {CLEAR/BLOCKED} |
| Tune | {level} | {done/failed} | {n} learnings, {m} next-cycle suggestions |

### State Machine Summary

| Stage | Status |
|-------|--------|
| Spec | {status from spiral-state.json} |
| Spec → Dev Gate | {status} |
| Dev | {status} |
| Dev → Ship Gate | {status} |
| Ship | {status} |
| Ship → Tune Gate | {status} |
| Tune | {status} |

Policy: {policy} | Regressions: {regression_count}/{max_regressions} | Escalations: {escalation_count}

### Team Summary (team policy only)

| Specialist | Composite | Cross-Review | Findings |
|-----------|-----------|-------------|----------|
| Shaper | Spec | Dev → {P1/P2/P3 counts} | {summary} |
| Builder | Dev | — | — |
| Critic | Ship | Spec → {P1/P2/P3 counts} | {summary} |

### Artifact Chain

| # | Artifact | Path |
|---|----------|------|
| 1 | Context Document | `.swe/active/01-understand.md` |
| 2 | Constraint Profile | `.swe/active/02-constrain.md` |
| 3 | Architecture Spec | `.swe/active/03-design.md` |
| 4 | Interface Contracts | `.swe/active/04-interface.md` |
| 5 | Test Suite | `.swe/active/05-test.md` |
| 6 | Implementation | `.swe/active/06-implement.md` |
| 7 | Verification Report | `.swe/active/07-verify.md` |
| 8 | Optimization Report | `.swe/active/08-optimize.md` |
| 9 | Ship Report | `.swe/active/09-ship.md` |
| 10 | Retrospect Report | `.swe/active/10-tune.md` |

### Next Spiral Turn

Compute next-turn parameters from cycle results:

1. **Task**: Use tune retrospect's primary recommendation. If tune failed or produced no recommendation, derive from the highest-priority finding across ship and dev reports
2. **Depths**: Apply the first matching row from `references/spiral-state.md` § Next Turn Recommendations. When tune retrospect specifies depths, those take precedence

Present the computed recommendation:

```text
Recommended next turn:
  Task: {computed from step 1}
  Depths: {computed from step 2}
  Focus: {matching row's focus area}
```

To start the next turn:
`/swe spiral "{computed task}" --depth {computed depths}`
```

## Phase 10.5: Archive (team policy: after shutdown)

Archive the turn's artifacts after all state updates are complete. Tune skips archiving when running inside a spiral (detects `spiral-state.json`), so spiral is responsible for archiving.

1. Derive task slug from the tune report or task description (lowercase, hyphens, max 30 chars)
2. Run: `Bash: scripts/artifact-lifecycle.sh archive "{slug}"`
3. If `.swe/active/` is already empty (tune archived in standalone mode): skip silently
4. Update Phase 10 Report's artifact table with final record/ paths

## Phase 10.6: Update Project Model

After archiving, update the living project model with this turn's findings. The project model (`docs/specs/project/`) maintains the cumulative specification state across spiral turns.

1. If `docs/specs/project/` does not exist: run `Bash: scripts/artifact-lifecycle.sh init-project` to create it
2. Locate the archived artifacts from Phase 10.5. Read each artifact's `## Summary` section:
   - `01-understand.md` → domain model changes
   - `02-constrain.md` → new/modified constraints
   - `03-design.md` → architecture decisions
   - `04-interface.md` → interface changes
3. For each project model file (`domain.md`, `constraints.md`, `architecture.md`, `interfaces.md`):
   - Read current content
   - Merge new findings from the archived artifact: append new entries, update existing entries if changed
   - Update the `## Summary` section to reflect the cumulative state
   - Add a Change Log entry: `| {NNN} | {slug} | {what changed} |`
   - Update the `Last updated` header line with today's date, turn number, and slug
4. Skip any stage artifact that doesn't exist in the archive (Light depth may skip some stages)

### Merge Strategy

- **Domain model**: Append new entities/value objects, update existing descriptions if changed, merge ubiquitous language terms
- **Constraints**: Append new constraints with feature attribution (Source column), update violated/relaxed constraints
- **Architecture**: Append new components/decisions, update existing component descriptions
- **Interfaces**: Append new contracts, update modified signatures/types

The merge is additive — never remove content. If a constraint was relaxed or an interface deprecated, mark it as such rather than deleting.

## Phase 11: Team Shutdown (team policy only)

Follow the Shutdown Protocol from `references/team-execution-pattern.md`:

1. Send `shutdown_request` to all 3 specialists (Shaper, Builder, Critic)
2. Wait for all 3 `shutdown_response(approve: true)` confirmations
3. `TeamDelete` to clean up team resources
4. Log: "Team spiral complete. Specialists shut down."

If a specialist rejects shutdown: wait for its current work to complete, then re-send.

## Decision Matrix

Consolidated branch conditions across all phases. Regression paths (marked with ↩) use the checkpoint-rewind protocol from `references/spiral-state.md`:

| Phase | Condition | Path A | Path B | Path C |
|-------|-----------|--------|--------|--------|
| 1 | Task empty | Abort with usage error | — | — |
| 1 | Invalid depth/policy | Abort with error | — | — |
| 1 | `--fast` + `--deep` both present | Abort with error | — | — |
| 2 | `--depth` provided | Use parsed values | — | — |
| 2 | No `--depth` | Standard for all composites | — | — |
| 3 (probe) | Probe result reviewed | Keep Light result → proceed | Escalate to target depth | — |
| 3 | Spec fails or user aborts | Retry with adjusted depth | Abort spiral | — |
| 4 | Interface Contracts missing | Run `/swe interface` standalone | Abort spiral | — |
| 4 | Artifacts present | Auto-proceed (unless user pauses) | — | — |
| 5 (probe) | Probe result reviewed | Keep Light result → proceed | Escalate to target depth | — |
| 5 | Dev fails or user aborts | Retry dev | ↩ Return to spec | Abort spiral |
| 6 | Tests not Green | Run `/swe implement` to fix | Proceed to Ship anyway | Abort spiral |
| 6 | Tests Green | Proceed to Ship | — | — |
| 7 (probe) | Probe result reviewed | Keep Light result → proceed | Escalate to target depth | — |
| 7 | Ship fails or user aborts | Retry ship | ↩ Return to dev | Abort spiral |
| 8 | P1 findings exist | ↩ Fix P1 + re-run ship | Abort spiral | Override → proceed to Tune |
| 8 | No P1 findings | Proceed to Tune | — | — |
| 9 (probe) | Probe result reviewed | Keep Light result → proceed | Escalate to target depth | — |
| 9 | Tune fails | Log warning, proceed to Phase 10 | — | — |
| 4.5 (team) | Cross-review P1 finding | ↩ Halt Builder + regress to spec | Continue (late stage) → defer to Tune | — |
| 4.5 (team) | Cross-review P2/P3 | Record in `.team/` → defer to Tune | — | — |
| 6.5 (team) | Cross-review P1 finding | ↩ Halt Critic + regress to dev | Continue (late stage) → defer to Tune | — |
| 6.5 (team) | Cross-review P2/P3 | Record in `.team/` → defer to Tune | — | — |
| any (team) | Specialist failure | Director executes composite directly (single-agent fallback) | — | — |
| any (team) | 2+ specialists fail | Fall back to linear/probe policy for remaining composites | — | — |
| any (team) | Bridge escalation (3 MCP failures) | Reassign stage to Claude specialist | — | — |
| any (team) | MCP server unavailable | Fall back to Claude specialist for affected stages | — | — |

### Regression Protocol (↩ paths)

When the user selects a regression path, execute the checkpoint-rewind protocol:

1. **Circuit breaker check**: `Bash: scripts/spiral-state.sh read --field ".regression_count"`. If `>= max_regressions` (default 3), present: "Circuit breaker: {count}/{max} regressions reached. Must abort or override (allows 1 more regression with confirmation)."

2. **Checkpoint**: `Bash: scripts/spiral-state.sh checkpoint {current_stage}` — saves all current artifacts to `.swe/active/.versions/` with version tracking.

3. **Cascade invalidation**: `Bash: scripts/spiral-state.sh cascade {target_artifact}` — computes which downstream stages are affected. Present the invalidation list to the user:

```markdown
## Regression: {from} → {to}

Reason: {user-provided reason}

**Invalidated** (must re-execute):
- {stage}: Required dependency on {artifact} changed
- ...

**Stale** (may preserve or re-execute — your choice):
- {stage}: Optional dependency on {artifact} changed
- ...

Proceed with regression?
```

4. **Restore**: On user approval, `Bash: scripts/spiral-state.sh restore {checkpoint_id}` — restores artifacts, resets downstream stages to `pending`, increments regression count.

5. **Re-enter**: Jump to the target composite phase (Phase 3 for spec, Phase 5 for dev, Phase 7 for ship).

**Phase 5 Path B** ("Return to spec"): checkpoint → cascade from spec artifacts → restore → re-enter Phase 3.
**Phase 7 Path B** ("Return to dev"): checkpoint → cascade from dev artifacts → restore → re-enter Phase 5.
**Phase 8 Path A** ("Fix P1 + re-run ship"): checkpoint → update ship_composite to pending → re-enter Phase 7. No cascade needed (same composite re-run).

## See Also

- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology, depth system, stage transitions
- **Analyst agent** (`agents/swe/analyst.md`) — executes specification stages (via `/swe spec`)
- **Implementer agent** (`agents/swe/implementer.md`) — executes development stages (via `/swe dev`)
- **Reviewer agent** (`agents/swe/reviewer.md`) — executes ship review stages (via `/swe ship`)
- **Bridge agent** (`agents/swe/bridge.md`) — delegates stages to external models via MCP (team policy + `--route`)
- **Depth System** (`skills/swe/methodology/references/depth-system.md`) — depth decision matrix and composite defaults
- **Pipeline Stages** (`skills/swe/methodology/references/pipeline-stages.md`) — detailed stage descriptions
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — inter-stage artifact dependencies
- **Spiral State** (`skills/swe/methodology/references/spiral-state.md`) — state machine schema, transition rules, checkpoint-rewind protocol
- **Team Execution Pattern** (`skills/swe/methodology/references/team-execution-pattern.md`) — team topology, specialist prompts, pipelined flow, cross-review protocol (team policy only)

## Rules

- The spiral command orchestrates composites — it never directly invokes agents or writes code
- Each composite is invoked via Skill tool, preserving the dogfooding principle — spiral does not duplicate composite logic
- Depth is forwarded to each composite as a global depth — the composite's internal depth planning further distributes across its stages
- Transition checkpoints (Phases 4, 6, 8) verify artifact readiness before proceeding to the next composite
- P1 gate at Ship → Tune transition: P1 findings default to blocking, but user can override to proceed
- Failure at any composite offers three choices: retry, return to prior composite, or abort
- The spiral does not auto-loop — one turn per invocation. The Report phase suggests the next turn's task and depths
- Tune's retrospect output is the spiral's self-improving mechanism: learnings from this turn inform the next turn's spec
- All composite artifacts accumulate in `.swe/active/` during the turn, then archive to `docs/specs/record/` after tune — each composite reads prior artifacts from this directory
- The spiral preserves each composite's user checkpoint (Review phase) — the user reviews each composite's output before proceeding
- Skip depth is not supported at the composite level — each composite must run at least at Light depth. To skip a composite, run the other composites individually instead of using spiral
- State file (`.swe/active/spiral-state.json`) tracks all composite and transition statuses throughout the spiral turn — all state operations go through `scripts/spiral-state.sh`, never direct JSON manipulation
- The state file is archived alongside other artifacts after completion — it provides an audit trail of the spiral's execution path
- Regression is user-initiated only — the spiral presents options but never automatically regresses. Circuit breaker at 3 regressions per turn prevents infinite loops
- Probe policy (default) wraps composites in Light-first exploration — it never modifies composite internal logic
- Probe's confidence check is user-driven — the user decides whether to keep Light results or escalate
- Escalation checkpoints Light artifacts before overwriting (probe version preserved in `.versions/`)
- Escalation is not regression — it does not count toward the circuit breaker limit
- When target depth equals Light, probe wrapper is skipped (no redundant execution)
- Depth and policy are orthogonal — depth controls how deep, policy controls how to traverse
- `--multi` is relayed to Ship and Tune composites — spiral does not perform multi-model operations itself
- Stage-level parallelism (Security Review ‖ Code Review, Improve ‖ Retrospect) is composite-internal, always active at Standard+ depth — not a spiral policy
- Team policy spawns 3 Specialists — Director never executes composites directly (except single-agent fallback)
- Team auto-gates (Phase 4, 6) are non-blocking — no user approval required. Phase 8 remains blocking for all policies
- Cross-review runs in parallel with the next composite — this is the pipelining mechanism that makes team faster than sequential
- Cross-review P1 findings may trigger backtracking via the standard regression protocol — progress-aware severity judgment applies
- Specialists communicate exclusively through SendMessage to Director — no direct inter-specialist messaging
- Specialist failure degrades gracefully to single-agent mode for that composite only — completed artifacts are preserved
- Team workspace (`.swe/active/.team/`) is created at Phase 2.7 and archived alongside standard artifacts
- `--route` requires team policy and stage-level execution — ignored with `--fast`, `--composite-level`, or non-team policies
- Bridge Agent uses sonnet model for cost efficiency — external model provides domain reasoning via MCP
- Bridge failure (MCP unavailable or 3 consecutive failures) falls back to Claude specialist — no stage is lost
- `--route` and `--multi` are independent: `--multi` handles evaluation/review one-shot relay, `--route` handles stage delegation via Bridge Agent
