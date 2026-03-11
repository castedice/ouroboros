# Agent Instruction Templates — Stage-Specific Delegation

Canonical instruction templates for delegating work to SWE pipeline agents. Primitive commands and composites both reference this file instead of maintaining inline copies.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For stage descriptions, see `pipeline-stages.md`. For artifact contracts, see `artifact-contracts.md`. For depth decisions, see `depth-system.md`.

## How to Use

When delegating to an agent in a command's Phase 4 (Analysis), reference the instruction template by stage number and bind the required variables:

```text
- **Instructions**: Follow the Stage 5 (Test) instruction template from `skills/swe/methodology/references/agent-instructions.md` at {depth} depth. Bind: framework={framework}.
```

Composites reference the same templates — no abbreviated inline copies needed.

---

## Specification Stages (Analyst Agent)

### Stage 1: Understand

> Agent: **analyst** | Procedure: 1 (Understand)

"Start your output with a `## Summary` section (3-5 sentences capturing the problem, key domain concepts, and affected components), then continue with full content. Execute Procedure 1 (Understand) at {depth} depth. Follow the template at `templates/swe/context-document.md` — include sections matching the depth markers for this depth level. Use the exact column schemas and section formats defined in the template. Return the artifact content as structured markdown."

**Bindings**: `{depth}`

### Stage 2: Constrain

> Agent: **analyst** | Procedure: 2 (Constrain)

"Start your output with a `## Summary` section (3-5 sentences capturing the dominant constraints, hard/soft counts, and key conflicts), then continue with full content. Execute Procedure 2 (Constrain) at {depth} depth. Follow the template at `templates/swe/constraint-profile.md` — include sections matching the depth markers for this depth level. Use the fixed column schema for all category tables. Sweep all 6 categories using detection questions from `skills/swe/constraint/references/constraint-categories.md`. Classify on 3 axes per `skills/swe/constraint/SKILL.md`. Identify conflicts per `skills/swe/constraint/references/conflict-resolution-patterns.md`. Populate the Open Questions Resolution section by resolving every A{n} from the upstream Context Document. Return the artifact content as structured markdown."

**Bindings**: `{depth}`

### Stage 3: Design

> Agent: **analyst** | Procedure: 3 (Design)

"Start your output with a `## Summary` section (3-5 sentences capturing the chosen architectural pattern, key decisions, and constraint traceability), then continue with full content. Execute Procedure 3 (Design) at {depth} depth. Follow the template at `templates/swe/architecture-spec.md` — include sections matching the depth markers for this depth level. Consider 2-3 alternatives (minimum 2 for Standard/Deep). Evaluate against the Constraint Profile. Design top-down: System > Component > Code. At Deep depth, use the 3-field ADR format (Context/Decision/Consequences). Ensure every design decision traces to at least one constraint in the Traceability Matrix. Return the artifact content as structured markdown."

**Bindings**: `{depth}`

### Stage 4: Interface

> Agent: **analyst** | Procedure: 4 (Interface)

"Start your output with a `## Summary` section (3-5 sentences capturing interfaces defined, key type decisions, and notable error conditions), then continue with full content. Execute Procedure 4 (Interface) at {depth} depth. Follow the template at `templates/swe/interface-contracts.md` — include sections matching the depth markers for this depth level. Always populate the Delta from Design section — if types or signatures changed from the Architecture Spec, document every change with reason. Use named structs for all public return types (no raw tuples). Use precise types — no `any`, no untyped dictionaries. Verify each interface is testable without implementation. At Standard+ depth: include the Test Suggestions section with full implementation detail — constructor signatures with parameter order, source module paths for mock targeting, and parameter style (object vs positional) for each function. These details prevent test-contract mismatches during Stage 5. Return the artifact content as structured markdown."

**Bindings**: `{depth}`

---

## Development Stages (Implementer Agent)

### Stage 5: Test (TDD Red Phase)

> Agent: **implementer** | Procedure: 1 (Test)

"Execute Procedure 1 (Test) at {depth} depth. Write tests using AAA pattern. Name tests descriptively: `test_<behavior>_when_<condition>_should_<expected>`. Ensure test independence — no shared mutable state between tests. Use the project's test framework: {framework}. At Light depth: 2-5 critical path tests only. At Standard depth: happy path + error cases + key edge cases. At Deep depth: unit + integration + property-based tests. For greenfield projects or new modules where source files do not yet exist, also generate minimal compilable stubs — module declarations, type definitions, error types — so that tests can compile and reach Red state. Stub constructors and methods must use the language's not-implemented idiom (e.g., `todo!()` in Rust, `raise NotImplementedError` in Python, `throw new Error('not implemented')` in TypeScript) and contain no implementation logic. CRITICAL — Contract accuracy check: after writing all tests, cross-verify each test against the Interface Contracts for these common mismatch categories: (1) Constructor/factory parameter count and order — match the exact signature from the contract, (2) Mock module paths — mock the actual source file that exports the function, not a re-export or barrel file, (3) Parameter style — if the contract specifies an object parameter, do not pass separate positional arguments, (4) Prop/field names — use the exact names from the contract type definitions. If the contract includes a Test Suggestions table, use it as the primary reference for these details. Return test code files, stub files (if created), and a test inventory table."

**Bindings**: `{depth}`, `{framework}`

### Stage 6: Implement (TDD Green Phase)

> Agent: **implementer** | Procedure: 2 (Implement)

"Execute Procedure 2 (Implement) at {depth} depth. Make tests pass with minimal code. Maximum 3 Red-Green rounds. Follow Architecture Spec for structure (module placement, naming conventions). Use Result pattern for errors — return errors, do not throw exceptions. Prefer pure functions and immutable data. At Standard+ depth, add docstrings and type annotations. At Deep depth, add structured logging and observability. Return source code with Green state confirmation — paste test runner output after each round."

**Bindings**: `{depth}`

### Stage 7: Verify (Broader Validation)

> Agent: **implementer** | Procedure: 3 (Verify)

"Execute Procedure 3 (Verify) at {depth} depth. Smoke test results: build {build_status}, execution {exec_status}. Include these in the Smoke Test Results section of the Verification Report. First, scope acceptance criteria to the current implementation unit: compare implemented types/modules against the full system scope from the Context Document. Classify each criterion as IN_SCOPE (directly testable with current implementation), PARTIAL (requires current implementation but also unimplemented components), or OUT_OF_SCOPE (entirely dependent on unimplemented components). Check IN_SCOPE and PARTIAL criteria with evidence of PASS or FAIL. List OUT_OF_SCOPE criteria separately noting which components are needed. Compare the implementation against the Architecture Spec for structural compliance. At Standard+ depth, check cross-type pattern consistency: if multiple types in the same bounded context use different access control strategies (e.g., private fields with accessors vs pub fields), different validation approaches (e.g., Result errors vs clamping), or different normalization patterns (e.g., one type normalizes input, another stores raw input), flag inconsistencies as deviations with impact assessment. Run integration tests if applicable. Document any deviations with rationale and impact assessment. Follow the template at `templates/swe/verification-report.md`. Return the Verification Report content as structured markdown."

**Bindings**: `{depth}`, `{build_status}`, `{exec_status}`

### Stage 8: Optimize (Profiling & Refactoring)

> Agent: **implementer** | Procedure: 4 (Optimize)

"Execute Procedure 4 (Optimize) at {depth} depth. Profile implementation to identify actual bottlenecks — do not optimize based on intuition. Prioritize against Constraint Profile performance targets: Hard constraint violations first, then Soft, then general code quality. Apply optimizations one at a time, running the full test suite after each change to keep tests Green. Measure before/after for every optimization. Refactor for clarity after performance work. Follow the template at `templates/swe/optimization-report.md`. Reference artifact contracts from `skills/swe/methodology/references/artifact-contracts.md` Stage 8 for required fields at {depth} depth. Return Optimization Report content as structured markdown."

**Bindings**: `{depth}`

---

## Ship Stages

### Integration Test (Implementer Agent)

> Agent: **implementer**

"Run all integration and e2e test suites using Bash. If no integration tests exist, run the full unit test suite as baseline validation. Report: total tests, pass count, fail count, error details for failures. Do not write new tests — only execute existing ones."

**Bindings**: none

### Security Review (Reviewer Agent)

> Agent: **reviewer** | Procedure: 1 (Security Review)

"Execute Procedure 1 (Security Review) at {depth} depth. Run dependency audit commands if available. Scan for exposed secrets. At Standard+ depth, check license compliance. Return findings classified as P1/P2/P3."

**Bindings**: `{depth}`

### Code Review (Reviewer Agent)

> Agent: **reviewer** | Procedure: 2 (Code Review)

"Execute Procedure 2 (Code Review) at {depth} depth. Review from all 4 perspectives: Architecture, Safety, Performance, Readability. Classify each finding as P1/P2/P3. Reference the Architecture Spec for structural expectations and Constraint Profile for performance boundaries. Return findings with concrete fix suggestions."

**Bindings**: `{depth}`

---

## Tune Stages

### Evaluate (Core Evaluator)

> Agent: **core evaluator** (via `subagent_type: "ouroboros:core:evaluator"`)

"Evaluate the implementation quality of the source code for the task: {task}. Apply SWE-adapted criteria: Does the code satisfy its interface contracts? Does it respect constraint boundaries? Is the TDD cycle evidence complete (Red state → Green state → verified)? Is the code minimal — no gold-plating beyond what constraints require? Rate quality on a scale and produce specific improvement recommendations."

**Bindings**: `{task}`

### Improve (Implementer Agent)

> Agent: **implementer** (via `subagent_type: "ouroboros:swe:implementer"`)

"Apply the following code improvements identified by evaluation: {improvement_targets}. For each improvement: apply the change, run the test suite to confirm Green state is maintained, document what changed and why. Do not introduce new features — only improve existing code quality."

**Bindings**: `{improvement_targets}`

### Retrospect (Core Researcher)

> Agent: **core researcher** (via `subagent_type: "ouroboros:core:researcher"`)

"Analyze the complete artifact chain for task: {task}. Extract: (1) Patterns — recurring approaches that worked well, (2) Learnings — what was discovered during the engineering process, (3) Decisions — key choices made and their rationale, (4) Improvements — what could be done better next time. At Standard+ depth, identify specific process improvements and evaluate depth accuracy for each stage that ran in this turn: compare the planned depth against the actual effort needed, mark as Over (too much ceremony — depth could have been lower), Under (gaps found that higher depth would have caught), or Correct, and in Notes explain what would have changed with different depth. Reference the Depth Accuracy section in the retrospect-report template. At Deep depth, track metrics and suggest next-cycle specifications."

**Bindings**: `{task}`
