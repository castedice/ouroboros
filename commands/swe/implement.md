---
description: "Stage 6 — Write minimal code to pass all tests using TDD Green Phase (TDD)"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <test-suite-path>]"
allowed-tools: Read, Glob, Grep, Write, Edit, Task, Bash
---

# Implement — TDD Green Phase (Stage 6)

Write the minimal code to pass all tests, following the Red-Green cycle.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | implementer | Code implementation — minimal code, Red-Green cycle, Result pattern |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to Test Suite artifact (Stage 5 output) | None |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe implement <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <test-suite-path>]`"
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
   - Standard when implementation touches multiple bounded contexts
   - Deep when performance constraints have numeric SLAs from the Constraint Profile
4. Check escalation rules (safety-critical code, concurrency, or public API implementation)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Log "Stage 6 skipped — no implementation changes. Use for spec-only workflows." Produce minimal skip artifact noting "No implementation — spec-only workflow" and jump to Phase 6.

### Depth-Specific Output Expectations

| Depth | Implementation Scope |
|-------|---------------------|
| Light | Minimal single-pass implementation. Happy path only. No docstrings beyond type annotations |
| Standard | Proper error handling using Result pattern. Type safety enforced. Inline documentation (docstrings, type annotations). Meaningful commit-granularity code organization |
| Deep | Production-grade: structured logging, observability hooks, defensive programming. Comprehensive inline documentation. Performance-aware implementation aligned to Constraint Profile SLAs |

## Phase 3: Context Gathering

Collect all upstream artifacts and baseline state:

1. **Test Suite artifact**: If `--artifact` is provided, read the file
   - If file is missing: warn "Test Suite not found at {path}."
   - If `--artifact` is not provided: use `.swe/active/05-test.md` as the Test Suite artifact. If not found:
     - Output: "Error: Test Suite artifact required. Run `/swe test` first or provide `--artifact <path>`."
     - Abort
2. **Interface Contracts**: Read `.swe/active/04-interface.md` in full (required)
   - Extract public interfaces, type definitions, error conditions — these are the contracts the implementation must fulfill
   - If not found: warn "No Interface Contracts found. Implementation will be guided by test assertions only."
3. **Architecture Spec**: Read `.swe/active/03-design.md`. At Light depth, read summary only (`Read(file, limit: 15)`) per the Selective Load Matrix in `artifact-contracts.md`. At Standard+ depth, read in full
   - Extract module placement, naming conventions, data model, selected patterns
   - If not found: warn "No Architecture Spec found. Implementation structure will follow existing codebase conventions."
4. **Constraint Profile**: At Light depth, read summary only from `.swe/active/02-constrain.md`. At Standard+ depth, read in full
   - Extract Hard performance constraints (required for Deep depth implementation)
   - If not found at Deep depth: warn "No Constraint Profile found for Deep implementation. Performance targets unavailable."
5. **Existing source code**: Survey codebase for files related to the task
   - Use Glob and Grep to identify modules, packages, or files that will be modified or extended
   - Read key files (up to 10 most relevant) to understand current patterns and conventions
6. **Build system identification**: Detect project build/test commands
   - Check for: `Cargo.toml` (cargo test), `package.json` (npm test / jest / vitest), `pyproject.toml` / `setup.py` (pytest), `Makefile`, `go.mod` (go test), etc.
   - Identify the specific test runner command
7. **Baseline test execution**: Run the test suite via Bash to confirm current Red state
   - Capture test output: number of failing tests, number of passing tests
   - If all tests already pass: warn "All tests already pass — no implementation needed. Verify this is the correct Test Suite artifact."

Log: "Context gathered: {n} failing tests, {m} passing tests. Build system: {system}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate implementation to the implementer agent via Task tool:

- **Input**: Test Suite content + Interface Contracts content (if available) + Architecture Spec context (module placement, naming, data model) + existing source code patterns + depth level + build system info (test runner command) + current test output (Red state baseline)
- **Instructions**: "Execute Procedure 2 (Implement) at {depth} depth. Make tests pass with minimal code. Maximum 3 Red-Green rounds. Follow Architecture Spec for structure (module placement, naming conventions). Use Result pattern for errors — return errors, do not throw exceptions. Prefer pure functions and immutable data. At Standard+ depth, add docstrings and type annotations. At Deep depth, add structured logging and observability. Return source code with Green state confirmation — paste test runner output after each round."
- **Expected output**: Source code files written to the project + Green state confirmation (test runner output showing all tests pass)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Implement the happy path for the primary interface only. Make the most basic test pass first." If retry fails: report error to user |
| Partial implementation (some tests still failing) | Accept partial result. Log progress: "{n}/{total} tests now passing." Present to user with option to continue: "Run `/swe implement` again to continue the Red-Green cycle." |
| Build errors (compilation/syntax failures) | Present build error output to user. Suggest: "Check Architecture Spec compatibility or adjust test expectations. Common causes: missing dependencies, type mismatches, incorrect module paths." |
| Test regression (previously passing tests now fail) | Log regression details. Instruct agent: "Revert the last change — a previously passing test now fails. Re-approach with a different implementation strategy." If regression persists after retry: report to user |

## Phase 5: Output

Source code has been written by the implementer agent during Phase 4. Now confirm and document:

1. **Green state verification**: Run the full test suite via Bash to independently confirm results
   - This is the command's own verification — do not rely solely on the agent's assertion
   - Capture complete test output
2. **Determine status**:
   - All tests pass → Green state confirmed
   - Some tests pass → Partial implementation (log progress)
   - Build failure → Report error (should have been caught in Phase 4 recovery)
3. Wrap agent output using the Stage 6 (Implement) artifact wrapper from `skills/swe/methodology/references/artifact-wrappers.md`. Bind: task_summary={task summary}, depth={depth}, task_description={task description}, upstream_path={upstream artifact path}, date={date}.
4. Write to output path (`.swe/active/06-implement.md`) via Write tool

Present to user:

```markdown
## Implementation: {task summary}

**Depth**: {depth}
**Tests**: {pass}/{total} passing
**Green State**: {Confirmed | Partial}
**Path**: `.swe/active/06-implement.md`

### Implementation Summary
{brief description of key implementation decisions}

### Green State Output
{test runner output showing all tests pass — or partial results with failing test names}

### Files Modified
| File | Action | Description |
|------|--------|-------------|
| {path} | Created/Modified | {what was done} |

Review the implementation and confirm to proceed, or request revisions.
```

## Phase 6: Report

After user confirms (or on auto-proceed for composite invocation):

```markdown
## Stage 6 Complete: Implement

**Artifact**: `.swe/active/06-implement.md`
**Depth**: {depth}
**Tests**: {pass}/{total} passing

### Next Stage
Run Stage 7 (Verify) to validate against acceptance criteria and spec compliance:
`/swe verify "{task}" --depth {recommended_depth} --artifact .swe/active/06-implement.md`

### See Also
- `/swe dev "{task}"` — run all 4 development stages in sequence
- `/swe optimize "{task}"` — Stage 8 (after Verify)
- `/swe test "{task}"` — revisit Stage 5 if implementation reveals test gaps
- **Implementer agent** (`agents/swe/implementer.md`) — executes TDD Green Phase
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Implementer agent writes code — the command orchestrates, confirms test results, and writes artifacts
- Code modifications happen during Phase 4 (agent execution), not in the command itself — the command's role is orchestration and verification
- Green state must be confirmed via actual test execution (Bash) in Phase 5 — do not rely solely on the agent's assertion
- If not all tests pass, the command still succeeds with partial result — allows iterative implementation via repeated `/swe implement` invocations
- Maximum 3 Red-Green rounds per invocation to keep context manageable — the agent stops and reports progress if more rounds are needed
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- Backward transition: if implementation reveals Interface Contract gaps, recommend returning to Stage 4 (Interface) — document the gap as a Contract Delta Note in the artifact
- Implementation artifact is the input contract for Stage 7 (Verify) — see `skills/swe/methodology/references/artifact-contracts.md`
- Output path follows `.swe/active/{NN}-{stage}.md` convention
- Depth decision must be logged with factor scores for traceability
