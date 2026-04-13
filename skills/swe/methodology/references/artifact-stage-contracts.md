# Artifact Stage Contracts

This reference lists the required outputs for each stage and the downstream stages that consume them.

## Stage 1: Understand → Context Document

| Field | Required | Description |
|-------|----------|-------------|
| Problem Statement | Always | What problem is being solved, and for whom |
| Domain Model | Standard+ | Entities, value objects, and relationships |
| Affected Components | Always | Files, modules, or services that will change |
| Success Criteria | Always | Measurable conditions for done |
| Ubiquitous Language | Standard+ | Glossary of domain terms with precise definitions |
| Bounded Contexts | Deep | Module boundaries and ownership |

Consumed by Constrain for scope, Design for the domain model, and Verify for success criteria.

## Stage 2: Constrain → Constraint Profile

| Field | Required | Description |
|-------|----------|-------------|
| Constraint List | Always | Constraints organized by six categories |
| Hard/Soft Classification | Always | Each constraint marked non-negotiable or flexible |
| Measurable Thresholds | Standard+ | Numeric bounds for each constraint |
| Conflict Analysis | Standard+ | Where constraints tension each other |
| Priority Ranking | Deep | Ordered importance for trade-off resolution |

Consumed by Design for boundaries, Interface for performance contracts, and Optimize for performance targets.

## Stage 3: Design → Architecture Spec

| Field | Required | Description |
|-------|----------|-------------|
| Architectural Pattern | Always | Selected pattern with rationale |
| Component Breakdown | Standard+ | Modules, services, layers, and responsibilities |
| Data Model | Standard+ | Key data structures with type definitions |
| Algorithm Rationale | Standard+ | Why the algorithm or data structure was chosen |
| Constraint Traceability | Standard+ | Each design decision linked to its driving constraint |
| Alternatives Considered | Deep | Other approaches and their trade-offs |

Consumed by Interface for boundaries, Implement for structure, and Verify for spec compliance.

## Stage 4: Interface → Interface Contracts

| Field | Required | Description |
|-------|----------|-------------|
| Public Interfaces | Always | Function signatures, API endpoints, or event schemas |
| Type Definitions | Always | Precise input and output types |
| Error Conditions | Standard+ | Error types, codes, and recovery paths |
| Invariants | Standard+ | Conditions that must always hold |
| Usage Examples | Standard+ | Code showing how to call each interface |
| Compatibility Matrix | Deep | Version compatibility and migration paths |

Consumed by Test for targets, Implement for fulfillment, and Verify for integration boundaries.

## Stage 5: Test → Test Suite

| Field | Required | Description |
|-------|----------|-------------|
| Unit Tests | Always | Tests per interface contract with descriptive names |
| Red State Confirmation | Always | Evidence that tests fail before implementation |
| Edge Case Tests | Standard+ | Boundary conditions and error paths |
| Integration Tests | Deep | Cross-component interaction tests |
| Property-Based Tests | Deep | Generative tests for invariant verification |

Consumed by Implement for the green target, Verify for the baseline, and Optimize for regression protection.

## Stage 6: Implement → Source Code

| Field | Required | Description |
|-------|----------|-------------|
| Source Code | Always | Implementation that passes all tests |
| Green State Confirmation | Always | Evidence that all tests pass |
| Inline Documentation | Standard+ | Docstrings, type annotations, or comments for non-obvious code |
| Commit History | Standard+ | Meaningful commits per Red-Green-Refactor cycle |

Consumed by Verify as the verification target and by Optimize as the optimization target.

## Stage 7: Verify → Verification Report

| Field | Required | Description |
|-------|----------|-------------|
| Acceptance Criteria Check | Always | Pass or fail for each criterion from the context document |
| Smoke Test Results | Always | Build status, execution status, and error output if any |
| Spec Compliance Check | Standard+ | Implementation versus architecture alignment |
| Integration Test Results | Standard+ | Cross-component interaction validation |
| Deviation Documentation | As needed | Any justified divergence from spec |

Consumed by Optimize for the baseline and by Tune for quality retrospection.

## Stage 8: Optimize → Optimization Report

| Field | Required | Description |
|-------|----------|-------------|
| Profiling Results | Standard+ | Bottleneck identification with data |
| Optimizations Applied | Always | What changed and why |
| Before/After Measurements | Standard+ | Quantified improvement per optimization |
| Remaining Tech Debt | As needed | Deferred issues with rationale |

Consumed by Tune for performance data and tech-debt backlog shaping.
