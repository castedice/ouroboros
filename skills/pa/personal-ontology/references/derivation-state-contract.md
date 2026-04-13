---
name: derivation-state-contract
description: This reference defines the ownership, persistence, refresh, and invalidation contract for the PA ontology overlay in `.pa/entities.json`, `.pa/relations.json`, and `.pa/derivation-state.json`.
---

# Derivation State Contract - Overlay Ownership and Lifecycle

> Purpose: Reference for `personal-ontology` - use it to understand how assistant-derived ontology state is created, refreshed, invalidated, and reconciled across PA commands.
> This reference complements `graph-refresh.md` by focusing on state ownership, persistence boundaries, and merge semantics.
> It does not restate entity ingress rules, relation catalogs, or presentation density thresholds.

## Scope

The ontology overlay is the assistant-maintained materialized head of graph state for the vault.
The user-facing source of truth remains markdown notes, confirmed profile state, approved overlays, and privacy registries.
`.pa/entities.json` and `.pa/relations.json` are derived caches with provenance, not authored notes.
`.pa/derivation-state.json` is the freshness and coordination ledger for that cache.
Commands may regenerate or merge the overlay automatically because `.pa/` is assistant state.

## File Ownership Model

| File | Role | Primary Writers | Read Contract |
|------|------|-----------------|---------------|
| `.pa/entities.json` | Materialized entity head | `pa:survey`, `pa:link`, `pa:focus`, approved `pa:capture` decision append, privacy-forget tooling | Consumers may trust it only after pending dirty paths relevant to their target are refreshed |
| `.pa/relations.json` | Materialized relation head | `pa:survey`, `pa:link`, `pa:focus`, privacy-forget tooling | Consumers may trust it only after pending dirty paths relevant to their target are refreshed |
| `.pa/derivation-state.json` | Refresh coordination state | `pa:init`, `pa:survey`, note-writing commands, `pa:link`, `pa:focus`, `pa:compile`, `pa:steward`, event and shadow scripts | Consumers read dirty status, compile cursor, and refresh timestamps before relying on graph output |

## Authority Boundaries

The weaver owns analysis and returned graph deltas, but it never writes files.
The caller command owns file persistence, retry behavior, and any merge with prior `.pa/` state.
`pa:survey` owns full-vault materialization and refresh-mode regeneration.
`pa:link` and `pa:focus` own neighborhood-scoped refresh and persistence after targeted analysis.
`pa:capture` owns the only routine direct entity append path by adding an approved decision entity to `.pa/entities.json`.
Composite commands such as `pa:reset` and `pa:steward` may reconcile child outputs, but they must not become a second source of truth.

## Creation Paths

Use these creation paths for the overlay.

| Path | Trigger | Expected Scope | Persistence Rule |
|------|---------|----------------|------------------|
| Full survey build | First `pa:survey` on an existing vault | Full vault structural scan plus optional life merge | Write fresh `entities.json`, `relations.json`, and initialize `dirty_paths: []` |
| Survey refresh | `pa:survey` in `refresh` mode | Full overlay regeneration with merge into existing settings and overlays | Regenerate ontology from current authorities and replace stale graph content |
| Fresh init bootstrap | `pa:init` creates `.pa/` state | No full graph yet unless later survey runs | Seed derivation-state only and leave ontology materialization to later extraction flows |
| Targeted graph materialization | `pa:link` or `pa:focus` without existing ontology files | Target note or target neighborhood only | Persist only the extracted neighborhood and do not escalate to a full-vault sweep |
| Approved decision append | `pa:capture` with accepted `decision_entity_candidate` | Single decision entity | Append to `entities.json` without forcing immediate relation regeneration |

## Overlay Invariants

The overlay must preserve these invariants after every write.

| Invariant | Contract |
|-----------|----------|
| Provenance | Every derived entity and relation keeps provenance strong enough to explain where it came from |
| Evidence slices | Vault-derived records keep note-level `evidence_slices` so subtract-on-delete is possible |
| Family boundary | `vault` and `life` entities stay distinct even when labels overlap |
| Privacy boundary | Masked `canonical_name` and `mask_id` stay in overlay files, and unmasking happens only in presentation |
| Canonical source | Life entities keep a profile or overlay-backed `canonical_source` even when vault reinforcement is absent |
| Regenerability | Overlay content must be reconstructable from vault notes, profile state, overlays, and mask registries |

## Dirty Queue Coupling

The overlay refresh contract is coupled to `derivation-state.json`.
Writers do not edit `entities.json` or `relations.json` blindly after vault mutations.
They first append or preserve a dirty-path entry that advertises pending downstream work.
The queue is statusful because shadow sync and ontology refresh complete independently.

## Dirty Entry Shape

Every object-form dirty entry should carry the fields below.

| Field | Meaning |
|-------|---------|
| `path` | Vault-relative markdown path that changed |
| `event` | Mutation source such as `draft:create`, `draft:revise`, `capture`, `ingest`, `compile`, `create`, `modify`, or `delete` |
| `content_hash` | Hash of the changed note content when available |
| `queued_at` | Timestamp when the path entered the queue |
| `shadow_status` | `pending` until shadow sync processes the note, then `synced` |
| `ontology_status` | `pending` until targeted ontology refresh processes the note, then `refreshed` |

Legacy string dirty entries may exist, but queue-maintenance scripts upgrade them to object form when they touch the queue.

## Status Lifecycle

| Stage | Required Meaning | Writer |
|-------|------------------|--------|
| Queued | The note changed and downstream derived views are stale | Note-writing commands or event reconcile |
| `shadow_status: "synced"` | The shadow vault has the latest protected copy or deletion outcome | `pa-shadow.sh` |
| `ontology_status: "refreshed"` | The relevant ontology consumer processed the change and persisted refreshed graph state | `pa:link`, `pa:focus`, or a rebuild flow |
| Cleanup eligible | Both statuses are complete for the same entry | Queue cleanup logic only |

Do not delete a dirty entry merely because one subsystem finished.
Cleanup happens only after both the shadow and ontology statuses are complete.

## Refresh Handshake With Weaver

The caller must follow this handshake whenever it uses weaver for incremental refresh.

1. Load the current `entities.json`, `relations.json`, and relevant pending `dirty_paths`.
2. Pass the existing graph plus pending dirty entries into the weaver request.
3. Let the weaver subtract stale `evidence_slices` before adding fresh slices for changed notes.
4. Let the weaver return updated entities, updated relations, and dirty entries with `ontology_status: "refreshed"` for the paths it processed.
5. Persist the returned graph and the updated dirty entries together in the same logical write step.

The weaver returns refresh results to the caller.
The caller owns persistence.

## Invalidation Rules

Apply invalidation at the evidence-slice level first, not by deleting whole entities immediately.

| Event Shape | Invalidation Rule | Result |
|-------------|-------------------|--------|
| Note modified with new hash | Remove prior slices for that note path, then re-extract from the current note | Entity and relation records keep only live slices |
| Note deleted or `event` contains `delete` | Remove all slices for that note path and do not re-extract | Relations with zero slices are removed |
| Vault entity loses all live slices | Mark as `orphan` rather than silently retyping or recreating it | Later health checks or rebuild logic decide final removal |
| Life entity loses vault reinforcement only | Keep the entity if its profile or overlay `canonical_source` still exists | Life identity survives because the authority is not the vault note |
| Masked entity is explicitly forgotten | Cascade removal from `mask-map`, `entities.json`, `relations.json`, and dossiers | Privacy operations may invalidate graph records outside normal note refresh |

## Special Direct-Write Exceptions

Most ontology changes should arrive through survey or weaver-mediated refresh.
Two exception classes are still valid.

| Exception | Why It Exists | Constraint |
|-----------|---------------|------------|
| Approved decision entity append from `pa:capture` | A user-confirmed decision is already approved overlay state | Append only the entity shell and let later refreshes discover reinforcement or relations |
| Registry-seeded privacy or person shells | A confirmed registration can seed an entity before broad vault reinforcement exists | Keep the shell minimal and privacy-safe until ordinary extraction enriches it |

These exceptions add state without pretending that a full graph pass happened.

## Merge Rules

Use merge semantics that respect child ownership and freshness.

| Scenario | Merge Rule |
|----------|------------|
| `pa:survey` refresh mode | Regenerate ontology from current authorities and replace stale graph head while preserving user-owned non-graph settings |
| `pa:link` or `pa:focus` refresh | Merge returned neighborhood changes into existing graph head and persist refreshed dirty statuses |
| `pa:reset` reconciliation | Merge additive `dirty_paths` or `last_compile` only when child commands did not already persist them |
| `pa:steward` bookkeeping | Merge `last_steward` only and never overwrite newer `dirty_paths`, `last_compile`, or child-owned graph updates |
| Queue cleanup | Remove entries only when `shadow_status = "synced"` and `ontology_status = "refreshed"` |

## Partial And Missing State Rules

Missing overlay files do not automatically justify a full rebuild inside every command.

| State Gap | Required Behavior |
|-----------|-------------------|
| No `entities.json` or `relations.json` during `link` or `focus` | Run lightweight target-scoped extraction only |
| No `personal-profile.json` during survey extraction | Skip life-entity creation and keep the vault graph only |
| No `mask-map.json` | Skip privacy normalization and continue with standard extraction |
| Malformed `derivation-state.json` in maintenance flows | Reinitialize the minimal object needed for the current writer rather than fabricating graph health |

## Read Trust Contract

Commands that consume ontology state must treat freshness as part of correctness.

| Consumer | Freshness Rule |
|----------|----------------|
| `pa:link` and `pa:focus` | Refresh relevant pending dirty paths before trusting neighborhood analysis |
| `pa:ask` and `pa:brief` | If ontology files are missing or unresolved, skip graph context and fall back to QMD-only retrieval |
| `pa:review` and `sentinel` | Mark ontology-health findings as provisional when dirty paths remain pending |
| `pa:heartbeat` | Use `derivation-state.json` as freshness evidence and report pending dirty counts directly |

## Validation Checklist

- [ ] `entities.json` and `relations.json` are treated as derived overlay state, not user-authored notes.
- [ ] Every targeted ontology refresh persisted both graph changes and refreshed dirty statuses together.
- [ ] Dirty entries were not removed until both `shadow_status` and `ontology_status` completed.
- [ ] Vault-derived entities and relations retained note-level `evidence_slices`.
- [ ] Life entities were not removed solely because vault reinforcement disappeared.
- [ ] Composite commands merged child-owned state additively instead of overwriting it.
- [ ] Presentation-layer unmasking did not leak back into persisted overlay files.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/graph-refresh.md` | Companion reference for dirty-path refresh and evidence-slice subtraction |
| `skills/pa/personal-ontology/references/ontology-health.md` | Defines how stale or provisional overlay state should be reported |
| `agents/pa/weaver.md` | Primary analysis consumer that returns refreshed graph deltas without writing files |
| `commands/pa/survey.md` | Owns full-vault ontology materialization and refresh-mode regeneration |
| `commands/pa/link.md` | Owns neighborhood refresh and persistence for link analysis |
| `commands/pa/focus.md` | Owns neighborhood refresh and persistence for dossier analysis |
