---
name: consultation-pattern
description: This reference defines the shared specialist consultation pattern used by PA commands. It should be consulted when a command needs to "run specialist consultation", "filter specialists by surface", "parallel specialist invocation", "collect specialist advice", "notify about suggested specialists", or "integrate specialist insights into command output".
---

# Specialist Consultation Pattern — Shared Runtime Contract

> Purpose: Reference for `domain-specialization` — defines the reusable flow that day, agenda, and review commands share after specialists exist.
> Commands reference this file instead of inlining the consultation protocol.

## Suggestion Handling

Suggested specialists are optional notifications, not blocking gates.

1. Check `.pa/specialists.json` for entries where `status == "suggested"`.
2. Surface a concise notice for each suggested area without interrupting the main command flow.
3. If the user accepts later, route into the specialist generation workflow.
4. If the user declines, preserve or suppress the suggestion according to activation rules.

## Consultation Entry Conditions

Run consultation only for specialists that satisfy all three conditions.

1. `status == "active"`.
2. `surfaces` includes the current command surface.
3. At least one work item or timeline event matches the specialist's `area_refs`.

If condition three fails, skip the specialist instead of returning empty advice.

## Input Contract

Each consulted specialist receives area-scoped context only.

| Field | Source |
|-------|--------|
| `area` | Primary area label from the specialist registry |
| `area_goals` | Active goals with matching `area_refs` from `.pa/entities.json` |
| `area_work_items` | Matching rows from `.pa/work.jsonl` |
| `area_timeline` | Matching rows from `.pa/timeline.jsonl` |
| `horizon` | The calling command's current horizon |
| `personal_context` | Direction or profile context for that area |
| `specialist_config` | The registry entry for the specialist |

## Advice Workflow

Run these steps inside the specialist.

1. Assess the current area state from goals, work items, habits, and timeline anchors.
2. Compare the current state against the area's active goals and recent movement.
3. Produce evidence-backed observations tied to explicit items or goals.
4. Produce limited suggestions and at most one risk, always tied to existing commitments.

## Output Contract

Use this compact structure for returned advice.

```markdown
### {area} Specialist Advice

**Status**: {on-track | needs-attention | at-risk | no-data}
**Confidence**: {high | medium | low}

**Observations**:
- {evidence-backed observation}

**Suggestions**:
- {goal- or work-linked suggestion}

**Risks**:
- {area-specific risk with evidence}
```

## Status Classification

| Status | Condition |
|--------|-----------|
| `on-track` | Goals are progressing, habits are consistent, and no meaningful overdue signals exist |
| `needs-attention` | Minor gaps exist, such as one overdue item, a broken streak, or an approaching deadline |
| `at-risk` | The area is stalled, multiple items are overdue, or a critical date is threatened |
| `no-data` | The specialist lacks goals, work items, or timeline evidence for the area |

## Runtime Rules

| Rule | Meaning |
|------|---------|
| Advice budget | Return 1 to 3 observations, 0 to 2 suggestions, and 0 to 1 risks |
| No fabrication | Never invent work, goals, deadlines, or obligations that do not exist in the inputs |
| Single-area scope | Never comment on other areas or cross-area trade-offs |
| Parallelism | Multiple active specialists may run in parallel because their input scopes do not overlap |
| Timeout behavior | If one specialist fails or times out, skip it and continue with the rest |

## Recording And Handoff

After consultation:

1. Update `auto_state.last_matched_at` for every specialist that matched area items.
2. Append one insight entry per returned advice block to `.pa/specialist-insights.jsonl`.
3. Pass the collected `specialist_advice[]` to the chief of staff or sentinel.
4. Let the calling command decide how to render suggestion notices and integrated insights.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/domain-specialization/SKILL.md` | Parent skill |
| `skills/pa/domain-specialization/references/specialist-generation.md` | Creation and regeneration workflow |
| `skills/pa/domain-specialization/references/specialist-registry.md` | Registry schema and surface filters |
| `skills/pa/domain-specialization/references/activation-signals.md` | Suggestion and deactivation rules |
| `skills/pa/domain-specialization/references/insight-accumulation.md` | Insight append schema and pattern detection |
