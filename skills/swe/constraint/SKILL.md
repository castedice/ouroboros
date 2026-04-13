---
name: swe-constraint-methodology
description: This skill provides constraint-first design methodology knowledge. It should be activated when an agent needs to "enumerate project constraints", "define design boundaries", "classify constraints as hard or soft", "analyze constraint conflicts", "apply constraint-first design", "prevent over-engineering by scoping to constraints", or "trace design decisions to constraints".
summary: Guides constraint-first design by enumerating, classifying, resolving, and tracing constraints before solution choices.
version: 1
tags: [swe, constraints, design, traceability, tradeoffs]
preamble_tier: 3
---

# Constraint-First Design Methodology

## Core Rule

**"Enumerate constraints before design, and trace every design decision back to them."**

Constraint-first design prevents both gold-plating and blind shortcuts.
The goal is not to collect every possible limitation.
The goal is to surface the constraints that actually bound the solution space before design starts.
Use the six-category sweep for coverage, the three-axis classification for clarity, and traceability to keep design right-sized.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Skipping a category because it looks irrelevant | Enumeration | Evaluate all six categories and record explicit "none identified" entries at Standard depth or above |
| Vague constraints like "must be fast" | Classification | Rewrite every important constraint into a measurable statement with timeframe and owner |
| Marking everything as `hard` | Classification | Separate non-negotiable limits from preferences and assumptions |
| Missing implicit constraints | Enumeration | Ask what a domain expert would consider non-negotiable even if nobody wrote it down |
| Ignoring conflict analysis | Resolution | Compare constraints pairwise and document which one yields or how the trade-off is staged |
| Designing beyond the constraint set | Design traceability | Reject or justify every decision that has no driving constraint |
| Letting assumptions stay vague forever | Maintenance | Give every assumption an owner and a validation path |
| Forgetting to revisit the design when a constraint changes | Change handling | Re-check every traced decision that depends on the changed constraint |

### Rationalization Red Flags

Treat these as constraint-integrity anti-drift checks before design decisions start.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Everyone already knows latency matters" | Leaving an important constraint as shared intuition | Rewrite it with metric, timeframe, owner, rigidity, source, and controllability |
| "This assumption is probably true, so design can depend on it" | Treating an unvalidated assumption as a hard design driver | Mark it as `assumption`, assign an owner, and define the validation path |
| "The best option is obvious, so conflict analysis is overhead" | Skipping pairwise conflict resolution and traceability | Record which constraint yields and cite the surviving driver in the design decision |

## Workflow

### 1. Sweep All Six Categories

Evaluate Performance, Scope, Team, Technology, Operations, and Business in order.
At Standard depth or above, every category must produce either one or more constraints or an explicit "none identified" entry.
Load `${CLAUDE_SKILL_DIR}/references/constraint-categories.md` when you need the detection questions, category definitions, or worked examples.

### 2. Classify And Rewrite Each Constraint

Assign rigidity as `hard`, `soft`, or `assumption`.
Assign source as `explicit`, `implicit`, or `discovered`.
Assign controllability as `controllable`, `shared`, or `external`.
Rewrite vague statements into the canonical form `<category> | <rigidity> | <statement with metric> | <timeframe> | <owner> | <source>`.

### 3. Resolve Conflicts And Rank Drivers

Compare constraints pairwise for tensions such as performance vs scope, technology vs team, or operations vs business.
Choose a documented resolution pattern, record which constraint yields, and rank the surviving constraints by how strongly they eliminate or shape design choices.

### 4. Enforce Traceability Through Design

Every design decision must cite at least one driving constraint.
A decision without a constraint trace is either gold-plating or a missing constraint that must be written down before proceeding.
If a constraint changes later, review every traced decision that depends on it.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Coverage discipline | At Standard depth or above, every one of the six categories must be evaluated explicitly |
| Rigidity | `hard` means violation is failure, `soft` means negotiable, and `assumption` means unverified and time-limited |
| Source | `explicit` is stated, `implicit` is domain-obvious, and `discovered` is found downstream and usually riskier |
| Controllability | `controllable` gets a local owner, `shared` needs a cross-team owner, and `external` needs contingency planning |
| Quality bar | A usable constraint is specific, measurable, time-bounded, owned, and evidence-backed |
| Conflict resolution | Use Decompose, Phase, Tier, Trade, or Escalate based on rigidity and business impact |
| Priority order | Rank first by constraints that eliminate options, then by constraints that shape options, then by softer preferences |
| Change handling | Any relaxed, tightened, or falsified constraint triggers a review of all traced design decisions |

## Reference Map

| Need | Reference |
|------|-----------|
| Category definitions, detection questions, and examples | `${CLAUDE_SKILL_DIR}/references/constraint-categories.md` |
| Vague-to-precise rewrite patterns and quality anti-patterns | `${CLAUDE_SKILL_DIR}/references/constraint-quality-examples.md` |
| Pairwise tension handling and escalation patterns | `${CLAUDE_SKILL_DIR}/references/conflict-resolution-patterns.md` |

## See Also

- `skills/swe/methodology/SKILL.md` — Hosts constraint work at Stage 2 of the SWE pipeline.
- `commands/swe/constrain.md` — Primitive command for constraint enumeration.
- `commands/swe/spec.md` — Composite command that includes Constrain in the specification pass.
