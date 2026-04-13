---
name: memory-signals
description: This reference defines the signal taxonomy, capture rules, confidence scoring, expiry policy, and privacy requirements for PA's conversational memory system. It should be consulted when an agent needs to "detect memory-worthy signals", "classify conversation observations", "apply memory confidence", "check signal expiry", or "flush pending observations".
---

# Memory Signals — Conversational Memory Taxonomy

> Purpose: Reference for `personal-profiling` — defines what PA should remember from conversations, how to classify observations, when they expire, and how to protect privacy.
> This reference is standalone and can be consulted without the parent skill.
> For profile lifecycle rules, see `skills/pa/personal-profiling/SKILL.md`.
> For enrichment proposal rules, see `skills/pa/personal-profiling/references/enrichment-rules.md`.

## File Structure

```
.pa/memory/
├── observations.jsonl    # Append-only structured observations
├── state.json            # Flush state, transcript cursor, active working memory
└── daily/
    └── YYYY-MM-DD.md     # Daily digest — injected at session start
```

## Observation Schema

```json
{
  "id": "mem-001",
  "ts": "2026-03-22T14:30:00+09:00",
  "kind": "profile-hint",
  "signal": "사용자가 운동을 2주째 못하고 있다고 언급",
  "field_hint": "focus.current_commitments",
  "confidence": 0.5,
  "session_id": "abc123",
  "actioned": false,
  "expires": null
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | yes | Unique observation ID (`mem-{NNN}`) |
| `ts` | ISO 8601 | yes | Timestamp when the signal was captured |
| `kind` | string | yes | Signal taxonomy kind (see below) |
| `signal` | string | yes | One-sentence description of what was observed |
| `field_hint` | string | no | Suggested personal-profile.json field path |
| `confidence` | number | yes | `0.0`-`1.0` confidence in the observation |
| `session_id` | string | yes | Session identifier for dedup and context |
| `actioned` | boolean | yes | Whether this observation has been acted upon (enrichment proposal, survey question, etc.) |
| `expires` | ISO 8601 | no | When the observation becomes stale. `null` = no expiry |

## Signal Taxonomy

| Kind | Description | Examples | Confidence Range | Expiry |
|------|-------------|----------|-----------------|--------|
| `profile-hint` | Explicit identity or role change | "직책이 바뀌었어", "이제 프리랜서야" | 0.5-0.8 | none |
| `work-change` | Project or work direction shift | "프로젝트 방향 변경", "새 팀 합류" | 0.6-0.8 | none |
| `relationship` | People relationship change | "Kim과 같이 일하게 됨", "멘토 만남" | 0.5-0.7 | none |
| `mood-energy` | Emotional or energy state signal | "요즘 번아웃 기미", "의욕 넘침" | 0.3-0.5 | **7 days** |
| `preference` | Interaction preference signal | "더 짧게 말해줘", "리스트로 보여줘" | 0.7-0.9 | none |
| `direction-shift` | Long-term direction change signal | "커리어 방향 변경 고민", "학교 갈까 생각 중" | 0.4-0.6 | none |

### Kind-Specific Behavior

| Kind | Downstream Action |
|------|-------------------|
| `profile-hint` | Enrichment proposal candidate. Maps to personal-profile.json fields |
| `work-change` | Enrichment proposal candidate. Also informs agenda and chief-of-staff |
| `relationship` | Person entity update candidate. Uses mask_id for storage |
| `mood-energy` | Short-lived. Informs chief-of-staff judgment but does not update profile. Auto-expires after 7 days |
| `preference` | soul.md frontmatter update proposal candidate |
| `direction-shift` | High-value but needs confirmation. Profile enrichment only after interview confirmation |

Expired mood-energy observations remain in `observations.jsonl` for long-term pattern aggregation via `pa-feedback-analysis.sh energy`.
The 7-day expiry applies to daily digests and active memory injection only, not to historical analysis.

## Capture Rules

### When to Capture

Capture when the user makes an explicit statement that reveals a change in identity, direction, relationships, energy, or preferences. The statement should be:
1. **Voluntary**: The user offered the information naturally, not extracted by PA questioning.
2. **Clear**: The signal is unambiguous enough to summarize in one sentence.
3. **Meaningful**: The observation would materially affect future PA behavior.

### When NOT to Capture

- Routine operational statements ("이 파일 수정해", "오늘 할 일 보여줘")
- Temporary task context ("이번 PR에서는 X를 해야 해")
- Greetings, acknowledgments, corrections to PA behavior
- Information PA asked for (that's interview data, not conversational memory)

### Frequency Limits

- At most **1 observation per PA command exit** (strong in-session signals only).
- Bulk flush via pre-compact hook is unlimited (transcript mining).
- Same-session dedup: if the same `kind` + similar `signal` already exists, skip.

## Confidence Assignment

| Evidence Type | Confidence |
|---------------|------------|
| Direct explicit statement ("직책이 바뀌었어") | 0.7-0.8 |
| Contextual mention ("요즘 좀 바쁘네") | 0.4-0.5 |
| Repeated pattern (3+ similar mentions across sessions) | 0.6-0.7 |
| Single offhand remark | 0.3-0.4 |

## Expiry Policy

| Kind | Default Expiry | Rationale |
|------|---------------|-----------|
| `mood-energy` | 7 days from `ts` | Emotional states are transient |
| All others | none | Durable signals persist until contradicted |

Expired observations are excluded from daily digests and active memory injection but remain in `observations.jsonl` for historical analysis.

## Flush Mechanism (2-Layer)

### Layer 1: Bash (PreCompact Hook)

The pre-compact hook extends to capture raw user messages:
1. Parse transcript JSONL for recent user messages.
2. Write raw messages to `.pa/memory/.pending-flush.jsonl`.
3. Set `flush_requested: true` in `.pa/memory/state.json`.
4. Record transcript cursor position.

`.pending-flush.jsonl` contains raw text — potentially sensitive. It must be processed and deleted promptly.

### Layer 2: LLM (Next PA Command)

When a PA command starts and detects `.pending-flush.jsonl`:
1. Read pending raw messages.
2. Apply signal taxonomy to classify each message.
3. Discard non-signal messages.
4. Apply mask_id for person references (privacy).
5. Append structured observations to `observations.jsonl`.
6. Delete `.pending-flush.jsonl`.
7. Update `state.json` with new cursor and `flush_requested: false`.

### Supplementary Trigger: PA Command Exit

During any PA command, if the conversation reveals a strong signal (direct user statement matching capture criteria), the command may append 1 observation to `observations.jsonl` at exit. This follows the same frequency limit as enrichment rules: at most 1 per session.

## Daily Digest

Generated on first PA command of each day (or at session start):

```markdown
## YYYY-MM-DD Memory Digest

### Recent Observations
- 프로젝트 X 방향 변경 (work-change, 3/21)
- 운동 2주 중단 (mood-energy, 3/20, expires 3/27)

### Pending Actions
- direction-shift: 커리어 방향 변경 고민 → profile enrichment candidate
```

Digest includes:
- Unactioned observations from the last 7 days.
- Expired observations are excluded.
- `mood-energy` observations show expiry date.
- `direction-shift` and `preference` observations show suggested downstream action.

## Session Injection

At session start, inject a concise memory summary:
- Latest daily digest (most recent file in `.pa/memory/daily/`).
- Up to 3 long-term unactioned observations.
- All unexpired `mood-energy` observations.

Format: `=== PA Memory ===` section in session-start output.

## Integration with Existing State

Memory does NOT directly modify profile, entities, or work state. It follows proposal-only principles:

| Consumer | How Memory Is Used |
|----------|-------------------|
| `enrichment-rules.md` | Memory observations as evidence for enrichment proposals |
| `survey.md` (catch-up) | Memory signals inform interview prompt selection |
| `day.md` (evening) | Unactioned signals included in closeout |
| `review.md` | Accumulated signals strengthen gap detection |
| `agenda.md` / `day.md` | `mood-energy` signals inform chief-of-staff judgment calibration |

## Privacy

| File | Privacy Rule |
|------|-------------|
| `observations.jsonl` | Person references use mask_id only |
| `.pending-flush.jsonl` | May contain raw names — process and delete promptly |
| `daily/*.md` | Uses mask_id for person references |
| `state.json` | No personal data, only cursor and flags |

All memory files should be in `.gitignore`. They are local assistant state, not vault content.

## state.json Schema

```json
{
  "version": 1,
  "flush_requested": false,
  "transcript_cursor": 0,
  "last_digest_date": "2026-03-22",
  "next_id": 1
}
```

## Validation Checklist

- [ ] Every observation `kind` is one of the allowed taxonomy values.
- [ ] Each observation `confidence` stays within the documented range for its `kind`.
- [ ] `mood-energy` observations receive a 7-day expiry and durable kinds are not given transient expiry by default.
- [ ] Person references in `observations.jsonl` and daily digests use `mask_id` instead of raw names.
- [ ] Same-session dedup skips near-identical `kind` plus `signal` observations before append.
- [ ] `.pending-flush.jsonl` is processed and deleted before the next PA command proceeds with fresh state.
- [ ] `flush_requested`, transcript cursor, and `next_id` are updated consistently after each flush.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/personal-profiling/SKILL.md` | Parent skill — memory feeds enrichment proposals |
| `skills/pa/personal-profiling/references/enrichment-rules.md` | Sibling — memory observations as enrichment evidence |
| `scripts/pre-compact.sh` | Layer 1 flush trigger |
| `scripts/session-start.sh` | Memory digest injection |
| `commands/pa/day.md` | Evening closeout includes unactioned signals |
| `commands/pa/survey.md` | Catch-up interview references memory signals |
