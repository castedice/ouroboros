---
name: serendipity-rules
description: This reference defines serendipity selection and contradiction detection rules for PA reviews. It should be consulted when an agent needs to "select random forgotten notes", "surface unexpected connections", "detect entity state conflicts", "find temporal contradictions", "identify decision direction conflicts", or "add creative discovery to reviews".
---

# Serendipity + Contradiction Detection

> Purpose: Reference for `review-and-journaling` — defines random note selection for creative rediscovery and contradiction detection for drift awareness.

## Serendipity Selection

### Eligibility

A note is eligible for serendipity selection when:
1. Not a daily note (not in `daily_dir` or matching `daily_note_pattern`)
2. Not a stub (> 100 characters of markdown content, excluding frontmatter)
3. Older than 30 days (last modified > 30 days ago)
4. Not in `.pa/`, `templates/`, `.obsidian/`, `.trash/`, or archive folders
5. Not recently surfaced as serendipity (check `review-state.json → serendipity_shown[]`, suppress for 90 days)

### Selection

Pick 1-3 notes uniformly at random from the eligible pool.
Include:
- Note title and path
- First 2-3 sentences of content (preview)
- Days since last modified
- Inbound wikilink count (connection density signal)

### Surface

- Review month+ horizons: always include if eligible pool has 5+ notes
- Output section: `## Serendipity` in follow-up report

## Contradiction Detection

### Contradiction Types

| Type | Detection Rule | Example |
|------|---------------|---------|
| Entity state conflict | Goal `status: active` but related work item `state: cancelled` or `done` | Active goal "Launch MVP" but all work items cancelled |
| Temporal conflict | Milestone `target_date` in the past with no `completed_at` | "Q1 launch" milestone with target 2026-03-31, no completion, now April |
| Decision direction conflict | Two decision entities in same `area_refs` with opposing `chosen` values within 90 days | Decided "focus on stability" then "pursue aggressive growth" in same area |
| Profile-behavior conflict | personal-profile `direction` says X but recent work items concentrated in opposite direction | (Overlaps with Values Alignment — only surface if not already caught by B) |

### Severity

| Severity | Condition |
|----------|-----------|
| `warning` | Single contradiction with moderate confidence |
| `info` | Potential contradiction, needs user interpretation |

Never `error` — contradictions may be intentional pivots.

### Surface

- Review month+ horizons
- Output section: `## Contradictions & Tensions` in follow-up report
- Present both sides neutrally: "Goal X is active, but all related work items are cancelled."

## Design Rationale

| Decision | Why |
|----------|-----|
| 30-day age threshold | Notes younger than 30 days are still in active memory — serendipity targets forgotten content |
| 100-char minimum | Very short stubs lack enough content to spark useful reconnection |
| 90-day suppression | Prevents the same "random" note from appearing in consecutive monthly reviews |
| 1-3 notes per review | More would dilute attention — serendipity is a garnish, not a main course |
| Contradiction severity capped at `warning` | Contradictions may be intentional pivots — never assume they are errors |
| Month+ horizon only | Weekly reviews are operational — serendipity belongs in reflective contexts |

## Common Pitfalls

| Pitfall | Why Wrong | Prevention |
|---------|-----------|------------|
| Using serendipity as a recommendation engine | Random ≠ relevant — serendipity is for surprise, not precision | Keep selection truly random from eligible pool |
| Flagging contradictions as errors | User may have intentionally changed direction | Present both sides neutrally, never prescribe resolution |
| Surfacing private or sensitive notes | Random selection could pick inner-circle person notes | Exclude notes in `.pa/people/` and notes with `private: true` |
| Same "random" notes every month | Pseudo-random with small pool creates repetition | Anti-nag suppression via serendipity_shown[] |

## Validation Checklist

- [ ] Daily notes are excluded using both folder and daily-note pattern checks before building the serendipity pool.
- [ ] The stub filter removes notes that do not clear the minimum content threshold.
- [ ] Every serendipity candidate is older than 30 days before random selection.
- [ ] `serendipity_shown` suppression is checked so recently surfaced notes stay hidden for 90 days.
- [ ] Random picks come from uniform selection over the eligible pool rather than manual preference or ranking.
- [ ] All documented contradiction types are scanned before reporting that no tensions were found.
- [ ] Findings use neutral language and keep severity at `info` or `warning` only.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill |
| `skills/pa/review-and-journaling/references/resurfacing-rules.md` | Sibling — resurfacing for relevance, serendipity for randomness |
| `skills/pa/review-and-journaling/references/values-alignment.md` | Sibling — profile-behavior conflicts may overlap |
| `agents/pa/sentinel.md` | Executor |
| `commands/pa/review.md` | Consumer |
