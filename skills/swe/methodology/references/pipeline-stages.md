# Pipeline Stages — Detailed Reference

Eight stages of the SWE pipeline. Each stage card includes: purpose, methodology anchor, key questions, procedure, output specification, DO/DON'T list, and depth-specific guidance.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For depth decision rules, see `depth-system.md`. For input/output contracts between stages, see `artifact-contracts.md`.

---

## Stage 1: Understand

**Methodology**: DDD (Domain-Driven Design)
**Purpose**: Analyze requirements, model the problem domain, survey existing code.
**Key Output**: Context Document

### Key Questions

- What problem are we solving? For whom?
- What is the domain vocabulary? (ubiquitous language)
- What existing code is affected? What is the current behavior?
- What are the success criteria? How will we know this is done?
- What bounded contexts are involved?

### Procedure

1. Read and restate the requirements in your own words
2. Identify domain entities, value objects, and their relationships
3. Survey existing codebase for affected areas (`Grep`, `Glob`, `Read`)
4. Define ubiquitous language — key terms and their precise meanings
5. Document bounded contexts — which modules own which concepts
6. Produce Context Document at the chosen depth level

### Output: Context Document

| Depth | Content |
|-------|---------|
| Skip | Not applicable (existing code change with no domain shift) |
| Light | 3-5 bullet points: problem statement, affected files, key terms |
| Standard | Structured document: problem statement, domain model, affected components, success criteria, ubiquitous language glossary |
| Deep | Full domain model with entity-relationship diagram, bounded context map, stakeholder analysis, existing code audit |

### Exit Criteria

- Ubiquitous language is stable enough to write constraints and tests
- Bounded context boundaries are explicit
- Unknowns are enumerated with owners

### DO / DON'T

| DO | DON'T |
|----|-------|
| Survey existing code before proposing changes | Jump to solution without understanding current state |
| Define domain terms precisely | Assume shared vocabulary — different people use different words for the same concept |
| Identify bounded contexts early | Treat the entire codebase as one undifferentiated mass |
| State success criteria explicitly | Leave "done" undefined |

---

## Stage 2: Constrain

**Methodology**: SDD (Specification-Driven Development)
**Purpose**: Enumerate constraints and boundaries before design.
**Key Output**: Constraint Profile

### Key Questions

- What are the performance requirements? (latency, throughput, resource limits)
- What is the scope boundary? (timeline, feature boundaries, explicit exclusions)
- What team constraints exist? (skills, expertise, learning curve)
- What technology constraints apply? (language, framework, infrastructure, compatibility)
- What operational constraints matter? (deployment, monitoring, maintenance)
- What business constraints limit choices? (budget, compliance, licensing)

### Procedure

1. Walk through all 6 constraint categories systematically (see `skills/swe/constraint/references/constraint-categories.md`)
2. For each category, ask the detection questions
3. Record constraints as concrete, measurable statements
4. Mark each constraint as Hard (non-negotiable) or Soft (preferred but flexible)
5. Identify constraint conflicts — where satisfying one constraint makes another harder
6. Produce Constraint Profile at the chosen depth level

### Output: Constraint Profile

| Depth | Content |
|-------|---------|
| Skip | Not applicable (pure refactoring with no new constraints) |
| Light | Bullet list of 3-5 dominant constraints with Hard/Soft classification |
| Standard | Structured table: all 6 categories evaluated, constraints with measurable thresholds, Hard/Soft classification, conflict analysis |
| Deep | Full constraint analysis: priority-ranked constraints, trade-off matrix, constraint interaction diagram, historical constraint evolution |

### Exit Criteria

- Every category has at least one entry (even if "no constraints identified")
- High-severity conflicts are resolved or escalated
- Measurable thresholds exist for Hard constraints

### DO / DON'T

| DO | DON'T |
|----|-------|
| Evaluate all 6 categories even if some are empty | Skip categories because "they probably don't apply" |
| Express constraints as measurable thresholds | Use vague terms ("fast enough", "reasonable cost") |
| Distinguish Hard from Soft constraints | Treat all constraints as equally rigid |
| Identify constraint conflicts explicitly | Ignore tensions between competing constraints |

---

## Stage 3: Design

**Methodology**: DDD (Domain-Driven Design)
**Purpose**: Architecture decisions, algorithm and data structure selection, structural choices.
**Key Output**: Architecture Spec

### Key Questions

- What architectural pattern fits the constraints? (layered, hexagonal, event-driven, etc.)
- What are the key data structures and algorithms?
- What are the bounded context boundaries in code?
- What design alternatives were considered? Why was this one chosen?
- Does every design decision trace to at least one constraint?

### Procedure

1. Review Context Document and Constraint Profile
2. Consider 2-3 architectural alternatives (minimum 2 for Standard/Deep)
3. Evaluate alternatives against Constraint Profile — select the one that best satisfies constraints
4. Design top-down: System → Container → Component → Code (C4 levels)
5. Select algorithms and data structures with rationale
6. Document design decisions with traceability to constraints
7. Produce Architecture Spec at the chosen depth level

### Output: Architecture Spec

| Depth | Content |
|-------|---------|
| Skip | Not applicable (implementation change within existing architecture) |
| Light | Key design decision + rationale in 3-5 sentences |
| Standard | Structured document: architectural pattern, component breakdown, data model, algorithm rationale, constraint traceability matrix |
| Deep | Full C4 architecture (all 4 levels), alternatives analysis with trade-off matrix, ADR for each significant decision |

### Exit Criteria

- Every major decision traces to at least one constraint
- Complexity and failure modes are acknowledged
- Interface definition can start without ambiguity

### DO / DON'T

| DO | DON'T |
|----|-------|
| Trace every design decision to a constraint | Design features that no constraint requires |
| Consider at least 2 alternatives (Standard/Deep) | Commit to the first idea without exploring options |
| Design for human AND AI readability | Create abstractions that only make sense to the author |
| Reference past decisions (`docs/adr/`, `docs/learnings/`) | Repeat mistakes already documented |

**Critical rule**: Never write code at the Design stage. Resist the urge to prototype during specification — that belongs in a separate POC workflow.

---

## Stage 4: Interface

**Methodology**: SDD (Specification-Driven Development)
**Purpose**: Define contracts between components — the boundaries where modules interact.
**Key Output**: Interface Contracts

### Key Questions

- What are the public interfaces? (APIs, function signatures, event schemas)
- What are the input/output types and their constraints?
- What error conditions exist? How are they communicated?
- What invariants must the interface maintain?
- Can a consumer write a test against this interface without seeing the implementation?

### Procedure

1. Review Architecture Spec for component boundaries
2. Define each interface: inputs, outputs, error conditions, invariants
3. Specify types precisely — no `any`, no untyped dictionaries in public interfaces
4. Document error handling contracts (Result pattern, exception hierarchy, error codes)
5. Verify each interface is testable — a consumer can write a test without seeing implementation
6. Produce Interface Contracts at the chosen depth level

### Output: Interface Contracts

| Depth | Content |
|-------|---------|
| Skip | Not applicable (internal refactoring with no interface changes) |
| Light | Function signatures with type annotations and docstrings |
| Standard | Structured interface spec: types, contracts, error conditions, invariants, usage examples |
| Deep | Full API spec (OpenAPI/protobuf/GraphQL), contract tests, compatibility matrix, migration guide |

### Exit Criteria

- Contract ambiguity is removed
- Test cases can be authored directly from interfaces
- Downstream consumers can use contracts independently

### DO / DON'T

| DO | DON'T |
|----|-------|
| Define error conditions explicitly | Return generic errors without classification |
| Use precise types (no `any`, no untyped dicts) | Leave type ambiguity "for flexibility" |
| Make interfaces testable without implementation | Create interfaces that require implementation details to test |
| Design for human AND AI readability | Use cryptic abbreviations in public interfaces |

---

## Stage 5: Test

**Methodology**: TDD (Test-Driven Development) — Red Phase
**Purpose**: Write tests against interfaces before implementation.
**Key Output**: Test Suite (failing)

### Key Questions

- What behaviors does each interface contract specify?
- What are the edge cases and boundary conditions?
- What is the test naming convention? (`test_<behavior>_when_<condition>_should_<expected>`)
- Are all tests independent? (no shared mutable state)
- Do the tests fail for the right reason? (Red phase validation)

### Procedure

1. Review Interface Contracts — each contract becomes one or more test cases
2. Write tests using Arrange-Act-Assert (AAA) pattern
3. Name tests descriptively: `test_<behavior>_when_<condition>_should_<expected>`
4. Ensure test independence — no shared mutable state, use fixtures/factories
5. Run tests — confirm they FAIL (Red state)
6. Verify failures are for the right reason (missing implementation, not test bugs)

### Output: Test Suite

| Depth | Content |
|-------|---------|
| Skip | Not applicable (configuration changes, documentation-only) |
| Light | 2-5 tests covering the critical path only |
| Standard | Test suite covering happy path, error cases, and key edge cases |
| Deep | Comprehensive test suite: unit + integration + property-based tests, coverage targets |

### Exit Criteria

- Red phase is real (tests fail for intended reasons)
- Test naming follows behavior pattern
- Test coverage reflects contract obligations

### DO / DON'T

| DO | DON'T |
|----|-------|
| Write tests BEFORE implementation | Write tests after implementation (loses design benefit) |
| Verify tests fail for the right reason (Red) | Skip the Red step — proves the test catches failures |
| One test = one behavior | Test multiple behaviors in a single test |
| Use fixtures/factories for setup | Create sequential test dependencies |

---

## Stage 6: Implement

**Methodology**: TDD (Test-Driven Development) — Green Phase
**Purpose**: Write the minimal code to pass all tests.
**Key Output**: Source Code (tests passing)

### Key Questions

- Does this implementation make all tests pass?
- Is this the minimal code needed? (no "while I'm here" features)
- Are side effects isolated to the adapter layer?
- Is the Result pattern used for error handling?

### Procedure

1. Implement the minimal code to make the first test pass
2. Run tests — confirm Green
3. Implement the next test — repeat Red-Green cycle
4. Resist adding features not covered by tests — if a new behavior is needed, return to Stage 5
5. Prefer pure functions, immutable objects, Result pattern for errors
6. Commit after each Green cycle (meaningful, self-contained commits)

### Output: Source Code

| Depth | Content |
|-------|---------|
| Skip | Not applicable (specification-only task) |
| Light | Minimal implementation, single commit |
| Standard | Implementation with proper error handling, type safety, documentation |
| Deep | Production-grade implementation with comprehensive error handling, logging, observability hooks |

### Exit Criteria

- All required tests pass
- No undocumented behavior deviates from interfaces
- New technical debt is recorded when introduced

### DO / DON'T

| DO | DON'T |
|----|-------|
| Write minimal code to pass current tests | Add "while I'm here" features |
| Prefer pure functions and immutable objects | Mix side effects throughout business logic |
| Use Result pattern for error handling | Throw exceptions for expected error conditions |
| Commit after each Green-Refactor cycle | Accumulate large uncommitted changes |

---

## Stage 7: Verify

**Methodology**: TDD — Broader Validation
**Purpose**: Broader validation beyond unit tests — integration, acceptance, manual verification.
**Key Output**: Verification Report

### Key Questions

- Do components integrate correctly? (integration tests)
- Does the system meet acceptance criteria from the Context Document?
- Are there manual verification steps that automated tests cannot cover?
- Does the implementation match the Architecture Spec?

### Procedure

1. Run integration tests (if applicable)
2. Verify acceptance criteria from the Context Document
3. Check implementation against Architecture Spec for drift
4. Perform manual verification for aspects that resist automation
5. Document any deviations from spec with rationale
6. Produce Verification Report

### Output: Verification Report

| Depth | Content |
|-------|---------|
| Skip | Not applicable (trivial change with unit test coverage) |
| Light | Automated smoke test (build + run) + confirmation that acceptance criteria met |
| Standard | Integration test results, acceptance criteria checklist, spec compliance check |
| Deep | Full verification matrix: integration tests, performance benchmarks, security scan, accessibility check, deployment validation |

### Exit Criteria

- Integration behavior is validated
- Critical risks have mitigation or explicit acceptance
- Release prerequisites are clear

### DO / DON'T

| DO | DON'T |
|----|-------|
| Check implementation against Architecture Spec | Assume unit tests are sufficient for all validation |
| Document deviations from spec | Silently diverge from the design |
| Verify acceptance criteria from Context Document | Declare "done" without checking original requirements |

---

## Stage 8: Optimize

**Methodology**: TDD — Refactor Phase
**Purpose**: Profiling-driven tuning and refactoring. Only after verification confirms correctness.
**Key Output**: Optimization Report

### Key Questions

- What does profiling data show? Where are the actual bottlenecks?
- Does the optimization address a constraint from the Constraint Profile?
- Do all tests still pass after optimization? (Refactor = Green must hold)
- Is the optimization justified by measurable improvement?

### Procedure

1. Profile the implementation — identify actual bottlenecks (not assumed ones)
2. Prioritize optimizations against Constraint Profile performance targets
3. Refactor code for clarity and maintainability (even without performance issues)
4. Apply optimizations — one at a time, tests must remain Green after each
5. Measure improvement — quantify before/after performance
6. Document optimizations with profiling evidence

### Output: Optimization Report

| Depth | Content |
|-------|---------|
| Skip | Not applicable (no performance requirements in Constraint Profile) |
| Light | Quick code cleanup, extract obvious duplication |
| Standard | Profiling results, refactoring applied, before/after measurements |
| Deep | Comprehensive profiling report, algorithmic complexity analysis, alternative implementations benchmarked, memory/CPU profiling |

### Exit Criteria

- Claimed improvements are measured with before/after data
- No contract regressions introduced
- Deferred optimization opportunities are documented

### DO / DON'T

| DO | DON'T |
|----|-------|
| Profile before optimizing | Optimize based on intuition without profiling data |
| Measure before/after | Assume an optimization helped without measuring |
| Keep tests Green after every change | Break tests during refactoring |
| Address constraints from the Constraint Profile | Optimize aspects that no constraint requires |

**Critical rule**: If profiling reveals a fundamentally wrong algorithm, return to Stage 3 (Design). Optimize is for tuning, not for wholesale redesign.
