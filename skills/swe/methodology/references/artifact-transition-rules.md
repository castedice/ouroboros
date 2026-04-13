# Artifact Transition Rules

This reference covers how downstream stages load, accept, reject, and revise upstream artifacts.

## Selective Load Matrix

Downstream stages can load upstream artifacts as full content or summary-only content.
At Light depth, optional artifacts load as summary-only to conserve context window.

| Downstream Stage | Required (always full) | Optional (summary at Light depth) |
|------------------|------------------------|-----------------------------------|
| S2 Constrain | S1 Context Document | — |
| S3 Design | S2 Constraint Profile | S1 Context Document |
| S4 Interface | S3 Architecture Spec | S1 Context Document, S2 Constraint Profile |
| S5 Test | S4 Interface Contracts | S3 Architecture Spec |
| S6 Implement | S4 Interface Contracts, S5 Test Suite | S1 Context Document, S2 Constraint Profile, S3 Architecture Spec |
| S7 Verify | S4 Interface Contracts, S6 Implementation | S1 Context Document, S2 Constraint Profile, S3 Architecture Spec, S5 Test Suite |
| S8 Optimize | S2 Constraint Profile, S3 Architecture Spec, S7 Verification | S1 Context Document, S4 Interface Contracts, S5 Test Suite, S6 Implementation |

Loading rules:

- Required artifacts are always read in full.
- Optional artifacts at Standard or Deep depth are read in full.
- Optional artifacts at Light depth are read as summary-only.

## Contract Quality Gates

Every artifact must pass these gates before the downstream stage may begin.

| Gate | Condition |
|------|-----------|
| Completeness | All required fields are present at the chosen depth |
| Traceability | Decisions and behaviors trace to prior artifacts |
| Consistency | No conflict with upstream contracts |
| Evidence | Claims are backed by tests, measurements, or cited sources |

A downstream stage may reject an upstream artifact that fails any gate.
That rejection reopens the producer stage instead of letting downstream work improvise around the gap.

## Backward Transition Protocol

When a downstream stage discovers an upstream gap:

1. Identify the specific missing or incorrect contract.
2. Document the gap in the current stage notes.
3. Return to the producer stage and update the artifact.
4. Cascade the impact through any intervening stages.
5. Resume from the current stage with the updated upstream artifact.

Backward transitions are not failures.
They are the mechanism that keeps the pipeline honest before the defect gets more expensive.

## Contract Delta Note Format

When revising a previously completed artifact, record:

- Artifact: name and stage
- Expected: previous assumption
- Actual: observed condition
- Impact: stages or components affected
- Change: exact contract update
- Owner: responsible role
- Timestamp: when the delta was discovered

## Rejection Criteria

Reject downstream execution when any of the following occurs:

- Required fields are missing from the producer artifact.
- Metric claims appear without evidence.
- The interface changed without a compatibility statement.
- The verification report omits acceptance scope.
- Tests were modified during Implement without returning to Interface.
