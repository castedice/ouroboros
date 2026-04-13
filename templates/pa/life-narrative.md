---
title: life-narrative
description: This template provides multi-period narrative output for PA review flows. It should be consulted when an agent needs to "render life narrative output", "format multi-period story", "structure narrative arc with decisions", "map direction evolution timeline", "compose period overview from sources", "extract recurring themes from period evidence", or "preserve open questions in narrative form".
---

# Life Narrative Template

> Output template for life narrative synthesis.
> Used by `/pa review --horizon year+ --narrative`.

## Template

```markdown
# Life Narrative: {period_label}

**Period**: {start_date} — {end_date}
**Sources**: {compilation_count} compilations, {review_count} reviews, {entity_count} entities, {decision_count} decisions
**Generated**: {generated_date}

## Period Overview

{2-3 sentence summary of what this period was about, grounded in evidence}

## Narrative Arc

{Chronological-thematic narrative.
What happened, in what order, and why it mattered.
Written in vault-native voice by the scribe.
Every claim grounded in a source document or entity.
Use [[wikilinks]] when linking_style.prefer_wikilinks is true.}

## Key Decisions & Outcomes

{Decisions made during this period with their outcomes (if post-mortem completed).
For decisions still pending review, note the review date.}

| Decision | Chosen | Outcome | Lessons |
|----------|--------|---------|---------|
| {title} | {chosen} | {outcome_actual or "pending review {review_date}"} | {lessons or "—"} |

## Direction Evolution

{How the user's direction shifted during this period.
Reference personal-profile direction changes, direction-shift memory observations, and goal status transitions.}

- **Start**: {direction_at_period_start}
- **End**: {direction_at_period_end}
- **Key shifts**: {notable direction changes with dates}

## Themes

{3-5 recurring patterns identified across compilations, reviews, and work items during this period.}

1. **{theme}**: {evidence and significance}

## Open Questions

{Unresolved threads, pending decisions, carry-forward items from the period.}

- {question_or_thread}
```

## Placeholder Mapping

| Placeholder | Source |
|-------------|--------|
| `{period_label}` | "2026 상반기", "2025년", etc. from review horizon |
| `{start_date}`, `{end_date}` | Review window boundaries |
| `{compilation_count}` | Count of period-compilation notes in window |
| `{review_count}` | Count of review checkpoints in review-state.json |
| `{entity_count}` | Active entities with first_seen in window |
| `{decision_count}` | Decision entities with decision_date in window |
| `{generated_date}` | Current date |

## Validation Checklist

- [ ] The period label, start date, end date, and source counts match the selected review window.
- [ ] The Period Overview stays grounded in compilations, review checkpoints, entities, or decisions gathered for the window.
- [ ] The Narrative Arc preserves chronological order while grouping related threads without inventing events or motives.
- [ ] The Key Decisions table uses real decision entities and marks unresolved outcomes with the correct pending review date.
- [ ] Direction Evolution reflects profile direction history, direction-shift memory, and goal status transitions for the same period.
- [ ] Themes emerge from repeated evidence across sources instead of being imposed as a generic storyline.
- [ ] Open Questions preserve unresolved threads and carry-forwards in neutral, forward-looking language.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/references/narrative-synthesis.md` | Synthesis methodology |
| `skills/pa/review-and-journaling/references/fractal-journaling.md` | Review hierarchy |
| `commands/pa/review.md` | Consumer — year+ with --narrative |
| `agents/pa/scribe.md` | Writer — vault-native voice synthesis |
| `templates/pa/period-compilation.md` | Input — period compilations feed narrative |
