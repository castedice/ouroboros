---
name: incremental-refresh
description: This reference defines the incremental refresh pattern for the PA ontology, including dirty-path production, targeted graph refresh, partial-state handling, and the command choreography that avoids unnecessary full rebuilds.
---
# Incremental Refresh - Dirty Paths, Targeted Rebuilds, and Partial State
> Purpose: Reference for `personal-ontology` - use it when a command needs to refresh only the graph slice affected by recent vault changes instead of rebuilding the entire ontology.
> This reference complements `graph-refresh.md` by focusing on command choreography and degraded-state behavior.
> It does not restate the full entity schema, relation taxonomy, or map-density thresholds.
## Core Pattern
Incremental refresh is a queue-and-replay pattern.
Writer commands record changed note paths in `derivation-state.json`.
Graph consumers refresh only the affected neighborhood before trusting ontology reads.
Full rebuilds remain available, but they are reserved for onboarding, explicit re-survey, or badly degraded state.
## Why The Pattern Exists
The ontology is expensive enough that every note write should not trigger a full-vault rebuild.
Most user actions affect one note and its immediate neighborhood.
Dirty-path tracking preserves freshness without hiding stale state.
The queue also lets shadow sync and ontology refresh complete independently.
## Producer Commands
These commands add dirty paths because they create or mutate authored notes that can stale the overlay.
| Producer | Trigger | Dirty Event |
|----------|---------|-------------|
| `pa:draft` | Successful note creation | `draft:create` |
| `pa:draft` | Successful note revision | `draft:revise` |
| `pa:capture` | Successful capture note write | `capture` |
| `pa:ingest` | Successful ingest digest write | `ingest` |
| `pa:compile` | Successful compilation note write | `compile` |
| `pa-event-reconcile.sh` | External vault edits detected after the fact | `create`, `modify`, or `delete` |
Each producer appends queue entries with `shadow_status: "pending"` and `ontology_status: "pending"`.
## Consumer Commands
These commands or scripts consume the queue.
| Consumer | Refresh Responsibility |
|----------|------------------------|
| `pa-shadow.sh sync` | Updates the privacy-safe shadow copy and marks `shadow_status: "synced"` |
| `pa:link` | Refreshes the target neighborhood before link suggestions or relationship maps |
| `pa:focus` | Refreshes the dossier neighborhood before graph analysis |
| `pa:survey` in refresh mode | Rebuilds the ontology against current authorities and resets freshness across the graph |
| `pa:steward` | Detects active dirty paths and composes the narrowest maintenance path that can resolve them |
| `pa:reset` | Reconciles additive child outputs but does not perform its own graph analysis |
## Observer Commands
These commands read freshness state without directly clearing it.
| Observer | Use Of Dirty State |
|----------|--------------------|
| `pa:ask` | Uses graph context only when ontology files are present and seed resolution succeeds |
| `pa:brief` | Uses graph context opportunistically and falls back to QMD-only retrieval otherwise |
| `pa:review` | Passes pending dirty counts to sentinel so ontology findings can be marked provisional |
| `pa:heartbeat` | Treats `derivation-state.json` as the source for pending ontology work and survey freshness |
## Active Dirty Path Definition
An active dirty path is any queue entry that has not finished the ontology side of refresh.
In maintenance flows, treat only entries with `ontology_status != "refreshed"` as active ontology work.
Shadow sync may already be complete while ontology refresh is still pending.
Completed entries remain in the queue until both subsystems finish.
## Targeted Refresh Scope
Incremental refresh is always scoped before execution.
| Command | Targeting Rule |
|---------|----------------|
| `pa:link` | Use the target note, explicitly linked notes, and the entity neighborhood implied by the requested topic |
| `pa:focus` | Use the central goal or entity, its subgraph, and the candidate notes returned by graph query or librarian seeds |
| `pa:survey` refresh mode | Treat the whole vault as the refresh target |
| `pa:steward` link-repair phase | Use one repair target at a time and do not broaden into a graph sweep |
If a command cannot define a bounded neighborhood, it should not pretend to have completed a targeted ontology refresh.
## Refresh Ordering Contract
Follow this order whenever a command performs incremental graph refresh.
1. Load `settings.json`, `vault-profile.json`, `derivation-state.json`, and existing ontology files if present.
2. Resolve the target neighborhood from the user request or maintenance target.
3. Filter pending dirty paths to the neighborhood the command actually owns.
4. Pass the filtered dirty entries plus existing graph state into the weaver.
5. Persist refreshed graph output and updated dirty statuses together.
6. Present graph-derived output only after the scoped refresh step completes or explicitly degrades.
## Full Rebuild Triggers
Use a full rebuild instead of targeted refresh in the cases below.
| Trigger | Why Full Rebuild Wins |
|---------|-----------------------|
| First survey on an onboarded vault | No baseline graph exists yet |
| Explicit `full re-survey` choice | The user requested global regeneration |
| Survey refresh after major structural drift | The vault adapter, overlays, and ontology should be re-derived together |
| Widespread malformed or missing graph state | Targeted patching no longer has a trustworthy base |
`pa:link` and `pa:focus` must not silently escalate themselves into full-vault rebuilds.
## Partial State Handling
Incremental refresh must survive incomplete PA state without inventing unsupported certainty.
| Missing Or Degraded State | Required Behavior |
|---------------------------|-------------------|
| No `entities.json` or `relations.json` | Run lightweight local extraction for the target only |
| No `personal-profile.json` | Skip life-entity refresh and keep vault entities only |
| No `mask-map.json` | Skip privacy normalization and keep standard names in analysis state |
| QMD unavailable | Continue with structural-only refresh and note the missing semantic reinforcement |
| No `derivation-state.json` in steward-like maintenance | Treat dirty paths as unknown rather than automatically clean |
| Few authored notes | Allow entity refresh but skip aggressive relation discovery when the vault is too sparse |
## Partial Result Handling
Commands may return useful partial results even when refresh coverage is incomplete.
| Failure Mode | Expected Output Behavior |
|--------------|--------------------------|
| Weaver timeout during `link` | Report the failure and suggest retrying with a narrower target |
| Librarian failure during `focus` | Continue with graph-only dossier construction |
| QMD unavailable during refresh | Continue with structural-only analysis and lower confidence |
| Dirty paths remain outside the current neighborhood | Present the scoped result and keep unrelated queue entries pending |
| Child command in a composite partially succeeds | Preserve the partial child output and continue with remaining phases |
## Refresh Producers And Neighborhood Consumers
The normal command path is asymmetric.
Write-producing commands only queue work.
Graph-reading commands perform the actual ontology refresh later.
This keeps simple note creation cheap and keeps graph refresh attached to a request that actually needs it.
## Dirty Queue Merge Rules
The queue is append-first.
Producers add new entries instead of trying to edit old ones in place.
Composite commands merge additive queue payloads from child commands when the child did not already persist them.
No composite may replace the queue from stale in-memory state.
## Queue Cleanup Rules
Cleanup is not the same as refresh.
`pa-shadow.sh` marks `shadow_status`.
Graph consumers mark `ontology_status`.
Cleanup removes only entries whose shadow and ontology work are both complete.
This prevents one subsystem from erasing the other subsystem's pending work.
## Survey Refresh Mode
`pa:survey` refresh mode is the only normal command path that treats incremental refresh as a vault-wide regeneration.
It still preserves user-owned settings fields rather than overwriting them wholesale.
It re-extracts `work.jsonl` and `timeline.jsonl` and merges regenerated overlays with confirmed user state.
It regenerates entities and relations from current authorities instead of replaying only the last few dirty entries.
## Link And Focus Refresh Mode
`pa:link` and `pa:focus` consume dirty paths only when they intersect the requested neighborhood.
They refresh before analysis rather than after presentation.
They persist newly discovered entities and relations even when the vault markdown remains read-only.
They should not claim a fresh graph when relevant dirty entries were skipped.
## Maintenance Flow
`pa:steward` treats active dirty paths as a maintenance signal.
If active dirty paths exist, steward prefers survey refresh or targeted link repair depending on the surrounding evidence.
`pa:reset` does not perform graph analysis itself.
It only merges additive dirty-path outputs returned by the child commands it composed.
## Provisional Read Contract
When dirty paths remain pending, downstream graph reads become provisional rather than invalid by default.
This is why ontology-health findings can be reported with provisional markers.
The system prefers explicit uncertainty over silent staleness or silent rebuilds.
## Event-Reconcile Interaction
Incremental refresh must account for note changes that happened outside PA commands.
`pa-event-reconcile.sh` compares the current vault against `event-index.json`.
It appends `create`, `modify`, and `delete` dirty entries into `derivation-state.json`.
This lets later graph consumers repair the ontology without requiring every external edit to pass through PA first.
## Shadow Interaction
Incremental refresh is paired with shadow sync, but the two are not the same step.
Shadow sync updates the privacy-safe read surface.
Ontology refresh updates the graph overlay.
Both must complete before a dirty entry is fully resolved.
## Trust And Presentation Rule
Assistant-state refresh inside `.pa/` may proceed automatically because the files are regenerable.
User-visible markdown remains proposal-first unless the child command's own posture rules allow a bounded write.
This separation is why `pa:steward` may auto-refresh `.pa/` while still reporting markdown edits as proposals.
## Validation Checklist
- [ ] Writer commands appended dirty entries instead of forcing immediate graph rebuilds.
- [ ] Graph consumers refreshed the relevant neighborhood before relying on ontology state.
- [ ] Missing graph or profile files downgraded scope instead of blocking the entire command unnecessarily.
- [ ] Full rebuilds were used only for onboarding, explicit re-survey, or badly degraded global state.
- [ ] Pending dirty paths remained visible to review and heartbeat flows until refresh completed.
- [ ] Queue cleanup waited for both shadow and ontology completion.
## See Also
| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-ontology/references/derivation-state-contract.md` | Defines the ownership and persistence contract behind the refresh pattern |
| `skills/pa/personal-ontology/references/graph-refresh.md` | Companion reference for evidence-slice subtraction and map thresholds |
| `commands/pa/draft.md` | Produces dirty paths after note creation or revision |
| `commands/pa/capture.md` | Produces dirty paths after capture writes and may append decision entities |
| `commands/pa/link.md` | Primary targeted ontology refresh consumer |
| `commands/pa/focus.md` | Primary dossier-oriented ontology refresh consumer |
| `commands/pa/survey.md` | Owns full-vault refresh and rebuild semantics |
