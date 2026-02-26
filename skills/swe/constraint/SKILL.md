---
name: swe-constraint-methodology
description: This skill provides constraint-first design methodology knowledge. It should be activated when an agent needs to "enumerate project constraints", "define design boundaries", "classify constraints as hard or soft", "analyze constraint conflicts", "apply constraint-first design", "prevent over-engineering by scoping to constraints", or "trace design decisions to constraints".
---

# Constraint-First Design Methodology

## Core Principle

**"Enumerate constraints before design. Every design decision must trace to at least one constraint."**

Constraint-first design prevents both over-engineering and under-engineering. Over-engineering happens when design adds capabilities that no constraint requires — gold-plating driven by "it might be useful." Under-engineering happens when design ignores constraints — shortcuts that create tech debt. By enumerating constraints first and tracing every design decision to a specific constraint, the design is right-sized by construction.

Why constraints before design rather than during? Because once design begins, the mind is captured by the solution. Constraints enumerated during design are filtered through the solution lens — you find the constraints that justify your design rather than constraints that shape it. Upfront enumeration forces honest assessment of the problem space before the solution space opens.

## Six Constraint Categories

Six categories provide comprehensive coverage of the constraint space. Systematically evaluating all six prevents blind spots — the most common constraint failures come from categories that "didn't seem relevant" and were never evaluated.

| # | Category | Key Concern |
|---|----------|-------------|
| 1 | **Performance** | Speed, throughput, resources |
| 2 | **Scope** | Timeline, boundaries, exclusions |
| 3 | **Team** | Skills, expertise, learning curve |
| 4 | **Technology** | Language, framework, infra, compatibility |
| 5 | **Operations** | Deployment, monitoring, maintenance |
| 6 | **Business** | Budget, compliance, licensing, stakeholders |

For detailed descriptions, detection questions, and examples per category, see `references/constraint-categories.md`.

## Constraint Classification

Every constraint is classified on three axes:

### Axis 1: Rigidity (Hard / Soft / Assumption)

| Classification | Definition | Example |
|---------------|------------|---------|
| **Hard** | Non-negotiable — violation is a project failure | "Must comply with GDPR" |
| **Soft** | Preferred but flexible — can be traded against other constraints | "Prefer latency < 100ms, acceptable up to 200ms" |
| **Assumption** | Unverified belief — must have expiry date and validation owner | "Database can handle 10x current load (unverified)" |

### Axis 2: Source (Explicit / Implicit / Discovered)

| Source | Definition | Risk Level |
|--------|------------|------------|
| **Explicit** | Stated in requirements | Low — already known |
| **Implicit** | Industry standard or obvious to domain experts | Medium — may be missed |
| **Discovered** | Revealed during analysis or downstream stages | High — causes backward transitions |

### Axis 3: Controllability

| Type | Definition | Execution Treatment |
|------|------------|-------------------|
| **Controllable** | Local team can change directly | Assign engineering owner |
| **Shared** | Depends on other teams | Assign cross-team owner and SLA |
| **External** | Vendor, legal, market, regulator | Track contingency and escalation owner |

Implicit constraints are the highest-risk category for omission. They are "obvious" only to people with domain experience. Always check: "What would a domain expert consider non-negotiable that isn't written anywhere?"

## Constraint Quality Standard

A constraint is acceptable only if it is:

- **Specific**: clear subject and boundary
- **Measurable**: numeric threshold or binary compliance rule
- **Time-bounded**: release or operational timeframe
- **Owned**: named decision owner
- **Evidence-backed**: source or measurement record

Reject vague statements such as "must be fast" or "team can probably learn this." Convert into measurable constraints with dates and owners. For transformation examples (vague → precise) per category, see `references/constraint-quality-examples.md`.

### Constraint Statement Template

Use this canonical format for each constraint:

```text
<category> | <rigidity> | <statement with metric> | <timeframe> | <owner> | <source>
```

Example: `Performance | Hard | P95 latency ≤ 200ms at 1000 RPS | Q2 release | Platform lead | load-test-2026-02-10`

## Constraint Enumeration Procedure

### Step 1: Systematic Category Sweep

Walk through all 6 categories. For each category, ask the detection questions from `references/constraint-categories.md`. Record every constraint, even tentative ones.

**Minimum coverage rule**: At Standard depth or above, every category must have at least one entry — even if the entry is "No constraints identified in this category." This forces conscious evaluation rather than silent omission.

### Step 2: Classify Each Constraint

For each constraint:
- Assign Rigidity: Hard, Soft, or Assumption
- Assign Source: Explicit, Implicit, or Discovered
- Assign Controllability: Controllable, Shared, or External
- Express as a measurable threshold where possible

### Step 3: Identify Conflicts

Compare constraints pairwise for tensions. Common conflict pairs: Performance vs Scope, Technology vs Team, Operations vs Business. For resolution strategies (Decompose, Phase, Tier, Trade, Escalate) and escalation protocol, see `references/conflict-resolution-patterns.md`.

Document each conflict with its resolution strategy: which constraint yields, or what compromise is reached.

### Step 4: Priority-Rank (Standard+ Depth)

Rank constraints by impact on design decisions:
1. Hard constraints that eliminate design alternatives
2. Hard constraints that shape design alternatives
3. Soft constraints that prefer certain alternatives
4. Soft constraints that are nice-to-have

## Constraint-to-Design Traceability

During the Design stage (Stage 3), every design decision must reference at least one constraint that necessitates it. Traceability is documented as a simple table:

| Design Decision | Driving Constraint(s) | Rationale |
|----------------|----------------------|-----------|
| Use PostgreSQL | Technology: "Must use PostgreSQL" (Hard) | Explicit technology requirement |
| Event-driven architecture | Performance: "< 200ms latency" (Hard) + Scope: "No synchronous blocking" (Soft) | Async processing meets latency constraint without blocking |
| No ML pipeline | Team: "No ML expertise" (Hard) + Scope: "2-week deadline" (Soft) | Team cannot learn ML tooling within timeline |

**Orphan detection**: A design decision with no constraint reference is a candidate for removal. Ask: "If no constraint requires this, why are we building it?" Legitimate answers exist (foundational infrastructure, enabling future work), but they should be documented as Soft constraints added during design, not left unjustified.

## Constraint Evolution

Constraints are not static — they change during the project lifecycle:

| Event | Action |
|-------|--------|
| New constraint discovered downstream | Add to Constraint Profile, cascade to affected stages |
| Constraint relaxed by stakeholder | Update classification (Hard → Soft), re-evaluate designs that were limited by it |
| Constraint conflict becomes blocking | Escalate to stakeholder for priority decision |
| Performance profiling reveals new limits | Add as Discovered constraint in Performance category |
| Assumption proven false | Reclassify as Hard/Soft based on evidence, cascade to Design |

Every constraint change triggers a review of design decisions that traced to the changed constraint.

## Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Skipping "obvious" categories | Evaluate all 6 categories — blind spots hide in "obvious" areas |
| Vague constraints ("fast enough") | Express as measurable thresholds (latency < 200ms) |
| All constraints marked Hard | Distinguish genuinely non-negotiable from preferred |
| No conflict analysis | Pairwise comparison reveals hidden tensions |
| Constraints as afterthought | Enumerate BEFORE design — not during, not after |
| Gold-plating (designing beyond constraints) | Every design decision needs a constraint reference |
| Missing implicit constraints | Ask: "What would a domain expert consider non-negotiable?" |
| Stale assumptions | Set expiry date and validation owner for every Assumption |

## Validation Checklist

Verify that constraint-first design is being applied correctly:

- [ ] All 6 constraint categories evaluated (even if some are empty)
- [ ] Each constraint classified on all 3 axes (rigidity, source, controllability)
- [ ] Constraints expressed as measurable thresholds where possible
- [ ] Constraint conflicts identified and documented
- [ ] Every design decision traces to at least one constraint
- [ ] No orphan design decisions (decisions without constraint justification)
- [ ] Implicit constraints explicitly surfaced and documented
- [ ] Assumptions have expiry dates and validation owners
- [ ] Constraint changes cascade to affected downstream stages

## See Also

- **swe-pipeline-methodology** (`skills/swe/methodology/SKILL.md`) — The pipeline that hosts constraint enumeration at Stage 2 (Constrain)
- **`/swe constrain`** (`commands/swe/constrain.md`) — Primitive command for constraint enumeration (Batch 2)
- **`/swe spec`** (`commands/swe/spec.md`) — Composite command that includes Constrain as Stage 2 (Batch 2)
