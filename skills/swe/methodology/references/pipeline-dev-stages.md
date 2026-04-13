# Pipeline Dev Stages — Test, Implement, Verify, and Optimize

Stages 5-8 of the SWE pipeline.
Each stage card includes: purpose, methodology anchor, key questions, procedure, output specification, DO / DON'T list, and depth-specific guidance.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For depth decision rules, see `depth-system.md`.
For input and output contracts between stages, see `artifact-contracts.md`.

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
**Purpose**: Profiling-driven tuning and refactoring.
Only after verification confirms correctness.
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

**Critical rule**: If profiling reveals a fundamentally wrong algorithm, return to Stage 3 (Design).
Optimize is for tuning, not for wholesale redesign.
