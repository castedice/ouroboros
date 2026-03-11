# Artifact Contracts — Stage Input/Output Specifications

Each pipeline stage produces an output artifact that serves as the input contract for the next stage. Breaking a downstream assumption requires going back to the producing stage and updating the artifact.

This reference is self-contained — it can be consulted independently of the parent SKILL.md. For stage procedures, see `pipeline-stages.md`. For depth-specific output forms, see `depth-system.md`.

## Contract Chain

```text
[Understand] → Context Document
                  ↓ input
[Constrain]  → Constraint Profile
                  ↓ input
[Design]     → Architecture Spec
                  ↓ input
[Interface]  → Interface Contracts
                  ↓ input
[Test]       → Test Suite (failing)
                  ↓ input
[Implement]  → Source Code (tests passing)
                  ↓ input
[Verify]     → Verification Report
                  ↓ input
[Optimize]   → Optimization Report
```

Each arrow represents a contract: the downstream stage may assume the upstream artifact is complete and accurate at the chosen depth level. If the downstream stage discovers the upstream artifact is incomplete, the correct action is to return upstream and update — not to proceed with assumptions.

## Path Conventions

Artifacts are stored in two locations based on lifecycle state:

### Active (Current Turn)

| Stage | File |
|-------|------|
| Understand | `.swe/active/01-understand.md` |
| Constrain | `.swe/active/02-constrain.md` |
| Design | `.swe/active/03-design.md` |
| Interface | `.swe/active/04-interface.md` |
| Test | `.swe/active/05-test.md` |
| Implement | `.swe/active/06-implement.md` |
| Verify | `.swe/active/07-verify.md` |
| Optimize | `.swe/active/08-optimize.md` |
| Ship | `.swe/active/09-ship.md` |
| Tune | `.swe/active/10-tune.md` |

### Record (Completed Turns)

`docs/specs/record/{package}/{NNN}-{task-slug}/{NN}-{stage}.md`

- `{package}`: auto-detected from manifest or "default"
- `{NNN}`: zero-padded sequential number within package
- `{task-slug}`: lowercase-hyphenated task description
- `{NN}-{stage}`: same as active numbering

### Project Model (Living Documents)

`docs/specs/project/{name}.md` — cumulative specification that evolves across spiral turns.

| File | Stage | Content |
|------|-------|---------|
| `docs/specs/project/domain.md` | 1 | Cumulative domain model: entities, bounded contexts, ubiquitous language |
| `docs/specs/project/constraints.md` | 2 | Cumulative constraint profile: all constraints with feature attribution |
| `docs/specs/project/architecture.md` | 3 | Cumulative architecture spec: components, decisions, patterns |
| `docs/specs/project/interfaces.md` | 4 | Cumulative interface contracts: module boundaries, types, invariants |

Project model files are initialized via `scripts/artifact-lifecycle.sh init-project` and updated after each spiral turn (Phase 10.6) or standalone tune (Phase 6.5). They serve as context for the next turn's specification stages. The merge is additive — entries are appended or updated, never removed. See DR-067.

### Knowledge Base

`docs/specs/knowledge/{entry}.md` — research entries and accumulated patterns.

| File | Content |
|------|---------|
| `docs/specs/knowledge/INDEX.md` | Auto-generated entry table + tag index |
| `docs/specs/knowledge/{topic}.md` | Individual knowledge entries with YAML frontmatter |

Knowledge entries are created via `/core absorb` and indexed via `scripts/knowledge-catalog.sh index`.

### Monorepo Layout

In monorepo workspaces, artifacts are scoped per subproject:

| Scope | Active | Specs |
|-------|--------|-------|
| Root (repo-wide) | `.swe/active/` | `docs/specs/` |
| Subproject | `packages/{pkg}/.swe/active/` | `packages/{pkg}/docs/specs/` |

Each subproject maintains independent `project/`, `record/`, and `knowledge/` directories. Root-level docs contain only repo-wide cross-cutting concerns.

**Cross-cutting artifacts**: When work primarily affects one subproject but impacts others, the artifact includes an `**Affects**: [pkg1, pkg2]` header field. Affected subprojects receive a link stub in their record pointing to the primary artifact.

## Per-Stage Contracts

### Stage 1: Understand → Context Document

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Problem Statement | Always | What problem are we solving, for whom |
| Domain Model | Standard+ | Entities, value objects, relationships |
| Affected Components | Always | Files, modules, services that will change |
| Success Criteria | Always | Measurable conditions for "done" |
| Ubiquitous Language | Standard+ | Glossary of domain terms with precise definitions |
| Bounded Contexts | Deep | Module boundaries and ownership |

**Consumed by**: Constrain (scope context), Design (domain model), Verify (success criteria)

### Stage 2: Constrain → Constraint Profile

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Constraint List | Always | Constraints organized by 6 categories |
| Hard/Soft Classification | Always | Each constraint marked as non-negotiable or flexible |
| Measurable Thresholds | Standard+ | Numeric bounds for each constraint |
| Conflict Analysis | Standard+ | Where constraints tension each other |
| Priority Ranking | Deep | Ordered by importance for trade-off resolution |

**Consumed by**: Design (design boundaries), Interface (performance contracts), Optimize (performance targets)

### Stage 3: Design → Architecture Spec

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Architectural Pattern | Always | Selected pattern with rationale |
| Component Breakdown | Standard+ | Modules, services, layers and their responsibilities |
| Data Model | Standard+ | Key data structures with type definitions |
| Algorithm Rationale | Standard+ | Why this algorithm/data structure was chosen |
| Constraint Traceability | Standard+ | Each design decision linked to its driving constraint |
| Alternatives Considered | Deep | Other approaches evaluated with trade-off analysis |

**Consumed by**: Interface (component boundaries), Implement (structural guidance), Verify (spec compliance)

### Stage 4: Interface → Interface Contracts

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Public Interfaces | Always | Function signatures, API endpoints, event schemas |
| Type Definitions | Always | Input/output types with precision (no `any`) |
| Error Conditions | Standard+ | Error types, codes, recovery paths |
| Invariants | Standard+ | Conditions that must always hold |
| Usage Examples | Standard+ | Code showing how to call each interface |
| Compatibility Matrix | Deep | Version compatibility, migration paths |

**Consumed by**: Test (test targets), Implement (contracts to fulfill), Verify (integration boundaries)

### Stage 5: Test → Test Suite

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Unit Tests | Always | Tests per interface contract, named descriptively |
| Red State Confirmation | Always | Evidence that tests fail before implementation |
| Edge Case Tests | Standard+ | Boundary conditions, error paths |
| Integration Tests | Deep | Cross-component interaction tests |
| Property-Based Tests | Deep | Generative tests for invariant verification |

**Consumed by**: Implement (Green target), Verify (test baseline), Optimize (regression guard)

### Stage 6: Implement → Source Code

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Source Code | Always | Implementation that passes all tests |
| Green State Confirmation | Always | Evidence that all tests pass |
| Inline Documentation | Standard+ | Docstrings, type annotations, comments for non-obvious code |
| Commit History | Standard+ | Meaningful commits per Red-Green-Refactor cycle |

**Consumed by**: Verify (verification target), Optimize (optimization target)

### Stage 7: Verify → Verification Report

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Acceptance Criteria Check | Always | Each criterion from Context Document: pass/fail |
| Smoke Test Results | Always | Build status, execution status, error output if any |
| Spec Compliance Check | Standard+ | Implementation vs Architecture Spec alignment |
| Integration Test Results | Standard+ | Cross-component interaction validation |
| Deviation Documentation | As needed | Any divergences from spec with rationale |

**Consumed by**: Optimize (verification baseline), tune retrospect (quality data)

### Stage 8: Optimize → Optimization Report

**Produces**:

| Field | Required | Description |
|-------|----------|-------------|
| Profiling Results | Standard+ | Bottleneck identification with data |
| Optimizations Applied | Always | What was changed and why |
| Before/After Measurements | Standard+ | Quantified improvement per optimization |
| Remaining Tech Debt | As needed | Known issues deferred with rationale |

**Consumed by**: tune retrospect (performance data, tech debt backlog)

## Artifact Summary Convention

Every artifact must start with a `## Summary` section (3-5 sentences) immediately after the metadata header. This summary enables downstream stages to load only the summary when full content is not required, reducing context window consumption.

```markdown
# {Artifact Title}: {task summary}

**Stage**: {N} — {Name}
**Depth**: {depth}
...

---

## Summary
> {3-5 sentences: key decisions, primary outputs, critical findings}

## Full Content
...
```

Agent instructions must include: "Start your output with a `## Summary` section (3-5 sentences capturing the key decisions and outputs), then continue with the full content."

## Selective Load Matrix

Downstream stages can load upstream artifacts as **full** (entire content) or **summary** (first ~15 lines, covering the Summary section). At Light depth, optional artifacts load as summary only to conserve context window.

| Downstream Stage | Required (always full) | Optional (summary at Light depth) |
|------------------|------------------------|-----------------------------------|
| S2 Constrain | S1 Context Document | — |
| S3 Design | S2 Constraint Profile | S1 Context Document |
| S4 Interface | S3 Architecture Spec | S1 Context Document, S2 Constraint Profile |
| S5 Test | S4 Interface Contracts | S3 Architecture Spec |
| S6 Implement | S4 Interface Contracts, S5 Test Suite | S1 Context Document, S2 Constraint Profile, S3 Architecture Spec |
| S7 Verify | S4 Interface Contracts, S6 Implementation | S1 Context Document, S2 Constraint Profile, S3 Architecture Spec, S5 Test Suite |
| S8 Optimize | S2 Constraint Profile, S3 Architecture Spec, S7 Verification | S1 Context Document, S4 Interface Contracts, S5 Test Suite, S6 Implementation |

**Loading rules**:

- **Required** artifacts → always read in full (`Read(file)`)
- **Optional** artifacts at Standard/Deep depth → read in full
- **Optional** artifacts at Light depth → read summary only (`Read(file, limit: 15)`)

## Contract Quality Gates

Every artifact must pass these quality gates before the downstream stage may begin:

| Gate | Condition |
|------|-----------|
| **Completeness** | All required fields present at the chosen depth level |
| **Traceability** | Decisions and behaviors trace to prior artifacts |
| **Consistency** | No conflict with upstream contracts |
| **Evidence** | Claims are backed by tests, measurements, or cited sources |

A downstream stage may reject an upstream artifact that fails any quality gate. The rejection is documented and the upstream stage is reopened.

## Backward Transition Protocol

When a downstream stage discovers an upstream gap:

1. **Identify** the specific gap — what is missing or incorrect in the upstream artifact
2. **Document** the gap — add it to the current stage's notes
3. **Return** to the upstream stage — update the artifact to fill the gap
4. **Cascade** downstream — check if the update affects intervening stages
5. **Resume** from the current stage with the updated upstream artifact

Example: During Implement (Stage 6), you discover that Interface (Stage 4) did not define error handling for a particular edge case. Return to Interface, add the error contract, return to Test (Stage 5) to add the missing test case, then return to Implement.

Backward transitions are not failures — they are the system working correctly. The pipeline is designed to surface gaps early. A backward transition in Test is cheaper than discovering the gap in production.

## Contract Delta Note Format

When revising a previously-completed artifact, document the change:

- **Artifact**: name and stage
- **Expected**: previous assumption
- **Actual**: observed condition
- **Impact**: stages/components affected
- **Change**: specific contract update
- **Owner**: responsible role
- **Timestamp**: when the delta was discovered

## Rejection Criteria

Reject downstream execution when any of the following occurs:

- Required fields missing from producer artifact
- Metric claims appear without evidence
- Interface changed without compatibility statement
- Verification report omits acceptance scope
- Tests modified during Implement stage without returning to Interface
