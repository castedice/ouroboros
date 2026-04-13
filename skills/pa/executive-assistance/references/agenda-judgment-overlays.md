---
name: agenda-judgment-overlays
description: This reference defines the chief-of-staff overlays applied on top of the base executive-assistance scoring model, including overload handling, conflict surfacing, tie-breaks, confidence caps, and output annotation logic.
---

# Agenda Judgment Overlays — Chief-Of-Staff Additions

> Purpose: Reference for `executive-assistance`.
> Scope: The extra judgment rules in `agents/pa/chief-of-staff.md` that sit on top of the base skill.

## Layering Rule

- The executive-assistance skill owns the base urgency, importance, staleness, and horizon rules.
- The chief-of-staff adds judgment overlays after those base scores exist.
- The overlays decide what to surface, what to compress, and how to explain trade-offs.
- The overlays do not invent new tasks, deadlines, or commitments.

## Base Score Inputs

- Urgency comes from due distance and explicit waiting-for escalation.
- Importance comes from connectedness, source breadth, dependency chains, and recent commitment creation.
- Staleness keeps undated or neglected work visible when simple due-date sorting would bury it.
- Ranking starts from the base methodology before any chief-of-staff-specific overrides are applied.

## Base Thresholds Inherited From The Skill

- `critical` means overdue.
- `high` means due within 2 days.
- `medium` means due within 7 days or stale 14 or more days without a due date.
- `low` means everything else.
- Waiting-fors can rise by one urgency level after 7 or more days without an update, capped at `high`.
- The rank formula is `(urgency * 2) + importance` before tie-break overlays.

## Horizon Caps Inherited From The Skill

- Today surfaces at most 7 items before overlays compress the view further.
- This Week surfaces at most 12 items before overlays compress the view further.
- This Month surfaces at most 20 items before overlays compress the view further.
- Monthly surfacing keeps low-urgency items only when importance is at least 2 or the item is a monthly milestone.

## Overload Overlay

- When the requested horizon is `today` and more than 5 surfaced items land in `critical` or `high`, the day is treated as overloaded.
- Overload does not change the underlying item scores.
- Overload compresses the recommendation to 1 to 3 must-focus threads.
- Overload adds a Triage section explaining what was deferred and why.
- Overload is the main reason the caller may need a user checkpoint before presenting the full agenda.

## Conflict Overlay

- If two top items are mutually exclusive by owner, time block, or dependency, the chief-of-staff must surface the conflict explicitly.
- The agent must preserve both options instead of silently picking one.
- Conflict reporting belongs in the Risks section.
- The agent presents trade-offs and lets the caller or user resolve the choice.

## Tie-Break Overlay

- When several items score similarly, prefer the thread that unblocks more downstream work.
- If unblock power is tied, prefer the thread with clearer user ownership.
- If ownership is tied, prefer the thread with stronger source evidence.
- The overlay exists to stop near-tied lists from becoming arbitrary calendar dumps.

## Partial-Evidence Overlay

- When evidence is partial or contradictory, keep the item visible.
- Lower the confidence instead of hiding the item.
- State which signal is missing, weak, or contradictory.
- The chief-of-staff must not promote partial evidence into certainty just to keep the report clean.

## Soul And Energy Overlays

- `soul_principles` can calibrate framing but not facts.
- A principle such as `사실 우선` should make the explanation more factual, not more severe.
- A principle such as `도전적으로` can justify sharper challenge framing, not a score change.
- A principle such as `안전하게` can justify stronger risk framing, not fabricated urgency.
- `energy_patterns` can calibrate load recommendations when the data is marked sufficient.
- Low-energy patterns should bias the recommendation toward lighter scheduling or narrower focus, not different facts.

## Confidence Caps

- Confidence is `high` only when work items, timeline events, and recent activity are all present and provenance is strong.
- Confidence is `medium` when work items exist but timeline or activity evidence is partial or many dates are missing.
- Confidence is `low` when work items exist but dates, owners, or provenance are mostly weak.
- Confidence is `none` when no work items exist.
- Stale operational data older than 7 days caps confidence at `medium` even if the report is otherwise coherent.

## Section Annotation Logic

- Focus is always present because the command must still answer what matters now.
- Triage appears only when overload is detected.
- Risks appears when inaction could cause concrete damage or when conflicts must be surfaced.
- Waiting-Fors appears when external dependencies exist and needs staleness-aware follow-up text.
- Follow-Ups appears for user-action items that are real but not urgent.
- Proactive Opportunities appears on quiet days or when the horizon supports strategic work.
- Specialist Insights appears only when structured specialist advice is present.

## Item-Level Annotation Rules

- Every Focus item needs a `because...` line that explains why it matters now.
- Waiting-for items must include the last known update, the expected owner, and a concrete follow-up suggestion.
- Risk items must include the consequence of inaction.
- Deferred items in Triage must explain why they lost to a higher-leverage thread.
- Proactive opportunities must explain why the item deserves attention despite lacking deadline pressure.

## Horizon-Specific Interpretation

- `today` should collapse into concrete action and narrow focus.
- `week` should preserve trajectory and near-term trade-offs.
- `month` should preserve longer-arc milestones and only the most important low-urgency items.
- The chief-of-staff must not use a month-like surface for a today request just because many items are open.

## Edge-Case Overlays

- If all open items lack due dates, prioritize by staleness, dependency, and confidence instead of pretending due-date urgency exists.
- If all work items are done, return a light overview and suggest longer-horizon planning rather than inventing pressure.
- If the user asked for `today` and nothing is due today, report the quiet day honestly and use proactive opportunities instead of forced urgency.
- If no work items exist, return a structural gap report with confidence `none`.

## Non-Goals

- The chief-of-staff is not allowed to create missing work items.
- The chief-of-staff is not allowed to rewrite source overlays.
- The chief-of-staff is not allowed to answer vault-content questions that belong to retrieval or synthesis commands.
- The chief-of-staff is not allowed to apply persona rendering.

## Practical Checklist

- Apply the base urgency, importance, and staleness rules first.
- Compress overloaded today views down to 1 to 3 must-focus threads.
- Surface mutually exclusive top priorities as explicit conflicts.
- Break near ties by downstream unblock power, then ownership clarity, then evidence strength.
- Lower confidence when evidence is partial instead of hiding the item.
- Keep section annotations aligned with Focus, Triage, Risks, Waiting-Fors, Follow-Ups, Proactive Opportunities, and Specialist Insights.
- Make every surfaced item answer the question, "Why now."
