---
name: personal-ontology
description: This skill provides entity extraction, relation discovery, and graph reasoning methodology for personal knowledge vaults and life-state overlays. It should be activated when an agent needs to "extract entities from vault notes", "create life entities from a personal profile", "discover relationships between notes or goals", "canonicalize entity identity across aliases", "build a personal knowledge graph from structural signals and profile state", "assess relation evidence strength", "refresh the semantic overlay after vault changes", or "determine when a relationship map is warranted".
summary: Models personal knowledge graphs with grounded entity discovery, alias discipline, relation evidence, memory facts, and privacy boundaries.
version: 1
tags: [pa, ontology, graph, entities, privacy, memory]
preamble_tier: 3
---

# Personal Ontology

## Core Rule

**"Discover what the vault and the profile already know about the user's world."**

The ontology has two families: `vault` entities discovered from structural note evidence and `life` entities grounded in confirmed profile or overlay state.
Structural evidence stays first-class for vault entities.
Profile-backed evidence stays first-class for life entities.
Semantic similarity can reinforce, but it never creates facts on its own.
Atomic claims live in `.pa/memories.jsonl`, which is the conservative fact store layered on top of entities and relations.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Creating entities from semantic similarity alone | Discovery | Require structural evidence for vault entities and confirmed profile or overlay sources for life entities |
| Over-merging entities with similar names | Canonicalization | Match on family, kind, and canonicalization rules before merging aliases |
| Collapsing `vault` and `life` entities because they share a label | Identity | Keep family boundaries explicit unless the user requests a merge |
| Treating goals, directions, and values as the same thing | Life modeling | Use the life-entity schema and keep layer boundaries intact |
| Creating typed relations without grounded evidence | Relation discovery | Require at least one structural or profile-backed signal before assigning any relation type |
| Flooding the user with maps and weak links | Presentation | Respect density thresholds and `moc_preference` before surfacing relationship maps |
| Letting stale overlay state survive vault edits | Refresh | Track dirty paths, refresh targeted neighborhoods, and subtract dead evidence slices |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "These names are close enough to be the same entity" | Merging entities before family, kind, and alias rules agree | Run canonicalization and keep ambiguous identities split |
| "Semantic similarity shows there is a relationship" | Creating a typed relation from semantic similarity alone | Require structural or profile-backed evidence before typing the relation |
| "The life entity and vault note share a label" | Collapsing `life` and `vault` families automatically | Keep family boundaries unless the user explicitly requests a merge |

## Workflow

### 1. Choose The Refresh Scope And Load Authorities

Decide whether the job is a full rebuild, a targeted entity refresh, or a link or focus neighborhood refresh.
Load the vault profile, profile-backed life state, and any pending dirty-path information before scanning notes.

### 2. Discover Entities From Their Correct Source Of Truth

Discover `vault` entities from structural note signals such as wikilinks, note titles, frontmatter, and repeated headings.
Create `life` entities from confirmed profile fields or approved overlay pointers, then attach vault reinforcement only after identity already exists.

### 3. Canonicalize Identity And Apply Privacy

Merge aliases only when canonicalization rules say the entities are the same thing.
Assign privacy fields and mask identifiers to privacy-bearing entities after canonicalization, not before it.

### 4. Discover And Type Relations

Start from co-occurrence, direct links, shared structural context, or profile-backed life connections.
Assign a relation type only when the relation taxonomy's minimum evidence rule is satisfied.
Keep semantic-only connections as suggestions.

### 5. Refresh Graph And Memory State And Control Presentation

Persist entities, relations, atomic facts, and evidence slices inside `.pa/`.
The weaver owns note-based fact extraction during entity refresh and returns append-ready memory records for the caller to write into `memories.jsonl`, `memory-links.jsonl`, and `memory-heads.json`.
Refresh dirty paths before link or focus analysis, drop evidence slices when notes change or disappear, and generate relationship maps only when density and vault preferences justify them.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Vault-entity ingress | Require 2 or more structural sources from the allowed signal classes before creating a `vault` entity |
| Life-entity ingress | Require a confirmed profile field or approved overlay pointer before creating a `life` entity |
| Family boundary | Shared names never justify automatic cross-family merges |
| Relation evidence | Every relation needs at least 1 structural or profile-backed signal, and semantic similarity is reinforcement only |
| Privacy application | Apply masking and privacy fields only after canonicalization resolves identity |
| Atomic fact storage | Store only clear, source-grounded claims in `.pa/memories.jsonl`, and keep inferred claims explicit through `derived_from` lineage |
| Map threshold | A relationship map is eligible when an entity has 5 or more meaningful relations and `moc_preference` permits it |
| Refresh discipline | Pending dirty paths must be refreshed before targeted link or focus outputs are trusted |
| State boundary | Entities, relations, memories, and dossiers stay in `.pa/` unless the user explicitly asks for user-visible note output |

## Reference Map

| Need | Reference |
|------|-----------|
| Family split, ingress priorities, and vault or life discovery workflows | `${CLAUDE_SKILL_DIR}/references/entity-discovery.md` |
| Alias resolution, merge safety, and identity splitting | `${CLAUDE_SKILL_DIR}/references/entity-canonicalization.md` |
| Lightweight mention resolution against entities and recent session state | `${CLAUDE_SKILL_DIR}/references/coreference-rules.md` |
| Entity history and append-only revision chains | `${CLAUDE_SKILL_DIR}/references/entity-revision-schema.md` |
| Relation types and evidence thresholds | `${CLAUDE_SKILL_DIR}/references/relation-taxonomy.md` |
| Atomic fact schema, memory links, and head materialization rules | `${CLAUDE_SKILL_DIR}/references/memory-schema.md` |
| AGM-style contradiction detection and contested-fact handling | `${CLAUDE_SKILL_DIR}/references/contradiction-resolution.md` |
| Life-entity hub for legacy navigation | `${CLAUDE_SKILL_DIR}/references/life-entities.md` |
| Life-entity schema, enums, and quantified rules | `${CLAUDE_SKILL_DIR}/references/life-entity-schema.md` |
| Life-entity worked examples and relation examples | `${CLAUDE_SKILL_DIR}/references/life-entity-examples.md` |
| Life-entity pitfalls, rationale, and validation checks | `${CLAUDE_SKILL_DIR}/references/life-entity-review.md` |
| Person entity extensions and profile privacy model | `${CLAUDE_SKILL_DIR}/references/people-schema.md` |
| Masking fields, mask-map schema, and privacy-layer mechanics | `${CLAUDE_SKILL_DIR}/references/privacy-node-schema.md` |
| Dirty-path refresh, density thresholds, and `.pa/` state boundaries | `${CLAUDE_SKILL_DIR}/references/graph-refresh.md` |
| Automated graph integrity and ontology health checks | `${CLAUDE_SKILL_DIR}/references/ontology-health.md` |

## See Also

- `agents/pa/weaver.md` — Primary consumer for graph extraction, relation analysis, and note-based fact extraction during refresh.
- `commands/pa/link.md` and `commands/pa/focus.md` — Use the ontology for relationship surfacing and neighborhood views.
- `skills/pa/trust-and-boundaries/SKILL.md` — Governs `.pa/` authority, privacy handling, and note-boundary discipline.
- `skills/pa/vault-modeling/SKILL.md` — Supplies linking preferences and map behavior defaults.
