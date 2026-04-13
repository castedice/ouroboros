---
name: swe:verify
description: "Use when implementation is complete and you need to check it against tests, acceptance criteria, and the spec"
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

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| `--depth` is provided | 2 | Use the explicit depth and skip automatic scoring. |
| `--fast` is active and all tests pass with a change smaller than 50 lines | 2, 5, 6 | Take the skip path, write the minimal verification artifact, and jump to Phase 6. |
| `--fast` is active but the fast-path checks fail | 2 | Force Light depth and continue with normal verification. |
| Explicit `Skip` depth is requested and the change is trivial and fully covered by unit tests | 2, 5, 6 | Take the skip path and write the minimal verification artifact. |
| Explicit `Skip` depth is requested but cross-component scope, external APIs, or broader acceptance criteria are in play | 2 | Override Skip to Light and continue with normal verification. |
| Neither `--depth` nor `--fast` is provided | 2 | Score the task via `skills/swe/methodology/references/depth-system.md` and apply stage-specific triggers. |
| Required upstream artifacts exist | 3 | Load them at the depth-appropriate fidelity and build the verification packet. |
| Some upstream artifacts are missing | 3, 4 | Continue with available artifacts, note the gaps, and instruct the agent to verify only against what exists. |
| No upstream artifacts are available | 3, 4 | Continue from task description and codebase state only with an explicit warning. |
| Test baseline is not Green | 3, 3.5, 4 | Warn that results may be unreliable, still run verification, and carry the warning into the report. |
| Smoke test is inapplicable because depth is Skip, the task is docs-only, or no build system exists | 3.5 | Skip the smoke test and record the reason. |
| Build fails during smoke test | 3.5, 4 | Record the failure and continue so the agent can account for it in the report. |
| Implementer times out or errors | 4 | Retry once with the simplified acceptance-criteria-only fallback prompt, then stop and report the failure. |
| Acceptance Criteria or Spec Compliance section is still missing after retry | 4, 5, 6 | Accept the partial report, mark the gaps explicitly, and continue. |
| Verification verdict is PASS | 5, 6 | Write the normal verification artifact and recommend `/swe optimize`. |
| Verification verdict is PARTIAL or FAIL | 5, 6 | Write the artifact with backward-transition guidance to Implement, Design, or Interface as applicable. |
| Invoked by `/swe dev` | 5, 6 | Skip the Phase 5 review checkpoint and continue directly to the Phase 6 report. |

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

## Output Contracts

| Mode | Trigger | Payload location | Required sections or fields |
|------|---------|------------------|-----------------------------|
| PASS | All scoped acceptance criteria pass and no critical spec drift exists | `.swe/active/07-verify.md` via the Stage 7 wrapper at `skills/swe/methodology/references/artifact-wrappers.md` | `# Verification Report: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, `Smoke Test Results`, `Acceptance Criteria Summary`, `Spec Compliance`, `Deviations`, `Overall Verdict`, and `**Exit Criteria Check**`. |
| PARTIAL | Some scoped criteria fail, some criteria are `OUT_OF_SCOPE`, or limited spec drift remains without a blocking failure | `.swe/active/07-verify.md` via the same Stage 7 wrapper | All PASS fields plus scoped `IN_SCOPE` / `PARTIAL` / `OUT_OF_SCOPE` markers, remaining gaps, explicit verdict `PARTIAL`, and backward-transition guidance. |
| FAIL | Critical acceptance criteria fail, blocking spec drift remains, or build or smoke failures invalidate confidence | `.swe/active/07-verify.md` via the same Stage 7 wrapper | All PASS fields plus blocking criteria with evidence, blocking deviations or smoke-test failures, explicit verdict `FAIL`, and required recovery command. |
| Skip | Fast-mode skip or validated Skip depth | `.swe/active/07-verify.md` | `# Verification Report: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, `## Summary`, `## Skip Reason`, `## Existing Validation Evidence`, and `## Next Stage Guidance`. |
| Error | Parse failure or unrecoverable verification failure | User-facing error only | `Error`, `Failed Phase`, `Blocking Condition`, `Artifact Write: none`, and `Next Command`. |
| Composite handoff | Invoked by `/swe dev` | Same artifact as PASS, PARTIAL, FAIL, or Skip plus the Phase 6 report | Artifact path, resolved depth, verdict, recommended next stage, and `See Also`. |

Phase 5 writes `.swe/active/07-verify.md` only for PASS, PARTIAL, FAIL, or Skip mode.

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
