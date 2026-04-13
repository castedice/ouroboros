---
name: survey-bootstrap-contract
description: This reference defines the shared bootstrap sequence for `/pa survey`, including state-file write order, refresh merge rules, specialist registry refresh, content-pipeline detection, shadow sync, and read-deny setup.
---

# Survey Bootstrap Contract — State Initialization, Registry Refresh, And Shadow Setup

This reference keeps `/pa survey` at the orchestration layer once the vault profile is confirmed.
The command owns sequencing and branching, while detailed generation rules live in sibling references or scripts.

## Write Order

1. Ensure `$VAULT/.pa/` exists.
2. Write `vault-profile.json`.
3. Render `vault-profile.md` from `templates/pa/vault-profile.md` using its Render / Parse Contract.
4. Write `settings.json`.
5. If Phase 5.5 approved a personal-profile update, write `personal-profile.json`.
6. Regenerate `work.jsonl` and `timeline.jsonl` from the full vault.
7. Write `derivation-state.json`.
8. Persist the delegated `ontology_pack` outputs to `entities.json`, `relations.json`, `entity-revisions.jsonl`, `memories.jsonl`, `memory-links.jsonl`, and `memory-heads.json`.
9. Refresh specialist registry state.
10. Run content-pipeline detection.
11. Run shadow sync.
12. Generate `.pa/deny-paths.json`.

## Refresh Merge Rules

Refresh mode preserves explicit user-owned settings fields unless the user changed them during confirmation.
Refresh mode rewrites generated overlays and derived assistant-state files.
Refresh mode re-extracts `work.jsonl` and `timeline.jsonl` and merges them with user-confirmed items that already exist.
Refresh mode never silently deletes approved profile or preference data.

## Specialist Registry Refresh

Use `skills/pa/domain-specialization/references/activation-signals.md` as the authoritative contract for coverage-signal calculation, suggested-specialist creation, decline suppression, and deactivation.
Use `skills/pa/interviewing/references/question-patterns.md` for the specialist persona interview when the user chooses `create now`.
If no `specialists.json` exists but the confirmed personal profile has `core_areas`, survey offers initial specialist creation after the state bootstrap.
Survey owns the registry update, but it does not restate the signal algorithm inline.

## Content Pipeline Detection

After `settings.json` exists, run `scripts/pa-extract.sh status` and `scripts/pa-youtube.sh status`.
Merge only successful detector outputs into `settings.json` under `content_pipeline.extractors`.
Missing detector scripts or failed probes are warnings, not bootstrap blockers.

## Shadow Bootstrap

Use `scripts/pa-shadow.sh sync $VAULT` as the authoritative shadow bootstrap surface.
Treat the resolved `shadow_root` as canonical.
Derive `shadow_vault_id` from the basename of the resolved `shadow_root` rather than reimplementing the hash formula in the command body.
If shadow sync succeeds, set `shadow_synced: true` and `shadow_sync_timestamp` in `derivation-state.json`.
If shadow sync fails, keep the survey successful and report the shadow state as degraded.

## Read-Deny Bootstrap

Create `.pa/deny-paths.json` after shadow sync using authored placement roots from `vault-profile.json`.
Keep `.pa/` as an allowed prefix.
The guard is opt-out by file presence, so creating the config does not force the user to keep it.
If deny-path generation fails, report the degraded guard status without rolling back prior state writes.

## Mirror Failure Rule

If only `vault-profile.md` rendering fails, keep the machine-readable state files and report the mirror as missing.
The JSON profile remains authoritative.

## Report Expectations

The final survey report should name which bootstrap steps succeeded, which were degraded, and which were skipped by branch choice.
