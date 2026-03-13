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

When `--policy probe` and the composite's target depth is not Light, each composite phase wraps the Composite Execution Pattern in a probe-then-decide sequence:

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

### Team Composite Delegation Pattern

When `--policy team` or `team+probe`, each composite phase delegates to the assigned specialist:

1. Director assigns composite to Specialist via SendMessage
2. State: `spiral-state.sh team-update {specialist} active --task "{Composite} composite"`
3. Specialist executes composite and sends Review content to Director
4. State: `spiral-state.sh update {stage_key} completed`, `spiral-state.sh team-update {specialist} idle`

When `team+probe`: Specialist executes at Light depth first. Director presents probe result to user with escalation option. Cross-review findings (if available) included in escalation context. See `references/team-execution-pattern.md` § Probe Composition Protocol.

### Transition Checkpoint Pattern

Each transition phase (4, 6, 8) follows the same verification sequence:

1. **State update**: `Bash: scripts/spiral-state.sh update {gate_key} running`
2. **Verify** prerequisite artifacts exist in `.swe/active/` using Glob
3. **Gate** on critical conditions — missing artifacts or failed state checks trigger options from the Decision Matrix
4. **State update**: `Bash: scripts/spiral-state.sh update {gate_key} completed`
5. **Present** transition summary listing produced artifacts and current state
6. **Proceed** automatically unless user requests a pause

The transition phases below specify only the critical gate condition and their unique checkpoint template.

### Team Auto-Gate Pattern

When `--policy team`, transition gates (Phase 4, 6) are auto-gates — no user approval:

1. Verify prerequisite artifact exists
2. State: `spiral-state.sh update {gate_key} completed`
3. Simultaneously (3 parallel actions):
   - Assign next composite to next Specialist via SendMessage
   - Assign cross-review of current composite to reviewing Specialist
   - Relay current Specialist's Review content to user
4. State updates for both new assignments

### Cross-Review Resolution Pattern

When `--policy team`, cross-review phases (4.5, 6.5) follow the same resolution sequence:

1. **State**: `spiral-state.sh cross-review {reviewer} {composite} completed`
2. **Save**: Write findings to `.swe/active/.team/{reviewer}-{composite}-review.md`
3. **Evaluate severity**:
   - **P1 findings**: Follow the Backtracking Decision Tree from `references/team-execution-pattern.md` — consider next composite's progress before deciding halt vs continue
   - **P2/P3 findings**: Record in `.team/`, defer to Tune
4. **If backtracking**: Use the Regression Protocol from the Decision Matrix. Send halt to active Specialist if needed

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--deep` | Shortcut for `--depth Deep` | Off |
| `--depth` | Depth specification (escalation target when probe policy is active) | Standard (global) |
| `--policy` | Transition policy preset (see `references/spiral-state.md`) | `linear` |
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

`--policy` accepts a policy name. Currently available: `linear` (default), `probe`, `team`, `team+probe`. Unknown policies produce an error with available options. The policy controls traversal behavior (how composites are executed), independent of depth (how deep they go). Stage-level parallelism (Security Review ‖ Code Review, Improve ‖ Retrospect) is composite-internal — see `commands/swe/ship.md` and `commands/swe/tune.md`.

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
4. If none of `--fast`, `--deep`, or `--depth`, prompt the user for depth selection:
   - **Step 1**: Ask "모든 composite를 Standard depth로 진행할까요? (Y/n)". If user confirms (Y or Enter): apply Standard to all composites
   - **Step 2** (user selects n): Present per-composite depth selection: "각 composite의 depth를 지정해 주세요:" with a table showing Spec, Dev, Ship, Tune — each selectable as Light/Standard/Deep. Apply user's selections
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

1. **CLI check**: Verify Codex CLI is available (`which codex` — Bridge Agent will check on startup)
2. **Spawn Bridge**: `Agent(name: "bridge", subagent_type: "general-purpose", team_name: "{team_name}", model: "sonnet")` with Bridge system prompt from `agents/swe/bridge.md`
3. **Wait for readiness**: Bridge confirms via SendMessage
4. **State**: `spiral-state.sh team-update bridge idle`
5. **Log**: "Bridge Agent spawned for external model routing: {models in routing table}."

If no external models in `--route` (all stages → claude): skip Bridge spawn. See `references/team-execution-pattern.md` § Selective Routing Protocol for routing logic and exec fallback.

## Phase 3: Spec

```text
Skill: swe:spec
Args: "{task}" --depth {spec_depth}
```

Runs Stages 1-4 (Understand → Constrain → Design → Interface). When probe policy is active and spec_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When team**: Follows Team Composite Delegation Pattern — Shaper executes Spec, Builder starts codebase pre-analysis (background → `.swe/active/.team/builder-prep.md`).

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

**When team**: Follows Team Auto-Gate Pattern — Builder receives Dev, Critic receives Spec cross-review.

## Phase 4.5: Spec Cross-Review Resolution (team policy only)

Critic reviews Spec artifacts (`.swe/active/01-understand.md` through `04-interface.md`) and sends findings to Director. Runs in parallel with Builder's Dev execution. Follows Cross-Review Resolution Pattern.

## Phase 5: Dev

```text
Skill: swe:dev
Args: "{task}" --depth {dev_depth} --artifact {interface_contracts_path}
```

Runs Stages 5-8 (Test → Implement → Verify → Optimize). When probe policy is active and dev_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When team**: Builder is already executing Dev (started in Phase 4 auto-gate). Director monitors for Builder completion and Critic cross-review. Follows Team Composite Delegation Pattern.

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

**When team**: Follows Team Auto-Gate Pattern — Critic receives Ship, Shaper receives Dev cross-review.

## Phase 6.5: Dev Cross-Review Resolution (team policy only)

Shaper reviews Dev artifacts (implementation, verification) and sends findings to Director. Runs in parallel with Critic's Ship execution. Follows Cross-Review Resolution Pattern.

## Phase 7: Ship

```text
Skill: swe:ship
Args: "{task}" --depth {ship_depth} [--multi] --artifact {latest_dev_artifact_path}
```

Pass `--multi` when multi_model is active. Runs Integration Test → Security Review ‖ Code Review → Deploy Readiness. When probe policy is active and ship_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: see Decision Matrix.

**When team**: Critic is already executing Ship (started in Phase 6 auto-gate). Follows Team Composite Delegation Pattern.

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

```text
Skill: swe:tune
Args: "{task}" --depth {tune_depth} [--multi] --artifact {ship_report_path}
```

Pass `--multi` when multi_model is active. Runs Evaluate → Improve ‖ Retrospect. When probe policy is active and tune_depth > Light: follows the Probe Execution Pattern. Otherwise: follows the Composite Execution Pattern. On failure: log warning and proceed to Phase 10 with partial results — all prior artifacts remain valid.

**When team**: Follows Tune Collaboration protocol from `references/team-execution-pattern.md`.

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

```bash
/swe spiral "{computed task}" --depth {computed depths}
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
2. Read Summary sections from archived artifacts, merge into corresponding project model files (`domain.md`, `constraints.md`, `architecture.md`, `interfaces.md`). Merge is additive (append/update, never remove). Add a Change Log entry and update the `Last updated` header for each modified file.
3. Skip any stage artifact that doesn't exist in the archive (Light depth may skip some stages)

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
| any (team) | Bridge escalation (3 exec failures) | Reassign stage to Claude specialist | — | — |
| any (team) | Codex CLI unavailable | Fall back to Claude specialist for affected stages | — | — |

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
- **Bridge agent** (`agents/swe/bridge.md`) — delegates stages to external models via exec (team policy + `--route`)

## Rules

- Spiral orchestrates composites only — never directly invoke agents or write code
- Each composite is invoked via Skill tool (dogfooding) — spiral does not duplicate composite logic
- One turn per invocation — no auto-loop. Report phase suggests next turn's task and depths
- Skip depth is not supported at composite level — to skip a composite, run others individually
- Depth and policy are orthogonal — depth controls how deep, policy controls how to traverse
- Regression is user-initiated only — circuit breaker at 3 regressions per turn
- Escalation is not regression — does not count toward the circuit breaker limit
- `--multi` is relayed to Ship and Tune composites — spiral does not perform multi-model operations itself
- `--route` requires team policy and stage-level execution — ignored with `--fast`, `--composite-level`, or non-team policies
- `--route` and `--multi` are independent: `--multi` handles evaluation/review relay, `--route` handles stage delegation via Bridge Agent
- Specialist failure degrades to single-agent mode for that composite — completed artifacts are preserved
- Bridge failure (Codex CLI unavailable or 3 consecutive failures) falls back to Claude specialist — no stage is lost
