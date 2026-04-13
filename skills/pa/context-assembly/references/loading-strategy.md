---
name: loading-strategy
description: This reference defines tiered context loading rules for PA commands. It should be consulted when a command needs to "decide which state files to load", "optimize context budget", "skip unnecessary file reads", "split Phase 2 into core and enrichment tiers", "map effort level to loading strategy", or "determine if a state file can be safely skipped".
---

# Loading Strategy — Tiered Context Loading

> Purpose: Reference for `context-assembly` — defines which `.pa/` state files each command should load and when files can be safely skipped.

## Loading Tiers

| Tier | Files | When to Load |
|------|-------|-------------|
| `core` | settings.json, vault-profile.json | Always — required for every command |
| `state` | work.jsonl, timeline.jsonl, entities.json, relations.json, derivation-state.json | Phase 2 if present. Skip if file is empty (0 lines for JSONL, empty object for JSON) |
| `enrichment` | soul.md, specialists.json, specialist-insights.jsonl, retrieval-profiles.json, memory/observations.jsonl, memory/.pending-flush.jsonl | Phase 2.5 — load only when the command flow will use them |

## Effort-Tier Mapping

| Effort | Loading |
|--------|---------|
| `low` | Core only. Enrichment only if command explicitly needs it (e.g., ask needs soul.md for persona) |
| `medium` | Core + state. Enrichment on demand |
| `high` | All tiers |

## Skip Conditions

| Condition | Action |
|-----------|--------|
| JSONL file has 0 lines | Skip, note in diagnostics |
| JSON file is `{}` or `[]` | Skip, note in diagnostics |
| Optional file missing | Skip silently |
| `specialists.json` has 0 active entries | Skip specialist consultation phases |

## Per-Command Matrix

| Command | Core | State | Enrichment | Notes |
|---------|------|-------|------------|-------|
| ask | yes | no | soul.md, observations | Retrieval-focused, minimal state |
| brief | yes | no | soul.md | Retrieval-focused |
| capture | yes | no | soul.md | Write-focused |
| draft | yes | no | soul.md | Write-focused |
| agenda | yes | work, timeline | soul.md, specialists, observations | State-heavy |
| day | yes | work, timeline | soul.md, specialists, observations, retrieval-profiles | Heaviest enrichment |
| link | yes | entities, relations, derivation-state | soul.md | Ontology-focused |
| focus | yes | entities, relations, derivation-state | soul.md, mask-map | Ontology + retrieval |
| review | yes | work, timeline, entities, relations | soul.md, personal-profile, specialists, review-state, observations | Heaviest overall |
| steward | yes | derivation-state, review-state | specialists | Meta-composite |

## Threshold Rationale

| Decision | Why |
|----------|-----|
| Core always loaded | settings.json and vault-profile.json are required for posture checks and vault conventions |
| State tier conditional | JSONL files can be empty — loading 0-line files wastes context tokens |
| Enrichment deferred | soul.md, specialists, memory are additive context that many commands don't need for their core function |
| Effort maps to tiers | Low-effort commands (ask, brief) rarely need full state; high-effort commands (review, steward) need everything |

## Common Pitfalls

| Pitfall | Why It Fails | Prevention |
|---------|-------------|------------|
| Loading enrichment for low-effort commands | Wastes context budget on unused files | Check effort level before enrichment reads |
| Skipping state files that have content | False-positive empty check (file exists but has only comments) | Check line count for JSONL, key count for JSON |
| Loading all files for status mode | day --mode status needs no specialists or memory | Mode-specific skip conditions |
| Not recording skip decisions | Hard to debug why a command missed context | Include skip diagnostics in ledger |

## Validation Checklist

- [ ] Core tier files loaded for every command invocation.
- [ ] Empty JSONL files (0 data lines) skipped with diagnostic note.
- [ ] Enrichment files loaded only when command flow will use them.
- [ ] Effort level respected: low = core, medium = core+state, high = all.
- [ ] Skip decisions recorded in state_files_loaded vs state_files_used telemetry.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/context-assembly/SKILL.md` | Parent skill |
| `skills/pa/context-assembly/references/query-patterns.md` | QMD retrieval patterns |
