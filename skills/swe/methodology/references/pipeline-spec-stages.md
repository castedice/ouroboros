# Pipeline Spec Stages — Understand, Constrain, Design, and Interface

Stages 1-4 of the SWE pipeline.
Each stage card includes: purpose, methodology anchor, key questions, procedure, output specification, DO / DON'T list, and depth-specific guidance.
This reference is self-contained — it can be consulted independently of the parent SKILL.md.
For depth decision rules, see `depth-system.md`.
For input and output contracts between stages, see `artifact-contracts.md`.

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

**Critical rule**: Never write code at the Design stage.
Resist the urge to prototype during specification — that belongs in a separate POC workflow.

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
