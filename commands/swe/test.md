---
description: "Stage 5 — Write tests against interface contracts using TDD Red Phase (TDD)"
argument-hint: "<task-description> [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Test — TDD Red Phase (Stage 5)

Write tests against interface contracts to define expected behavior before implementation.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | implementer | Test generation — interface contract translation, AAA pattern, Red state validation |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Explicit depth override | None (decided in Phase 2) |
| `--artifact` | Path to Interface Contracts (Stage 4 output) | None (auto-discovered) |

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe test <task-description> [--depth Skip|Light|Standard|Deep] [--artifact <interface-contracts-path>]`"
- Abort

If `--depth` is provided, validate it is one of: Skip, Light, Standard, Deep. If invalid:

- Output: "Error: Invalid depth '{value}'. Must be one of: Skip, Light, Standard, Deep."
- Abort

### Artifact Resolution

If `--artifact` is provided, use that path directly.

If `--artifact` is not provided: use `.swe/active/04-interface.md` as the Interface Contracts artifact.

If no Interface Contracts artifact found:

- Output: "Error: Interface Contracts artifact required. Run `/swe interface` first or provide `--artifact <path>`."
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
   - Standard when customer-visible behavior changes
   - Deep when interface has 10+ public methods or complex error hierarchies
4. Check escalation rules (migration >= 1M rows or flaky-test rate > 2% escalates Test)

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

### Skip Handling

If depth is **Skip**: Verify — "Configuration-only changes, documentation-only" per `depth-system.md`. If the task involves new behavior, changed interfaces, or new error conditions:

- Log: "Skip not applicable — task changes behavior. Defaulting to Light."
- Set depth to Light

Otherwise: produce a minimal skip artifact noting "Stage 5 skipped — no new tests generated. Interface contracts unchanged." and jump to Phase 6.

## Phase 3: Context Gathering

1. **Interface Contracts**: Read the artifact from `--artifact` or auto-discovered path
   - Extract public interfaces, type definitions, error conditions, invariants, usage examples
   - If artifact is unreadable or empty: abort with "Error: Interface Contracts artifact at {path} is empty or malformed."
2. **Upstream artifacts**: Search `.swe/active/` for related artifacts:
   - Context Document (`.swe/active/01-understand.md`): extract success criteria for test scenario derivation
   - Constraint Profile (`.swe/active/02-constrain.md`): extract performance requirements for threshold-based tests
   - Architecture Spec (`.swe/active/03-design.md`): extract component structure for test organization
3. **Existing test files**: Survey the codebase for existing test patterns:
   - Glob for `**/test*`, `**/*_test*`, `**/tests/**`, `**/*spec*`, `**/__tests__/**`
   - Identify test framework and conventions from existing tests
4. **Test framework detection**: Identify the project's test framework:
   - Rust: check `Cargo.toml` for `[dev-dependencies]` (default: built-in `#[test]`)
   - Python: check `pyproject.toml` or `setup.cfg` for pytest/unittest configuration
   - TypeScript/JS: check `package.json` for jest/vitest/mocha in devDependencies
   - Go: built-in `testing` package
   - If undetectable: ask the user

Log: "Context gathered: {n} interface contracts, {m} existing test files, framework: {framework}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate test generation to the implementer agent via Task tool:

- **Input**: Interface Contracts content + upstream artifact context (success criteria, performance requirements, component structure) + existing test patterns (framework, naming convention, directory layout) + depth level
- **Instructions**: "Execute Procedure 1 (Test) at {depth} depth. Write tests using AAA pattern. Name tests descriptively: `test_<behavior>_when_<condition>_should_<expected>`. Ensure test independence — no shared mutable state between tests. Use the project's test framework: {framework}. At Light depth: 2-5 critical path tests only. At Standard depth: happy path + error cases + key edge cases. At Deep depth: unit + integration + property-based tests. For greenfield projects or new modules where source files do not yet exist, also generate minimal compilable stubs — module declarations, type definitions, error types — so that tests can compile and reach Red state. Stub constructors and methods must use the language's not-implemented idiom (e.g., `todo!()` in Rust, `raise NotImplementedError` in Python, `throw new Error('not implemented')` in TypeScript) and contain no implementation logic. CRITICAL — Contract accuracy check: after writing all tests, cross-verify each test against the Interface Contracts for these common mismatch categories: (1) Constructor/factory parameter count and order — match the exact signature from the contract, (2) Mock module paths — mock the actual source file that exports the function, not a re-export or barrel file, (3) Parameter style — if the contract specifies an object parameter, do not pass separate positional arguments, (4) Prop/field names — use the exact names from the contract type definitions. If the contract includes a Test Suggestions table, use it as the primary reference for these details. Return test code files, stub files (if created), and a test inventory table."
- **Expected output**: Test code (one or more files) + compilable stubs if greenfield (module declarations, type skeletons with not-implemented bodies) + test inventory table (test name, target interface, scenario type)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Write 3-5 critical path tests for the primary interface using AAA pattern. Return test code only." If retry fails: report error to user |
| Incomplete output (tests but no inventory) | Accept test code. Generate inventory from test function names in Phase 5 |
| Test syntax errors (compilation failure) | Retry with instruction: "Fix syntax errors in the test code. Ensure all imports are present and types match the interface contracts." |

## Phase 5: Output

1. Determine output path for test files based on project conventions:

| Language | Test Location | Pattern |
|----------|---------------|---------|
| Rust | `tests/` or alongside source with `#[cfg(test)]` | `test_{module}.rs` |
| Python | `tests/` | `test_{module}.py` |
| TypeScript/JS | `__tests__/` or alongside source | `{module}.test.ts` |
| Go | alongside source | `{module}_test.go` |
| Default | `tests/` | `test_{module}.{ext}` |

2. Write test files via Write tool
3. Run tests via Bash to confirm Red state:

| Result | Action |
|--------|--------|
| All tests fail | Confirmed Red state — proceed |
| Some tests pass unexpectedly | Warning: "{n} tests pass without implementation — may indicate existing code or test bugs." List the passing tests. Proceed with documentation of the anomaly |
| Compilation/syntax error | Return to agent for fix (see Recovery). If second attempt fails: write tests anyway, document the error, ask user for guidance |

4. Write test artifact to `.swe/active/05-test.md`:

```markdown
# Test Suite: {task summary}

**Stage**: 5 — Test (TDD Red Phase)
**Depth**: {depth}
**Task**: {task description}
**Upstream**: {interface contracts path}
**Framework**: {framework}
**Date**: {date}

---

## Test Inventory

| # | Test Name | Target Interface | Scenario | Status |
|---|-----------|-----------------|----------|--------|
| 1 | {name} | {interface} | {happy/error/edge} | FAIL (Red) |

## Test Files

| # | Path | Tests |
|---|------|-------|
| 1 | {file path} | {count} |

## Red State Confirmation

{test runner output showing failures}

---

**Exit Criteria Check**:
- [ ] All tests fail for the right reason (missing implementation, not test bugs)
- [ ] {If greenfield} Compilable stubs generated — not-implemented bodies only, no implementation logic
- [ ] Test naming follows `test_<behavior>_when_<condition>_should_<expected>` convention
- [ ] AAA pattern used consistently
- [ ] Test independence — no shared mutable state
- [ ] {At Standard+} Error path tests present
- [ ] {At Standard+} Edge case tests present
- [ ] {At Deep} Integration tests present
- [ ] {At Deep} Property-based tests present
```

Present to user for review:

```markdown
## Test Suite: {task summary}

**Depth**: {depth}
**Tests**: {n} tests across {m} files
**Framework**: {framework}
**Red State**: {confirmed/warning — n unexpected passes}

### Test Inventory
| # | Test Name | Target Interface | Scenario |
|---|-----------|-----------------|----------|
| 1 | {name} | {interface} | {happy/error/edge} |

### Red State Output
{test runner output showing failures — truncated to key lines}

Review the test suite and confirm to proceed, or request revisions.
```

## Phase 6: Report

After user confirms (or on auto-proceed for composite invocation):

```markdown
## Stage 5 Complete: Test

**Artifact**: `.swe/active/05-test.md`
**Depth**: {depth}
**Tests**: {n} tests across {m} files
**Red State**: {confirmed/warning}

### Next Stage
Run Stage 6 (Implement) to write code that passes these tests:
`/swe implement "{task}" --depth {recommended_depth} --artifact .swe/active/05-test.md`

### See Also
- `/swe interface "{task}"` — revisit Stage 4 if tests reveal interface gaps
- `/swe dev "{task}"` — run all 4 development stages in sequence
- `/swe verify` — Stage 7 (after Implement)
```

## Rules

- Implementer agent generates test code — only the command writes files and runs tests via Bash
- Stage 5 (Test) can be skipped per pipeline methodology when interface contracts haven't changed (configuration-only or documentation-only tasks)
- Test Suite is the input contract for Stage 6 (Implement) — see `skills/swe/methodology/references/artifact-contracts.md`
- Depth decision must be logged with factor scores for traceability
- Output path follows `.swe/active/{NN}-{stage}.md` convention for the artifact; actual test files go in project-conventional locations
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- Red state must be confirmed via actual test execution (Bash), not just agent assertion
- Backward transition: if test authoring reveals interface gaps (ambiguous contracts, untestable interfaces, missing error conditions), recommend returning to Stage 4 (Interface) with specific gap description rather than proceeding with assumptions
