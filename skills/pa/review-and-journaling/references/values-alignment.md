---
name: values-alignment
description: This reference defines the values alignment check methodology for PA. It should be consulted when an agent needs to "compare stated values against behavior", "compute work distribution by area", "detect value-behavior misalignment", "present alignment data neutrally", "ground direction review in behavioral evidence", or "map values to life areas".
---

# Values Alignment — Behavioral Evidence for Stated Values

> Purpose: Reference for `review-and-journaling` — defines how PA compares personal-profile values against actual work distribution to detect alignment gaps.
> This reference is standalone and can be consulted without the parent skill.
> For personal profile schema, see `skills/pa/personal-profiling/references/profile-schema.md`.
> For review methodology, see `skills/pa/review-and-journaling/SKILL.md`.

## Core Principle

**"Present data, never judge."**

PA detects distribution patterns, not value violations.
The user decides what the data means.
PA never says "you are not living your values" — it says "here is how your time was distributed."

## Analysis Method

1. Load `identity.values_and_principles` from personal-profile.json.
2. Load `identity.core_areas` and `direction.directions_by_area`.
3. Map each value to aligned areas using direction_by_area text matching and goal entity value_refs.
4. Count work items per area over the review period from work.jsonl (using source_docs folder patterns and entity area_refs).
5. Compute distribution: percentage of work items per area.
6. Detect potential misalignment: if a stated value maps to area X, but area X has < 10% of work items while another area has > 40%.

## Value-to-Area Mapping

| Signal | Weight |
|--------|--------|
| Goal entity with matching `value_refs` | Strong |
| `directions_by_area[area]` text contains the value keyword | Medium |
| Area name semantically aligns with value (e.g., "health" ↔ "sustainable pace") | Weak — require confirmation |

When a value cannot be mapped to any area, note it as "unmapped" and skip alignment scoring for that value.

## Presentation Rules

Always neutral language.
Examples:

Good: "Your stated values include 'sustainable pace'. Work distribution this year: career 62%, finance 18%, health 8%."
Bad: "You are neglecting your health despite saying you value sustainable pace."

Good: "The health area — aligned with sustainable pace — had the lowest work item share."
Bad: "You should spend more time on health."

## Misalignment Thresholds

| Condition | Signal |
|-----------|--------|
| Aligned area has < 10% of work items | Potential misalignment — surface data |
| Aligned area has 0 work items | Strong misalignment signal — surface with emphasis |
| Value has no mapped area | Unmapped — note but do not flag as misalignment |
| All values have >= 15% aligned area coverage | Aligned — no finding |

## Minimum Data Requirements

- personal-profile.json must have `identity.values_and_principles` with at least 1 value
- work.jsonl must have 20+ items in the review window
- Below these thresholds: skip values alignment and note "insufficient data"

## Design Rationale

| Decision | Why |
|----------|-----|
| Work items as proxy for time | Direct time tracking is unavailable — work item count is the best available behavioral signal |
| 10% misalignment threshold | Below 10% suggests the area is systematically deprioritized, not just temporarily quiet |
| 20-item minimum | Smaller samples produce misleading distributions — a few items can dominate percentages |
| Neutral language only | PA is not a therapist or judge — behavioral data speaks for itself |
| Year+ horizon only | Short-term distributions fluctuate naturally — alignment is a long-arc signal |
| Value-to-area mapping via goals | Goals explicitly connect values to areas via `value_refs` — strongest available signal |

## Bias Mitigation

| Bias | Risk | Countermeasure |
|------|------|----------------|
| Productivity bias | Over-weighting career/work areas because they generate more work items | Present all areas equally, note that some areas (health, relationships) generate fewer trackable items |
| Recency bias | Recent busy period dominates the year view | Use full review window, not just recent months |
| Narrative bias | Imposing a "you should balance" story on the data | Present distribution only — user decides what it means |
| Measurement bias | Treating work item count as equivalent to time or importance | Explicitly state "work item distribution" not "time spent" or "priority" |

## Common Pitfalls

| Pitfall | Why Wrong | Prevention |
|---------|-----------|------------|
| Judging the user's choices | PA is not a moral authority | Present data only, never prescribe |
| Counting note count as time spent | Notes ≠ time allocation | State "work item distribution" not "time spent" |
| Flagging intentional trade-offs | User may knowingly deprioritize | Present neutrally, let user interpret |
| Running on sparse data | Small samples produce misleading distributions | Enforce 20-item minimum |

## Validation Checklist

- [ ] All findings use neutral descriptive language rather than judgment, advice, or moral framing.
- [ ] The review window contains at least 20 work items before values alignment is computed.
- [ ] Values that cannot be mapped to an area are noted as unmapped and are not flagged as misalignment.
- [ ] Area distribution percentages add up to approximately 100 percent after rounding.
- [ ] Findings describe work item share, not time spent or effort certainty.
- [ ] No prescriptive recommendations are added to the alignment output.
- [ ] Value-to-area mapping respects the documented strong, medium, and weak evidence hierarchy.

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill |
| `skills/pa/personal-profiling/references/profile-schema.md` | Source of values and areas |
| `commands/pa/review.md` | Consumer — year+ Values Alignment section |
| `agents/pa/sentinel.md` | Executor — computes alignment data |
| `commands/pa/day.md` | Potential future consumer — energy + alignment combined daily insight |
| `skills/pa/personal-profiling/references/feedback-learning.md` | Parallel pattern — behavioral evidence for preferences vs values |
