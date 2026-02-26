---
description: "Stage 8 — Profile, optimize, and refactor the implementation based on measured data (TDD)"
argument-hint: "<task-description> [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
allowed-tools: Read, Glob, Grep, Write, Edit, Task, Bash
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

If `--depth` was provided, use that value directly. Log: "Depth override: {depth}."

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors (Task Scope, Risk Level, Domain Familiarity, Team Impact, Reversibility) based on the task description and codebase signals
2. Sum scores (range 5-15) and map to depth level:

| Score | Depth |
|-------|-------|
| 5-6 | Light |
| 7-10 | Standard |
| 11-15 | Deep |

3. Check stage-specific minimum depth triggers from `depth-system.md`:
   - Standard when Constraint Profile contains Hard performance constraints
4. Check escalation rules (latency SLA < 100ms or throughput > 1000 RPS escalates Optimize)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Verify — "No performance requirements in Constraint Profile and no code quality concerns" per `depth-system.md`. If Constraint Profile contains any performance-related constraints or code review flagged quality issues:

- Log: "Skip not applicable — performance constraints exist. Defaulting to Light."
- Set depth to Light

Otherwise: produce minimal skip artifact noting "Stage 8 skipped — no performance requirements in Constraint Profile." and jump to Phase 6.

## Phase 3: Context Gathering

Survey upstream artifacts and codebase to build optimization context:

1. **Constraint Profile**: Read `.swe/active/02-constrain.md` for the Constraint Profile. Extract performance constraints (Hard and Soft) with measurable thresholds — these define optimization targets
2. **Architecture Spec**: Read `.swe/active/03-design.md` for the Architecture Spec. Extract algorithm rationale and component structure — these define which optimizations are architecturally sound
3. **Verification Report**: Read `.swe/active/07-verify.md` for the Verification Report. Confirm all acceptance criteria pass — optimization must not begin on unverified code
   - If no Verification Report found: warn "No Verification Report found. Optimizing unverified code risks masking correctness bugs. Consider running `/swe verify` first."
4. **Source code survey**: Use Glob and Grep to identify optimization candidates:
   - Files modified in the current task (from Implementation Report if available)
   - Hot paths identified by Architecture Spec
   - Code with known complexity concerns (nested loops, repeated allocations, synchronous blocking)
5. **Test baseline**: Run the full test suite via Bash to establish Green baseline
   - If tests fail: abort with "Test suite is not Green. Fix failing tests before optimizing. Run `/swe verify` to diagnose."
6. **Profiling tools**: Identify available profiling tools for the project language/framework:
   - Check for profiling dependencies in manifest files (Cargo.toml, package.json, requirements.txt, etc.)
   - Check for existing profiling configuration files
   - Detect language runtime (for built-in profiling: `node --prof`, `python -m cProfile`, `cargo bench`, etc.)

If `--artifact` is provided, read that file as additional context (any upstream artifact type).

Log: "Context gathered: {n} performance constraints, tests {pass}/{total} passing, profiling tools: {tools}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate optimization to the implementer agent via Task tool:

- **Input**: Source code file list + Constraint Profile content (performance constraints section) + Architecture Spec content (algorithm rationale section) + test baseline output + available profiling tools + depth level
- **Instructions**: "Execute Procedure 4 (Optimize) at {depth} depth. Profile implementation to identify actual bottlenecks — do not optimize based on intuition. Prioritize against Constraint Profile performance targets: Hard constraint violations first, then Soft, then general code quality. Apply optimizations one at a time, running the full test suite after each change to keep tests Green. Measure before/after for every optimization. Refactor for clarity after performance work. Follow the template at `templates/swe/optimization-report.md`. Reference artifact contracts from `skills/swe/methodology/references/artifact-contracts.md` Stage 8 for required fields at {depth} depth. Return Optimization Report content as structured markdown."
- **Expected output**: Optimization Report content + modified source code

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Perform code review and suggest top 3 refactoring opportunities. Do not modify code." If retry fails: report error to user |
| Test regression after optimization | Present the regression to user: "Optimization caused test failure in {test names}. Recommend reverting to last Green state." The implementer agent should have already reverted per its procedure, but confirm via test re-run. If tests still fail: abort and recommend `/swe verify` |
| No profiling tools available | Proceed with code-level analysis only. Log: "No profiling tools detected. Performing static code analysis and algorithmic complexity assessment instead." |
| Fundamentally wrong algorithm discovered | Do not attempt to fix at this stage. Report: "Profiling reveals algorithmic bottleneck in {component} — O({current}) where O({needed}) is required by constraint {ID}. Recommend returning to Stage 3 (Design) to select appropriate algorithm. Optimization is for tuning, not redesign." |

## Phase 5: Output

1. Code modifications were applied by the implementer agent during Phase 4
2. Run the full test suite via Bash to confirm Green state after all changes
   - If tests fail: warn user and recommend reverting. Do not write artifact with failing tests
3. Write the Optimization Report to `.swe/active/08-optimize.md`

Wrap implementer output in artifact template:

```markdown
# Optimization Report: {task summary}

**Stage**: 8 — Optimize (TDD)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {verification report path or "none"}
**Date**: {date}

---

{implementer output content}

---

**Exit Criteria Check**:
- [ ] All optimizations have before/after measurements
- [ ] No optimization targets constraints outside the Constraint Profile
- [ ] All tests remain Green after every change
- [ ] {At Standard+} Profiling data identifies actual bottlenecks
- [ ] {At Standard+} Each optimization traces to a constraint
- [ ] {At Deep} Algorithmic complexity analysis for hot paths
- [ ] {At Deep} Alternative benchmark comparisons
```

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
