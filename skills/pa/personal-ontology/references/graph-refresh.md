---
name: graph-refresh
description: This reference defines density thresholds, dirty-path refresh, evidence-slice rules, and `.pa/` state boundaries for the PA ontology. It should be consulted when an agent needs to "refresh ontology state after vault edits", "decide whether to generate a relationship map", "track dirty paths", "subtract stale evidence", or "keep ontology state inside .pa".
---

# Graph Refresh — Density Control, Dirty Paths, and State Boundaries

> Purpose: Reference for `personal-ontology` — use it after entity and relation discovery to keep the graph current and appropriately surfaced.
> This reference is standalone and can be used without the parent skill.

## Density Thresholds

Use relation count to decide whether an entity deserves only link suggestions or a fuller relationship view.

| Relation Count | Default Presentation |
|----------------|----------------------|
| 0 to 1 | Treat as isolated and surface only as a simple suggestion or gap |
| 2 to 4 | Eligible for link suggestions, but no automatic map |
| 5 or more | Eligible for a relationship map or dossier-style neighborhood view |

Eligibility does not guarantee map generation.
Vault preferences still govern whether the map should be created.

## MOC And Map Rules

Respect `linking_style.moc_preference` from the vault profile.

| Preference | Behavior |
|------------|----------|
| `heavy` | Full map with categories, cross-links, and metadata |
| `light` | Compact relationship map with links only |
| `none` | No automatic map generation, even when density is high |

Generate a map only when the density threshold is met, the profile permits it, or the user explicitly asks for the view.

## Dirty-Path Triggers

Track writes that can stale the ontology.

| Event | Dirty Scope |
|-------|-------------|
| `/pa draft` writes a note | The new note path plus linked entities |
| `/pa capture` writes a note | The captured note path |
| `/pa survey` completes | Full vault refresh |
| `/pa link` or `/pa focus` runs | Target neighborhood refresh before analysis |

Record these events in `.pa/derivation-state.json`.

## Dirty-Path Entry Shape

Use a minimal appendable record.

```json
{
  "path": "notes/new-note.md",
  "event": "draft:create",
  "content_hash": "sha256:7b8c...",
  "queued_at": "2026-03-23T09:30:00+09:00",
  "ontology_status": "pending"
}
```

The next targeted ontology read should process pending entries in the relevant neighborhood before trusting the graph.

## Refresh Procedure

1. Load pending dirty paths for the relevant neighborhood.
2. Remove stale evidence slices for changed or deleted notes.
3. Re-extract entities and relations from the surviving paths.
4. Mark processed entries as refreshed.
5. Re-run health checks if the refresh changed topology significantly.

## Evidence Slices

Every entity and relation should keep note-level extraction provenance.

| Field | Meaning |
|-------|---------|
| `note_path` | Vault-relative note path |
| `note_hash` | Content hash at extraction time |
| `signals` | The structural signals found in that note |
| `extracted_at` | Timestamp of that extraction slice |

These slices make subtract-on-delete possible.

## Subtract-On-Delete Rules

When a note changes or disappears:

1. Remove the matching evidence slices from every entity and relation that references the note.
2. Re-extract fresh slices if the note still exists.
3. Mark entities with zero live slices and no profile-backed identity as orphan candidates.
4. Remove relations that no longer have any valid slices.

## Sensitive Inference Boundaries

Ontology state belongs in `.pa/`, not in visible user notes, unless the user explicitly asks for note output.

| Rule | Why It Exists |
|------|---------------|
| Store entities in `.pa/entities.json` | Ontology is assistant state, not authored prose |
| Store relations in `.pa/relations.json` | The graph should be regenerable and auditable |
| Keep confidence and provenance on every entity and relation | Traceability limits hallucinated structure |
| Do not create vault facts from semantic similarity alone | Similarity is suggestive, not authoritative |
| Do not expose hidden ontology state in notes automatically | User-visible markdown deserves explicit consent |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/SKILL.md` | Parent skill |
| `skills/pa/personal-ontology/references/ontology-health.md` | Health checks for stale or inconsistent graph state |
| `skills/pa/personal-ontology/references/relation-taxonomy.md` | Relation typing rules used after refresh |
| `commands/pa/link.md` | Consumes refreshed graph neighborhoods |
| `commands/pa/focus.md` | Uses density and map rules for focused context views |
