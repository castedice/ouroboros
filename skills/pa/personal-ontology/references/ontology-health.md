---
name: ontology-health
description: This reference defines health check criteria for the PA ontology. It should be consulted when an agent needs to "check ontology health", "detect orphan entities", "find duplicate candidates", "verify alias integrity", "assess relation staleness", "check revision-chain integrity", "detect stale contested facts", or "check privacy integrity of the entity graph".
---

# Ontology Health — Automated Graph Integrity Checks

> Purpose: Reference for `personal-ontology` — defines what constitutes a healthy ontology and how to detect structural problems.
> This reference is standalone and can be consulted without the parent skill.
> For entity extraction rules, see `skills/pa/personal-ontology/SKILL.md`.
> For entity canonicalization, see `skills/pa/personal-ontology/references/entity-canonicalization.md`.
> For revision-chain rules, see `skills/pa/personal-ontology/references/entity-revision-schema.md`.
> For fact-state rules, see `skills/pa/personal-ontology/references/memory-schema.md`.

## Health Checks

| Check | Detection Rule | Severity | Resolution |
|-------|---------------|----------|------------|
| **Orphan entities** | Entity has zero live `evidence_slices` and no profile-backed identity (`ontology_family: "life"` entities are exempt if their profile source exists) | warning | Remove from entities.json or flag for review |
| **Duplicate candidates** | Two entities with same `kind`, same `ontology_family`, and normalized `canonical_name` similarity > 0.85 (case-insensitive, whitespace-normalized) | info | Propose merge via entity-canonicalization rules |
| **Alias collision** | One alias string maps to 2+ active entities | error | Require user disambiguation — present both entities and ask which one owns the alias |
| **Stale relations** | Relation's `source_id` or `target_id` references an entity that is orphan, deleted, or missing from entities.json | warning | Remove relation or flag for review |
| **Contested fact drift** | Two or more facts for the same `subject_id + predicate` remain `state: "contested"` and their newest observed temporal signal is older than 14 days | warning | Surface for review and resolve the winning fact or preserve the tie intentionally |
| **Orphaned revision chain** | An entity revision chain has 2+ open revisions with `valid_to: null`, or a revision points to `supersedes` that cannot be resolved | warning | Rebuild the chain so only one current revision remains open |
| **Memory-head orphan** | A `memory-heads.json` entry has no matching non-superseded fact in `memories.jsonl` | error | Rebuild `memory-heads.json` from the fact log before consumers trust it |
| **Unresolved coreference candidate** | `.pa/sessions/{id}.json -> unresolved_entities[]` still contains pending same-kind merge candidates | warning | Surface for steward review and confirm merge or keep-separate explicitly |
| **Privacy integrity** | (a) Entity has `mask_id` but no matching entry in mask-map.json, (b) mask-map entry exists but entity is missing, (c) real name appears in entity `canonical_name` for a privacy-bearing kind | error | Flag for immediate review — privacy leak risk |
| **Weak edge overgrowth** | `related-to` relations exceed 60% of total relation count for an entity | warning | Suggest re-classification — some `related-to` edges may have stronger specific types |
| **Confidence decay** | Entity's newest `evidence_slices[].extracted_at` is older than 90 days and confidence > 0.7 | info | Suggest refresh — confidence may be stale |

## Dirty-Path Interaction

When `dirty_paths` has pending entries (any entry with `ontology_status: "pending"`), ontology health findings are provisional:

| Finding Type | Provisional? | Rationale |
|-------------|-------------|-----------|
| Orphan entities | Yes — pending refresh may re-introduce evidence | Show but mark `(provisional — pending refresh)` |
| Duplicate candidates | No — structural, independent of pending refresh | Report as-is |
| Alias collision | No — structural | Report as-is |
| Stale relations | Yes — pending refresh may restore endpoints | Show but mark provisional |
| Contested fact drift | Yes — pending refresh may introduce a stronger fact and resolve the tie | Show but mark provisional |
| Orphaned revision chain | No — structural append-log integrity problem | Report as-is |
| Memory-head orphan | No — materialized view integrity problem | Report as-is |
| Unresolved coreference candidate | No — explicit review debt persisted in session state | Report as-is |
| Privacy integrity | No — structural, immediate risk | Report as-is |
| Weak edge overgrowth | Yes — pending refresh may add stronger edges | Show but mark provisional |
| Confidence decay | Yes — pending refresh may update timestamps | Show but mark provisional |

## Output Contract

Health check results are returned as a structured object for the sentinel agent:

```json
{
  "ontology_health": {
    "status": "healthy|warnings|errors",
    "pending_dirty_paths": 3,
    "findings": [
      {
        "check": "orphan_entity",
        "severity": "warning",
        "provisional": true,
        "affected_ids": ["e-042"],
        "evidence": "Entity 'old-project' has 0 live evidence slices",
        "recommended_action": "Remove or verify after pending refresh completes"
      }
    ],
    "summary": {
      "total_entities": 45,
      "total_relations": 120,
      "orphans": 2,
      "duplicates": 1,
      "alias_collisions": 0,
      "stale_relations": 3,
      "contested_facts": 1,
      "orphaned_revision_chains": 0,
      "memory_head_orphans": 0,
      "unresolved_coreference_candidates": 2,
      "privacy_issues": 0,
      "weak_edges": 1
    }
  }
}
```

## Integration Points

| Consumer | How Health Is Used |
|----------|-------------------|
| `agents/pa/sentinel.md` | Runs health checks during review detection pass. Returns findings in structured output |
| `commands/pa/review.md` | Renders `## Ontology Health` section in follow-up report |
| `commands/pa/steward.md` | Uses health findings in need detection — errors trigger survey refresh, warnings inform link repair |
| Phase 19 heartbeat | Health check runs as part of self-check, errors trigger push notification |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill — entity extraction and refresh methodology |
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | Merge rules for duplicate resolution |
| `skills/pa/personal-ontology/references/entity-revision-schema.md` | Append-only revision-chain contract |
| `skills/pa/personal-ontology/references/memory-schema.md` | Fact-state and memory-head materialization contract |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Relation types for weak-edge classification |
| `agents/pa/sentinel.md` | Primary consumer — runs health checks |
| `commands/pa/review.md` | Renders health report |
| `commands/pa/steward.md` | Acts on health findings |
