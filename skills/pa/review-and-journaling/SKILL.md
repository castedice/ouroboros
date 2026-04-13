---
name: review-and-journaling
description: This skill provides review loop methodology for periodic vault health checks. It should be activated when an agent needs to "run a review loop", "detect stale commitments", "find orphan notes", "check vault health", "resurface forgotten context", "assess review cadence", or "determine review horizon scope".
summary: Runs periodic vault reviews that detect drift, resurface relevant context, and support operational or strategic reflection.
version: 1
tags: [pa, review, journaling, vault-health, resurfacing]
preamble_tier: 3
---

# Review and Journaling

## Core Rule

**"Catch what is slipping before it becomes a crisis."**

Review loops protect trust in the vault by detecting drift while it is still cheap to fix.
Short horizons protect execution.
Long horizons protect direction.
The review should stay evidence-heavy when the question is operational and become conversation-led only when the horizon is strategic.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Reusing old findings as if they were still current | Detection | Recompute drift from current overlays and compare against the last snapshot |
| Turning a weekly review into vague life coaching | Horizon choice | Keep `week` and `month` grounded in evidence and explicit actions |
| Letting metrics answer strategy questions by themselves | Strategic review | Use data as prompts, not as the final judge, for `year+` horizons |
| Surfacing too many forgotten-context notes | Resurfacing | Rank candidates and cap resurfacing strictly |
| Writing checkpoints before the review is actually done | Closeout | Update `review-state.json` only after findings are shown and the run is complete |
| Treating every stale note as a failure | Detection | Ask whether the note is intentionally dormant, archival, or still relevant |
| Skipping lower-layer syntheses on longer reviews | Review pack | Read the nearest lower synthesis before climbing to a wider horizon |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Last review already found this, so reuse the finding" | Reporting old drift as current without recomputation | Recompute current state and compare against the prior snapshot |
| "A strategic review should be objective, so metrics can decide it" | Letting review metrics answer year-plus direction questions by themselves | Use data as prompts and keep long-horizon review conversation-led |
| "More resurfaced notes will give the user better coverage" | Surfacing a broad stale-note list instead of ranked forgotten context | Apply eligibility rules and cap resurfacing strictly |
| "The review is basically done, so update the checkpoint now" | Writing `review-state.json` before findings are shown and the run is complete | Update checkpoints only after closeout |
| "A stale note means something went wrong" | Treating dormant, archival, or intentionally parked notes as failures | Ask whether the note is still relevant before proposing action |

## Workflow

### 1. Choose The Horizon And Review Mode

Default to `week` when the user asks for general review without a horizon.
Treat `week` and `month` as data-driven, `quarter` as hybrid, and `year+` as conversation-driven with evidence support.

### 2. Build The Review Pack

Read `.pa/work.jsonl`, `.pa/timeline.jsonl`, `.pa/entities.json`, and `.pa/review-state.json` first.
Add orphan-note, unresolved-link, and recent-activity evidence for operational reviews.
For longer horizons, read the nearest lower-level syntheses before raw note sprawl.

### 3. Detect Mechanical Drift

Scan for stale items, stale waiting-fors, orphan notes, unresolved links, forgotten context, and open loops.
Compare the current open loops against the prior snapshot so findings distinguish `new`, `persistent`, and `resolved`.

### 4. Resurface Supporting Context

Select notes that are both stale and relevant to active work or active entities.
Apply suppression rules, optionally surface serendipity or contradiction signals, and keep the resurfacing list small enough to be useful.

### 5. Run The Horizon Review And Close The Loop

For short horizons, return concrete follow-up, relink, close, and carry-forward actions.
For long horizons, lead with narrative, values, and direction questions anchored by the evidence pack.
After completion, update the review checkpoint state and resurfacing history.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Default horizon | Use `week` unless the user asks for a different review scope |
| Mode by horizon | `week` and `month` are operational, `quarter` is hybrid, and `year`, `3y`, `10y`, `30y`, and `lifetime` are conversation-led |
| Staleness thresholds | Open items go stale at 14+ days, and waiting-fors go stale at 7+ days |
| Resurfacing gate | A forgotten-context note must be 14+ days stale and score `>= 0.4` semantic relevance to an active anchor |
| Resurfacing cap | Surface at most 3 forgotten-context notes per invocation |
| Structural checks | Include orphan-note and unresolved-link scans for operational reviews, using CLI or raw-link fallback |
| Snapshot comparison | Label loops against the prior `open_loops_snapshot` instead of presenting one flat unresolved list |
| Checkpoint timing | Never update `last_review` or snapshots before the review has actually been completed |

## Reference Map

| Need | Reference |
|------|-----------|
| Checkpoint schema, open-loop snapshots, and suppression state | `${CLAUDE_SKILL_DIR}/references/review-state-schema.md` |
| Forgotten-context eligibility, ranking, and anti-nag rules | `${CLAUDE_SKILL_DIR}/references/resurfacing-rules.md` |
| Review hierarchy and lower-layer synthesis mapping | `${CLAUDE_SKILL_DIR}/references/fractal-journaling.md` |
| Serendipity and contradiction surfacing rules | `${CLAUDE_SKILL_DIR}/references/serendipity-rules.md` |
| Multi-period story synthesis for long horizons | `${CLAUDE_SKILL_DIR}/references/narrative-synthesis.md` |
| Values and direction prompts for strategic review | `${CLAUDE_SKILL_DIR}/references/values-alignment.md` |

## See Also

- `agents/pa/sentinel.md` — Primary detector for review findings.
- `commands/pa/review.md` — Main command consumer for review execution.
- `commands/pa/reset.md` — Uses the same hierarchy and carry-forward logic when resetting periods.
- `skills/pa/executive-assistance/SKILL.md` — Supplies operational priority context that reviews inspect.
