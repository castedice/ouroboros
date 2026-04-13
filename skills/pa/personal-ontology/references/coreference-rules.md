---
name: coreference-rules
description: This reference defines the lightweight PA coreference resolution MVP. It should be consulted when an agent needs to "resolve entity mentions against entities.json", "reuse recent session entities", "avoid duplicate entity creation from name variants", or "decide when a mention should stay unresolved for later review".
---

# Coreference Resolution - Lightweight Session-Aware Matching

> Purpose: Reference for `personal-ontology` and `curator` entity normalization.
> This is a lightweight mention-resolution pass.
> It never uses graph traversal, QMD lookup, or semantic expansion.

## Scope

Resolve named mentions against `.pa/entities.json` and the active `.pa/sessions/{id}.json`.
Normalize only when the candidate is strong enough to trust.
Prefer a missed merge over a false merge.

## Matching Order

1. **Exact canonical name match**: Match the raw mention exactly against `entities.json -> canonical_name`.
2. **Alias match**: Match the raw mention exactly against `entities.json -> aliases[]`.
3. **Normalized name match**: Lowercase, trim, collapse whitespace, and strip surrounding punctuation before comparing names.
4. **Recent session entity match**: Match against `.pa/sessions/{id}.json -> recent_entities` when the current session recently resolved the same name.

Stop at the first unambiguous strategy that yields a same-kind candidate.
If multiple same-kind candidates tie within a strategy, keep the mention unresolved.

## Confidence Defaults

| Strategy | Default Confidence |
|----------|--------------------|
| Exact canonical name match | `1.0` |
| Alias match | `0.95` |
| Normalized name match | `0.85` |
| Recent session entity match | `0.8` |

If the best surviving candidate is below `0.8`, do not auto-merge it.

## Kind Guards

Only merge candidates that share the same entity kind.
Never auto-merge `person` with `organization`, `project`, `place`, or any other kind.
If the mention kind is unknown and the candidate set spans multiple kinds, keep it unresolved.

## Session Rules

`recent_entities` is a recency hint, not a replacement for `entities.json`.
Use the session strategy only after canonical, alias, and normalized-name checks fail.
Session matches may break ties only inside the same entity kind.

## Unresolved Handling

Keep the raw mention in the output when no candidate reaches `0.8`.
Add the mention to `unresolved_entities` with the best same-kind candidate, attempted strategy, and confidence when available.
Flag unresolved mentions for later weaver or steward review.

## Output Contract

Resolved mentions should carry the existing entity identifier or canonical name plus kind.
Unresolved mentions should preserve the original surface form verbatim.
Do not create new entities during this pass.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/entity-canonicalization.md` | Broader merge and alias rules used after mention resolution |
| `agents/pa/curator.md` | Uses the lightweight pass during capture and ingest triage |
| `agents/pa/weaver.md` | Uses the same pass before materializing new entity rows |
