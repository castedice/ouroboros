---
name: entity-canonicalization
description: This reference provides entity identity resolution rules for personal knowledge vaults. It should be consulted when an agent needs to "resolve entity aliases", "merge duplicate entities safely", "prevent alias collision between similar names", "select the canonical form for an entity", "determine if two names refer to the same concept", or "split a previously merged entity".
---

# Entity Canonicalization — Alias Resolution and Identity Rules

> Purpose: Detection and execution reference for `personal-ontology` — use it to resolve entity identity across aliases, merge duplicate entities safely, and prevent alias collision. This reference is standalone and can be consulted without the parent skill. For the full entity extraction workflow, see `skills/pa/personal-ontology/SKILL.md`.

## Scope

This reference covers three concerns: how to determine that two names refer to the same entity, how to select the canonical form, and how to prevent false merges that collapse distinct entities. It does not cover relation discovery (handled by `references/relation-taxonomy.md`) or graph density decisions (handled in the parent skill).

## Canonical Form Selection

When multiple names refer to the same entity, one becomes the canonical name. Selection priority:

| Priority | Rule | Example |
|----------|------|---------|
| 1 | **Dedicated note title** — if the entity has its own note, use the filename (without extension) | Note `meta-prompts-moc.md` → canonical `meta-prompts-moc` |
| 2 | **Longest unambiguous form** — among aliases, prefer the most specific name | `Kim`, `Kim Park`, `Kim Park (eng)` → canonical `Kim Park` |
| 3 | **Most frequent wikilink target** — the form used most often in `[[...]]` | `[[meta-prompts]]` appears 5x vs `[[MP]]` 1x → canonical `meta-prompts` |
| 4 | **Frontmatter canonical alias** — if `alias_source: frontmatter` and an `aliases` field exists | `aliases: [MP, meta-prompts]` → first alias or note title |

When Priority 1 and 3 disagree (note title differs from the most-linked form), prefer the note title — it represents the author's explicit naming decision.

### Privacy-Kind Canonical Override

For entities with a `mask_id` as defined in `references/privacy-node-schema.md`, the `mask_id` takes absolute precedence over all Priority `1`-`4` rules.

| Priority | Rule | Example |
|----------|------|---------|
| 0 (highest) | **mask_id** — if the entity has a `mask_id`, use it as `canonical_name` | Entity "삼성전자" with `mask_id` `ORG_A` -> canonical `ORG_A` |

Standard person entities with no `mask_id` follow the normal Priority `1`-`4` rules.
Only inner-circle persons and non-person privacy kinds use this override.

## Alias Matching Rules

### Normalization

Before matching, normalize all candidate names:

1. Lowercase the entire string.
2. Trim leading and trailing whitespace.
3. Collapse consecutive whitespace to a single space.
4. Remove trailing punctuation (periods, commas) but preserve hyphens and underscores.
5. Strip `[[` and `]]` wikilink delimiters if present.

### Match Criteria

Two names are potential aliases when any of the following holds:

| Criterion | Description | Example |
|-----------|-------------|---------|
| **Normalized equality** | Identical after normalization | `Meta-Prompts` = `meta-prompts` |
| **Prefix/suffix match** | One name is a prefix or suffix of the other (minimum 4 characters) | `meta-prompts` and `meta-prompts-moc` |
| **Abbreviation** | One name is an acronym or initialism of the other | `MP` and `meta-prompts` (M + P initials) |
| **Frontmatter alias list** | One name appears in the other entity's `aliases` frontmatter field | `aliases: [MP, meta prompts]` |
| **Wikilink alias** | `[[canonical|display]]` syntax connects two forms | `[[Kim Park|Kim]]` |

### mask-map Alias Resolution

When `.pa/mask-map.json` is available, its `aliases` arrays act as an additional alias source.

| Priority | Rule | Example |
|----------|------|---------|
| 6 | **mask-map aliases** — if the name matches any `real_name` or `aliases` entry in `mask-map.json` | Vault text "삼성" matches a mask-map alias for "삼성전자" -> resolves to `ORG_A` |

mask-map alias matching applies after structural alias resolution.
When a mask-map match is found, the entity's `canonical_name` becomes the `mask_id`, not the matched alias.

### Merge Threshold

Two candidates merge into one entity when:
- They share 2+ alias matching criteria, OR
- They share 1 alias matching criterion AND appear in the same note context (within 3 paragraphs or under the same heading).

A single matching criterion across different notes is insufficient for automatic merge — flag it as a merge suggestion for user review.

## Collision Prevention

### False Merge Risks

| Risk | Signal | Prevention |
|------|--------|------------|
| **Homonym collision** | Same name, different meaning (e.g., `Apple` the company vs `apple` the fruit) | Check `kind` field — if candidates have different kinds, do not merge without user confirmation |
| **Acronym collision** | Same abbreviation, different expansions (e.g., `ML` = machine learning or mailing list) | Require context agreement — the abbreviation must expand consistently in 80%+ of occurrences |
| **Name overlap** | Partial name match that is coincidental (e.g., `Project Alpha` and `Alpha Testing`) | Require the full shorter name to match, not just a shared word |
| **Cross-kind merge** | A person name matches a project name (e.g., person `Phoenix` and project `Phoenix`) | Never auto-merge across kinds — always flag for user review |

### Safe Merge Rules

1. **Same kind and family required**: Auto-merge only when both candidates have the same `kind` and `ontology_family` (person+person, life goal+life goal, topic+topic, etc.).
2. **Evidence overlap**: At least one source note must contain both alias forms (proving the author treats them as equivalent).
3. **No conflicting canonical notes**: If both candidates have dedicated notes, do not merge — they are distinct entities. Flag for user review.
4. **Reversibility**: Record the merge decision in the entity's provenance. Include the pre-merge state so the user can undo.

## Entity Splitting

Sometimes a previously merged entity needs to be split — the user created a new note that disambiguates what was previously one entry.

### Split Triggers

| Trigger | Action |
|---------|--------|
| User creates a new note with a name that was previously an alias | Check if the new note's content diverges from the canonical entity. If so, propose a split |
| User adds frontmatter that distinguishes an alias as a separate entity | Propose split with the new frontmatter as evidence |
| Relation analysis reveals contradictory connections | Flag for review — one "entity" may actually be two |

### Split Procedure

1. Identify which source notes belong to which entity after the split.
2. Create two separate entity records with appropriate canonical names.
3. Reassign relations to the correct entity.
4. Record the split decision in provenance for both new entities.

## Refresh Behavior

During incremental refresh (dirty-path), canonicalization runs only on entities touched by the dirty path:

1. Re-extract aliases from modified notes.
2. Check if any new alias matches an existing entity.
3. Check if any removed alias breaks a merge.
4. Update the entity record without re-processing the entire vault.

## Life Entity Identity Rules

Life entities resolve identity from user-owned state before they resolve it from note structure.
For `ontology_family: "life"`, the canonical source is the primary identity anchor.

| Rule | Handling | Example |
|------|----------|---------|
| **Profile path as canonical source** | Use the profile field path or overlay pointer as the source-of-truth anchor for identity | `identity.core_areas[0]` creates the `area` entity `career` |
| **Stable identity across reinforcement** | Vault wikilinks or note titles may reinforce a life entity, but they do not replace the canonical source | `focus.current_focus[1]` stays the goal source even after `[[build studio]]` appears in notes |
| **Same name, different family** | Never auto-merge a life entity with a vault entity that only shares the display name | vault `topic` `건강` stays separate from life `area` `건강` |
| **Same name, different kind** | Never auto-merge across life kinds without explicit matching source and evidence | life `direction` `health` does not collapse into life `goal` `health` |
| **Confidence inheritance** | Seed life-entity confidence from the relevant profile layer, then reinforce it with vault evidence when present | `focus` confidence `0.6` seeds a goal, and repeated wikilinks can raise it |

For life entities, name similarity is secondary evidence.
The entity exists because the user profile or overlay named it, not because the vault happened to mention similar words.

### Life Entity Confidence Rules

Start life entities at the confidence level of the originating profile layer.
Use `identity` confidence for `area` and `value`.
Use `direction` confidence for `direction`.
Use `focus` confidence for `goal`.
For overlay-backed `habit` and `milestone`, start from the overlay extraction confidence or the closest justified profile baseline.
Vault wikilinks, dedicated notes, and repeated source-note reinforcement can raise confidence, but they do not change the entity family.

## Bias Mitigation

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Familiarity bias | Canonical Form Selection | Preferring the form the model has seen most often in training, not the form the vault uses most | Use vault-internal frequency (wikilink count), not model familiarity |
| Over-merge bias | Merge Threshold | Aggressively merging entities to reduce graph size, losing intentional distinctions | Require same-kind + evidence overlap before auto-merge |
| Recency bias | Alias Matching | Preferring recent alias forms over established canonical names | Canonical form is the note title or longest form, regardless of when it appeared |
| Confirmation bias | Collision Prevention | Ignoring collision signals because the merge "makes sense" semantically | Cross-kind merge is always flagged, even when semantically plausible |
| Cross-family collapse | Life Identity | A life `area` and a vault `topic` with the same name get merged because the wording overlaps | Require matching `ontology_family` before any auto-merge |

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Vault has < 5 entities | Canonicalization is trivial — apply rules but expect no merges |
| Entity has 10+ aliases | Cap alias list at 10 most-used forms. Archive the rest in provenance |
| Wikilink alias `[[A|B]]` where A does not exist as a note | A is still a valid entity reference. Record as unresolved canonical note |
| Frontmatter `aliases` field contains the canonical name | Ignore — do not create a self-referential alias |
| Two entities merge but have conflicting `kind` | Do not auto-merge. Present both options to the user |
| `identity.core_areas` was reordered | Preserve the existing `area` entity when the normalized name matches, then update `canonical_source` to the new path |

## Design Rationale

Why longest unambiguous form as canonical: shorter forms are ambiguous by nature (abbreviations match multiple expansions, first names match multiple people). The longest form that uniquely identifies the entity provides the best display name while avoiding collision. When the note title disagrees with the most-linked form, the note title wins because it represents an explicit authoring decision — the user chose that name for their note.

Why same-kind required for auto-merge: personal knowledge vaults contain many homonyms across categories (a person named "Phoenix" and a project named "Phoenix"). Auto-merging across kinds destroys information the user intended to keep separate. The cost of a false merge (lost distinction) exceeds the cost of a missed merge (duplicate entries that the user can manually resolve).

Why evidence overlap required: requiring at least one source note that contains both alias forms ensures the author themselves treats the names as equivalent. Without this rule, canonicalization relies on statistical patterns that may reflect coincidence rather than intent.

Why life entities anchor to profile paths: life entities exist because the user explicitly stated them in a profile or because PA created an approved overlay pointer for them.
That origin is a stronger identity signal than note frequency.
Without a source-path anchor, simple homonyms like `health` or `career` would constantly collapse life structure into vault topics.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill — entity extraction workflow and evidence thresholds |
| `skills/pa/personal-ontology/references/life-entities.md` | Life-entity schema and `ontology_family` rules |
| `skills/pa/personal-ontology/references/privacy-node-schema.md` | Privacy override rules for canonical form selection |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Sibling reference — relation classification uses canonicalized entities |
| `agents/pa/weaver.md` | Primary consumer — applies canonicalization during entity extraction |
| `commands/pa/link.md` | Caller — link suggestions depend on canonicalized entity identity |
| `commands/pa/survey.md` | Caller — full-vault entity extraction includes canonicalization pass |
