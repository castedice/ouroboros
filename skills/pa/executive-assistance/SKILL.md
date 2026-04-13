---
name: executive-assistance
description: This skill provides time-aware executive assistance methodology for `.pa/work.jsonl`-driven prioritization. It should be activated when an agent needs to "score work by urgency x importance x staleness", "assess waiting-for staleness", "build a horizon-based agenda", "identify what matters now from `.pa/work.jsonl`", "track deadlines and waiting-fors", or "plan across time horizons".
summary: Ranks work across time horizons using urgency, importance, staleness, deadlines, and waiting-for follow-up cues.
version: 1
tags: [pa, agenda, prioritization, work-items, time-horizons]
preamble_tier: 3
---

# Executive Assistance

## Core Rule

**"Surface what matters before it becomes urgent."**

The chief-of-staff view exists to make the next action obvious without flooding the user.
Urgency comes from time.
Importance comes from connectedness and commitment strength.
Staleness catches the neglected work that simple due-date sorting misses.
The assistant should show the minimum set of items that truly demand attention now and keep everything else quiet but recoverable.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Treating every open item as equally urgent | Scoring | Recompute urgency from due distance and staleness every time |
| Ignoring waiting-fors because they depend on other people | Scoring | Escalate stale dependencies and annotate them as follow-ups |
| Dumping too many items into today's agenda | Ranking | Keep the Today horizon capped and let overflow stay ranked but unsurfaced |
| Using one flat priority number for everything | Ranking | Separate urgency, importance, and annotation before grouping |
| Letting undated items disappear forever | Scoring | Elevate neglected undated items through the staleness rule |
| Missing commitments that live only in notes | Annotation | Flag `commitment-gap` when the vault mentions work that the overlay does not track |
| Treating habits exactly like deadlines | Scoring | Use cadence and last completion signals, not just due-date logic |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Open work should all be visible today" | Dumping every open item into the Today horizon | Apply horizon caps and keep overflow ranked but unsurfaced |
| "No due date means this is not urgent" | Letting neglected undated work disappear from the agenda | Apply staleness scoring and annotate stale undated items as `review` |
| "Waiting-for items are blocked, so they can stay quiet" | Ignoring stale dependencies because someone else owns the next move | Escalate stale waiting-fors and mark them as `follow-up` |

## Workflow

### 1. Gather The Operational State

Load open and waiting items from `.pa/work.jsonl`.
Load relevant anchors from `.pa/timeline.jsonl`.
Use recent activity and vault profile data when available to measure staleness and cadence expectations.

### 2. Score Urgency

Classify due items as overdue, imminent, approaching, or low urgency from their distance to today.
For undated items, use inactivity and waiting-for staleness to raise urgency when neglect is the real risk.

### 3. Score Importance

Estimate importance from connectedness rather than tone.
Use entity connections, source breadth, dependency chains, and recent commitment signals as the four proxy inputs.

### 4. Rank By Horizon

Group the ranked items into Today, This Week, and This Month.
Within each horizon, rank by `(urgency * 2) + importance`, then break ties by earlier due date and older creation date.

### 5. Annotate Actions And Flags

Mark each surfaced item as `act`, `follow-up`, `decide`, or `review`.
Attach special flags such as `overdue`, `stale-waiting`, and `commitment-gap` so the user sees why the item surfaced.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Urgency thresholds | `critical` is overdue, `high` is due within 2 days, `medium` is due within 7 days or stale 14+ days without a due date, and `low` is everything else |
| Waiting-for escalation | Raise urgency by one level when the waited-on source shows no update for 7+ days, capped at `high` |
| Importance score | Add one point each for entity connections, source breadth, dependency chains, and recent commitment creation |
| Horizon caps | Surface at most 7 Today items, 12 This Week items, and 20 This Month items |
| Month filter | This Month surfaces only low-urgency items with importance `>= 2` plus monthly milestones |
| Annotation choice | `act` means actionable now, `follow-up` means stale dependency, `decide` means ambiguous next step, and `review` means stale undated work |
| Timeline interaction | Timeline events never replace deadlines and work items, but they must surface beside them when they shape context |
| Commitment gaps | If the vault records an obligation without a matching work item, flag it instead of inventing a task silently |

## Reference Map

| Need | Reference |
|------|-----------|
| `.pa/work.jsonl` schema, extraction rules, and item semantics | `${CLAUDE_SKILL_DIR}/references/work-schema.md` |
| `.pa/timeline.jsonl` schema and date-anchor rules | `${CLAUDE_SKILL_DIR}/references/timeline-schema.md` |
| Compilation window and source selection policy | `${CLAUDE_SKILL_DIR}/references/compilation-policy.md` |
| Chief-of-staff overload handling, tie-break overlays, and annotation logic | `${CLAUDE_SKILL_DIR}/references/agenda-judgment-overlays.md` |

## See Also

- `agents/pa/chief-of-staff.md` — Primary consumer for agenda judgment.
- `commands/pa/agenda.md` and `commands/pa/day.md` — Call this methodology for horizon views and follow-up cues.
- `commands/pa/compile.md` — Uses the sibling compilation policy when period synthesis is requested.
