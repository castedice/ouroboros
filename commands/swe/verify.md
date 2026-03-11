---
description: "Stage 7 — Verify implementation against acceptance criteria and architecture spec (TDD)"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Verify — Broader Validation (Stage 7)

Verify the implementation against acceptance criteria from the Context Document and check compliance with the Architecture Spec.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | implementer | Verification — acceptance criteria check, spec compliance, integration validation |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to any upstream artifact for additional reference | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe verify <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <path>]`"
- Abort

If `--depth` is provided, validate it is one of: Skip, Light, Standard, Deep. If invalid:

- Output: "Error: Invalid depth '{value}'. Must be one of: Skip, Light, Standard, Deep."
- Abort

## Phase 2: Depth Decision

If `--depth` was provided, use that value directly. Log: "Depth override: {depth}."

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` (score 5 factors → sum → map to depth level). Stage-specific triggers:

- Deep when rollback > 2 hours or compliance scope exists
- Escalation: security/compliance, migration size, flaky-test rate > 2%

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Conditional Routing

| Condition | Depth | Action |
|-----------|-------|--------|
| `--fast` + all tests pass + change < 50 lines | Skip | Minimal artifact → Phase 6 |
| `--fast` + above not met | Light | Proceed normally |
| `--depth Skip` + trivial change fully covered by unit tests | Skip | Minimal artifact → Phase 6 |
| `--depth Skip` + cross-component, external API, or acceptance criteria beyond unit scope | Light | Override: "Skip not applicable — task requires broader validation." |
| `--depth` Light/Standard/Deep | As specified | Proceed normally |
| No flags | Scored | Apply depth decision matrix from `depth-system.md` |

For fast mode: check by running test suite and counting changed lines (from Implementation artifact or `git diff --stat`).

For Skip validation: confirm "Trivial change fully covered by unit tests" per `depth-system.md`.

## Phase 3: Context Gathering

Read the full artifact chain from `.swe/active/` and survey the implementation:

1. **Upstream artifacts**: Read upstream artifacts from `.swe/active/`. At Light depth, read optional artifacts as summary only (`Read(file, limit: 15)`) per the Selective Load Matrix in `artifact-contracts.md`. At Standard+ depth, read all in full:
   - `.swe/active/04-interface.md` — Interface Contracts (required — always full)
   - `.swe/active/06-implement.md` — Implementation artifact (required — always full)
   - `.swe/active/01-understand.md` — Context Document (optional — summary at Light)
   - `.swe/active/02-constrain.md` — Constraint Profile (optional — summary at Light)
   - `.swe/active/03-design.md` — Architecture Spec (optional — summary at Light)
   - `.swe/active/05-test.md` — Test Suite artifact (optional — summary at Light)
   - If `--artifact` is provided, also read that specific file
2. **Source code survey**: Use Glob and Grep to identify implemented source files related to the task
3. **Test baseline**: Run existing test suites using Bash to confirm Green state baseline. Record pass/fail counts
4. **Integration tests**: Search for integration test files (patterns: `*integration*`, `*e2e*`, `*acceptance*`)

Log: "Context gathered: {n} upstream artifacts, {m} source files, {p} tests ({pass}/{total} passing)."

If no upstream artifacts found: Log "Warning: No upstream artifacts found in `.swe/active/`. Verification will be based on task description and codebase state only. Consider running earlier pipeline stages first."

If test baseline is not Green: Log "Warning: {fail} tests failing before verification. Verification proceeds but results may be unreliable. Consider running `/swe implement` to resolve failures first."

## Phase 3.5: Smoke Test

Run a minimal end-to-end execution of the implementation to confirm it builds and runs correctly.

1. **Build**: Run the project's build command via Bash. If build fails: log error and proceed to Phase 4 — agent will note build failure in the verification report
2. **Smoke execution**: Run a representative usage scenario (entry point, test suite as smoke, or minimal subcommand) and check for crashes
3. **Record**: Log build status (success/failure), execution status (success/crash/timeout), and any unexpected output

Log: "Smoke test: build {pass/fail}, execution {pass/fail/skipped}."

Skip smoke test when: depth is Skip, no executable artifact exists (docs-only), or no build system detected.

## Phase 4: Analysis

> Agent: **implementer**

Delegate verification to the implementer agent via Task tool:

- **Input**: Artifacts gathered in Phase 3 + source code file paths + test baseline results + smoke test results + depth level
- **Instructions**: Follow the Stage 7 (Verify) instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth. Bind: depth={depth}, build_status={build status from Phase 3.5}, exec_status={execution status from Phase 3.5}.
- **Expected output**: Verification Report content (structured markdown with scoped acceptance criteria checklist, spec compliance check, cross-type consistency check at Standard+, deviation documentation, integration test results)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Check the top 3 acceptance criteria from the Context Document and report PASS/FAIL with evidence for each. Skip spec compliance and integration tests." If retry fails: report error to user |
| Missing upstream artifacts | Log which artifacts are missing. Proceed with available artifacts. Instruct agent: "The following artifacts are unavailable: {list}. Verify only against available artifacts. Note gaps in the report." |
| Incomplete output (missing Acceptance Criteria or Spec Compliance section) | If Acceptance Criteria section missing and Context Document was available: retry with explicit instruction to check each criterion. Otherwise: proceed with partial report and note gaps |

## Phase 5: Output

Write the Verification Report artifact:

1. Determine output path: `.swe/active/07-verify.md`
2. Wrap agent output using the Stage 7 (Verify) artifact wrapper from `skills/swe/methodology/references/artifact-wrappers.md`. Bind: task_summary={task summary}, depth={depth}, task_description={task description}, upstream_path={upstream artifact path}, date={date}.
3. Write to output path (`.swe/active/07-verify.md`) via Write tool

Present artifact to user for review:

```markdown
## Verification Report: {task summary}

**Depth**: {depth}
**Path**: `.swe/active/07-verify.md`

### Acceptance Criteria Summary
| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| AC1 | {criterion from Context Document} | PASS/FAIL | {brief evidence} |
| AC2 | {criterion} | PASS/FAIL | {brief evidence} |

### Spec Compliance
| Component | Expected (from spec) | Actual (in code) | Status |
|-----------|---------------------|-------------------|--------|
| {component} | {architecture spec expectation} | {implementation reality} | Match/Drift |

### Deviations
{count} deviations documented. {summary of most significant if any}

### Overall Verdict
{PASS — all acceptance criteria met and spec compliance confirmed / PARTIAL — {n} criteria failed or {m} spec drifts found / FAIL — critical acceptance criteria not met}

Review the verification report and confirm to proceed, or request revisions.
```

## Phase 6: Report

After user confirms (or on auto-proceed for composite invocation):

```markdown
## Stage 7 Complete: Verify

**Artifact**: `.swe/active/07-verify.md`
**Depth**: {depth}
**Verdict**: {PASS/PARTIAL/FAIL}

### Next Stage
Run Stage 8 (Optimize) for profiling-driven improvements and refactoring:
`/swe optimize "{task}" --depth {recommended_depth}`

### Backward Transition
{If verdict is PARTIAL or FAIL}: Consider returning to the appropriate upstream stage:
- Failed acceptance criteria → `/swe implement "{task}"` (Stage 6) to address gaps
- Spec drift → `/swe design "{task}"` (Stage 3) to reconcile architecture decisions
- Contract violations → `/swe interface "{task}"` (Stage 4) to update contracts

### See Also
- `/swe dev "{task}"` — run all 4 development stages in sequence
- `/swe implement "{task}"` — Stage 6 (return if verification reveals implementation gaps)
- `/swe optimize "{task}"` — Stage 8 (proceed after successful verification)
- **Implementer agent** (`agents/swe/implementer.md`) — executes verification analysis
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Implementer agent performs verification analysis — only the command writes the report artifact
- Acceptance criteria come from the Context Document (Stage 1), not invented during verification
- When verifying a partial implementation (subset of the full system), scope acceptance criteria to the implementation unit — do not mark unrelated criteria as FAIL; classify them as OUT_OF_SCOPE with required components noted
- Spec compliance checks against the Architecture Spec (Stage 3)
- Verification Report is the input contract for Stage 8 (Optimize) — see `skills/swe/methodology/references/artifact-contracts.md`
- Output path follows `.swe/active/{NN}-{stage}.md` convention
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- If verdict is FAIL on critical acceptance criteria, recommend backward transition to the appropriate upstream stage rather than proceeding to Optimize
