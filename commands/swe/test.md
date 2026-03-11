---
description: "Stage 5 — Write tests against interface contracts using TDD Red Phase (TDD)"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <path>]"
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

### Conditional Routing

| Condition | Depth | Action |
|-----------|-------|--------|
| `--depth` Light/Standard/Deep | As specified | Proceed normally |
| `--depth Skip` + config-only or docs-only change | Skip | Minimal artifact → Phase 6 |
| `--depth Skip` + new behavior, changed interfaces, or new error conditions | Light | Override: "Skip not applicable — task changes behavior." |
| No flags | Scored | Apply depth decision matrix from `depth-system.md` |

Stage-specific depth triggers: Standard when customer-visible behavior changes. Deep when interface has 10+ public methods or complex error hierarchies. Escalation: migration >= 1M rows or flaky-test rate > 2%.

Log: "Depth: {depth} (score: {sum}, factors: S:{n} R:{n} F:{n} T:{n} V:{n})."

## Phase 3: Context Gathering

1. **Interface Contracts**: Read the artifact from `--artifact` or auto-discovered path
   - Extract public interfaces, type definitions, error conditions, invariants, usage examples
   - If artifact is unreadable or empty: abort with "Error: Interface Contracts artifact at {path} is empty or malformed."
2. **Upstream artifacts**: Search `.swe/active/` for related artifacts. At Light depth, read optional artifacts as summary only (`Read(file, limit: 15)`) per the Selective Load Matrix in `artifact-contracts.md`. At Standard+ depth, read all in full:
   - Architecture Spec (`.swe/active/03-design.md`): extract component structure for test organization (optional — summary at Light)
   - Context Document (`.swe/active/01-understand.md`): extract success criteria for test scenario derivation (optional — summary at Light)
   - Constraint Profile (`.swe/active/02-constrain.md`): extract performance requirements for threshold-based tests (optional — summary at Light)
3. **Existing test files**: Survey the codebase for existing test patterns using Glob (common test directory/file conventions). Identify test framework and conventions from existing tests
4. **Test framework detection**: Detect the project's test framework from manifest files and existing test imports. If undetectable: ask the user

Log: "Context gathered: {n} interface contracts, {m} existing test files, framework: {framework}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate test generation to the implementer agent via Task tool:

- **Input**: Interface Contracts content + upstream artifact context (success criteria, performance requirements, component structure) + existing test patterns (framework, naming convention, directory layout) + depth level
- **Instructions**: Follow the Stage 5 (Test) instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth. Bind: depth={depth}, framework={framework}.
- **Expected output**: Test code (one or more files) + compilable stubs if greenfield (module declarations, type skeletons with not-implemented bodies) + test inventory table (test name, target interface, scenario type)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Write 3-5 critical path tests for the primary interface using AAA pattern. Return test code only." If retry fails: report error to user |
| Incomplete output (tests but no inventory) | Accept test code. Generate inventory from test function names in Phase 5 |
| Test syntax errors (compilation failure) | Retry with instruction: "Fix syntax errors in the test code. Ensure all imports are present and types match the interface contracts." |

## Phase 5: Output

1. Determine output path for test files based on project conventions detected in Phase 3 (existing test file locations and framework defaults)
2. Write test files via Write tool
3. Run tests via Bash to confirm Red state:

| Result | Action |
|--------|--------|
| All tests fail | Confirmed Red state — proceed |
| Some tests pass unexpectedly | Warning: "{n} tests pass without implementation — may indicate existing code or test bugs." List the passing tests. Proceed with documentation of the anomaly |
| Compilation/syntax error | Return to agent for fix (see Recovery). If second attempt fails: write tests anyway, document the error, ask user for guidance |

4. Wrap agent output using the Stage 5 (Test) artifact wrapper from `skills/swe/methodology/references/artifact-wrappers.md`. Bind: task_summary={task summary}, depth={depth}, task_description={task description}, upstream_path={upstream artifact path}, date={date}, framework={framework}.
5. Write to output path (`.swe/active/05-test.md`) via Write tool

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
- **Implementer agent** (`agents/swe/implementer.md`) — executes test generation
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
```

## Rules

- Implementer agent generates test code — only the command writes files and runs tests via Bash
- Stage 5 (Test) can be skipped per pipeline methodology when interface contracts haven't changed (configuration-only or documentation-only tasks)
- Test Suite is the input contract for Stage 6 (Implement) — see `skills/swe/methodology/references/artifact-contracts.md`
- Output path follows `.swe/active/{NN}-{stage}.md` convention for the artifact; actual test files go in project-conventional locations
- When invoked by `/swe dev`, skip user checkpoint (Phase 5 review) and proceed directly to Phase 6 report
- Red state must be confirmed via actual test execution (Bash), not just agent assertion
- Backward transition: if test authoring reveals interface gaps (ambiguous contracts, untestable interfaces, missing error conditions), recommend returning to Stage 4 (Interface) with specific gap description rather than proceeding with assumptions
