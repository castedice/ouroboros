---
description: "Spiral meta-composite — orchestrate the full engineering cycle: spec → dev → ship → tune, with each turn's learnings feeding the next"
argument-hint: "<task-description> [--depth <global|per-composite>]"
allowed-tools: Read, Glob, Grep, Write, Skill, Bash
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
| Artifact Contracts | `skills/swe/methodology/references/artifact-contracts.md` | Artifact naming convention `.swe/active/{NN}-{stage}.md` (working) and `.swe/record/{package}/{NNN}-{slug}/{NN}-{stage}.md` (archived), required fields, inter-stage dependencies |
| Pipeline Stages | `skills/swe/methodology/references/pipeline-stages.md` | Stage definitions, composite boundaries, ordering constraints |

## Composite Execution Pattern

Each composite phase (3, 5, 7, 9) follows the same invocation sequence:

1. **Invoke** via Skill tool: `Skill: swe:{composite}` with `Args: "{task}" --depth {depth} [--artifact {path}]`
2. **Wait** for composite completion — each composite runs its internal stages, presents its Review phase to the user, and produces artifacts in `.swe/active/`
3. **Log**: "{Composite} composite complete."
4. **On failure**: present options from the Decision Matrix and wait for user decision

The composite phases below specify only the Skill call and stage-specific parameters. Shared invocation mechanics are defined here.

### Transition Checkpoint Pattern

Each transition phase (4, 6, 8) follows the same verification sequence:

1. **Verify** prerequisite artifacts exist in `.swe/active/` using Glob
2. **Gate** on critical conditions — missing artifacts or failed state checks trigger options from the Decision Matrix
3. **Present** transition summary listing produced artifacts and current state
4. **Proceed** automatically unless user requests a pause

The transition phases below specify only the critical gate condition and their unique checkpoint template.

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Depth specification | Standard (global) |

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 composites at Deep depth |
| Per-composite | `--depth S:Deep D:Std H:Light N:Light` | Individual composite depths (S=Spec, D=Dev, H=sHip, N=tuNe) |

Parsing rules:

- If single word (Light/Standard/Deep): apply to all 4 composites
- If colon-separated pairs: parse each. Missing composites default to Standard
- Abbreviations: S=Spec, D=Dev, H=Ship, N=Tune
- If any abbreviation is invalid: error and abort
- If any depth value is invalid: error and abort

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe spiral <task-description> [--depth <global|S:level D:level H:level N:level>]`"
- Abort

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If no `--depth`, apply Standard to all composites per `skills/swe/methodology/references/depth-system.md` (each composite's internal depth planning will further distribute across its stages)
3. Build Depth Plan:

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

## Phase 3: Spec

```
Skill: swe:spec
Args: "{task}" --depth {spec_depth}
```

Runs Stages 1-4 (Understand → Constrain → Design → Interface). Invocation follows the Composite Execution Pattern above. On failure: see Decision Matrix.

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

## Phase 5: Dev

```
Skill: swe:dev
Args: "{task}" --depth {dev_depth} --artifact {interface_contracts_path}
```

Runs Stages 5-8 (Test → Implement → Verify → Optimize). Invocation follows the Composite Execution Pattern above. On failure: see Decision Matrix.

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

## Phase 7: Ship

```
Skill: swe:ship
Args: "{task}" --depth {ship_depth} --artifact {latest_dev_artifact_path}
```

Runs Integration Test → Security Review → Code Review → Deploy Readiness. Invocation follows the Composite Execution Pattern above. On failure: see Decision Matrix.

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
Args: "{task}" --depth {tune_depth} --artifact {ship_report_path}
```

Runs Evaluate → Improve → Retrospect. Invocation follows the Composite Execution Pattern above. On failure: log warning and proceed to Phase 10 with partial results — all prior artifacts remain valid.

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

{From tune retrospect: suggested next task and focus areas}

To start the next turn:
`/swe spiral "{suggested next task}" --depth {recommended depths}`
```

### Next Turn Derivation

Derive next-turn parameters from cycle results before presenting the report. Apply the first matching row:

| Cycle Outcome | Recommended Depth | Focus |
|---------------|-------------------|-------|
| Ship had P1 overrides (Phase 8 Path C) | S:Standard D:Deep H:Deep N:Standard | Security hardening — address overridden P1 findings |
| Dev required 2+ retries or backward transitions | S:Deep D:Deep H:Standard N:Standard | Spec refinement — Interface Contracts or Architecture may need revision |
| Spec completed at Light depth | S:Standard D:Standard H:Light N:Light | Deepen specification — constraints and contracts may be underspecified |
| All composites completed clean first pass | S:Light D:Light H:Light N:Deep | Comprehensive retrospect — maximize learning extraction |
| Tune identified architectural debt | S:Deep D:Standard H:Standard N:Standard | Architecture revision — revisit Design stage decisions |

When tune retrospect provides specific recommendations, merge them with the derivation table above: tune's suggestions take precedence for `{suggested next task}`, the derivation table provides default `{recommended depths}` when tune does not specify depth.

## Phase 10.5: Archive Verification

After tune completes, verify that artifacts were archived:

1. Check `.swe/active/` — if empty, tune already archived (normal case)
2. If `.swe/active/` still has files: run `scripts/artifact-lifecycle.sh archive "{slug}"` as fallback
3. Update Phase 10 Report's artifact table with final record/ paths

## Decision Matrix

Consolidated branch conditions across all phases:

| Phase | Condition | Path A | Path B | Path C |
|-------|-----------|--------|--------|--------|
| 1 | Task empty | Abort with usage error | — | — |
| 1 | Invalid depth abbreviation or value | Abort with error | — | — |
| 2 | `--depth` provided | Use parsed values | — | — |
| 2 | No `--depth` | Standard for all composites | — | — |
| 3 | Spec fails or user aborts | Retry with adjusted depth | Abort spiral | — |
| 4 | Interface Contracts missing | Run `/swe interface` standalone | Abort spiral | — |
| 4 | Artifacts present | Auto-proceed (unless user pauses) | — | — |
| 5 | Dev fails or user aborts | Retry dev | Return to spec | Abort spiral |
| 6 | Tests not Green | Run `/swe implement` to fix | Proceed to Ship anyway | Abort spiral |
| 6 | Tests Green | Proceed to Ship | — | — |
| 7 | Ship fails or user aborts | Retry ship | Return to dev | Abort spiral |
| 8 | P1 findings exist | Fix P1 + re-run ship (re-enter Phase 7) | Abort spiral | Override → proceed to Tune |
| 8 | No P1 findings | Proceed to Tune | — | — |
| 9 | Tune fails | Log warning, proceed to Phase 10 | — | — |

## Rules

- The spiral command orchestrates composites — it never directly invokes agents or writes code
- Each composite is invoked via Skill tool, preserving the dogfooding principle — spiral does not duplicate composite logic
- Depth is forwarded to each composite as a global depth — the composite's internal depth planning further distributes across its stages
- Transition checkpoints (Phases 4, 6, 8) verify artifact readiness before proceeding to the next composite
- P1 gate at Ship → Tune transition: P1 findings default to blocking, but user can override to proceed
- Failure at any composite offers three choices: retry, return to prior composite, or abort
- The spiral does not auto-loop — one turn per invocation. The Report phase suggests the next turn's task and depths
- Tune's retrospect output is the spiral's self-improving mechanism: learnings from this turn inform the next turn's spec
- All composite artifacts accumulate in `.swe/active/` during the turn, then archive to `.swe/record/` after tune — each composite reads prior artifacts from this directory
- The spiral preserves each composite's user checkpoint (Review phase) — the user reviews each composite's output before proceeding
- Skip depth is not supported at the composite level — each composite must run at least at Light depth. To skip a composite, run the other composites individually instead of using spiral
