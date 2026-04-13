---
name: pa:day
description: "Use when you need a morning brief, an evening closeout, or a read-only view of today"
effort: medium
allowed-tools:
  - Read
  - Write
  - Edit
  - Agent
  - mcp__qmd__status
argument-hint: [--mode morning|evening|status]
---

# Day - Daily Flow

Run the daily flow by combining today's agenda, a daily briefing, recent vault activity, and mode-aware daily-note handling.

Mode: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load settings.json, vault-profile.json, work.jsonl, timeline.jsonl, retrieval overrides, and today's daily note when present |
| 3 | librarian (agent, sonnet, optional) | Gather recent vault activity and same-day capture evidence when QMD is available and recent context would sharpen today's view |
| 4 | chief-of-staff (agent, opus) | Judge priorities, render the daily brief packet, surface waiting-fors, and prepare closeout or carry-forward guidance |
| 5 | Read/Write/Edit (tools) | Render daily-brief or daily-link-hub output, apply bounded daily-note updates when allowed, and append the assistant ledger entry |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | QMD collection name, capability tier, vault path, and automation posture |
| `.pa/vault-profile.json` | read | Daily-note placement, naming rules, journaling style, linking style, and assistant preferences |
| `.pa/work.jsonl` | read | Open tasks, commitments, deadlines, waiting-fors, and ownership metadata |
| `.pa/timeline.jsonl` | read | Today's events, milestones, dated anchors, and recurring temporal context |
| `.pa/calendar-events.jsonl` | read (optional) | Today's calendar events for morning scheduling context |
| `.pa/context-profiles.json` | read (optional) | Approved context budget for `day` optional state loading |
| `.pa/preferences-learned.json` | read (optional) | Approved learned preferences for `day` adjustments |
| `.pa/heartbeat.json` | read (optional) | Latest relationship health summary when same-day date surfacing reuses the heartbeat |
| `.pa/retrieval-profiles.json` | read (optional) | `day` retrieval overrides for recent-activity lookup |
| `.pa/intelligence/energy-patterns.json` | read (optional) | Aggregated day-of-week and time-of-day energy patterns for load calibration |
| `{today's daily note path}` | read/write | Existing daily note for status inspection, daily-brief creation, or daily-link-hub refresh |
| `.pa/soul.md` | read | Soul layer — render settings (frontmatter) + reasoning personality (body) |
| `.pa/specialists.json` | read | Specialist registry for Phase 3.4 suggestions and Phase 3.5 consultation |
| `.pa/ingest-tracker.jsonl` | read/append | Evening mode: surface unreflected ingest items, append reflection entry when user responds |
| `.pa/specialist-insights.jsonl` | append | Specialist advice status history for enrichment loop |
| `.pa/assistant-ledger.jsonl` | append | Audit trail for proposals and applied daily-note mutations |

## Decision Matrix

Reuse the corresponding shared validation and fallback rows from `commands/pa/agenda.md` when the behavior is materially the same.
This includes missing required `.pa` state files and QMD availability failures in Phases 2 and 3.
For partially empty state, follow the same "continue with remaining evidence" pattern as `agenda.md`, but keep today's daily note state in the surviving inputs when available.
Apply the day-specific conditions below for mode parsing, retrieval-profile fallback, daily-note resolution, and write posture.

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No argument | 1 | Default to `--mode morning` |
| `--mode` missing a value | 1 | Abort: "Provide a mode: `morning`, `evening`, or `status`" |
| `--mode` value is invalid | 1 | Abort: "Invalid mode. Use `morning`, `evening`, or `status`" |
| Extra arguments beyond `--mode` | 1 | Abort: "Day only accepts `--mode morning|evening|status`" |
| `retrieval-profiles.json` missing | 2 | Continue with `vault-profile.json` retrieval defaults |
| `work.jsonl` is empty | 2 | Continue with timeline data, daily-note state, and recent activity only |
| `timeline.jsonl` is empty | 2 | Continue with work data, daily-note state, and recent activity only |
| `calendar-events.jsonl` missing or empty | 2 | Continue without calendar context |
| Calendar events present but stale (`synced_at > 30h ago`) | 2 | Use available events but warn: "캘린더 데이터가 오래되었을 수 있습니다" |
| `work.jsonl` and `timeline.jsonl` are both empty | 2 | Continue with today's note and recent activity only, and mark the output low confidence |
| Today's daily note path cannot be resolved | 2 | Continue in conversation-only mode and state that the daily note path is unavailable |
| `day.session_lane.enabled` missing or false | 3 | Keep the session lane disabled by default and continue with vault recent-activity lookup only |
| Mode is `status` | 5 | Never write. Present a read-only today view only |
| Mode is `morning`, `daily_note_content = links-only`, and direct write is permitted | 5 | Create or refresh today's daily link hub, and present the briefing in the conversation |
| Mode is `morning`, `daily_note_content = mixed` or `full-text`, and today's note is missing | 5 | Create today's daily brief note when the direct write path is low-risk and allowed |
| Mode is `morning`, `daily_note_content = mixed` or `full-text`, and today's note already exists | 5 | Present the daily brief in the conversation or as an exact append proposal only |
| Mode is `evening` | 5 | Present closeout plus compile-ready output in the conversation, and treat note mutation as proposal-only unless a bounded managed block already exists |
| Chief-of-staff returns low confidence | 5 | Present the day packet with explicit low-confidence markers |

### Mode Verification

After Phase 2 loads state, validate that the requested mode still fits the available state and posture before any delegation.

| Requested Mode | Verification | If Check Fails | Resulting Behavior |
|----------------|-------------|----------------|--------------------|
| `status` | Core `.pa` state loaded successfully | A required core state file is missing | Abort per the Decision Matrix. Otherwise status always remains available |
| `morning` | Today's daily note path resolves, the chosen daily template exists, and posture permits either a bounded write or a proposal-only surface | Daily note path or template is unavailable | Downgrade to conversation-only morning output and suggest `/pa day --mode status` for a pure snapshot |
| `morning` | There is enough same-day evidence in work, timeline, calendar, recent activity, or today's note to build a brief | All those sources are empty or unavailable | Continue with a sparse brief, mark low confidence, and suggest `/pa capture` or `/pa ask` to seed today's context |
| `evening` | Closeout inputs exist from today's work, activity, ingest tracker, or daily note | No same-day evidence exists | Downgrade to a minimal status-style closeout and suggest `/pa day --mode status` or `/pa capture` |
| `evening` | A bounded managed closeout block exists before any note mutation | No managed block exists or posture blocks write | Keep evening output conversation-only and do not propose an unmanaged note edit |


## Phase 1: Parse Input

Parse `$ARGUMENTS` as a single optional mode flag.

Accepted forms:

- no argument
- `--mode morning`
- `--mode evening`
- `--mode status`

Default to `morning` when no argument is provided.

Do not accept topic text, dates, or additional flags.

Resolve malformed input per the Decision Matrix.

## Phase 2: Core + State Load

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `intermediate`, present guidance and suggest `/pa ask` or `/pa capture`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` and extract `automation_posture`, capability tier, vault path, and QMD collection name.
2. Read `.pa/vault-profile.json` and extract `placement_rules.daily_dir`, `naming_rules.daily_note_pattern`, `naming_rules.timestamp_note_pattern`, `journal_style`, `linking_style`, and `assistant_preferences`.
3. Read `.pa/work.jsonl` in full.
4. Read `.pa/timeline.jsonl` in full.
5. Read `.pa/calendar-events.jsonl` (optional). Filter to today's events by comparing `date` field to current local date. If the file is missing or empty, continue without calendar data. If present, compute `calendar_summary: {total_events, timed_events, all_day_events, first_event_at, last_event_at}`.
6. Read `.pa/context-profiles.json` (optional). If present, load the approved `day` profile and use it to decide which optional state or enrichment files to skip. If the file is missing or has no approved `day` profile, follow the defaults from `skills/pa/context-assembly/references/loading-strategy.md`.
7. Read `.pa/preferences-learned.json` (optional). Apply approved rules for `day` (e.g., verbosity, aggressiveness adjustments). If file missing, continue with defaults.
8. Read `.pa/retrieval-profiles.json` and look for `day` overrides.
9. If `retrieval-profiles.json` does not exist or the approved context profile excludes it, fall back to `vault-profile.json` -> `qmd_defaults`.
Treat `day.session_lane.enabled=false` as the default session archive setting unless the profile explicitly opts in with `enabled=true`.
10. Resolve today's daily note title and path from the current local date, `placement_rules.daily_dir`, and `naming_rules.daily_note_pattern`.
11. Read `shadow_root` from `.pa/settings.json`. If today's daily note already exists, prefer reading from `{shadow_root}/{relative_path}` when shadow is available. Fall back to `.pa/shadow/` for backward compatibility, then raw vault path if no shadow exists.
12. Determine whether the selected mode can write directly.
13. `status` is always read-only.
14. `morning` and `evening` respect `automation_posture`, `assistant_preferences.auto_create_low_risk_notes`, and the bounded write rules from the daily templates.

### Phase 2.5: Enrichment Load

Apply tier decisions from `skills/pa/context-assembly/references/loading-strategy.md`.
Skip optional files that are empty or missing.

#### Enrichment Load

Read `.pa/soul.md` per the approved `day` context profile or the default tier decision from `skills/pa/context-assembly/references/loading-strategy.md`.
If `.pa/soul.md` is missing, read `.pa/persona.json` as fallback (render only).
If both are missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.
In `--mode morning` and `--mode evening`, also read `.pa/specialists.json` and `.pa/memory/observations.jsonl` when the same tier decision includes them.
If `.pa/specialists.json` is missing, skip specialist consultation in Phase 3.5.
Pass unexpired `mood-energy` signals from `.pa/memory/observations.jsonl` to chief-of-staff as supplementary judgment context.
If `.pa/memory/observations.jsonl` is missing, continue without memory.
If `.pa/memory/.pending-flush.jsonl` exists in `--mode morning` or `--mode evening`, distill raw messages into structured observations (Layer 2 flush) before proceeding.
Append results to `observations.jsonl`, delete `.pending-flush.jsonl`, and update `state.json`.
In `--mode status`, skip specialist and memory reads in this header after the soul load.

#### Intelligence Load

In `--mode morning` and `--mode evening`, read `.pa/intelligence/energy-patterns.json` when the approved `day` context profile or default tier decision includes it.
If `energy-patterns.json` is present and `sufficient: true`, pass it to chief-of-staff as `energy_patterns`.
If `energy-patterns.json` is missing or insufficient, continue without energy calibration.
In `--mode morning`, read relationship upcoming dates via `scripts/pa-relationship.sh upcoming --days 1` or from the latest heartbeat.
If upcoming notify-enabled dates exist for today or tomorrow, pass them to chief-of-staff.
In `--mode status`, skip the intelligence reads in this header.

If any required state file is missing, abort through the Decision Matrix.

## Shared Delegation Contract

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass the selected mode, concrete local date, resolved daily note path, and Phase 2 state explicitly on every call.
Use named return payloads rather than prose-only summaries.
The command owns note writes, ledger updates, and mode gating.
Internal calls use `Agent(subagent_type: "ouroboros:pa:librarian")` and `Agent(subagent_type: "ouroboros:pa:chief-of-staff")`.

Phase 3 and Phase 4 use the same compact delegation contract shape.

| Contract Part | Shared Requirement |
|---------------|--------------------|
| Input | Pass only the selected mode, the concrete local date, the minimum relevant Phase 2 state, and any phase-specific artifacts needed for the delegated judgment |
| Instructions | Keep the task narrow, prefer evidence tied to existing commitments or today's artifacts, and return compact results instead of a full dossier |
| Expected Output | Return a structured pack with concise evidence, a short assessment, and no fabricated state |

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:librarian` | 3 | `mode`, `local_date`, recent-state summary, retrieval overrides including default `session_lane.enabled=false`, daily note path, and filesystem or QMD availability | `context_pack`, `citations`, `same_day_captures[]`, optional `session_hits[]`, `session_lookup`, and `activity_assessment` |
| `ouroboros:pa:chief-of-staff` | 4 | `mode`, `local_date`, filtered work and timeline state, optional calendar and recent-activity context, optional `session_hits[]` as advisory context only, optional specialist inputs, and daily note snapshot | `day_packet`, `priorities[]`, `waiting_fors[]`, `confidence`, and `source_index` |

## Phase 3: Recent Activity

Recent activity is additive context, not the primary source of truth.

Use it to surface same-day captures, recently touched notes, and fresh evidence that materially changes today's priorities or closeout.

### Preconditions

1. Check `mcp__qmd__status` for the configured collection.
2. If QMD is unavailable, unhealthy, or unregistered, skip semantic recent-activity lookup and continue with filesystem-only daily artifact discovery.
3. If the selected mode is `morning`, prefer activity from the last 24 hours plus any same-day captures already present.
4. If the selected mode is `evening` or `status`, prefer activity from the start of the current local day.
5. When `journal_style.timestamp_notes_enabled` is `true` or `journal_style.daily_note_content` is `links-only`, collect same-day timestamp notes by filename pattern even if QMD is skipped.

### Phase-Specific Contract

Use the shared delegation contract with the following phase-specific content.

| Part | Phase 3 Content |
|------|-----------------|
| Input Additions | settings.json contents, vault-profile.json contents, retrieval-profile overrides, resolved daily note path, and a summary of the relevant work and timeline items from Phase 2 |
| Instructions | Retrieve only recent vault activity likely to affect today's plan, status, or closeout. Prefer today's daily note, same-day timestamp captures, and recently touched project or people notes tied to already-open commitments |
| Expected Output | Recent-activity pack with note titles, paths, timestamps or recency signals, brief excerpts, same-day capture candidates, optional `session_hits[]`, `session_lookup`, and a short activity assessment |

The session lane is off by default for `/pa day`.
Only include session hits when the `day` retrieval profile explicitly sets `session_lane.enabled=true`.

### Recovery

Use one bounded recovery loop per delegated or optional surface.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Recent-activity lookup | 1 status check + 1 retrieval attempt | QMD stays unavailable, or the retrieval adds no new same-day evidence | Stop lookup and continue with work, timeline, and filesystem daily artifacts only |
| Chief-of-staff day packet | 1 full attempt + 1 narrowed retry with optional enrichment removed | The retry returns the same failure class, the same low-confidence packet, or misses the same required day-packet fields | Stop retrying, render a degraded conversation-only day packet, and do not attempt note mutation |
| Evening ingest follow-up | 1 pass over the latest-entry-per-path set | The same item still has no writable target note or the same tracker conflict persists | Skip that item for this run, keep tracker state append-only, and continue with the remaining items |

## Phase 3.4: Specialist Suggestions (Optional)

Apply the specialist suggestion flow from `skills/pa/domain-specialization/references/consultation-pattern.md` Phase 3.4.
Skip in `--mode status`.

## Phase 3.5: Specialist Consultation (Optional)

Apply the specialist consultation flow from `skills/pa/domain-specialization/references/consultation-pattern.md` Phase 3.5 with surface `"day"`.
Skip in `--mode status`.
Pass `specialist_advice[]` to Phase 4 chief-of-staff delegation.

## Phase 4: Chief-of-Staff Delegation

> Agent: **chief-of-staff**

Delegate daily judgment to the chief-of-staff agent.

The chief-of-staff decides what matters now, what should carry forward, and what belongs in a bounded daily surface.

### Phase-Specific Contract

Use the shared delegation contract with the following phase-specific content.

| Part | Phase 4 Content |
|------|-----------------|
| Input Additions | filtered `work.jsonl` records, filtered `timeline.jsonl` records, optional `calendar_events` and `calendar_summary` from `.pa/calendar-events.jsonl`, optional recent-activity pack, optional `session_hits[]` from the session archive as advisory context only, optional `specialist_advice[]` from Phase 3.5, optional `energy_patterns` from `.pa/intelligence/energy-patterns.json`, optional relationship upcoming dates for today or tomorrow, today's daily note snapshot if present, settings.json contents, vault-profile.json contents, and optional `soul_principles` from `.pa/soul.md` body `## Principles` section |
| Instructions | Apply `skills/pa/executive-assistance/SKILL.md` workflow. For `morning`, combine agenda judgment with a daily briefing packet and note-write recommendation. For `evening`, produce a closeout plus compile-ready view from today's work and activity. For `status`, produce a read-only today snapshot with priorities, waiting-fors, and daily-note coverage. Prefer state-backed urgency over generic productivity advice. Return a structured day packet |
| Expected Output | Day packet with priorities, risks, waiting-fors, focus suggestions, confidence, source index, and mode-specific sections for briefing, closeout, carry-forward, compile candidates, or status snapshot |

### Judgment Rules

1. Overdue commitments outrank merely recent activity.
2. Deadline proximity matters more than note freshness.
3. Morning focus should narrow attention to `1-3` concrete threads.
4. Evening closeout should separate completed work, unresolved work, and carry-forward recommendations.
5. Status mode summarizes only the current state and never introduces a write recommendation.
6. Do not fabricate commitments, completions, capture counts, or compile themes that are not supported by state or recent evidence.
7. Do not infer commitments, deadlines, completions, or compile themes from `session_hits[]` alone.

## Phase 5: Present

Output the day flow directly in the conversation, and apply only the bounded write path allowed by the Decision Matrix.

### Morning Mode

1. Read `templates/pa/daily-brief.md`.
2. Render the daily briefing from the day packet using today's commitments, risks and deadlines, recent activity, focus suggestions, waiting-fors, and the source index.
3. If `calendar_events` exist for today, render a `## Today's Schedule` section. For timed events (`all_day: false`), list by start time: `HH:MM {title} [{location}]`. For all-day events (`all_day: true`), list at the top as `종일 {title}`. For multi-day events spanning into today, include them if today falls between `start` date and `end` date (inclusive).
This section provides temporal anchoring before Today's Commitments.
4. If upcoming relationship dates exist, render a brief `오늘/내일: {Person} {label}` line before `Next Actions`.
5. If `journal_style.daily_note_content` is `links-only`, read `templates/pa/daily-link-hub.md` and prepare the same-day link hub from timestamp links plus optional highlights.
6. **Declassification gate**: Before any Write or Edit, run `scripts/pa-write-safe.sh inspect` on the rendered content. If `write_safe: false`, skip vault write and present in conversation only. If no mask-map exists, skip declassification.
7. If direct write is permitted, declassification passed, and the resolved action is low-risk, create today's daily brief note when it is missing, or create or refresh only the managed `Links` section of today's daily hub.
8. If today's full-text or mixed daily note already exists, do not rewrite the note body. Present the briefing in the conversation, or present an exact bounded append proposal only.
9. Always present the morning briefing in the conversation even when a note is written.
10. Append a ledger entry for any applied or proposed daily-note mutation. Include `declassification` metadata plus `state_files_loaded`, `state_files_used`, and `estimated_context_chars` per the Context Telemetry section in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

### Evening Mode

1. Render a closeout with completed threads, unresolved items, carry-forward, waiting-fors, and compile candidates from today's captures or note changes.
2. Include unactioned memory signals from today's session in the closeout: list any observations captured during the day with their kind and signal text.
3. Treat the evening closeout as conversation-first output.
4. If today's note already contains a clearly bounded PA-managed closeout block and posture allows, present the exact append or refresh proposal, but do not rewrite existing prose.
5. Do not create new compilation notes from `/pa day`. The compile output is a structured handoff for a future `/pa compile`.

#### Unreflected Ingest Follow-Up

Apply the evening follow-up procedure from `skills/pa/content-pipeline/references/reflection-prompts.md` (`Evening Follow-Up` section) instead of restating the tracker rules inline.

1. Check `.pa/settings.json -> content_pipeline.reflection_remind_evening`.
2. Read `.pa/ingest-tracker.jsonl` and use the reference's `latest-entry-per-path` rule to identify today's unreflected items.
3. If no eligible items remain, skip this subsection silently.
4. If eligible items exist, present the reminder text from the reference and collect the user's reply in the conversation.
5. When the user gives substantive text, follow the reference contract for `## My Thoughts` append behavior and append-only tracker updates.
6. When the user declines, skips, or the target note does not exist, follow the reference's tracker-only path and keep the reminder pending for later review.

Do not implement any alternate tracker precedence rule here.
The reference file is authoritative for reminder wording, skip keywords, append-only tracker semantics, and proposal-only ingest behavior.

#### Compile-Candidate Handoff Format

The evening closeout must include a structured compile-candidate block following the format defined in `skills/pa/executive-assistance/references/compilation-policy.md` (Day Handoff Integration section). This block lists today's eligible sources with theme hints and carry-forward counts, enabling `/pa compile` to pre-filter and theme-sort without re-scanning the vault. The handoff is produced even when the user does not invoke `/pa compile` immediately — it accumulates in the conversation or daily note for later use.

### Status Mode

1. Render a read-only today view with current focus, waiting-fors, recent activity, same-day capture coverage, and daily-note status.
2. Never write or propose a file mutation in status mode.

### Output Requirements

The rendered day flow must include all of the following:

1. A short mode header that states the selected mode and today's concrete date.
2. A prioritized view of what matters now or what carries forward, depending on the mode.
3. A waiting-fors section.
4. A recent-activity or same-day capture section.
5. A visible confidence marker when the chief-of-staff reports low confidence.
6. If the session lane is enabled and hits exist, include them under `## Recent Activity` as "Session archive" bullets with `[S1]` ids and short snippets.

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

### Rendering Guidance

- Use concrete dates when referring to `today`, `tomorrow`, `overdue`, or carry-forward timing.
- When `linking_style.prefer_wikilinks` is `true`, render referenced note titles as wikilinks where available.
- If `journal_style.daily_note_content` is `links-only`, keep the written daily note as a hub and keep the richer briefing in the conversation.
- If today's daily note path is unresolved or blocked by structure-change rules, say so explicitly and remain in conversation-only mode.
- If there are no meaningful compile candidates in `evening` mode, say so instead of forcing a summary.
- Never rewrite unmanaged prose inside an existing daily note.

## Phase 6: Feedback Recording

If morning or evening mode produced a vault write proposal (daily note creation or append), record user feedback per the Feedback Recording Contract in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

Skip this phase in unattended mode or status mode.

## Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Day reveals a concrete priority | `/pa draft "{priority}"` - turn the active thread into a note or plan |
| Day reveals missing context | `/pa brief "{project_or_person}"` - load surrounding context before acting |
| The day produces new raw obligations | `/pa capture "{raw obligation or meeting note}"` - record it before it gets lost |
| The user wants an end-of-day pass | `/pa day --mode evening` - close out today and prepare carry-forward |
| The user wants a passive snapshot | `/pa day --mode status` - inspect today's state without writing |
| Recurring monitoring | `/loop 30m /pa day --mode status` — periodic snapshot during active sessions |

## Composability

| Context | Usage |
|---------|-------|
| `/pa agenda` | Agenda provides the prioritization core that `morning` and `status` reuse |
| `/pa brief` | Brief provides deeper context on one project, person, or topic surfaced by the day packet |
| `/pa capture` | Capture feeds same-day timestamp notes and raw obligations back into the daily flow |
| `templates/pa/daily-brief.md` | Day renders the morning briefing from this template when mixed or full-text daily notes are appropriate |
| `templates/pa/daily-link-hub.md` | Day creates or refreshes a link-first daily hub for Fractal Journaling vaults |

## Rules

- **Mode-aware**: `morning` may create or refresh today's daily surface, `evening` is closeout-first and compile-oriented, and `status` is strictly read-only
- **State-first judgment**: Work and timeline state are the primary inputs. Recent activity and the existing daily note are supporting context
- **Link-first respect**: When daily notes are `links-only`, never turn the hub into a full journal
- **Bounded writes only**: `/pa day` may touch only today's daily note and `.pa/assistant-ledger.jsonl`, and never rename, move, delete, create folders, or rewrite unmanaged prose
- **No fabrication**: Never invent commitments, completions, captures, deadlines, or compile themes not supported by state or recent vault evidence
- **Session archive opt-out by default**: The `day` session lane stays disabled unless `session_lane.enabled=true` is explicitly configured
