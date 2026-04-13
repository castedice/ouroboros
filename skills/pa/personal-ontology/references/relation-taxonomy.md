---
name: relation-taxonomy
description: This reference provides the relation type catalog and evidence validation rules for personal knowledge graphs and fact-to-fact memory edges. It should be consulted when an agent needs to "classify a relation between two entities", "validate relation evidence strength", "determine the minimum evidence for a relation type", "upgrade a weak relation as new evidence appears", "distinguish structural from semantic relations", "apply the starter relation set to discovered connections", or "classify the memory-layer derives edge".
---

# Relation Taxonomy — Starter Relation Set and Evidence Rules

> Purpose: Detection and execution reference for `personal-ontology` — use it to classify discovered relations between entities and validate their evidence. This reference is standalone and can be consulted without the parent skill. For the full relation discovery workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Scope

This reference covers two concerns: the starter set of relation types available for classification, and the evidence rules that determine when a relation type can be assigned.
It also defines the special memory-layer `derives` edge for fact-to-fact links.
It does not cover entity extraction (handled in the parent skill) or alias resolution (handled by `references/entity-canonicalization.md`).

## Starter Relation Set

These relation types cover the most common patterns in personal knowledge vaults. The set is intentionally small — a constrained taxonomy prevents over-classification and keeps the graph interpretable.

### Structural Relations

Structural relations are derived from explicit vault artifacts (wikilinks, folder hierarchy, frontmatter). They have the highest evidence reliability.

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `references` | A → B | A explicitly cites or links to B | Wikilink `[[B]]` in A's body |
| `parent-of` | A → B | A is a broader category, MOC, or container for B | B is in A's subfolder, or A is a MOC that links to B |
| `tagged-with` | A → B | A is tagged with B as a topic or category | Frontmatter tag or wikilink-as-tag pattern |
| `owned-by` | A → B | A belongs to person or project B | Frontmatter `owner`, `author`, `project` field pointing to B |

### Semantic Relations

Semantic relations require structural evidence plus contextual analysis. They represent meaning beyond simple linking.

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `extends` | A → B | A builds on or develops ideas from B | A references B AND A's content elaborates on B's concepts |
| `contradicts` | A ↔ B | A and B present conflicting views on the same topic | Both reference a shared entity AND contain opposing claims |
| `supports` | A → B | A provides evidence or examples for B's claims | A references B AND A's content validates B's assertions |
| `supersedes` | A → B | A replaces or updates B | A references B AND has a later date AND covers the same scope |

### Memory-Layer Semantic Relation

`derives` is a semantic relation reserved for fact-to-fact memory edges, not a shortcut for ordinary entity graph links.
Evidence strength for `derives` is `contextual`.

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `derives` | fact A → fact B | Two or more facts combined to infer a new fact | Grounded source facts plus an explicit composition path in context |

Example: `Alice works at Google` + `Google is in Mountain View` derives `Alice works in Mountain View`.

### Weak Relations

Weak relations are the default when structural evidence exists but type-specific evidence is insufficient.

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `related-to` | A ↔ B | A and B share structural connections but the relationship type is unclear | Co-occurrence in 2+ notes without stronger type evidence |
| `co-occurs-with` | A ↔ B | A and B appear together but without meaningful connection evidence | Same note but no wikilink, shared heading, or frontmatter link |

## Life-Specific Relation Additions

These five relation types extend the starter set without changing the original 10 vault relations.
Use them when at least one side has `ontology_family: "life"`.

### Structural Life Relation

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `belongs-to-area` | A → B | A life commitment or recurring practice belongs to area B | Goal or habit entity carries an `area_ref`, or profile extraction mapped the item to a core area |

### Semantic Life Relations

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `advances-direction` | A → B | Goal A is one bounded expression of direction B | Goal and direction are linked by the personal profile or reinforced by aligned vault notes |
| `guided-by-value` | A → B | Goal or habit A should be constrained by value B | Profile or interview evidence ties the commitment to the named value |
| `informed-by-decision` | A → B | Goal or direction A was shaped by a recorded decision B | Goal or direction metadata, capture output, or review evidence explicitly points to the decision |
| `embodies` | A → B | Habit A is a recurring practice that expresses value B | Habit wording and profile evidence show the practice is how the value is lived |

## Person-Specific Relation Additions

These five relation types extend the starter set without changing the original 10 vault relations or the four life-specific relations.
Use them when at least one side is a `person` entity.

### Structural Person Relations

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `colleague-of` | A ↔ B | A and B work together professionally | Both persons share a project or area entity, or co-occur in work-related notes |
| `family-of` | A ↔ B | A and B are family members | Profile or interview evidence declares the family relationship |

### Semantic Person Relations

| Type | Direction | Description | Primary Evidence |
|------|-----------|-------------|------------------|
| `friend-of` | A ↔ B | A and B have a friendship relationship | Profile or interview evidence, reinforced by co-occurrence in personal notes |
| `mentored-by` | A → B | A is mentored by B | Profile or interview evidence, optionally reinforced by learning-related note co-occurrences |
| `reports-to` | A → B | A reports to B in an organizational hierarchy | Profile or interview evidence with organizational context |

Key rules:

- `colleague-of`, `family-of`, and `friend-of` are symmetric, so store both directions.
- `mentored-by` and `reports-to` are asymmetric.
- Person-specific relations require profile-backed or interview evidence.
- Vault co-occurrence alone is insufficient for person-specific relations.
- All person entities use mask_ids such as `Person_A`, never real names, per `references/people-schema.md`.

## Evidence Rules

Each relation type requires specific evidence patterns. A relation cannot be assigned a type unless it meets the minimum evidence requirement.

### Evidence Strength Levels

| Level | Definition | Usage |
|-------|------------|-------|
| `structural` | Directly observable in vault artifacts (wikilinks, frontmatter, folder position) | Required for vault-native relation types |
| `profile-backed` | Directly observable in `personal-profile.json`, `work.jsonl`, `timeline.jsonl`, or approved life-entity metadata | Allowed as the grounding signal for life-specific relation types |
| `contextual` | Inferred from co-occurrence patterns, section-level analysis, or life-entity alignment | Required for semantic relations in addition to structural or profile-backed evidence |
| `semantic` | Derived from QMD vector similarity | Reinforcement only — never sufficient alone |

### Per-Type Evidence Requirements

| Relation Type | Minimum Evidence | Reinforcement |
|---------------|------------------|---------------|
| `references` | 1 wikilink from A to B | Multiple wikilinks, backlink from B to A |
| `parent-of` | Folder containment OR MOC link pattern (A links to 3+ children including B) | Consistent naming pattern (B's title matches A's section heading) |
| `tagged-with` | Frontmatter tag field OR consistent `#tag` usage in 2+ notes | Tag appears in vault-profile `theme_fields` |
| `owned-by` | Frontmatter field matching vault-profile `people_fields` or explicit `owner`/`project` field | Person/project entity has a canonical note |
| `extends` | A references B (structural) + A's content adds depth to B's topic (contextual) | QMD similarity score > 0.6 between A and B |
| `contradicts` | Both reference a shared entity (structural) + opposing claims on the same topic (contextual) | Rare — only assign when contradiction is explicit |
| `supports` | A references B (structural) + A provides examples or evidence for B (contextual) | A has later date than B |
| `supersedes` | A references B (structural) + A has later date + A covers B's scope (contextual) | B contains a note or link indicating it is outdated |
| `related-to` | Co-occurrence in 2+ notes (any structural signal) | Default fallback — upgrade to a specific type when evidence grows |
| `co-occurs-with` | Same note, no stronger signal | Weakest relation — do not present in relationship maps unless requested |
| `belongs-to-area` | Goal or habit has an explicit `area_ref`, profile-area mapping, or area-specific origin path | Matching area name in a dedicated note or repeated source-note reinforcement |
| `advances-direction` | Goal is linked to a direction by profile extraction, goal metadata, or consistent vault reinforcement | Direction note and goal note share reinforcing source notes or explicit cross-links |
| `guided-by-value` | Goal or habit is explicitly tied to a value in the profile, interview-derived update, or entity metadata | Repeated co-reference in notes or a dedicated value note linked from the goal or habit |
| `informed-by-decision` | Goal or direction is explicitly linked to a decision entity by metadata, capture output, or review evidence | Shared `goal_refs`, `area_refs`, or aligned source-note reinforcement |
| `embodies` | Habit is the recurring practice associated with a value in profile or entity metadata | Repeated source-note evidence that the habit operationalizes the value |
| `derives` | Two or more grounded facts plus an explicit composition path that yields the new claim | Store in `.pa/memory-links.jsonl` only, and never infer it from semantic similarity or a single fact |
| `colleague-of` | Profile or interview evidence of professional relationship, optionally reinforced by shared project or area entities | Repeated co-occurrence in work-related notes |
| `family-of` | Profile or interview evidence declaring family relationship | n/a — interview or profile only |
| `friend-of` | Profile or interview evidence of friendship, optionally reinforced by personal note co-occurrence | Repeated co-occurrence in non-work notes |
| `mentored-by` | Profile or interview evidence of mentorship relationship | Co-occurrence in learning-related notes |
| `reports-to` | Profile or interview evidence of organizational hierarchy | Shared project entities with hierarchical context |

### Evidence Accumulation

Relations can be upgraded as new evidence appears:

| Current Type | New Evidence | Upgrade To |
|--------------|--------------|------------|
| `related-to` | Direct wikilink discovered | `references` |
| `related-to` | Folder containment confirmed | `parent-of` |
| `references` | Contextual analysis shows elaboration | `extends` |
| `references` | Later date + scope overlap | `supersedes` |
| `co-occurs-with` | Second co-occurrence note found | `related-to` |
| `guided-by-value` | Stronger recurring-practice evidence appears | `embodies` |
| `colleague-of` | Shared project evidence + mentorship signals | `mentored-by` |

Relations are never downgraded automatically. If evidence weakens (e.g., a wikilink is removed), flag the relation for review rather than silently removing it.

## Relation Direction

| Convention | Rule |
|------------|------|
| Asymmetric relations | Arrow points from the more specific to the more general, or from the dependent to the source |
| `A references B` | A contains the link — A is the referencer |
| `A extends B` | A builds on B — A is the extension |
| `A supersedes B` | A replaces B — A is newer |
| `A belongs-to-area B` | A is the goal or habit, B is the area that contains it |
| `A advances-direction B` | A is the bounded goal, B is the open-ended direction |
| `A guided-by-value B` | A is the goal or habit, B is the value that constrains it |
| `A informed-by-decision B` | A is the goal or direction, B is the recorded decision that shaped it |
| `A embodies B` | A is the habit, B is the value made concrete through repetition |
| `A derives B` | A is one grounded source fact and B is the newly derived fact — asymmetric and stored as premise → derived claim in the memory layer |
| `A colleague-of B` | A and B are peers — symmetric |
| `A family-of B` | A and B are family — symmetric |
| `A friend-of B` | A and B are friends — symmetric |
| `A mentored-by B` | A is the mentee, B is the mentor — asymmetric |
| `A reports-to B` | A is the report, B is the manager — asymmetric |
| Symmetric relations | `contradicts`, `related-to`, `co-occurs-with` are bidirectional |
| Storage | Store both directions for symmetric relations. Store only the canonical direction for asymmetric relations |

## Sparse Vault Considerations

| Vault Size | Behavior |
|------------|----------|
| < 10 notes | Expect few entities and relations. Do not force relation discovery. Report the graph as sparse |
| 10-30 notes | Relation discovery is useful but expect many `related-to` (untyped) relations |
| 30-100 notes | Full taxonomy applies. Expect typed relations and relationship map candidates |
| 100+ notes | Consider clustering entities by topic before exhaustive pairwise comparison |

For sparse vaults, prioritize unresolved wikilink resolution (connecting existing stubs) over new relation discovery.

## Prohibited Patterns

| Pattern | Phase | Why Prohibited | Prevention |
|---------|-------|---------------|------------|
| Creating a relation from QMD similarity alone | Relation Discovery Step 1 | Semantic signals suggest, structural or profile-backed signals confirm | Require at least one structural or profile-backed signal before creating any relation |
| Assigning `contradicts` without explicit evidence | Relation Typing Step 2 | False contradiction claims damage trust | Require explicit opposing claims on the same topic, not just different perspectives |
| Assigning `supersedes` without date comparison | Relation Typing Step 2 | Recency assumption without evidence is unreliable | Compare `created`/`updated` frontmatter or filename dates before assigning |
| Assigning `derives` without at least 2 explicit grounded facts | Relation Typing Step 2 | Derived claims need a visible composition path, not a guess | Require 2 or more source facts, keep them in `derived_from`, and store premise → derived links only when the combination is explicit |
| Creating relations between an entity and itself | Candidate Assembly | Self-referential relations are noise | Filter out entity pairs where both sides resolve to the same canonical name |
| Inferring `owned-by` from note content alone | Relation Typing Step 2 | Ownership requires frontmatter or explicit structural signal | Check vault-profile `people_fields` and explicit `owner`/`project` frontmatter only |
| Assigning `guided-by-value` from generic self-help language | Relation Typing Step 2 | Not every positive-sounding note expresses a user-confirmed value relation | Require profile, interview, or entity-metadata evidence tying the goal or habit to the value |

## Design Rationale

Why a small starter set: a constrained vault taxonomy (10 core relation types) prevents over-classification.
Most vault-native connections are still `related-to` until enough evidence accumulates to justify something stronger.
The five life-specific relations are additive, not a replacement for the starter set.
The five person-specific relations are also additive, not a replacement for the starter set.
They exist because life entities need a few explicit links that vault structure alone cannot express.
They exist because person entities need explicit interpersonal links that structural vault evidence alone cannot safely infer.

Why grounded evidence is mandatory: semantic similarity (QMD vec scores) captures surface vocabulary overlap, not intentional authoring decisions.
Two notes about "meetings" may score high on similarity without any real relationship.
Vault relations need structural signals such as wikilinks, shared tags, or folder containment.
Life relations may use profile-backed evidence because the user explicitly named the connection in profile state.
Requiring structural or profile-backed evidence prevents the graph from filling with speculative connections.

Why relations upgrade but never downgrade: removing a relation when evidence weakens (e.g., a wikilink is deleted) could silently destroy information the user expected to persist. Flagging for review preserves user agency — they decide whether the connection still holds rather than having PA make an irreversible judgment.
Why `derives` stays explicit: a derived claim is not directly observed the way a supporting or superseding relation often is.
Keeping `derives` separate preserves the chain from grounded source facts to the inferred claim.

## Validation Checklist

- [ ] Each relation uses the canonical direction for its type, and symmetric relations are stored bidirectionally while asymmetric ones are not mirrored.
- [ ] Structural evidence is present before any semantic, life-specific, or person-specific relation is assigned.
- [ ] The same canonical entity pair does not accumulate duplicate copies of the same relation type.
- [ ] Weak connections stay `related-to` or `co-occurs-with` until stronger type-specific evidence is present.
- [ ] Person-specific relation types are used only when the relevant entities are person entities.
- [ ] Life-specific relation types are used only when at least one side belongs to the life ontology family.
- [ ] `derives` is used only for explicit fact-to-fact composition in the memory layer, not for speculative entity graph links.
- [ ] Similarity alone never promotes a candidate into a typed relation.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill — relation discovery workflow and evidence thresholds |
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | Sibling reference — canonicalized entities are the nodes that relations connect |
| `skills/pa/personal-ontology/references/life-entities.md` | Life-entity schema that introduces goals, areas, values, and directions |
| `skills/pa/personal-ontology/references/people-schema.md` | Person schema that defines mask_ids, profiles, and privacy boundaries |
| `agents/pa/weaver.md` | Primary consumer — applies taxonomy during relation classification |
| `commands/pa/link.md` | Caller — link suggestions present typed relations to the user |
| `commands/pa/focus.md` | Caller — project dossiers group related entities by relation type |
