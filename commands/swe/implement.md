---
name: swe:implement
description: "Use when tests and interfaces are ready and you need the minimal code that makes them pass"
argument-hint: "<task-description> [--fast] [--depth Skip|Light|Standard|Deep] [--artifact <test-suite-path>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
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

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not write artifacts. |
| `--depth` value is invalid | 1 | Abort with the validation error and do not write artifacts. |
| `--depth` is provided | 2 | Use the explicit depth and skip automatic scoring. |
| No explicit depth is provided | 2 | Score the task via `skills/swe/methodology/references/depth-system.md` and apply stage-specific triggers. |
| Resolved depth is `Skip` | 2, 5, 6 | Write the minimal spec-only skip artifact to `.swe/active/06-implement.md` and jump to Phase 6. |
| `--artifact` is provided and readable | 3 | Use that Test Suite artifact as the implementation contract. |
| `--artifact` is missing or `.swe/active/05-test.md` does not exist | 3 | Abort because Stage 6 requires a Test Suite artifact. |
| `.swe/active/04-interface.md` exists | 3 | Load Interface Contracts and use them as the primary non-test contract source. |
| `.swe/active/04-interface.md` is missing | 3 | Warn and continue with test-driven implementation only. |
| `.swe/active/03-design.md` or `.swe/active/02-constrain.md` is missing | 3 | Warn and continue with reduced architectural or performance context. |
| Baseline tests already pass before implementation | 3 | Warn that no implementation may be needed and continue so the user can verify the artifact choice. |
| Implementer times out or errors | 4 | Retry once with the simplified happy-path fallback prompt, then stop and report the failure. |
| Implementation is partial and some tests still fail | 4, 5, 6 | Accept the partial result, write the artifact with the partial status, and recommend another `/swe implement` pass. |
| Build errors or regressions persist after retry | 4, 5 | Stop and report the blocking failure rather than writing a false Green artifact. |
| Independent Phase 5 verification confirms all tests pass | 5, 6 | Write the normal Green-state artifact and report success. |
| Invoked by `/swe dev` | 5, 6 | Skip the Phase 5 review checkpoint and continue directly to the Phase 6 report. |
### Skip Handling

If depth is **Skip**: Log "Stage 6 skipped — no implementation changes. Use for spec-only workflows." Produce minimal skip artifact noting "No implementation — spec-only workflow" and jump to Phase 6.

### Depth-Specific Output Expectations

| Depth | Implementation Scope |
|-------|---------------------|
| Light | Minimal single-pass implementation. Happy path only. No docstrings beyond type annotations |
| Standard | Proper error handling using Result pattern. Type safety enforced. Inline documentation (docstrings, type annotations). Meaningful commit-granularity code organization |
| Deep | Production-grade: structured logging, observability hooks, defensive programming. Comprehensive inline documentation. Performance-aware implementation aligned to Constraint Profile SLAs |

## Phase 3: Context Gathering

### Stage 6 Execution Boundary

Use the shared Stage 6 procedure at `skills/swe/methodology/references/agent-instructions.md` for implementation behavior.
Use `skills/swe/methodology/references/artifact-stage-contracts.md` and `skills/swe/methodology/references/artifact-wrappers.md` for required artifact fields.
Local shell work stays limited to packet assembly, one baseline Red-state capture, and one post-change confirmation run.

| Packet element | Source | Command responsibility |
|----------------|--------|------------------------|
| Test Suite contract | `--artifact` or `.swe/active/05-test.md` | Resolve it first and abort if neither exists. |
| Interface contract | `.swe/active/04-interface.md` | Read it in full when present because it defines the public boundary. |
| Design and constraint context | `.swe/active/03-design.md` and `.swe/active/02-constrain.md` | Read summary-only at Light depth or full at Standard+ depth when present. |
| Candidate source files | Codebase survey | Read only the files needed to recover naming, placement, and error-handling patterns. |
| Runner command | Project manifests and existing scripts | Record the chosen command and the evidence for choosing it. |
| Baseline Red-state evidence | One local test run | Capture exactly one pre-change run for the implementer packet and Phase 5 verification. |

1. Resolve the Test Suite artifact from `--artifact` or `.swe/active/05-test.md`.
2. Load the supporting artifacts and code patterns listed in the execution boundary table.
3. Detect the primary runner command, capture one baseline Red-state run, and record pass or fail counts.
4. If the baseline already passes, warn that the selected artifact may already be implemented and continue so the user can validate scope.

Log: "Context gathered: {n} failing tests, {m} passing tests. Build system: {system}."

## Phase 4: Analysis

> Agent: **implementer**

Delegate implementation to the implementer agent via Task tool:

- **Input**: Test Suite content + Interface Contracts content (if available) + Architecture Spec context (module placement, naming, data model) + existing source code patterns + depth level + build system info (test runner command) + current test output (Red state baseline)
- **Instructions**: "Follow the shared Stage 6 (Implement) procedure in `skills/swe/methodology/references/agent-instructions.md` at {depth} depth. Bind: runner_command={detected runner}, baseline_red_state={captured Phase 3 output}, architecture_context={Phase 3 summary}, interface_context={Phase 3 contract summary}. Respect the minimal-code goal, the maximum of 3 Red-Green rounds, and the Result-pattern/error-handling rules from the shared procedure. Return only the changed-file summary and the per-round Green-state evidence."
- **Expected output**: Source code files written to the project + Green state confirmation (test runner output showing all tests pass)

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Implement the happy path for the primary interface only. Make the most basic test pass first." If retry fails: report error to user |
| Partial implementation (some tests still failing) | Accept partial result. Log progress: "{n}/{total} tests now passing." Present to user with option to continue: "Run `/swe implement` again to continue the Red-Green cycle." |
| Build errors (compilation/syntax failures) | Present build error output to user. Suggest: "Check Architecture Spec compatibility or adjust test expectations. Common causes: missing dependencies, type mismatches, incorrect module paths." |
| Test regression (previously passing tests now fail) | Log regression details. Instruct agent: "Revert the last change — a previously passing test now fails. Re-approach with a different implementation strategy." If regression persists after retry: report to user |

## Output Contracts

| Mode | Trigger | Payload location | Required sections or fields |
|------|---------|------------------|-----------------------------|
| Normal | Phase 5 verification confirms full Green state | `.swe/active/06-implement.md` via the Stage 6 wrapper at `skills/swe/methodology/references/artifact-wrappers.md` | `# Implementation: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, `## Green State`, `## Implementation Summary`, `## Files Modified`, `## Constraint Traceability`, `## Contract Delta Notes`, and `**Exit Criteria Check**`. |
| Partial | Some tests pass but full Green state is not reached | `.swe/active/06-implement.md` via the same Stage 6 wrapper | All Normal fields plus `**Status**: Partial`, partial pass or fail counts, `Remaining Failing Tests`, and `Next Implementation Step`. |
| Skip | Resolved depth is `Skip` for a spec-only workflow | `.swe/active/06-implement.md` | `# Implementation: {task summary}`, `**Stage**`, `**Depth**`, `**Task**`, `**Upstream**`, `**Date**`, `## Summary`, `## Skip Reason`, `## Upstream Contract Status`, and `## Next Stage Guidance`. |
| Error | Missing Test Suite artifact or unrecoverable implementation failure | User-facing error only | `Error`, `Failed Phase`, `Blocking Condition`, `Artifact Write: none`, and `Next Command`. |
| Composite handoff | Invoked by `/swe dev` | Same artifact as Normal, Partial, or Skip plus the Phase 6 report | Artifact path, resolved depth, final test counts, final status, next-stage command, and `See Also`. |

Phase 5 writes `.swe/active/06-implement.md` only for Normal, Partial, or Skip mode.

## Phase 5: Output

Phase 5 is a command-only confirmation pass.
Implementation behavior stays in the shared Stage 6 procedure at `skills/swe/methodology/references/agent-instructions.md`.
Artifact fields stay aligned to `skills/swe/methodology/references/artifact-stage-contracts.md` and `skills/swe/methodology/references/artifact-wrappers.md`.

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
