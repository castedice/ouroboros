---
name: pa:agenda
description: "Use when you need a current priority view of commitments, deadlines, waiting-fors, and focus"
effort: medium
allowed-tools:
  - Read
  - Write
  - Agent
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: [--horizon today|week|month]
---

# Agenda — What Matters Now

Show what matters now by combining open commitments, upcoming deadlines, waiting-fors, timeline anchors, and optional recent vault activity into a single prioritized agenda.

Horizon: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load settings.json, vault-profile.json, work.jsonl, and timeline.jsonl |
| 3 | librarian (agent, sonnet, optional) | Gather recent vault activity when QMD is available and recent context would sharpen prioritization |
| 4 | chief-of-staff (agent, opus) | Judge urgency, sequence priorities, surface waiting-fors, and recommend focus |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/settings.json` | read | QMD collection name, capability tier, vault path, and automation posture |
| `.pa/vault-profile.json` | read | Linking style and retrieval defaults for optional recent-activity lookup |
| `.pa/work.jsonl` | read | Open tasks, commitments, deadlines, waiting-fors, and ownership metadata |
| `.pa/timeline.jsonl` | read | Upcoming events, milestones, dated anchors, and recurring temporal context |
| `.pa/calendar-events.jsonl` | read (optional) | Calendar events within the selected horizon for scheduling-aware prioritization |
| `.pa/context-profiles.json` | read (optional) | Approved context budget for `agenda` optional state loading |
| `.pa/preferences-learned.json` | read (optional) | Approved learned preferences for `agenda` adjustments |
| `.pa/soul.md` | read | Soul layer — render settings (frontmatter) + reasoning personality (body) |
| `.pa/specialists.json` | read | Specialist registry for Phase 3.4 suggestions and Phase 3.5 consultation |
| `.pa/intelligence/energy-patterns.json` | read (optional) | Aggregated day-of-week and time-of-day energy patterns for load calibration |
| `.pa/specialist-insights.jsonl` | append | Specialist advice status history for enrichment loop |
| `.pa/assistant-ledger.jsonl` | append | Read-only run telemetry and audit metadata |

## Unified Branch Table

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| No argument | 1 | Default to `--horizon week` |
| `--horizon` missing a value | 1 | Abort: "Provide a horizon: `today`, `week`, or `month`" |
| `--horizon` value is invalid | 1 | Abort: "Invalid horizon. Use `today`, `week`, or `month`" |
| Extra arguments beyond `--horizon` | 1 | Abort: "Agenda only accepts `--horizon today|week|month`" |
| No `.pa/settings.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 2 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/work.jsonl` | 2 | Abort: "Run `/pa survey` first to build work state" |
| No `.pa/timeline.jsonl` | 2 | Abort: "Run `/pa survey` first to build timeline state" |
| Selected horizon is `today`, `week`, or `month` | 2, 4, 5 | Apply the matching window from `Horizon Interpretation` and keep urgency labels horizon-appropriate |
| `work.jsonl` is empty | 2, 4, 5 | Continue with timeline data only and make the missing work layer explicit |
| `timeline.jsonl` is empty | 2, 4, 5 | Continue with work data only and make the missing timeline layer explicit |
| `work.jsonl` and `timeline.jsonl` are both empty | 2 | Report: "No current work or timeline data found. Run `/pa survey` again or add commitments first" |
| Optional enrichment files are missing or empty | 2.5, 3.4, 3.5, 4, 5 | Skip that enrichment only and continue without fabricating context |
| QMD collection is unregistered, unhealthy, unavailable, or not worth querying for the selected horizon | 3 | Skip recent-activity lookup and continue from state files only |
| Librarian returns zero recent activity | 3 | Continue with work and timeline state only |
| Chief-of-staff surfaces conflicting priorities or overload | 5 | Present the `Agenda Checkpoint`, wait for one focus choice, then rerun presentation once around that choice |
| Judgment remains sparse or chief-of-staff returns low confidence | 5 | Render the agenda with explicit low-confidence or missing-evidence notes instead of inventing priorities |

### Recovery

Use one bounded recovery loop per delegated or optional surface in this command.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Optional recent-activity lookup | 1 status check + 1 retrieval attempt | QMD remains unavailable, or the retrieval adds no new activity beyond state files | Stop lookup, note the limitation, and continue with state-backed evidence only |
| Chief-of-staff judgment | 1 full attempt + 1 narrowed retry using state files only | The retry returns the same failure class, the same low-confidence packet, or misses the same required agenda fields | Stop retrying, render a degraded agenda from the surviving state, and mark confidence as low |
| Focus checkpoint rerun | 1 rerun after fresh user input | The rerun still asks for the same checkpoint or does not reduce the conflict set | Preserve the unresolved checkpoint, stop rerunning, and ask the user to continue in a new invocation if needed |


## Phase 1: Parse Input

Parse `$ARGUMENTS` as a single optional horizon flag.

Accepted forms:

- no argument
- `--horizon today`
- `--horizon week`
- `--horizon month`

Default to `week` when no argument is provided.

Do not accept topic text, custom date ranges, or additional flags.

Resolve malformed input per the Unified Branch Table.

## Phase 2: Load State

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `intermediate`, present guidance and suggest `/pa ask` or `/pa brief`.
Continue regardless.
Guidance is advisory.

1. Read `.pa/settings.json` and extract vault path, QMD collection name, capability tier, and automation posture.
2. Read `.pa/vault-profile.json` and extract linking style plus any QMD defaults needed for optional recent-activity retrieval.
3. Read `.pa/work.jsonl` in full.
4. Read `.pa/timeline.jsonl` in full.
5. Read `.pa/calendar-events.jsonl` (optional). Filter to events within the selected horizon. If missing or empty, continue without calendar data.
6. Read `.pa/preferences-learned.json` (optional). Apply approved rules for `agenda`. If file missing, continue with defaults.
7. Read `.pa/context-profiles.json` (optional). If present, load the approved `agenda` profile and use it to decide which optional state or enrichment files to skip. If the file is missing or has no approved `agenda` profile, follow the defaults from `skills/pa/context-assembly/references/loading-strategy.md`.
8. Filter the loaded records to the selected horizon while preserving overdue items and unresolved waiting-fors from before the window.
9. Keep only items that are still actionable or still temporally relevant.

### Phase 2.5: Enrichment Load

Apply tier decisions from `skills/pa/context-assembly/references/loading-strategy.md`.
Skip optional files that are empty or missing.

#### Enrichment Load

Read `.pa/soul.md` per the approved `agenda` context profile or the default tier decision from `skills/pa/context-assembly/references/loading-strategy.md`.
If `.pa/soul.md` is missing, read `.pa/persona.json` as fallback (render only).
If both are missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.
Read `.pa/specialists.json` when the same tier decision includes specialist consultation.
If `.pa/specialists.json` is missing, skip specialist consultation in Phase 3.5.
Read `.pa/memory/observations.jsonl` when the same tier decision includes supplementary judgment context.
Pass unexpired `mood-energy` signals from `.pa/memory/observations.jsonl` to chief-of-staff as supplementary judgment context.
If `.pa/memory/observations.jsonl` is missing, continue without memory.

#### Intelligence Load

Read `.pa/intelligence/energy-patterns.json` when the approved `agenda` context profile or default tier decision includes it.
If `energy-patterns.json` is present and `sufficient: true`, pass it to chief-of-staff as `energy_patterns`.
If `energy-patterns.json` is missing or insufficient, continue without energy calibration.

### Horizon Interpretation

| Horizon | Window | Required Inclusion |
|---------|--------|--------------------|
| `today` | Current day only | Include overdue items, items due today, events today, and active waiting-fors |
| `week` | Current day through the next 7 days | Include overdue items, this week's deadlines, near-term milestones, and active waiting-fors |
| `month` | Current day through the next 30 days | Include overdue items, longer-arc deadlines, major milestones, and active waiting-fors |

If both state files are present but both are empty, resolve through the Unified Branch Table.

## Phase 3: Recent Activity

> Agent: **librarian** (optional)

Recent activity is additive context, not the primary source of truth.

Use it only when QMD is available and it can sharpen prioritization by surfacing very recent notes, changed topics, or newly active projects within the selected horizon.

### Preconditions

1. Check `mcp__qmd__status` for the configured collection.
2. If QMD is unavailable, unhealthy, or unregistered, skip this phase without aborting.
3. If the selected horizon is `today` or `week`, prefer recent activity lookup.
4. If the selected horizon is `month`, use recent activity only when the work and timeline state appears sparse or ambiguous.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | selected horizon, current date, settings.json contents, vault-profile.json contents, and a summary of the relevant work and timeline items from Phase 2 |
| Instructions | Retrieve only recent vault activity likely to affect "what matters now". Prefer recent authored notes, daily notes, and project notes tied to already-open commitments. Return compact evidence, not a full dossier |
| Expected Output | Recent-activity pack with note titles, paths, timestamps or recency signals, brief excerpts, and a short activity assessment |

### Recovery

| Failure | Action |
|---------|--------|
| QMD unavailable or status check fails | Continue with work and timeline state only |
| Librarian timeout | Continue with work and timeline state only |
| Librarian returns zero results | Continue with work and timeline state only |
| Librarian returns an error | Report the error briefly and continue with work and timeline state only |

## Phase 3.4: Specialist Suggestions (Optional)

Apply the specialist suggestion flow from `skills/pa/domain-specialization/references/consultation-pattern.md` Phase 3.4.

## Phase 3.5: Specialist Consultation (Optional)

Apply the specialist consultation flow from `skills/pa/domain-specialization/references/consultation-pattern.md` Phase 3.5 with surface `"agenda"`.
Pass `specialist_advice[]` to Phase 4 as an additional input for the chief-of-staff.

## Phase 4: Chief-of-Staff Delegation

> Agent: **chief-of-staff**

Delegate judgment to the chief-of-staff agent.

The chief-of-staff decides what deserves attention now and does not invent new work.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | selected horizon, current date, filtered `work.jsonl` records, filtered `timeline.jsonl` records, optional `calendar_events` from `.pa/calendar-events.jsonl` filtered to horizon, optional recent-activity pack, optional `specialist_advice[]` from Phase 3.5, settings.json contents, vault-profile.json contents, optional `soul_principles` from `.pa/soul.md` body `## Principles` section, optional `mood_energy_signals` from `.pa/memory/observations.jsonl`, and optional `energy_patterns` from `.pa/intelligence/energy-patterns.json` |
| Instructions | Apply `skills/pa/executive-assistance/SKILL.md` workflow. Identify priorities, deadline pressure, blockers, waiting-fors, and the best focus recommendation for the current horizon. Prefer state-backed urgency over generic productivity advice. Return a structured agenda report |
| Expected Output | Agenda report with prioritized items, urgency markers, deadline proximity, waiting-fors, suggested focus, confidence, notable gaps in the current state, and any conflict or overload checkpoint signal |

### Judgment Rules

1. Overdue commitments outrank merely recent activity.
2. Deadline proximity matters more than note freshness.
3. Waiting-fors should be surfaced separately from direct action items.
4. Suggested focus should be constrained to `1-3` concrete threads, proportional to the horizon.
5. Do not fabricate commitments, due dates, or blockers that are not present in the state or recent-activity evidence.
6. When the state is sparse or stale, say so explicitly.

## Phase 5: Present

Output the agenda directly in the conversation.

Do not write it to the vault.

### User Checkpoint

If chief-of-staff reports conflicting priorities or overload, stop before presenting the full agenda.
Ask the user to choose the focus first, then render the full agenda around that choice.

```markdown
## Agenda Checkpoint

**Horizon**: {today|week|month}
**Reason for checkpoint**: {conflicting priorities|overload}
**Decision needed**: Choose the focus before I expand the full agenda.

### Competing Focus Options
1. **{option_1}** - {why it competes now}
2. **{option_2}** - {why it competes now}
3. **{option_3_optional}** - {why it competes now}

### Trade-Offs
- **If you choose {option_1}**: {what gets protected, deferred, or renegotiated}
- **If you choose {option_2}**: {what gets protected, deferred, or renegotiated}
- **If you choose {option_3_optional}**: {what gets protected, deferred, or renegotiated}

Reply with: `{chosen option}` or your own focus choice.
```

### Agenda Template

If no checkpoint is needed, or after the user chooses a focus, render the agenda in this exact shape.

```markdown
## Agenda

**Horizon**: {today|week|month}
**Date**: {YYYY-MM-DD}
**Confidence**: {high|medium|low}
**Focus Choice**: {user-selected focus | not needed}

### What Matters Now
1. **{item_1}** [{Overdue|Today|Soon|This Week|This Month}] - {why it matters now}
   Source: {source_doc or work item id}
   Due: {YYYY-MM-DD | none}
2. **{item_2}** [{Overdue|Today|Soon|This Week|This Month}] - {why it matters now}
   Source: {source_doc or work item id}
   Due: {YYYY-MM-DD | none}

### Risks
- **{risk_item}** - {risk description}

### Waiting-Fors
- **{waiting_item}** - waiting on {owner}, last update {YYYY-MM-DD}, follow-up {next step}

### Schedule ({N} events)
{Present only when calendar events are available. List timed events within the selected horizon.}

- **{HH:MM}** {event_title} [{location_optional}]

### Suggested Focus
- **Primary thread**: {1-3 concrete threads}
- **Defer**: {items to delay, delegate, or renegotiate}
- **Watch**: {upcoming risk or dated anchor}

### Notes
- {low-confidence note | missing evidence | no meaningful agenda explanation}
```

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

### Rendering Guidance

- Use clear urgency markers such as `Overdue`, `Today`, `Soon`, `This Week`, or `This Month`.
- Prefer one line per item unless a brief clarification is necessary.
- When `linking_style.prefer_wikilinks` is `true`, render referenced note titles as wikilinks where available.
- If chief-of-staff confidence is low, add a visible note that the agenda is based on limited or stale state.
- If calendar events are present, render a `### Schedule ({N} events)` section listing timed events for the horizon.
- If there are no actionable priorities but there are waiting-fors or upcoming events, say so instead of forcing action items.
- If there is no meaningful agenda, state that clearly and explain whether the gap comes from missing state, empty state, or lack of recent evidence.

## Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Agenda reveals a concrete priority | `/pa draft "{priority}"` — turn the active thread into a note or plan |
| Agenda reveals missing context | `/pa brief "{project_or_person}"` — load surrounding context before acting |
| Agenda reveals new raw obligations | `/pa capture "{raw obligation or meeting note}"` — record it before it gets lost |
| User wants a day flow | `/pa day` — compose agenda with daily guidance |

## Phase 6: Ledger Append

1. Append the agenda run entry to `.pa/assistant-ledger.jsonl`.
2. Include `state_files_loaded`, `state_files_used`, and `estimated_context_chars` in the ledger entry per the Context Telemetry section in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

## Composability

| Context | Usage |
|---------|-------|
| `/pa day` | Day composes agenda into a fuller daily operating flow |
| `/pa brief` | Brief provides deeper context on one project, person, or topic surfaced by agenda |
| `/pa capture` | Capture records new commitments, follow-ups, and meeting fallout revealed by agenda |

## Rules

- **Read-only**: Agenda never writes to the vault. Output is conversation-only
- **State-first judgment**: Work and timeline state are the primary inputs. Recent activity is optional supporting context
- **No fabrication**: Never invent priorities, deadlines, or waiting-fors not supported by loaded state or recent vault evidence
- **Judgment, not retrieval dump**: The output should prioritize and compress, not simply echo every record
- **Horizon-bounded**: Prioritization and focus suggestions must match the selected horizon
