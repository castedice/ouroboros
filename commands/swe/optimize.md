---
name: swe:optimize
description: "Use when working code exists and you need to improve performance or simplify it based on measured evidence"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Optimize — Profiling & Refactoring (Stage 8)

Profile the implementation, apply measured optimizations, and refactor for clarity. Only after verification confirms correctness.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | implementer | Optimization — profiling, constraint-driven tuning, refactoring |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to upstream artifact | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe optimize <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <path>]`"
- Abort

If `--depth` is provided, validate it is one of: Skip, Light, Standard, Deep. If invalid:

- Output: "Error: Invalid depth '{value}'. Must be one of: Skip, Light, Standard, Deep."
- Abort

## Phase 2: Depth Decision

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| `--depth` is provided | 2 | Use the explicit depth and skip automatic scoring. |
| `--fast` is active and neither the task nor the Constraint Profile names a performance concern | 2, 5, 6 | Take the skip path, write the minimal optimization artifact, and jump to Phase 6. |
| `--fast` is active but a performance or simplification concern exists | 2 | Force Light depth and continue with normal optimization. |
| Explicit `Skip` depth is requested and there are no performance constraints or quality issues | 2, 5, 6 | Take the skip path and write the minimal optimization artifact. |
| Explicit `Skip` depth is requested but performance constraints or quality issues exist | 2 | Override Skip to Light and continue with normal optimization. |
| Neither `--depth` nor `--fast` is provided | 2 | Score the task via `skills/swe/methodology/references/depth-system.md` and apply stage-specific triggers. |
| Required upstream artifacts exist | 3 | Load Constraint Profile, Architecture Spec, and Verification Report to build the optimization packet. |
| Verification Report is missing | 3 | Warn and continue, but note that optimization is proceeding on unverified code. |
| Full test baseline is not Green | 3 | Abort Stage 8 before any optimization work begins. |
| Profiling tools are available | 3, 4 | Use them to collect measured before/after data. |
| No profiling tools are available | 3, 4 | Fall back to static analysis and algorithmic complexity assessment. |
| Implementer times out or errors | 4 | Retry once with the analysis-only fallback prompt, then stop and report the failure. |
| Optimization introduces test regressions | 4, 5 | Require reversion to the last Green state, and abort if Green cannot be restored. |
| Profiling reveals a fundamentally wrong algorithm | 4, 6 | Stop tuning work, report the design-level bottleneck, and recommend returning to `/swe design`. |
| Invoked by `/swe dev` | 5, 6 | Skip the Phase 5 review checkpoint and continue directly to the Phase 6 report. |

### Depth Scoring

If no `--depth` override, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` (score 5 factors → sum → map to depth level). Stage-specific triggers:

- Standard when Constraint Profile contains Hard performance constraints
- Escalation: latency SLA < 100ms or throughput > 1000 RPS

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

## Phase 3: Context Gathering

Survey upstream artifacts and codebase to build optimization context:

1. **Constraint Profile**: Read `.swe/active/02-constrain.md` in full (required). Extract performance constraints (Hard and Soft) with measurable thresholds — these define optimization targets
2. **Architecture Spec**: Read `.swe/active/03-design.md` in full (required). Extract algorithm rationale and component structure — these define which optimizations are architecturally sound
3. **Verification Report**: Read `.swe/active/07-verify.md` in full (required). Confirm all acceptance criteria pass — optimization must not begin on unverified code
   - If no Verification Report found: warn "No Verification Report found. Optimizing unverified code risks masking correctness bugs. Consider running `/swe verify` first."
4. **Source code survey**: Use Glob and Grep to identify optimization candidates:
   - Files modified in the current task (from Implementation Report if available)
   - Hot paths identified by Architecture Spec
   - Code with known complexity concerns (nested loops, repeated allocations, synchronous blocking)
5. **Test baseline**: Run the full test suite via Bash to establish Green baseline. If tests fail: abort with "Test suite is not Green. Fix failing tests before optimizing. Run `/swe verify` to diagnose."
6. **Profiling tools**: Detect available profiling tools by checking manifest files and language runtime capabilities

If `--artifact` is provided, read that file as additional context (any upstream artifact type).

Log: "Context gathered: {n} performance constraints, tests {pass}/{total} passing, profiling tools: {tools}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate optimization to the implementer agent via Task tool:

- **Input**: Source code file list + Constraint Profile content (performance constraints section) + Architecture Spec content (algorithm rationale section) + test baseline output + available profiling tools + depth level
- **Instructions**: Follow the Stage 8 (Optimize) instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth. Bind: depth={depth}.
- **Expected output**: Optimization Report content + modified source code

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Perform code review and suggest top 3 refactoring opportunities. Do not modify code." If retry fails: report error to user |
| Test regression after optimization | Present regression to user with failing test names. Confirm agent reverted per its procedure via test re-run. If still failing: abort and recommend `/swe verify` |
| No profiling tools available | Proceed with code-level analysis only. Log: "No profiling tools detected. Performing static code analysis and algorithmic complexity assessment instead." |
| Fundamentally wrong algorithm discovered | Do not attempt to fix at this stage. Report: "Profiling reveals algorithmic bottleneck in {component} — O({current}) where O({needed}) is required by constraint {ID}. Recommend returning to Stage 3 (Design) to select appropriate algorithm. Optimization is for tuning, not redesign." |

## Phase 5: Output

1. Code modifications were applied by the implementer agent during Phase 4
2. Run the full test suite via Bash to confirm Green state (see Rules: tests must remain Green). If tests fail: warn user and recommend reverting. Do not write artifact with failing tests
3. Write the Optimization Report to `.swe/active/08-optimize.md`

Wrap agent output using the Stage 8 (Optimize) artifact wrapper from `skills/swe/methodology/references/artifact-wrappers.md`. Bind: task_summary={task summary}, depth={depth}, task_description={task description}, upstream_path={upstream artifact path}, date={date}.

Present artifact to user for review:

```markdown
## Optimization Report: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/08-optimize.md`

### Performance Summary
| Metric | Before | After | Improvement | Driving Constraint |
|--------|--------|-------|-------------|-------------------|
| {metric} | {value} | {value} | {%} | {constraint ID} |

### Refactoring Summary
{n} refactoring changes applied

### Technical Debt
{n} items deferred (documented in report)

### Test Status
All {n} tests passing (Green confirmed)

Review the optimization report and confirm, or request revisions.
```

## Phase 6: Report

After user confirms (or on auto-proceed for composite invocation):

```markdown
## Stage 8 Complete: Optimize

**Artifact**: `.swe/active/08-optimize.md`
**Depth**: {depth}

### Development Pipeline Complete
All 4 development stages (Test → Implement → Verify → Optimize) are complete.

### Artifacts Produced
| # | Stage | Artifact |
|---|-------|----------|
| 5 | Test | `.swe/active/05-test.md` |
| 6 | Implement | `.swe/active/06-implement.md` |
| 7 | Verify | `.swe/active/07-verify.md` |
| 8 | Optimize | `.swe/active/08-optimize.md` |

### See Also
- `/swe dev "{task}"` — run all 4 development stages in sequence
- `/swe verify "{task}"` — return to Stage 7 if optimization introduced concerns
- `/swe design "{task}"` — return to Stage 3 if profiling revealed algorithmic redesign needs
- **Implementer agent** (`agents/swe/implementer.md`) — executes optimization
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Implementer agent performs optimization — the command orchestrates, confirms tests, and writes the artifact
- Optimization must be measured — no "this should be faster" without before/after data
- Tests must remain Green after every optimization — this is the TDD Refactor guarantee
- If profiling reveals a fundamentally wrong algorithm, recommend return to Stage 3 (Design) — optimization is for tuning, not redesign
- Optimization against constraints not in the Constraint Profile is not permitted (no gold-plating)
- Output path follows `.swe/active/{NN}-{stage}.md` convention
- Optimization Report is consumed by tune retrospect for performance data and tech debt backlog — see `skills/swe/methodology/references/artifact-contracts.md`
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- Backward transition: if optimization reveals that Stage 7 missed a correctness issue, recommend returning to `/swe verify` before continuing
