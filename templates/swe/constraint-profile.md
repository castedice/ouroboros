# Constraint Profile Template (Stage 2 — Constrain)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Constraint Profile: {title}

**Stage**: 2 — Constrain (SDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Upstream**: {path to Context Document}
**Date**: {YYYY-MM-DD}
```

---

## Constraint Summary <!-- [Light+] -->

At Light depth: this is the entire artifact. 3-5 dominant constraints with Hard/Soft classification and one-line threshold.

```markdown
| # | Constraint | Rigidity | Threshold |
|---|-----------|----------|-----------|
| 1 | {most impactful constraint} | Hard | {measurable threshold} |
| 2 | ... | ... | ... |
```

---

## Category Tables <!-- [Standard+] -->

Six category tables, one per category. Every category must have at least one entry at Standard+ depth. All tables use the same fixed column schema.

### Column Schema (fixed — do not vary)

```markdown
| ID | Constraint | Rigidity | Source | Controllability | Threshold | Timeframe | Owner | Evidence |
|----|-----------|----------|--------|----------------|-----------|-----------|-------|----------|
```

Column definitions:

- **ID**: `{category prefix}-{nn}` (PF, SC, TM, TC, OP, BU)
- **Constraint**: specific, measurable statement
- **Rigidity**: Hard (non-negotiable) / Soft (flexible) / Assumption (unverified)
- **Source**: Explicit (stated) / Implicit (industry standard) / Discovered (found during analysis)
- **Controllability**: Controllable (local team) / Shared (cross-team) / External (vendor, legal)
- **Threshold**: measurable number with unit and conditions. No "should be fast"
- **Timeframe**: when this constraint applies (e.g., v1 release, ongoing)
- **Owner**: who is responsible for satisfying this constraint
- **Evidence**: data source, benchmark reference, or codebase citation

### Categories

```markdown
## 1. Performance
{table}

## 2. Scope
{table}

## 3. Team
{table}

## 4. Technology
{table}

## 5. Operations
{table}

## 6. Business
{table}
```

---

## Conflict Analysis <!-- [Standard+] -->

Fixed column schema. Compare constraints pairwise for tensions. Apply resolution strategies: Decompose, Phase, Tier, Trade, Escalate.

```markdown
| ID | Constraint A | Constraint B | Tension | Strategy | Resolution | Yields | Risk |
|----|-------------|-------------|---------|----------|------------|--------|------|
| C-{nn} | {ID + name} | {ID + name} | {what conflicts} | {Decompose/Phase/Tier/Trade/Escalate} | {how resolved} | {what was given up} | {residual risk} |
```

---

## Open Questions Resolution <!-- [Standard+] -->

Explicit resolution of Open Questions from Stage 1 Context Document. Every A{n} must be addressed.

```markdown
| Stage 1 ID | Question | Resolution | Resolved As |
|-----------|----------|------------|-------------|
| A{n} | {original question from Context Document} | {how it was resolved — which constraint captures it} | {constraint ID, e.g., TC-01} |
```

---

## Assumption Registry <!-- [Standard+] -->

Track every Assumption-rigidity constraint. Each assumption needs a validation plan and fallback.

```markdown
| ID | Assumption | Depends On | Validation | Deadline | Fallback |
|----|-----------|-----------|------------|----------|----------|
| {constraint ID} | {what is assumed} | {which decisions break if wrong} | {how to verify} | {by when} | {plan B} |
```

---

## Priority Ranking <!-- [Deep] -->

Four tiers ordered by design impact.

```markdown
### Tier 1: Hard — Eliminates alternatives
| Rank | ID | Constraint | Eliminates |
|------|-----|-----------|------------|

### Tier 2: Hard — Shapes alternatives
| Rank | ID | Constraint | Shapes |
|------|-----|-----------|--------|

### Tier 3: Soft — Prefers alternatives
| Rank | ID | Constraint | Prefers |
|------|-----|-----------|---------|

### Tier 4: Nice-to-have
| Rank | ID | Constraint | Note |
|------|-----|-----------|------|
```

---

## Trade-off Matrix <!-- [Deep] -->

One table per major technology or approach decision. Compare alternatives against driving constraints.

```markdown
### {Decision Name}: {Option A} vs {Option B} [vs {Option C}]

| Dimension | {Option A} | {Option B} | [{Option C}] |
|-----------|-----------|-----------|-------------|
| {Constraint ID + name} | {assessment + ✓/△/✗} | ... | ... |
| ... | ... | ... | ... |
| **Decision** | **{Selected}** | {reason rejected} | {reason rejected} |
```

---

## Constraint Interaction Diagram <!-- [Deep] -->

ASCII diagram showing how constraints influence each other. Use labeled edges: `eliminates`, `shapes`, `reinforces`, `conflicts`, `forces`.

```markdown
{Constraint A} ──{relationship}──→ {Constraint B}
       │{relationship}
       ▼
{Constraint C} ←─{relationship}─→ {Constraint D}
```

Below diagram: prose explanation of key interaction chains.

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] All 6 categories swept (Standard+)
- [ ] 3-axis classification on every constraint (Standard+)
- [ ] Measurable thresholds on all Hard constraints
- [ ] Conflict analysis complete with resolution strategies (Standard+)
- [ ] Stage 1 Open Questions resolved or escalated (Standard+)
- [ ] Assumption registry populated (Standard+)
- [ ] {At Deep} Priority ranking covers all constraints
- [ ] {At Deep} Trade-off matrices for major decisions
```
