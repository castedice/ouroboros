---
name: pa:review
description: "Use when you need to inspect vault health, stale commitments, and forgotten context across a time horizon"
effort: high
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Agent
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: "[--horizon week|month|quarter|year|3y|10y|30y|lifetime] [--narrative]"
---

# Review — Horizon-Aware Vault Health

Review vault health across a chosen horizon.
Detect stale commitments, orphan notes, unresolved links, forgotten context, and open-loop drift without modifying vault notes.

Horizon: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load state files, the personal profile when present, the review checkpoint, and the follow-up-report template |
| 2 | mcp__qmd__status (tool) | Check whether QMD-backed recency and resurfacing are available |
| 3 | Glob / Grep (tools, via sentinel) | Support structural orphan-note and unresolved-link scans when the vault graph must be inspected directly |
| 3 | sentinel (agent, sonnet) | Run the detection pass and return a follow-up report plus checkpoint payload |
| 3 | mcp__qmd__query / mcp__qmd__get (tools, via sentinel) | Resolve note activity metadata and semantic resurfacing evidence when QMD is available |
| 3.5 | specialist agents (agent, sonnet, optional) | Provide area-specific review guidance based on capabilities and horizon |
| 4 | scribe (agent, opus, optional) | Synthesize a life narrative for year+ reviews when `--narrative` is requested |

## References

| Reference | Path | Usage |
|-----------|------|-------|
| Review Methodology | `skills/pa/review-and-journaling/SKILL.md` | Horizon logic, thresholds, and review-pack rules |
| Review State Schema | `skills/pa/review-and-journaling/references/review-state-schema.md` | First-run initialization and checkpoint payload shape |
| Resurfacing Rules | `skills/pa/review-and-journaling/references/resurfacing-rules.md` | Candidate eligibility, ranking, and suppression |
| Values Alignment | `skills/pa/review-and-journaling/references/values-alignment.md` | Value-to-area mapping, coverage thresholds, and neutral year+ presentation |
| Serendipity Rules | `skills/pa/review-and-journaling/references/serendipity-rules.md` | Random note resurfacing, contradiction detection, and suppression rules |
| Fractal Journaling | `skills/pa/review-and-journaling/references/fractal-journaling.md` | Quarter and year+ lower-layer review posture |
| Narrative Synthesis | `skills/pa/review-and-journaling/references/narrative-synthesis.md` | Multi-period narrative collection and evidence-grounded synthesis workflow |
| Temporal Grounding | `skills/pa/content-pipeline/references/temporal-grounding.md` | Distinguish artifact time from event time when reviewing staleness |
| Follow-Up Report Template | `templates/pa/follow-up-report.md` | Output contract for the rendered report |
| Life Narrative Template | `templates/pa/life-narrative.md` | Output contract for `--narrative` year+ synthesis |
| Domain Specialization | `skills/pa/domain-specialization/SKILL.md` | Specialist methodology and capability-based invocation |
| Activation Signals | `skills/pa/domain-specialization/references/activation-signals.md` | auto_state update rules for last_matched_at |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | Vault path, QMD mode, collection name, and capability tier |
| `.pa/vault-profile.json` | read | Journaling style, intentional-island rules, and linking style |
| `.pa/personal-profile.json` | read | Stated direction, values, and current focus for year-plus checkpoint grounding |
| `.pa/work.jsonl` | read | Open work, waiting-fors, owners, and stable item ids |
| `.pa/timeline.jsonl` | read | Dated anchors, milestones, and cadence pressure |
| `.pa/entities.json` | read | Active entities, semantic anchors for resurfacing, and life goals with `horizon`, `status`, and optional `area_refs` |
| `.pa/relations.json` | read | Typed graph edges for ontology health checks |
| `.pa/memories.jsonl` | read | Fact history used for contested-fact review and ontology health |
| `.pa/memory-heads.json` | read | Active or contested fact heads for integrity checks |
| `.pa/entity-revisions.jsonl` | read | Entity identity history for revision-chain integrity checks |
| `.pa/derivation-state.json` | read | Dirty-path state used to mark ontology health findings as provisional |
| `.pa/review-state.json` | read+write | Prior checkpoints, open-loop snapshot, resurfacing history, serendipity suppression, and the new checkpoint |
| `.pa/context-profiles.json` | read (optional) | Approved context budget for `review` optional state loading |
| `.pa/soul.md` | read | Soul layer — render settings (frontmatter) + reasoning personality (body) |
| `.pa/specialists.json` | read | Specialist registry for capability-based review consultation |
| `.pa/specialist-insights.jsonl` | append | Specialist advice status history for enrichment loop |
| `.pa/assistant-ledger.jsonl` | append | Read-only run telemetry and audit metadata |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Default to `--horizon week` |
| `--horizon` missing a value | 1 | Abort: "Provide a horizon: `week`, `month`, `quarter`, `year`, `3y`, `10y`, `30y`, or `lifetime`" |
| `--horizon` value is invalid | 1 | Abort: "Invalid horizon. Use `week`, `month`, `quarter`, `year`, `3y`, `10y`, `30y`, or `lifetime`" |
| `--narrative` with horizon below `year` | 1 | Abort: "`--narrative` is only available with year+ horizons" |
| Extra arguments beyond `--horizon` and optional `--narrative` | 1 | Abort: "Review only accepts `--horizon week|month|quarter|year|3y|10y|30y|lifetime` and optional `--narrative`" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/review-state.json` or malformed checkpoint | 2 | First run — continue with a full scan and initialize the checkpoint on completion |
| Missing `work.jsonl`, `timeline.jsonl`, or `entities.json` | 2 | Continue with partial evidence, lower confidence, and say which overlay was missing |
| Missing `memories.jsonl`, `memory-heads.json`, or `entity-revisions.jsonl` | 2 | Continue without contested-fact or revision-chain checks and say which overlay was missing |
| QMD unavailable | 3 | Skip resurfacing and any QMD-backed recency lookup, then continue with structural review only |
| `week` horizon | 3 | Scan the last 7 days of work items and check waiting-fors with full operational thresholds |
| `month` horizon | 3 | Scan the last 30 days, include orphan notes, and run resurfacing when QMD is available |
| `quarter` horizon | 3 | Scan the last 90 days, keep only the highest-signal drift, and add a goal-progress check |
| `year`, `3y`, `10y`, `30y`, or `lifetime` | 4 | Render only the highest-signal mechanical findings, add `Goal Progress`, `Values Alignment`, `Serendipity`, and `Contradictions & Tensions` sections as available, and append a direction checkpoint grounded in both `personal-profile.json` and goal entities when available |

### Recovery

Use one bounded recovery loop per delegated surface in this review.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Sentinel review pass | 1 full attempt + 1 narrowed retry using only the currently available overlays | The retry times out again, omits the same required sections, or returns the same failure class | Stop retrying, present the partial report, and preserve the limitation note |
| Specialist consultation | 1 attempt per qualifying specialist | The same specialist times out or returns `no-data` for the same matched inputs | Skip that specialist for this run and continue without looping |
| Narrative synthesis (`--narrative`) | 1 scribe attempt + 1 narrower retry with the highest-signal source subset only | The retry still cannot produce the required narrative sections | Stop retrying, omit the narrative, and keep the standard review report only |
| Repeated partial coverage inside the same run | 0 extra retries once two consecutive phases fail to add new evidence | Two consecutive retries preserve the same missing evidence categories or the same unresolved gaps | Stop escalation inside this invocation and recommend the narrow follow-up command in the rendered report |

| `--narrative` with year+ | 4 | After standard review, delegate narrative synthesis to scribe |
| Sentinel surfaces no actionable findings | 4 | Render a healthy-vault report that explicitly says the vault is healthy |
| Sentinel fails | 4 | Present a partial report with the failure note and do not hide the missing coverage |

## Horizon Behavior

| Horizon | Scope | Output Posture |
|---------|-------|----------------|
| `week` | Last 7 days of work items plus waiting-for drift | Operational follow-up report with concrete stale and carry-forward signals |
| `month` | Last 30 days plus orphan-note scan and resurfacing | Broader follow-up report with neglected themes and structural drift |
| `quarter` | Last 90 days plus selective goal-progress check | Hybrid review that compresses lower-signal noise and preserves only material drift |
| `year`, `3y`, `10y`, `30y`, `lifetime` | Conversation-driven review using vault data as prompts instead of verdicts | Follow-up report plus `Goal Progress` and a direction checkpoint grounded in the vault's current trajectory, personal profile, and active goal entities when available |

## Phase 1: Parse Input

Parse `$ARGUMENTS` as an optional horizon flag plus an optional `--narrative` flag.

Accepted forms:

- no argument
- `--horizon week`
- `--horizon month`
- `--horizon quarter`
- `--horizon year`
- `--horizon 3y`
- `--horizon 10y`
- `--horizon 30y`
- `--horizon lifetime`
- `--horizon year --narrative`
- `--narrative` (only valid with `year+` horizons)

Default to `week` when no argument is provided.
`--narrative` is supported with `year`, `3y`, `10y`, `30y`, and `lifetime`.
If `--narrative` is present without an explicit horizon, resolve the default horizon first, then apply the year+ validation from the Decision Matrix.

Do not accept custom date ranges or extra flags.
Resolve malformed input per the Decision Matrix.

## Phase 2: Core + State Load

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `advanced`, present guidance and suggest `/pa brief`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` and extract the vault path, QMD collection, QMD mode, and capability tier.
2. Read `.pa/vault-profile.json` and extract `linking_style`, journaling style, intentional-island patterns, and any profile-aware exclusions relevant to orphan detection.
3. Read `.pa/work.jsonl` when present.
4. Read `.pa/timeline.jsonl` when present.
5. Read `.pa/entities.json` when present.
Filter active life goals from entities for year+ horizons.
6. Read `.pa/memories.jsonl`, `.pa/memory-heads.json`, and `.pa/entity-revisions.jsonl` when present.
Pass them to sentinel for contested-fact review and ontology health checks.
7. Read `.pa/relations.json` and `.pa/derivation-state.json` when present.
Pass entities, relations, and `dirty_paths` to sentinel for ontology health checks (pending paths allow sentinel to mark findings as provisional).
8. Check `mcp__qmd__status` before any QMD-backed resurfacing or note-activity resolution.
9. Read `templates/pa/follow-up-report.md` so the render phase stays template-faithful.
10. Read `.pa/context-profiles.json` (optional). If present, load the approved `review` profile and use it to decide which optional state or enrichment files to skip. If the file is missing or has no approved `review` profile, follow the defaults from `skills/pa/context-assembly/references/loading-strategy.md`.
11. Do not interpret stale-date semantics during load.
Pass any available `event_date_*` and `document_date` fields through unchanged so sentinel can apply the temporal review rules once in Phase 3.

### Phase 2.5: Enrichment Load

Load enrichment files per `skills/pa/context-assembly/references/loading-strategy.md`.
Skip files that are empty or missing.

10. Read `.pa/personal-profile.json` when present and extract `direction.long_term_direction`, `direction.directions_by_area`, `identity.values_and_principles`, `focus.current_focus`, and `direction.last_direction_review`.
11. Read `.pa/review-state.json` when present.
If `.pa/review-state.json` is missing or malformed, treat the run as first-run context and prepare the default object from `skills/pa/review-and-journaling/references/review-state-schema.md`.
12. Read `.pa/soul.md` — load soul layer (frontmatter for render settings, body for soul context). If missing, read `.pa/persona.json` as fallback (render only). If both missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.
13. Read `.pa/specialists.json` — load specialist registry. If missing, skip specialist consultation in Phase 3.5.
14. Read `.pa/memory/observations.jsonl` (optional) — load accumulated signals to strengthen gap detection. Unactioned `direction-shift` and `work-change` observations inform the sentinel's review scope. If missing, continue without memory augmentation.

Only `.pa/settings.json` and `.pa/vault-profile.json` are hard prerequisites.
Missing overlays or a missing personal profile lower confidence but do not block the review.

### Year-Plus Goal Horizon Filter

For `year+` horizons, load active goals whose `goal.horizon` is the selected horizon or longer.

| Selected Horizon | Included Goal Horizons |
|------------------|------------------------|
| `year` | `year`, `3y`, `10y`, `30y`, `lifetime` |
| `3y` | `3y`, `10y`, `30y`, `lifetime` |
| `10y` | `10y`, `30y`, `lifetime` |
| `30y` | `30y`, `lifetime` |
| `lifetime` | `lifetime` |

If no matching goals exist, continue with profile-grounded direction review only.

## Phase 3: Sentinel Delegation

> Agent: **sentinel**

Delegate the review pass to the sentinel agent.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | selected horizon, current date, `.pa/settings.json`, `.pa/vault-profile.json`, `.pa/personal-profile.json` when present, available overlay contents from `.pa/work.jsonl`, `.pa/timeline.jsonl`, `.pa/entities.json`, `.pa/memories.jsonl`, `.pa/memory-heads.json`, `.pa/entity-revisions.jsonl`, `.pa/relations.json`, `.pa/derivation-state.json -> dirty_paths` when present, `.pa/review-state.json` or the prepared first-run default, and QMD availability |
| Instructions | Apply `skills/pa/review-and-journaling/SKILL.md`, `skills/pa/review-and-journaling/references/review-state-schema.md`, `skills/pa/review-and-journaling/references/resurfacing-rules.md`, `skills/pa/review-and-journaling/references/values-alignment.md`, `skills/pa/review-and-journaling/references/serendipity-rules.md`, `skills/pa/review-and-journaling/references/fractal-journaling.md`, `skills/pa/content-pipeline/references/temporal-grounding.md`, `skills/pa/personal-ontology/references/ontology-health.md`, and `skills/pa/personal-ontology/references/contradiction-resolution.md`. Match the scan depth to the selected horizon. Keep `week` and `month` evidence-heavy, treat `quarter` as hybrid, and treat `year+` as conversation-driven. When checking stale commitments, use `event_date_start` / `event_date_end` to determine when the commitment or progress actually happened, and fall back to `document_date` only when no event date is grounded. When checking goal staleness, use the most recent event-date evidence as the last meaningful progress signal before falling back to document-date evidence. When `event_date` and `document_date` differ, return both dates, the `temporal_source` that drove the stale calculation, and any material temporal-gap note. When contested memory facts remain unresolved, return them in a dedicated `Contested Facts` category with both versions, their evidence, and when each version was observed. When `personal-profile.json` is available, use stated direction and values to ground direction checkpoint questions. When matching life goal entities are available at `year+`, return a `goal_progress` summary that lists active goals, their areas, and recent evidence of progress or staleness. Run values alignment only for `year+` horizons, and keep all alignment and contradiction wording neutral. Skip resurfacing when QMD is unavailable. Never mutate vault notes or assistant state. Return only findings, evidence, and checkpoint payloads. |
| Expected Output | Structured follow-up-report fields, a health summary, surfaced note paths, optional `contested_facts`, optional `goal_progress`, optional `values_alignment`, optional `ontology_health`, optional `knowledge_decay_candidates`, optional `serendipity_candidates`, optional `contradictions`, optional long-horizon direction questions, and a `checkpoint_payload` for `.pa/review-state.json` |

### Recovery

| Failure | Action |
|---------|--------|
| Sentinel timeout | Present a partial report with the timeout noted and preserve the already-known state limitations |
| Missing overlays | Continue with structural-only or partial evidence categories and lower confidence |
| QMD unavailable | Omit `Resurfacing Candidates` and note the limitation in the summary |
| Zero findings | Return a healthy-vault result instead of padding the report |

## Phase 3.5: Specialist Consultation (Optional)

Skip this phase if `.pa/specialists.json` is missing, has zero active entries, or no active specialist has `surfaces` including `"review"`.

### Capability-Based Selection

Only call specialists whose `capabilities` match the review horizon:

| Review Horizon | Required Capabilities |
|---------------|----------------------|
| `week` | `assess_today`, `habit_check` |
| `month` | `assess_today`, `habit_check`, `carry_forward` |
| `quarter+` | `risk_scan`, `carry_forward` |

A specialist is called only when:
1. `status == "active"` and `surfaces` includes `"review"`.
2. At least one of its `capabilities` matches the horizon's required capabilities.
3. At least one work item or timeline event matches its `area_refs`.

### Specialist Input

For each qualifying specialist:

1. Filter work.jsonl and timeline.jsonl items that match the specialist's `area_refs` (exact match on tags, title, description, or source path).
2. If zero items match, skip this specialist.
3. Load area-specific context: `area_goals` from entities.json (goals with matching `area_refs`), `personal_context` from personal-profile.json (`directions_by_area[area]`).
4. Add `review_findings` slice: pass sentinel-surfaced stale items, risks, and orphan notes that match this specialist's `area_refs` to the specialist input.
5. Delegate to the specialist agent (`Agent(model: sonnet)`) with the area-scoped input contract from `skills/pa/domain-specialization/SKILL.md`.
6. Run matching specialists in parallel when multiple qualify.
7. Collect `specialist_advice[]`. If a specialist times out, skip it and continue.
8. Update `auto_state.last_matched_at` for each specialist that received at least one matching item.
9. For each specialist that returned advice, append one insight entry to `.pa/specialist-insights.jsonl` per `skills/pa/domain-specialization/references/insight-accumulation.md`. If append fails, continue without blocking.

Pass `specialist_advice[]` to Phase 4 for rendering.

## Phase 4: Present

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

Render the result per `templates/pa/follow-up-report.md`.

Preserve the sentinel's evidence fields as-is.
Do not rewrite weak evidence into stronger claims.
When stale findings include both `event_date` and `document_date`, render both dates and keep the sentinel's `temporal_source` explanation intact.
When `contested_facts` are present, render a dedicated `## Contested Facts` section that shows both versions, their evidence, and their temporal context without picking a winner in the presentation layer.
Keep the section framed for user resolution rather than automated closure.

### Output Shape

| Horizon | Required Shape |
|---------|----------------|
| `week` | `Stale Items` → `Stale Waiting-Fors` → `Contested Facts` → `Orphan Notes` → `Unresolved Links` → `Resurfacing Candidates` → `Open Loops Delta` → `Ontology Health` → `Specialist Guidance` → `Summary` |
| `month`, `quarter` | `Stale Items` → `Stale Waiting-Fors` → `Contested Facts` → `Orphan Notes` → `Unresolved Links` → `Resurfacing Candidates` → `Open Loops Delta` → `Ontology Health` → `Knowledge Refresh Candidates` → `Serendipity` → `Contradictions & Tensions` → `Specialist Guidance` → `Summary` |
| `year+` | The same follow-up report, but with only the highest-signal mechanical findings, followed by `Contested Facts` → `Goal Progress` → `Ontology Health` → `Knowledge Refresh Candidates` → `Values Alignment` → `Serendipity` → `Contradictions & Tensions` → `Specialist Guidance` → a `Direction Checkpoint` with 3-5 grounded questions that reference `personal-profile.json` and active goal entities when available |

### Narrative Synthesis (`--narrative` only)

When `--narrative` is specified:

1. Collect narrative input sources per `skills/pa/review-and-journaling/references/narrative-synthesis.md`.
2. Delegate to scribe with `mode: "narrative"`, passing the collected sources, the review window, and `templates/pa/life-narrative.md`.
3. The scribe applies the synthesis workflow from `narrative-synthesis.md` and writes in vault-native voice.
4. Present the narrative in the conversation.
5. If posture is `apply-low-risk` or higher, propose writing the narrative as a vault note at `{authored_root}/{period_label}-narrative.md`.

### Specialist Guidance Rendering

If `specialist_advice[]` from Phase 3.5 is non-empty, render a `## Specialist Guidance` section after the sentinel follow-up report sections (or after `Goal Progress` for year+ horizons).

- Order specialist insights by `priority_hint` (high → normal → low).
- Render each specialist's advice using the output contract from `skills/pa/domain-specialization/SKILL.md`.
- If no specialists were called or all returned `no-data`, omit the section entirely.
- Do not fabricate specialist advice. The section appears only when Phase 3.5 produced results.

If the sentinel surfaced no actionable findings, the summary must explicitly say: "Vault is healthy. No actionable mechanical drift detected."
When matching year-plus goals are available, `Goal Progress` should list each active goal, its area, and the clearest progress evidence or staleness signal from the review pack.
When `.pa/personal-profile.json` is available, include at least one `Direction Checkpoint` question in this form: "Your stated direction is '{long_term_direction}', and your active {selected_horizon}+ goals are {goal_list}. Does that goal mix still feel aligned with the direction?"

### Decision Boundary

After presenting findings, ask once:

```text
Address these findings now?
```

If the user declines, end the report after the findings and skip follow-up suggestions. Phase 5/6 state persistence still runs regardless.

### Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Stale items or waiting-fors surfaced and the selected horizon is `week` | `/pa agenda --horizon week` — turn the review findings into a concrete weekly priority reset |
| Stale items or waiting-fors surfaced and the selected horizon is `month` or longer | `/pa agenda --horizon month` — turn the review findings into a bounded carry-forward reset |
| Orphan note or unresolved link surfaced | `/pa link "{note_path_or_topic}"` — inspect the connection gap directly |
| Resurfacing candidate surfaced | `/pa link "{resurfaced_note_path}"` — reconnect the resurfaced note to current work |
| User wants the full reset | `/pa reset --horizon {selected_horizon}` — compose review with compile, agenda, and link |
| `year+` direction checkpoint rendered | Reply to the questions before deciding what to recommit, stop, or reshape |
| Recurring review | `/loop 2h /pa review --horizon week` — watch for stale items during active sessions |

## Phase 5: State Update

Update `.pa/review-state.json` after the report is shown.

1. If the file was missing or malformed, initialize it with `last_review: {}`, `open_loops_snapshot: []`, `resurfaced: []`, and `knowledge_decay_suppressed: []`.
2. Write `last_review[{horizon}]` with the completion timestamp and findings count from the sentinel output.
3. Replace `open_loops_snapshot` when the run was operational (`week`, `month`, or `quarter`) and the sentinel returned a current loop view.
4. Append resurfaced-note entries shown in this run with `acted_on: null`.
5. If the run was purely strategic at `year+`, update `last_review` only unless the sentinel returned an explicit operational snapshot change.

When `/pa review` is consumed by `/pa reset`, reuse the same `checkpoint_payload` and avoid double-writing stale state.

## Phase 6: Ledger Append

1. Append the review run entry to `.pa/assistant-ledger.jsonl`.
2. Include `state_files_loaded`, `state_files_used`, and `estimated_context_chars` in the ledger entry per the Context Telemetry section in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

## Composability

| Context | Usage |
|---------|-------|
| `/pa reset` | Primary composite consumer that embeds or summarizes this follow-up report |
| `templates/pa/follow-up-report.md` | Output artifact produced by this command |
| `/pa agenda` | Downstream consumer for stale commitments, waiting-fors, and carry-forward pressure |
| `/pa link` | Downstream consumer for orphan notes, unresolved links, and resurfaced notes |

## Rules

- **Read-only for vault notes**: Review never edits, archives, or rewrites user notes.
- **Detection-first**: Review detects drift and open loops. It does not remediate them inline.
- **Horizon-aware**: Keep short horizons operational and long horizons conversation-driven.
- **QMD-optional**: Resurfacing is skipped cleanly when QMD is unavailable.
- **Checkpointed**: Update `.pa/review-state.json` after every completed run.
