---
name: entity-discovery
description: This reference defines the ingress rules and discovery workflows for vault and life entities in the PA ontology. It should be consulted when an agent needs to "discover vault entities", "create life entities from profile state", "choose structural source priorities", "assign entity confidence", or "build entity candidates before canonicalization".
---

# Entity Discovery — Ingress Rules For Vault And Life Entities

> Purpose: Reference for `personal-ontology` — use it to decide where entities may come from and how discovery proceeds before relation typing.
> This reference is standalone and can be used without the parent skill.
> Canonicalization rules live in `references/entity-canonicalization.md`.

## Ontology Families

Always record `ontology_family` on every entity.

| Family | Source Of Truth | Creation Rule | Typical Kinds |
|--------|-----------------|---------------|---------------|
| `vault` | Structural vault scan | Requires structural note evidence | `person`, `organization`, `place`, `education`, `project`, `topic`, `event`, `artifact`, `concept` |
| `life` | Personal profile or approved overlays | Requires confirmed profile or overlay identity | `area`, `goal`, `direction`, `value`, `habit`, `milestone` |

Shared names do not justify shared identity across families.

## Vault Entity Source Priority

Use stronger structural evidence before weaker signals.

| Priority | Source | Why It Counts |
|----------|--------|---------------|
| 1 | Wikilinks | Intentional author reference |
| 2 | Note titles or dedicated notes | First-class entity candidate |
| 3 | Frontmatter fields | Structured metadata with stable semantics |
| 4 | Repeated headings | Weak but sometimes meaningful structural recurrence |
| 5 | Semantic clusters | Suggestion only, never standalone evidence |

Do not create a vault entity from prose interpretation alone.

## Life Entity Source Priority

Use confirmed life state before vault reinforcement.

| Priority | Source | Why It Counts |
|----------|--------|---------------|
| 1 | `personal-profile.json` | User-owned structured state |
| 2 | Approved interview output written into the profile | Explicit confirmation |
| 3 | Operational overlays such as `work.jsonl` or `timeline.jsonl` | Approved assistant-side life state |
| 4 | Vault reinforcement | Raises confidence but does not create identity alone |

## Shared Entity Fields

Every entity should keep these fields as early as discovery makes possible.

| Field | Meaning |
|-------|---------|
| `canonical_name` | Primary display or masked name |
| `ontology_family` | `vault` or `life` |
| `canonical_source` | The authoritative note path, profile field, or overlay pointer |
| `kind` | The entity kind appropriate to the family |
| `confidence` | Discovery confidence before later refresh |
| `provenance` | Which pass or workflow created the entity |
| `first_seen` | Earliest known discovery timestamp |
| `source_notes` | Notes that observed or reinforced the entity |

Detailed life and person schema rules live in the sibling references.

## Vault Entity Workflow

### 1. Structural Scan

Extract wikilinks, note titles, matching frontmatter fields, and repeated headings from the scanned notes.
Record the source note for every observation.

### 2. Candidate Assembly

Normalize names, group repeated signals, and discard one-off weak mentions.
A vault entity candidate should appear in at least 2 structural sources, 2 distinct notes, or 2 signal types before it proceeds.

### 3. Kind Inference

Infer a provisional `kind` from the dominant signal context.
Frontmatter `people` fields lean toward `person`, tag-like frontmatter leans toward `topic`, and dedicated project notes lean toward `project`.

### 4. Canonicalization Handoff

Send the surviving candidates to canonicalization before committing them as live entities.
Alias resolution, collision protection, and privacy application happen after this step.

### 5. Confidence Assignment

| Evidence Pattern | Confidence |
|------------------|------------|
| Dedicated note plus several supporting structural signals | `high` |
| Multiple strong structural signals without a dedicated note | `medium` |
| Minimal qualifying evidence from weak structural sources | `low` |

Semantic-only suggestions do not become entities.

## Life Entity Workflow

### 1. Read Profile And Overlay State

Load `identity.core_areas`, `focus.current_focus`, values, directions, habits, and milestone pointers from the approved sources.

### 2. Create Life Entities Directly

Create `life` entities directly from their authoritative profile field or overlay pointer.
Do not require repeated structural evidence to create them.

### 3. Attach Reinforcement

Look for supporting wikilinks, note titles, or dedicated notes that operationalize the life entity.
Use that reinforcement to raise confidence and attach `source_notes` or `canonical_note`.

### 4. Seed Life Relations

Create the obvious life-entity links once the entities exist.
Typical seeded relations are `belongs-to-area`, `advances-direction`, `guided-by-value`, and `embodies`, but only when their evidence rules are satisfied.

## Hard Boundaries

| Boundary | Rule |
|----------|------|
| Vault prose | Vault prose may suggest candidates, but structural signals still decide vault-entity creation |
| Cross-family merge | Never merge `vault` and `life` entities automatically |
| Operational duplication | Habits and milestones may point into overlays instead of copying the full overlay payload into the ontology |
| User-visible output | Discovery writes to `.pa/` state only unless the user explicitly asks for notes or maps |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill |
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | Alias resolution and merge safety |
| `skills/pa/personal-ontology/references/life-entities.md` | Detailed life-entity schema |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | Privacy fields for sensitive entities |
