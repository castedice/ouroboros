---
name: swe:dev
description: "Use when you already have a specification and need one command to drive it to working, verified code"
argument-hint: "<task-description> [--fast] [--depth <global|per-stage>] [--artifact <interface-contracts-path>]"
allowed-tools: Read, Glob, Grep, Write, Edit, Task, Bash
---

# Dev — Development Composite (Stages 5-8)

Orchestrate the 4 development stages sequentially — Test, Implement, Verify, Optimize — to produce working, verified, optimized code from interface contracts.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | implementer | Stage 5 — Test generation (TDD Red Phase) |
| 4 | implementer | Stage 6 — Code implementation (TDD Green Phase) |
| 5 | implementer | Stage 7 — Acceptance and spec verification |
| 6 | implementer | Stage 8 — Profiling and refactoring |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass implementer artifact paths, repo survey outputs, and inline contents on every call.
Use named return payloads rather than prose-only summaries.
The command owns code writes, Bash verification, and artifact persistence.
Internal implementer calls use `Agent(subagent_type: "ouroboros:swe:implementer")`.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:swe:implementer` | 3 | `task`, `depth_level`, `interface_contracts`, `upstream_artifacts`, and repo test-pattern survey | `test_suite`, `test_inventory`, and optional `unresolved_questions[]` |
| `ouroboros:swe:implementer` | 4 | `task`, `depth_level`, `test_suite`, `interface_contracts`, `upstream_artifacts`, code-pattern survey, and Red-state baseline | `implementation_patchset`, `green_state`, and optional `unresolved_questions[]` |
| `ouroboros:swe:implementer` | 5 | `task`, `depth_level`, full artifact chain, source paths, and Bash verification context | `verification_report`, `verification_verdict`, `accepted_strengths[]`, `required_revisions[]`, and optional `unresolved_questions[]` |
| `ouroboros:swe:implementer` | 6 | `task`, `depth_level`, source paths, performance constraints, verification context, and test baseline | `optimization_report`, `optimization_patchset`, `green_state`, and optional `unresolved_questions[]` |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--depth` | Depth specification | Standard (global) |
| `--artifact` | Path to Interface Contracts (Stage 4 output) | None (auto-discovered) |

**`--fast` mode**: Sets all stages to Light depth and enables relaxed skip conditions in each primitive stage. If both `--fast` and `--depth` are present, `--depth` takes precedence.

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 stages at Deep depth |
| Per-stage | `--depth T:Std I:Std V:Deep O:Light` | Individual stage depths (T=Test, I=Implement, V=Verify, O=Optimize) |

Parsing rules:

- If single word (Skip/Light/Standard/Deep): apply to all 4 stages
- If colon-separated pairs: parse each. Missing stages default to Standard
- If any stage abbreviation is invalid: error and abort
- If any depth value is invalid: error and abort

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe dev <task-description> [--depth <global|T:level I:level V:level O:level>] [--artifact <interface-contracts-path>]`"
- Abort

### Artifact Resolution

If `--artifact` is provided, use that path directly.

If `--artifact` is not provided: check for `.swe/active/04-interface.md` as the Interface Contracts artifact.

If no Interface Contracts artifact found:

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not continue. |
| `--depth` format, stage abbreviation, or depth value is invalid | 1 | Abort with the validation error and do not continue. |
| `--artifact` is provided and readable | 1 | Use it as the Interface Contracts entry artifact. |
| No Interface Contracts artifact can be resolved | 1 | Abort because Dev requires Stage 4 output. |
| `--depth` is provided | 2 | Use the parsed global or per-stage depths. |
| `--fast` is provided without `--depth` | 2 | Force Light depth across Stage 5-8 and enable relaxed skip behavior. |
| Neither `--depth` nor `--fast` is provided | 2 | Build the per-stage depth plan from `skills/swe/methodology/references/depth-system.md`. |
| Stage 5 succeeds | 3-8 | Continue to Stage 6 with `.swe/active/05-test.md`. |
| Stage 5 fails after one retry | 3 | Abort the composite because implementation cannot proceed without tests. |
| Stage 6 reaches full Green state | 4-8 | Continue normally to Stage 7. |
| Stage 6 is partial and the user or composite policy allows continuation | 4-8 | Continue to Stage 7 with the partial state documented. |
| Stage 6 is partial and the user chooses to stop | 4 | Abort after preserving Stage 5-6 artifacts. |
| Stage 6 fails after retry | 4-8 | Preserve completed Stage 5 artifacts, report the failure, and stop unless the user explicitly continues. |
| Stage 7 returns PASS | 5-8 | Continue to Stage 8 normally. |
| Stage 7 returns PARTIAL | 5-8 | Continue to Stage 8 with partial-state warnings. |
| Stage 7 returns FAIL on critical criteria and the user does not approve continuation | 5 | Stop and recommend `/swe implement`. |
| Stage 8 succeeds | 6-8 | Present the full Test → Implement → Verify → Optimize chain. |
| Stage 8 fails after retry | 6-8 | Preserve Stages 5-7 artifacts, mark Optimize as failed, and continue to final review/report. |


- Output: "Error: Interface Contracts artifact required. Run `/swe interface` or `/swe spec` first, or provide `--artifact <path>`."
- Abort
## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all stages to Light and enable `fast_mode=true` — skip depth matrix scoring entirely
3. If neither, apply the depth decision matrix from `skills/swe/methodology/references/depth-system.md` independently for each stage:
   - Score 5 factors once (they apply to the task overall)
   - Apply stage-specific minimum depth triggers for each stage:
     - Test: Standard when customer-visible behavior changes
     - Implement: Standard when implementation touches multiple bounded contexts; Deep when performance constraints have numeric SLAs
     - Verify: Deep when rollback > 2 hours or compliance scope exists
     - Optimize: Standard when Constraint Profile contains Hard performance constraints
   - Apply escalation rules per stage
4. Build Depth Plan:

```text
Depth Plan: T:{level} I:{level} V:{level} O:{level}
Rationale: {key drivers}
Escalation Triggers: {list if any}
```

Log the Depth Plan. Present to user for confirmation:

```markdown
## Depth Plan

| Stage | Depth | Rationale |
|-------|-------|-----------|
| 5. Test | {level} | {reason} |
| 6. Implement | {level} | {reason} |
| 7. Verify | {level} | {reason} |
| 8. Optimize | {level} | {reason} |

Proceed with this plan, or adjust depths?
```

## Stage Execution Pattern

Stages 5-8 follow the same orchestration loop.
Use this shared pattern, then apply the stage-specific bindings in each phase below.

| Step | Shared Action |
|------|---------------|
| 1 | Load the stage input artifact from `.swe/active/` plus the repo survey data needed for the stage |
| 2 | Delegate to `agents/swe/implementer.md` using the matching stage instructions from `skills/swe/methodology/references/agent-instructions.md` |
| 3 | Run the stage-local Bash verification command to confirm the required state transition |
| 4 | Write the stage artifact to `.swe/active/{NN}-{stage}.md` |
| 5 | Classify the stage verdict, apply the stage recovery table, and either continue or stop per Branch Summary |

## Phase 3: Stage 5 — Test (TDD Red Phase)

Execute the Test stage by delegating to the implementer agent:

> Agent: **implementer**

- **Input**: Task description + Interface Contracts content + upstream artifacts (Context Document for success criteria, Constraint Profile for performance thresholds, Architecture Spec for component structure) + existing test patterns (framework, naming convention, directory layout) + depth level for Test
- **Instructions**: Follow the Stage 5 (Test) instruction template from `skills/swe/methodology/references/agent-instructions.md` at the planned depth. Bind: framework={framework}.
- **Expected output**: Test code (one or more files) + test inventory table

Use the shared Stage Execution Pattern above with the Stage 5 bindings in this section.

1. Survey codebase for test patterns and detect test framework (same as test.md Phase 3)
2. Read Interface Contracts from the resolved artifact path
3. Delegate to implementer
4. Write test files to project-conventional locations
5. Run tests via Bash to confirm Red state
6. Write Test Suite artifact to `.swe/active/05-test.md`
7. Validate output: All tests must fail for the right reason (missing implementation, not test bugs). If compilation/syntax error: retry once with fix instruction
8. Log: "Stage 5 complete. Test Suite written. {n} tests across {m} files. Red state: {confirmed/warning}."

### Stage 5 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Write 3-5 critical path tests for the primary interface using AAA pattern." If retry fails: abort composite |
| Incomplete output (tests but no inventory) | Accept test code. Generate inventory from test function names |
| Test syntax errors (compilation failure) | Retry with instruction: "Fix syntax errors. Ensure all imports are present and types match interface contracts." If second attempt fails: abort composite |
| Red state warning (some tests pass unexpectedly) | Log warning with list of passing tests. Proceed — document anomaly in artifact |

### Stage 5 Failure

If implementer fails after retry: abort composite. Output: "Stage 5 (Test) failed. Cannot implement without a test suite. Run `/swe test` standalone for diagnostics."

## Phase 4: Stage 6 — Implement (TDD Green Phase)

Execute the Implement stage, passing the Test Suite forward:

> Agent: **implementer**

- **Input**: Task description + Test Suite content + Interface Contracts content + Architecture Spec context (module placement, naming, data model) + existing source code patterns + depth level for Implement + build system info + current test output (Red state baseline)
- **Instructions**: Follow the Stage 6 (Implement) instruction template from `skills/swe/methodology/references/agent-instructions.md` at the planned depth.
- **Expected output**: Source code files + Green state confirmation (test runner output)

Use the shared Stage Execution Pattern above with the Stage 6 bindings in this section.

1. Read the Test Suite artifact from Phase 3 output
2. Survey existing source code for patterns and conventions (same as implement.md Phase 3)
3. Run baseline test to confirm Red state
4. Delegate to implementer with Test Suite and upstream artifacts
5. Run the full test suite via Bash to independently confirm Green state
6. Write Implementation artifact to `.swe/active/06-implement.md`
7. Determine status: All pass → Green confirmed. Some pass → Partial implementation
8. Log: "Stage 6 complete. Implementation written. {pass}/{total} tests passing. Green state: {confirmed/partial}."

### Stage 6 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Implement the happy path for the primary interface only." If retry fails: report to user, offer to continue remaining stages or abort |
| Partial implementation (some tests still failing) | Accept partial result. Warn: "{pass}/{total} tests passing. Partial implementation — some tests still fail." Offer: "(A) Continue to Verify/Optimize with partial result. (B) Abort — re-run `/swe dev` or `/swe implement` to continue Red-Green cycle." |
| Build errors (compilation/syntax) | Present build error output. Retry once with error context. If retry fails: report to user |
| Test regression (previously passing tests fail) | Instruct agent to revert. If regression persists: report to user |

### Stage 6 Partial Handling

If Green state is only partial ({pass}/{total} < total):

- Log: "Warning: Partial implementation — {fail} tests still failing."
- If user chose to continue (option A) or in composite auto-proceed: proceed to Stage 7 with documented partial state
- Stage 7 will include partial implementation in its verification assessment

## Phase 5: Stage 7 — Verify (Broader Validation)

Execute the Verify stage, passing the Implementation forward:

> Agent: **implementer**

- **Input**: Task description + full artifact chain content (Context Document, Constraint Profile, Architecture Spec, Interface Contracts, Test Suite, Implementation summary) + source code file paths + test baseline results + depth level for Verify
- **Instructions**: Follow the Stage 7 (Verify) instruction template from `skills/swe/methodology/references/agent-instructions.md` at the planned depth. Bind: build_status and exec_status from smoke test results.
- **Expected output**: Verification Report content (acceptance criteria checklist, spec compliance, deviation documentation)

Use the shared Stage Execution Pattern above with the Stage 7 bindings in this section.

1. Gather the full artifact chain from `.swe/active/` (same as verify.md Phase 3)
2. Run existing test suites via Bash to confirm Green baseline
3. Delegate to implementer with all upstream artifacts
4. Write Verification Report to `.swe/active/07-verify.md`
5. Determine verdict: PASS (all criteria met), PARTIAL (some failures or spec drifts), FAIL (critical criteria not met)
6. Log: "Stage 7 complete. Verification Report written. Verdict: {verdict}."

### Stage 7 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Check the top 3 acceptance criteria from the Context Document and report PASS/FAIL with evidence." If retry fails: report error, present Stage 5-6 artifacts as still valid |
| Missing upstream artifacts | Log which artifacts are missing. Proceed with available artifacts. Instruct agent to note gaps |
| Incomplete output | Accept partial report. Note gaps in artifact |

### Stage 7 FAIL Verdict Handling

If verdict is FAIL on critical acceptance criteria:

- Log: "Warning: Verification FAIL — critical acceptance criteria not met."
- Present the failed criteria with evidence
- Recommend backward transition: "Consider returning to Stage 6 (Implement) to address failed acceptance criteria. Run `/swe implement \"{task}\"` to resume the Red-Green cycle."
- Proceed to Stage 8 only if the failures are non-critical or user explicitly approves continuation

If verdict is PARTIAL:

- Log the partial results
- Proceed to Stage 8 with documented partial state — optimization may still be valuable for the passing portions

## Phase 6: Stage 8 — Optimize (Profiling & Refactoring)

Execute the Optimize stage, passing the Verification Report forward:

> Agent: **implementer**

- **Input**: Source code file list + Constraint Profile content (performance constraints) + Architecture Spec content (algorithm rationale) + Verification Report + test baseline output + available profiling tools + depth level for Optimize
- **Instructions**: Follow the Stage 8 (Optimize) instruction template from `skills/swe/methodology/references/agent-instructions.md` at the planned depth.
- **Expected output**: Optimization Report content + modified source code

Use the shared Stage Execution Pattern above with the Stage 8 bindings in this section.

1. Survey codebase for optimization candidates and identify profiling tools (same as optimize.md Phase 3)
2. Run full test suite via Bash to establish Green baseline
3. If tests fail: abort Stage 8 with "Test suite not Green. Fix failing tests before optimizing. Prior stage artifacts remain valid."
4. Delegate to implementer with upstream artifacts
5. Run full test suite via Bash to confirm Green state after all changes
6. Write Optimization Report to `.swe/active/08-optimize.md`
7. Log: "Stage 8 complete. Optimization Report written. Tests: {pass}/{total} passing."

### Stage 8 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions: "Perform code review and suggest top 3 refactoring opportunities. Do not modify code." If retry fails: report error, present Stages 5-7 artifacts as valid |
| Test regression after optimization | Present regression. Recommend reverting to last Green state. If tests still fail: abort Stage 8, prior artifacts remain valid |
| No profiling tools available | Proceed with code-level analysis only. Log: "No profiling tools detected. Static analysis and algorithmic complexity assessment only." |
| Algorithmic bottleneck discovered | Do not fix at this stage. Report: "Profiling reveals algorithmic bottleneck — recommend returning to Stage 3 (Design). Optimization is for tuning, not redesign." |

### Stage 8 Failure

If implementer fails after retry: present partial results. All prior artifacts (Stages 5-7) remain valid. "Stage 8 (Optimize) failed, but Stages 5-7 completed successfully. Code is functional and verified. Run `/swe optimize` standalone if optimization is needed."

## Phase 7: Review

Present the complete development results for user approval:

```markdown
## Development Complete: {task summary}

### Artifact Chain

| # | Stage | Depth | Artifact | Status |
|---|-------|-------|----------|--------|
| 5 | Test | {depth} | `.swe/active/05-test.md` | {done/failed} |
| 6 | Implement | {depth} | `.swe/active/06-implement.md` | {done/partial/failed} |
| 7 | Verify | {depth} | `.swe/active/07-verify.md` | {done/partial/failed} |
| 8 | Optimize | {depth} | `.swe/active/08-optimize.md` | {done/failed/skipped} |

### Key Highlights
- **Tests**: {n} tests across {m} files
- **Green State**: {confirmed/partial — n/total passing}
- **Verification Verdict**: {PASS/PARTIAL/FAIL}
- **Optimizations**: {n} applied, {m} refactoring changes

### TDD Cycle Summary
- Red: {n} tests written, all failing for correct reasons
- Green: {pass}/{total} tests passing after implementation
- Refactor: {n} optimizations applied, all tests remain Green

### Contract Chain Validation
- [ ] Interface Contracts → Test Suite: all public interfaces have test coverage
- [ ] Test Suite → Implementation: all tests pass (Green state)
- [ ] Implementation → Verification Report: acceptance criteria checked with evidence
- [ ] Verification Report → Optimization Report: optimizations preserve Green state

Review the development artifacts, or approve to proceed.
```

## Phase 8: Report

```markdown
## Dev Complete: {task summary}

**Depth Plan**: T:{level} I:{level} V:{level} O:{level}
**Artifacts**: 4 files in `.swe/active/`

### Next Steps
- `/swe verify "{task}"` — return to Stage 7 if optimization introduced concerns
- `/swe design "{task}"` — return to Stage 3 if profiling revealed algorithmic redesign needs

### Full Pipeline Reference
- `/swe spec "{task}"` — upstream specification (Stages 1-4)
- `/swe spiral "{task}"` — full engineering cycle (spec + dev + ship + tune)

### Individual Stage Review
- `/swe test "{task}"` — revisit test suite
- `/swe implement "{task}"` — revisit implementation
- `/swe verify "{task}"` — revisit verification
- `/swe optimize "{task}"` — revisit optimization
```

### See Also
- **Implementer agent** (`agents/swe/implementer.md`) — executes all 4 development stages
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — stage input/output specifications

## Rules

- Each stage delegates to the implementer agent — the command orchestrates, not executes
- Artifacts are written sequentially: each stage's output becomes the next stage's input
- Artifact paths follow `.swe/active/{NN}-{stage}.md` convention
- User checkpoint occurs once at Phase 7 (Review) — individual stages do not pause for user review when run as part of dev
- Backward transitions within dev: if a downstream stage reveals upstream gaps, the command re-runs the upstream stage (not the primitive command) with additional context
- Failure isolation: each stage can fail independently. Prior completed artifacts remain valid
- Graceful degradation: Stage 5 failure aborts (tests required). Stage 6 partial offers continue option. Stage 7 FAIL recommends backward transition to implement. Stage 8 failure preserves Stages 5-7 artifacts
- Test baseline invariant: Stage 5 establishes Red state, Stage 6 turns it Green, Stage 7 verifies Green, Stage 8 keeps Green. Every stage transition preserves or improves the test state
- If Stage 6 achieves only partial implementation, warn user and offer to continue or abort remaining stages
- Depth references: `skills/swe/methodology/references/depth-system.md` for depth decisions, `skills/swe/methodology/references/artifact-contracts.md` for Stage 5-8 contracts
- The dev composite consumes Interface Contracts (Stage 4 output) as its entry artifact — produced by `/swe interface` or `/swe spec`
- The dev composite produces 4 artifacts consumed by downstream composites and tune retrospect
