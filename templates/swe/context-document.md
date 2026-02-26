# Context Document Template (Stage 1 — Understand)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Context Document: {title}

**Stage**: 1 — Understand (DDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Date**: {YYYY-MM-DD}
```

---

## Problem Statement <!-- [Light+] -->

Three subsections. At Light depth, 2-3 sentences each. At Standard+, full paragraphs.

```markdown
### Who
- **Primary users**: {who directly uses the system}
- **Secondary users**: {who consumes outputs or integrates}
- **Stakeholders**: {who cares about the outcome}

### What
{What behavior changes — new, modified, or removed. Enumerate each capability.}

### Why
{Business value or technical necessity. Why now, why this approach.}
```

---

## Affected Components <!-- [Light+] -->

At Light depth: 3-5 bullet points with name + one-line responsibility.
At Standard+: full table with boundaries.

```markdown
### {Component N}: {name}
- **Responsibility**: {what it owns}
- **Key capabilities**: {what it does}
- **Boundary**: {what it does NOT do — delegates to whom}
```

---

## Ubiquitous Language <!-- [Light+] -->

Fixed column schema. At Light depth: 5-10 key terms. At Standard+: comprehensive.

```markdown
| Term | Definition | Context |
|------|-----------|---------|
| {term} | {precise definition} | {which components use this term} |
```

---

## Domain Model <!-- [Standard+] -->

### Entities

```markdown
| Entity | Description | Identity |
|--------|-------------|----------|
| {name} | {what it represents} | {how instances are uniquely identified} |
```

### Value Objects

```markdown
| Value Object | Description | Constraints |
|-------------|-------------|-------------|
| {name} | {what it represents} | {invariants, valid ranges, format rules} |
```

### Relationships

ASCII diagram showing entity relationships with cardinality.

```markdown
{Entity A}
  └── {cardinality} {Entity B}
        └── {cardinality} {Value Object}
```

Below the diagram: prose explanation of each relationship with cardinality rationale.

---

## Success Criteria <!-- [Standard+] -->

Three tables with fixed schemas.

### Behavioral Criteria

```markdown
| ID | Criterion | Verification Method |
|----|-----------|-------------------|
| B{n} | {what the system does} | {how to verify — test strategy, not implementation} |
```

### Quality Criteria

```markdown
| ID | Criterion | Threshold |
|----|-----------|-----------|
| Q{n} | {measurable quality attribute} | {specific number with unit and conditions} |
```

### Exclusion Criteria

```markdown
| ID | Exclusion | Rationale |
|----|-----------|-----------|
| E{n} | {what is explicitly out of scope} | {why excluded — complexity, timeline, or value} |
```

---

## User Scenarios <!-- [Standard+] -->

2-4 key usage scenarios. Each scenario is a concrete step-by-step interaction (CLI command, API call, or workflow). These serve as seeds for Stage 5 (Test).

```markdown
### Scenario {N}: {title}

**Actor**: {who}
**Precondition**: {system state before}

1. {User action}
2. {System response}
3. {User action}
4. {System response}

**Postcondition**: {system state after}
**Relates to**: {B{n} criteria reference}
```

---

## Context Map <!-- [Deep] -->

Bounded Context relationships using DDD patterns (upstream/downstream, conformist, anticorruption layer, shared kernel, etc.).

```markdown
### Bounded Contexts

| Context | Owns | Key Entities |
|---------|------|-------------|
| {name} | {domain area} | {entities within this context} |

### Context Relationships

{ASCII diagram showing BC relationships}

{Context A} ──[relationship type]──> {Context B}

{Prose explanation of each relationship: who is upstream, who conforms, where translation layers exist.}
```

---

## Stakeholder Analysis <!-- [Deep] -->

```markdown
| Stakeholder | Concern | Influence | Impact |
|-------------|---------|-----------|--------|
| {who} | {what they care about} | {High/Medium/Low} | {how this task affects them} |
```

---

## Existing Code Audit <!-- [Deep] -->

For brownfield tasks. Skip for greenfield.

```markdown
### Relevant Code

| File/Module | Role | Lines | Complexity | Notes |
|-------------|------|-------|-----------|-------|
| {path} | {what it does} | {approx} | {High/Med/Low} | {patterns, tech debt, risks} |

### Patterns Observed
- {Pattern}: {where and how it's used}

### Technical Debt
- {Debt item}: {impact on this task}
```

---

## Open Questions <!-- [Light+] -->

Fixed column schema. Every ambiguity must be recorded — never silently resolved.

```markdown
| ID | Ambiguity | Impact | Recommended Resolution |
|----|-----------|--------|----------------------|
| A{n} | {what is unclear} | {which downstream decisions are blocked} | {which stage resolves it, or "User decision needed"} |
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] Ubiquitous language stable enough to write constraints
- [ ] Component/context boundaries explicit
- [ ] Unknowns enumerated with resolution owners
- [ ] {At Standard+} Success criteria are measurable
- [ ] {At Deep} Context Map relationships defined
```
