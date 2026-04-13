---
name: insight-accumulation
description: This reference defines the specialist-insights.jsonl schema, pattern detection rules, survey integration contract, and profile feedback mechanism. It should be consulted when an agent needs to "record specialist insight", "detect area patterns from specialist history", "generate insight-driven catch-up questions", "propose confidence adjustment from specialist patterns", or "read specialist insight accumulation rules".
---

# Insight Accumulation — Specialist Feedback Loop

> Purpose: Reference for `domain-specialization` — defines how specialist advice status is recorded over time, how patterns are detected, and how those patterns feed into survey catch-up questions and profile confidence proposals.
> This reference is standalone and can be consulted without the parent skill.
> For the specialist methodology, see `skills/pa/domain-specialization/SKILL.md`.
> For the specialist registry, see `skills/pa/domain-specialization/references/specialist-registry.md`.

## specialist-insights.jsonl Schema

`{vault}/.pa/specialist-insights.jsonl` — append-only JSONL. Created lazily on first successful specialist consultation write.

### Entry Format

```jsonl
{"ts":"2026-03-20T09:30:00+09:00","surface":"day","context":"morning","specialist_id":"health","area_id":"health","area_refs":["health","fitness","exercise","운동","건강"],"status":"on-track","confidence":"high"}
```

### Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `ts` | string (ISO 8601) | yes | Timestamp of the consultation |
| `surface` | string | yes | Command that produced this insight: `day`, `agenda`, `review` |
| `context` | string | yes | Command mode or horizon: `morning`, `evening`, `status`, `today`, `week`, `month`, `quarter`, etc. |
| `specialist_id` | string | yes | Specialist registry id (matches specialists.json `id`) |
| `area_id` | string | yes | Primary area from `area_refs[0]` |
| `area_refs` | string[] | yes | Snapshot of the specialist's `area_refs` at consultation time. Preserves matching even if aliases change later |
| `status` | string | yes | `on-track`, `needs-attention`, `at-risk`, `no-data` |
| `confidence` | string | yes | Specialist-reported confidence: `high`, `medium`, `low` |

### Append Rules

- One entry per returned specialist advice from day, agenda, or review Phase 3.5.
- Append after `auto_state.last_matched_at` update.
- Record `no-data` entries too, but exclude them from pattern calculation.
- If append fails, continue without blocking the command. Insight recording is supplementary.

### Design Rationale

Why status + confidence only (no observation text): pattern detection needs only status trends. Full text is consumed in conversation and has low reuse value. Keeping entries compact ensures the JSONL stays small even with daily use.

Why `area_refs` snapshot: if the user renames or adds aliases to a specialist during survey, historical entries still match the area via the stored snapshot.

Why JSONL: consistent with work.jsonl, timeline.jsonl, assistant-ledger.jsonl. Append-only, simple to write, and pattern detection only needs the tail.

## Pattern Detection

### When Calculated

Pattern detection runs only during `/pa survey` Phase 5.5. Day, agenda, and review are writers only — they never read insight patterns.

### Same-Day Deduplication

Before counting streaks, collapse entries to the latest per `area_id + local_date`. If the user runs both `/pa day` and `/pa agenda` on the same day, only the last entry for each area counts toward the streak. This prevents fake streaks from multiple runs in one day.

### Streak Calculation

1. Load all readable lines from specialist-insights.jsonl. Skip malformed lines.
2. Filter by `area_id` matching current profile `core_areas` or `directions_by_area` keys.
3. Exclude entries where `status == "no-data"`.
4. Apply same-day dedup: keep the latest entry per `area_id + local_date(ts)`.
5. Sort remaining entries by `ts` descending.
6. Count the consecutive run of the same `status` from the most recent entry.

### Pattern Types

| Pattern | Detection Rule | Meaning |
|---------|---------------|---------|
| `stable` | Latest streak >= 3 and status is `on-track` | Area is consistently well-managed |
| `declining` | Latest streak >= 3 and status is `at-risk` or `needs-attention` | Area is persistently struggling |
| `shifted-down` | Previous streak >= 3 was `on-track`, current status is `needs-attention` or `at-risk` | Area went from healthy to struggling |
| `shifted-up` | Previous streak >= 3 was `at-risk` or `needs-attention`, current status is `on-track` | Area recovered |
| `insufficient` | Fewer than 3 valid (non-no-data, deduped) entries for this area | Not enough data for pattern detection |

### Priority When Multiple Areas Qualify

If multiple areas have detectable patterns, select one for the survey catch-up question using this priority:

1. `at-risk` declining (most urgent)
2. `needs-attention` declining
3. `shifted-down`
4. `shifted-up`
5. `stable` (least urgent — confirmation only)

Ask about at most one area per survey.

## Survey Integration

### Where

`commands/pa/survey.md` Phase 5.5 — after existing gap detection, before final catch-up question selection.

### Flow

1. If `personal-profile.json` does not exist, skip insight pattern reading entirely.
2. Read `.pa/specialist-insights.jsonl`. If missing or empty, skip.
3. Calculate patterns for each area present in both insights and profile.
4. Select the highest-priority area per the priority table above.
5. Add one insight-driven catch-up question to the question candidates.
6. Insight-driven questions are additive: existing gap-based questions (2-3) come first, insight question (0-1) fills remaining budget.
7. Total catch-up questions remain within the 2-3 limit (+ 0-1 insight = max 4).

### Question Templates

| Pattern | Question Template | Primary Fields |
|---------|-------------------|----------------|
| `stable` | "{area} 영역이 안정적으로 유지되고 있는데, 이 방향을 계속 유지하면 될까요? 아니면 더 높은 목표를 세워볼까요?" | `direction.directions_by_area[area]`, `focus.current_focus` |
| `declining` | "{area} 영역에서 최근 계속 어려움이 보이는데, 이 영역의 우선순위나 방향을 조정할 필요가 있나요?" | `direction.directions_by_area[area]`, `direction.paused_areas`, `focus.current_focus` |
| `shifted-down` | "{area} 영역이 이전에는 안정적이었는데 최근 어려워지고 있어요. 뭔가 변화가 있었나요?" | `direction.directions_by_area[area]`, `focus.current_commitments` |
| `shifted-up` | "{area} 영역이 최근 좋아지고 있어요. 뭔가 변화가 있었나요?" | `direction.directions_by_area[area]`, `focus.current_focus` |

`needs-watch` (3+ needs-attention without reaching at-risk) is included in `declining` — the question addresses both severity levels.

`insufficient` generates no question.

### Context-Only Patterns

When a pattern exists but is not selected as the primary question (because a higher-priority area was chosen), include it as context for the survey agent: "참고: {area} 영역 상태가 최근 {pattern} 중입니다." This context does not generate a question but informs the catch-up agent's synthesis.

## Profile Feedback

### Proposal-Only Rule

Profile changes from specialist patterns are never automatic. They follow the same proposal-only workflow as `skills/pa/personal-profiling/references/enrichment-rules.md`.

### Feedback Flow

After the user answers the insight-driven catch-up question in survey Phase 5.5:

1. Synthesize the answer into a minimal profile patch per the enrichment rules workflow.
2. Present the proposal before any write.
3. Log the outcome to `.pa/proposals.jsonl` with `kind: "insight-driven-enrichment"`.

### Confidence Adjustment Rules

| Pattern | User Response | Confidence Delta | Affected Fields |
|---------|--------------|------------------|-----------------|
| `stable` | Confirm direction ("계속 유지") | `+0.05` | `confidence.direction` |
| `stable` | Escalate ("더 높은 목표") | `+0.05` (new direction content) | `confidence.direction` |
| `declining` | Reorient/pause | `+0.05` (new direction content) | `confidence.direction` |
| `declining` | Persist ("계속 노력") | `0.00` | no change |
| `shifted-down` | Explain change | `0.00` (patch content if needed) | varies |
| `shifted-up` | Confirm recovery | `+0.05` | `confidence.direction` |
| Any | Decline proposal | `0.00` | no change |

Cap: confidence.direction never exceeds `0.7` from insight-driven enrichment. Higher values require formal `direction` or `deep` interviews.

### Constraint Summary

- Pattern detection nominates a question, not a write.
- The user's survey answer is the anchor signal.
- Confidence moves only after proposal approval.
- One insight-driven proposal per survey, using the existing one-proposal-per-session cap.

## Graceful Degradation

| Missing State | Behavior |
|---------------|----------|
| `specialist-insights.jsonl` missing | No insight append during day/agenda/review. Pattern detection returns `insufficient` for all areas. Survey skips insight-driven questions |
| `specialist-insights.jsonl` empty | Same as missing |
| `specialists.json` missing | No specialist consultation → no insights generated |
| `personal-profile.json` missing | Insight recording still works (day/agenda/review append). Survey skips insight-driven questions (no profile to update) |
| `entities.json` missing | Insight recording still works. area_goals passed as empty to specialists |
| Specialist returns `no-data` | Entry recorded. Excluded from pattern counting |
| Specialist times out | No entry recorded for that specialist |
| JSONL malformed line | Skip that line only during pattern detection |
| Append failure during day/agenda/review | Continue without blocking. Skip insight write silently |

## Validation Checklist

- [ ] Each specialist consultation in day/agenda/review produces exactly one JSONL entry per returned advice.
- [ ] `no-data` entries are recorded but excluded from streak counting.
- [ ] Same-day dedup is applied before streak calculation.
- [ ] Pattern detection runs only in survey Phase 5.5.
- [ ] At most one insight-driven question is added per survey.
- [ ] Profile changes are proposal-only with user approval.
- [ ] Confidence delta never exceeds `+0.05` per insight-driven enrichment.
- [ ] `proposals.jsonl` entry uses `kind: "insight-driven-enrichment"`.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/domain-specialization/SKILL.md` | Parent skill — Enrichment Loop section |
| `skills/pa/domain-specialization/references/activation-signals.md` | Sibling — auto_state lifecycle (last_matched_at updates happen before insight recording) |
| `skills/pa/domain-specialization/references/specialist-registry.md` | Sibling — specialist_id and area_refs source |
| `skills/pa/personal-profiling/references/enrichment-rules.md` | Proposal-only workflow and confidence delta rules |
| `skills/pa/interviewing/references/question-patterns.md` | Insight-triggered catch-up question templates |
| `commands/pa/day.md` | Writer — appends insight entries in Phase 3.5 |
| `commands/pa/agenda.md` | Writer — appends insight entries in Phase 3.5 |
| `commands/pa/review.md` | Writer — appends insight entries in Phase 3.5 |
| `commands/pa/survey.md` | Reader — pattern detection in Phase 5.5 |
