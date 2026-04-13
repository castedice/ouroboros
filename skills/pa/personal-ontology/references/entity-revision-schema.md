---
name: entity-revision-schema
description: This reference defines the PA entity revision history contract. It should be consulted when an agent needs to "track entity identity changes", "append entity revision entries", "rebuild current entities from revision history", "record merge or split events", or "validate revision chains".
---

# Entity Revision Schema

> Purpose: Reference for `personal-ontology` — defines the append-only history for identity-level entity changes.
> `entities.json` remains the materialized head that represents the current state.
> `entity-revisions.jsonl` preserves how that head changed over time.

## File

| File | Role | Write Pattern |
|------|------|---------------|
| `.pa/entity-revisions.jsonl` | Append-only entity identity history | Append new revision rows only |

## `.pa/entity-revisions.jsonl`

Each line is one revision event for one entity chain.
Write a new line only when identity-level state changes.
Do not write a revision row for routine evidence refresh, confidence tuning, or source-note accumulation.

| Field | Meaning |
|------|---------|
| `revision_id` | Stable revision event id such as `rev-e-042-20260329-001` |
| `entity_id` | Entity id from `entities.json` that this revision describes |
| `supersedes` | Previous `revision_id` in the same chain, or `null` when seeding history |
| `valid_from` | Semantic start date for this revision, preferring grounded `event_date` and falling back to `document_date` |
| `valid_to` | Semantic end date for this revision, or `null` for the current open revision |
| `evidence` | Array of source-note paths that justify the identity change |
| `change_type` | One of `identity`, `merge`, `split`, `status`, `canonical_note`, `attribute` |
| `change_summary` | Short human-readable explanation of what changed |

## `change_type`

| Value | Use |
|------|-----|
| `identity` | Canonical name, alias ownership, or external identity label changed |
| `merge` | Two previously separate entities were combined into one current head |
| `split` | One prior entity was divided into two or more current entities |
| `status` | Entity lifecycle changed such as `active -> inactive` or `active -> archived` |
| `canonical_note` | The canonical note anchor changed |
| `attribute` | A durable identity attribute changed and the change matters to entity resolution |

## Write Rules

- Revisions are append-only.
- Never edit or delete an existing revision row.
- `entities.json` is always the current materialized head, not the history log.
- Only identity-level changes create revision rows.
- Pure evidence refreshes do not create revision rows.
- Use the strongest grounded temporal signal for `valid_from`.
- When a new revision supersedes the previous current revision, append the new row and ensure chain reconstruction can infer that the prior revision is no longer current without rewriting history.
- Each entity chain should materialize to at most one open revision with `valid_to: null`.

## Trigger Rules

Create revision rows when one of these happens:

- An entity's canonical identity changes enough that alias ownership or display identity changes.
- A merge combines duplicate entities into one surviving head.
- A split creates separate entities from one overloaded identity.
- An entity changes lifecycle status in a way that affects ontology behavior.
- The canonical note changes and becomes the new identity anchor.
- A durable identity attribute changes and should be reconstructible later.

Do not create revision rows for:

- New evidence slices on the same identity.
- Confidence recalculation only.
- Memory fact refreshes that do not alter entity identity.
- Relation updates that leave entity identity unchanged.

## Reconstruction Rule

To rebuild the current head for an entity, follow the newest revision chain with `valid_to: null`, then read `entities.json` as the materialized projection of that open revision.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/memory-schema.md` | Fact history lives beside entity history but follows a separate append log |
| `skills/pa/personal-ontology/references/ontology-health.md` | Detects broken or orphaned revision chains |
| `skills/pa/personal-ontology/references/contradiction-resolution.md` | Fact contradictions may trigger entity refresh, but not every contradiction becomes a revision |
