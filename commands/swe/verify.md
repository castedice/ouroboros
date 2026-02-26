---
description: "Stage 7 — Verify implementation against acceptance criteria and architecture spec (TDD)"
argument-hint: "<task-description> [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
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

Otherwise, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md`:

1. Score 5 factors (Task Scope, Risk Level, Domain Familiarity, Team Impact, Reversibility) based on the task description and codebase signals
2. Sum scores (range 5-15) and map to depth level:

| Score | Depth |
|-------|-------|
| 5-6 | Light |
| 7-10 | Standard |
| 11-15 | Deep |

3. Check stage-specific minimum depth triggers from `depth-system.md`:
   - Deep when rollback > 2 hours or compliance scope exists
4. Check escalation rules (security/compliance, migration size, observed flaky-test rate > 2%)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Verify skip is valid — "Trivial change fully covered by unit tests" per `depth-system.md`. If the task involves cross-component changes, external API contracts, or acceptance criteria beyond unit test scope:

- Log: "Skip not applicable — task requires broader validation. Defaulting to Light."
- Set depth to Light

Otherwise: Log "Stage 7 skipped — trivial change with unit test coverage sufficient." Produce minimal skip artifact noting "No broader validation needed — unit tests provide sufficient coverage" and jump to Phase 6.

## Phase 3: Context Gathering

Read the full artifact chain from `.swe/active/` and survey the implementation:

1. **Upstream artifacts**: Read upstream artifacts from `.swe/active/`:
   - `.swe/active/01-understand.md` — Context Document (source of acceptance criteria / success criteria)
   - `.swe/active/02-constrain.md` — Constraint Profile (performance targets, hard constraints)
   - `.swe/active/03-design.md` — Architecture Spec (structural compliance reference)
   - `.swe/active/04-interface.md` — Interface Contracts (contract compliance reference)
   - `.swe/active/05-test.md` — Test Suite artifact (test baseline)
   - `.swe/active/06-implement.md` — Implementation artifact (implementation summary)
   - If `--artifact` is provided, also read that specific file
2. **Source code survey**: Use Glob and Grep to identify implemented source files related to the task
3. **Test baseline**: Run existing test suites using Bash to confirm Green state baseline. Record pass/fail counts
4. **Integration tests**: Search for integration test files (patterns: `*integration*`, `*e2e*`, `*acceptance*`)

Log: "Context gathered: {n} upstream artifacts, {m} source files, {p} tests ({pass}/{total} passing)."

If no upstream artifacts found: Log "Warning: No upstream artifacts found in `.swe/active/`. Verification will be based on task description and codebase state only. Consider running earlier pipeline stages first."

If test baseline is not Green: Log "Warning: {fail} tests failing before verification. Verification proceeds but results may be unreliable. Consider running `/swe implement` to resolve failures first."

## Phase 3.5: Smoke Test

Run a minimal end-to-end execution of the implementation to confirm it builds and runs correctly.

1. **Build**: Run the project's build command via Bash (e.g., `cargo build`, `npm run build`, `go build ./...`). If build fails: log error and proceed to Phase 4 — agent will note build failure in the verification report
2. **Smoke execution**: Run the implementation's entry point or a representative usage scenario:
   - If a binary: execute with minimal input and check exit code
   - If a library: run the test suite as smoke (already done in Phase 3 step 3 — confirm no panics/crashes beyond assertion failures)
   - If a CLI tool: run `--help` or minimal subcommand
3. **Record**: Log build status (success/failure), execution status (success/crash/timeout), and any unexpected output

Log: "Smoke test: build {pass/fail}, execution {pass/fail/skipped}."

### Smoke Test Skip

Skip smoke test when:
- Depth is Skip (Stage 7 skipped entirely)
- No executable artifact exists (specification-only task, documentation changes)
- Build system not detected (no Cargo.toml, package.json, go.mod, Makefile)

## Phase 4: Analysis

> Agent: **implementer**

Delegate verification to the implementer agent via Task tool:

- **Input**: Full artifact chain content (Context Document, Constraint Profile, Architecture Spec, Interface Contracts, Test Suite, Implementation summary) + source code file paths + test baseline results + depth level
- **Instructions**: "Execute Procedure 3 (Verify) at {depth} depth. Smoke test results: build {status}, execution {status}. Include these in the Smoke Test Results section of the Verification Report. First, scope acceptance criteria to the current implementation unit: compare implemented types/modules against the full system scope from the Context Document. Classify each criterion as IN_SCOPE (directly testable with current implementation), PARTIAL (requires current implementation but also unimplemented components), or OUT_OF_SCOPE (entirely dependent on unimplemented components). Check IN_SCOPE and PARTIAL criteria with evidence of PASS or FAIL. List OUT_OF_SCOPE criteria separately noting which components are needed. Compare the implementation against the Architecture Spec for structural compliance. At Standard+ depth, check cross-type pattern consistency: if multiple types in the same bounded context use different access control strategies (e.g., private fields with accessors vs pub fields), different validation approaches (e.g., Result errors vs clamping), or different normalization patterns (e.g., one type normalizes input, another stores raw input), flag inconsistencies as deviations with impact assessment. Run integration tests if applicable. Document any deviations with rationale and impact assessment. Follow the template at `templates/swe/verification-report.md`. Return the Verification Report content as structured markdown."
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
2. Wrap implementer output in artifact template:

```markdown
# Verification Report: {task summary}

**Stage**: 7 — Verify (TDD)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {list of artifact paths read, or "none"}
**Date**: {date}

---

{implementer output content}

---

**Exit Criteria Check**:
- [ ] Smoke test executed (build + run) or skip documented
- [ ] Acceptance criteria scoped to implementation unit (IN_SCOPE / PARTIAL / OUT_OF_SCOPE)
- [ ] Each IN_SCOPE and PARTIAL criterion checked with evidence
- [ ] {At Standard+} Spec compliance check against Architecture Spec
- [ ] {At Standard+} Cross-type pattern consistency checked (access control, validation, normalization)
- [ ] {At Standard+} Integration test results documented
- [ ] Deviations documented with rationale and impact
- [ ] {At Deep} Performance benchmarks against Constraint Profile targets
- [ ] {At Deep} Security scan results documented
```

3. Write to output path via Write tool

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
```

## Rules

- Implementer agent performs verification analysis — only the command writes the report artifact
- Verification references the full artifact chain — not just the immediate upstream artifact (implementation)
- Acceptance criteria come from the Context Document (Stage 1), not invented during verification
- When verifying a partial implementation (subset of the full system), scope acceptance criteria to the implementation unit — do not mark unrelated criteria as FAIL; classify them as OUT_OF_SCOPE with required components noted
- Spec compliance checks against the Architecture Spec (Stage 3)
- Verification Report is the input contract for Stage 8 (Optimize) — see `skills/swe/methodology/references/artifact-contracts.md`
- Depth decision must be logged with factor scores for traceability
- Output path follows `.swe/active/{NN}-{stage}.md` convention
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- If verdict is FAIL on critical acceptance criteria, recommend backward transition to the appropriate upstream stage rather than proceeding to Optimize
