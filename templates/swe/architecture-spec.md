# Architecture Spec Template (Stage 3 — Design)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Architecture Spec: {title}

**Stage**: 3 — Design (DDD)
**Depth**: {Light | Standard | Deep}
**Task**: {task description}
**Upstream**: {path to Context Document}, {path to Constraint Profile}
**Date**: {YYYY-MM-DD}
```

---

## Design Summary <!-- [Light+] -->

At Light depth: this is the entire artifact. 3-5 sentences covering the selected approach, key rationale, and primary driving constraints.

```markdown
**Selected approach**: {pattern name + one-line description}
**Key rationale**: {why this over alternatives — reference constraint IDs}
**Driving constraints**: {list of constraint IDs that most influenced the decision}
```

---

## Alternatives Analysis <!-- [Standard+] -->

Minimum 2 alternatives at Standard, 3 at Deep. Each alternative gets a brief description, then all are compared in an evaluation matrix.

```markdown
### Alternative A: {name} — {one-line summary}
{2-3 sentences: structure, pros, cons}

### Alternative B: {name} — {one-line summary}
{2-3 sentences: structure, pros, cons}

### Evaluation Matrix

| Criterion | A: {name} | B: {name} | [C: {name}] |
|-----------|:---------:|:---------:|:-----------:|
| {constraint or quality} | {Pass/Fail/Partial} | ... | ... |
| ... | ... | ... | ... |

**Selected: Alternative {X}**. {One sentence justification referencing Hard constraints.}
```

---

## Component Breakdown <!-- [Standard+] -->

Module layout as a tree, then per-component detail.

```markdown
### Module Layout

{ASCII tree showing directory/module structure}

### {Component N}: {name} (`{path}/`)

- **Responsibility**: {single sentence}
- **Key types/traits**: {list}
- **Dependencies**: {which other components it uses}
- **Boundary**: {what it does NOT do}
```

Trait/interface signatures go here as code blocks — these are design-level signatures, not final contracts (Stage 4 refines them).

---

## Data Model <!-- [Standard+] -->

Key data structures in the target language. Mark entities vs value objects vs transient types.

```markdown
// === Entities ===
{code block with struct/class definitions}

// === Value Objects ===
{code block}

// === Transient ===
{code block}
```

If storage estimates are relevant, include a size table:

```markdown
### Storage Estimate ({scale})

| Store | Format | Size |
|-------|--------|------|
| {store name} | {format} | {estimated size} |
```

---

## Algorithm Rationale <!-- [Standard+] -->

One subsection per major algorithm choice. Each must reference driving constraints.

```markdown
### {Algorithm Name}: {technique}

{2-3 sentences: what it does, why this technique, key parameters.}

**Driving**: {constraint IDs}
```

---

## Constraint Traceability Matrix <!-- [Standard+] -->

Every design decision must trace to at least one constraint. Orphan decisions (no constraint) must be flagged and justified.

```markdown
| # | Design Decision | Driving Constraint(s) | Rationale |
|---|----------------|----------------------|-----------|
| D-{nn} | {decision} | {constraint IDs} | {why this satisfies the constraint} |
```

Footer: `{N}/{N} decisions traced. {0 or N} orphan decisions.`

---

## C4 Architecture <!-- [Deep] -->

Context and Container level diagrams as ASCII. Component level if system is complex.

```markdown
### Context Level
{ASCII diagram: system boundary, external actors, external systems}

### Container Level
{ASCII diagram: internal containers/processes, data stores, communication}
```

---

## ADRs <!-- [Deep] -->

One ADR per significant decision. Use 3-field format (Nygard-inspired).

```markdown
| ADR | Context | Decision | Consequences |
|-----|---------|----------|-------------|
| {nn} | {why this decision was needed — problem context} | {what was decided} | {positive and negative consequences, trade-offs accepted} |
```

---

## Data Flow <!-- [Deep] -->

Separate write path and read path (or equivalent flows for the domain).

```markdown
### Write Path
{ASCII flow: input → processing stages → output/storage}

### Read Path
{ASCII flow: query → processing stages → result}
```

---

## Deployment View <!-- [Deep] -->

How the system is built, packaged, and delivered. Connects to Operations constraints.

```markdown
### Build
{Build toolchain, compilation targets, CI pipeline}

### Package
{Binary format, dependencies bundled vs external, artifact size}

### Deliver
{Distribution channels, installation steps, first-run experience}

**Driving**: {OP constraint IDs}
```

---

## Dependency Map <!-- [Deep] -->

External dependencies with license and phase information.

```markdown
| Dependency | Purpose | License | Phase |
|-----------|---------|---------|-------|
| {name} | {why needed} | {license} | {which delivery phase} |
```

Footer: `All {license types}. {constraint ID} satisfied.`

---

## Risk Register <!-- [Deep] -->

```markdown
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| {what could go wrong} | {Low/Medium/High} | {Low/Medium/High} | {how to prevent or respond} |
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] Every design decision traces to at least one constraint (Standard+)
- [ ] No orphan decisions without justification (Standard+)
- [ ] Complexity and failure modes acknowledged (Standard+)
- [ ] Interface definitions sufficient to start Stage 4 without ambiguity (Standard+)
- [ ] {At Deep} All significant decisions have ADRs
- [ ] {At Deep} Deployment view covers build → package → deliver
```
