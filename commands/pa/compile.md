---
name: pa:compile
description: "Use when you need to roll up captures and recent inputs into a durable period summary"
effort: medium
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Agent
  - Write
  - AskUserQuestion
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: "[--from YYYY-MM-DD] [--to YYYY-MM-DD]"
---

# Compile — Period Synthesis

Aggregate timestamp notes, captures, and ingest digests from a time period into a single compilation note with themes, decisions, carry-forward items, and evergreen candidates.

Arguments: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 4 | scribe (agent, opus) | Vault-native voice synthesis for period summary |
| 3 | librarian (agent, sonnet) | QMD retrieval for source collection and theme reinforcement |
| 2 | Read (tool) | Load state files, read eligible source notes |
| 5 | Bash (tool) | Run the write-safe inspect or declassify gate before any direct write |
| 5 | Write (tool) | Create period compilation note |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | compile_cadence, naming rules, placement, linking style |
| `.pa/settings.json` | read | Vault path, collection name, posture |
| `.pa/derivation-state.json` | read+write | Compile cursor (last_compile), dirty paths |
| `.pa/ingest-tracker.jsonl` | read | Consumption log entries for the compilation window |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `compile_cadence` and no explicit range | 1 | Abort per compilation-policy.md no-op conditions |
| Fewer than 3 eligible sources | 3 | No-op: report source count and suggest wider range |
| All sources already compiled | 3 | No-op: report "all captures already compiled" |
| Explicit `--from` / `--to` provided | 2 | Override cadence-derived window |
| Day handoff present in conversation | 3 | Use handoff for pre-filtering and theme hints |
| Posture is `observe` or `propose` | 5 | Present proposal without writing |
| Posture is `apply-low-risk` or higher | 5 | Write the compilation note |

### Output Contracts

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `abort` | Required setup, cadence, or range validation fails | Short error with the failed prerequisite, the affected window if known, and the exact next command or correction |
| `no-op` | Fewer than 3 eligible sources or all sources are already compiled | Window summary, source count, exact no-op reason, and one widening or retry suggestion |
| `proposal-only` | Posture or declassification blocks the write | Full rendered compilation note, proposed target path, gate status, and blocking reason |
| `written` | Compilation note is created successfully | Full rendered compilation note, written path, source count, and next actions |
| `synthesis-failure` | Source assembly or scribe synthesis fails after bounded recovery | Short failure report with window, source count, failed phase, and one concrete retry suggestion |

Use the matching output contract in Phase 6 so every material outcome stays reconstructable.


## Phase 1: Parse Arguments

Extract optional `--from` and `--to` date arguments from `$ARGUMENTS`. If neither is provided, the compilation window is derived from `compile_cadence` in Phase 2.

## Phase 2: Determine Compilation Window

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `advanced`, present guidance and suggest `/pa day --mode evening`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` (including `shadow_root`), `.pa/vault-profile.json`, `.pa/derivation-state.json`.
2. Apply `skills/pa/executive-assistance/references/compilation-policy.md` cadence-to-window mapping.
3. If `--from` or `--to` is provided, override the cadence-derived defaults.
4. If `last_compile.timestamp` exists, use it as the start boundary for `rolling` / `custom` cadence.
5. Log the resolved window: "Compilation window: {start} — {end}".

## Phase 3: Collect Eligible Sources

Build a deterministic manifest first, then delegate compilation-scoped extraction and temporal grouping to the librarian.

### Manifest Build

1. Use `skills/pa/executive-assistance/references/compilation-policy.md` to resolve eligible source families and exclusion rules for the selected window.
2. Build a manifest of candidate note paths from timestamp notes, clippings, ingest-digest notes, and any same-period handoff artifacts already surfaced by `/pa day --mode evening`.
3. Read `.pa/ingest-tracker.jsonl` only to assemble reflection summaries and latest-entry-per-path consumption status for the selected window.
4. Exclude existing compilation notes, profiled notes, `.pa/` files, and templates before any delegated reading.
5. Keep the manifest as path-level evidence only.
Do not extract durable units, infer themes, or perform temporal bucketing inline in the command body.

### No-Op Check

If the manifest has fewer than 3 eligible sources, report and stop per `skills/pa/executive-assistance/references/compilation-policy.md` no-op conditions.
If all eligible sources are already covered by the current `last_compile.output_path` or cursor window, report and stop with the exact reason.

### Scope Confirmation

Present the compilation scope to the user:

```text
Compiling period {start} — {end} with {n} eligible sources. Proceed?
```

Wait for user confirmation before delegated source reading.
Skip this checkpoint only when `/pa compile` is called by `/pa reset`.

### Librarian Delegation

> Agent: **librarian**

Delegate source condensation, temporal bucketing, and theme reinforcement to the librarian.

| Contract Part | Content |
|---------------|---------|
| Input | compilation window metadata, manifest paths with source-family labels, optional day-handoff compile-candidate block, latest-entry-per-path ingest tracker summaries for the window, settings.json contents including `shadow_root`, vault-profile.json contents, and `last_compile` cursor when present |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` only for compilation-scoped source assembly. Read the manifest items, prefer shadow copies when available, extract durable units, and apply the temporal grouping rules from `skills/pa/executive-assistance/references/compilation-policy.md` plus `skills/pa/content-pipeline/references/temporal-grounding.md`. Return event-first temporal buckets, theme hints, carry-forward candidates, evergreen candidates, and any coverage limitations. Do not write files |
| Expected Output | `collection_pack` with `eligible_sources[]`, per-source durable units, event-first temporal buckets, theme hints, carry-forward candidates, evergreen candidates, consumption-log summaries, and `coverage_note` |

### Recovery

| Failure | Action |
|---------|--------|
| Librarian timeout or QMD/tool failure before source condensation completes | Retry once with the top 10 highest-signal manifest items only |
| Librarian returns partial coverage | Keep the partial `collection_pack`, mark the missing source families, and continue to scribe |
| Librarian returns the same failure class or no additional coverage on the retry | Stop retrying, report source-assembly failure, and do not continue to scribe |

## Phase 4: Scribe Synthesis

> Agent: **scribe**

Delegate vault-native voice synthesis to the scribe agent.

### Pre-delegation: Exemplar Collection

Search for existing compilation notes in the vault (notes with `compiled_from` frontmatter or matching compilation title patterns). Use these as exemplars for voice adaptation per `skills/pa/writing/SKILL.md`.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | Extracted durable units grouped by event-first temporal buckets and then by theme, compilation window metadata, exemplars (if found), vault-profile.json contents |
| Instructions | Apply `skills/pa/writing/SKILL.md` workflow. Walk the precedent ladder using existing compilation notes as exemplars. Synthesize the period's content into event-date bucketed sections with thematic grouping inside each bucket. Use `event_date_start` / `event_date_end` when available, fall back to `document_date` when they are absent, and preserve legacy grouping only when no temporal fields exist. Produce carry-forward items, decisions, evergreen candidates, and the `Temporal Coverage` summary line. Render per `templates/pa/period-compilation.md` |
| Expected Output | write_plan with rendered compilation note content, confidence, style sources |

### Recovery

| Failure | Action |
|---------|--------|
| Scribe timeout | Report error, suggest retrying with fewer sources |
| No exemplars found | Use vault-profile writing_style defaults. Note low voice confidence |

## Phase 5: Render and Write

Apply posture check per `skills/pa/trust-and-boundaries/SKILL.md`. Single note creation is a low-risk write — allowed at `apply-low-risk` or higher.

### Declassification Gate

Before writing, run `scripts/pa-write-safe.sh inspect` on the scribe's rendered content. If `write_safe: false`, downgrade to proposal-only with blocking reason. If no mask-map exists, skip. Include `declassification` metadata in the ledger entry.

### Rendering

1. Use the scribe's write_plan rendered content (declassified if applicable).
2. Apply vault-profile naming: `{start}--{end}-compilation.md` or per `note_title_style`.
3. Place in `placement_rules.authored_root` (compilations are authored notes, not inbox).

### State Update

After writing:
1. Update `.pa/derivation-state.json` → `last_compile` cursor with timestamp, window, source count, and output path.
2. Append a dirty_path entry to `dirty_paths`: `{path: "{compilation_note_path}", event: "compile", content_hash: "{sha256_first_8}", queued_at: "{ISO_timestamp}", shadow_status: "pending", ontology_status: "pending"}`.

## Phase 6: Present

Output the compilation in conversation regardless of whether it was written.

### Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Evergreen candidates found | "`/pa draft '{topic}'` — 이 주제를 durable note로 승격할까요?" |
| Carry-forward items exist | "`/pa agenda --horizon week` — prioritize carry-forward items: {carry_forward_summary}" |
| Compilation complete | "`/pa link {compilation_path}` — discover connections for the new synthesis" |
| Proposal only | "이 컴파일 노트를 저장하려면 말씀하세요" |

## Composability

| Context | Usage |
|---------|-------|
| `/pa day --mode evening` | Day produces compile-candidate handoff consumed by compile |
| `/pa draft` | Receives evergreen promotion candidates from compile |
| `/pa ingest` | Ingest digests are eligible compilation sources |
| `/pa link` | After compile, link discovers connections for the new note |
| `/pa agenda` | Carry-forward items feed into next agenda cycle |
| `/pa weekly` (future) | Weekly reset will compose day + compile + review |
| `/pa` router | Router classifies compile intent and delegates here (always deep path) |

## Rules

- **Period-bounded**: Compile operates on a defined time window, not the entire vault
- **No evergreen promotion**: Compile identifies evergreen candidates but does not create them. Promotion goes through `/pa draft`
- **Single output**: One compilation note per invocation
- **Scribe handles voice**: Compilation prose matches vault writing style via exemplar-driven voice adaptation
- **Compile cursor prevents recompilation**: The cursor in derivation-state.json prevents processing the same window twice
- **Vault-profile faithful**: Respect naming, placement, frontmatter, and linking conventions
- **No-op is valid**: When sources are too few or already compiled, report cleanly and stop
