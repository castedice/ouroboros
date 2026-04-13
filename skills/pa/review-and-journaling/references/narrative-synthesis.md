---
name: narrative-synthesis
description: This reference defines multi-period narrative synthesis rules for PA. It should be consulted when an agent needs to "generate a life narrative", "synthesize multi-period story from vault data", "compose direction evolution summary", "aggregate compilations into narrative", "identify recurring themes across periods", or "ground narrative claims in vault evidence".
---

# Narrative Synthesis — Multi-Period Life Story

> Purpose: Reference for `review-and-journaling` — defines how PA synthesizes accumulated vault data into a coherent life narrative.
> For single-period compilation, see `skills/pa/review-and-journaling/references/fractal-journaling.md`.
> For the output template, see `templates/pa/life-narrative.md`.

## Core Principle

**"Narrate what happened, not what should have happened."**

A life narrative is a retrospective story grounded in vault evidence.
It describes trajectory, not prescription.
Every claim must trace to a source document, entity, or observation.

## Input Collection

Collect from these sources for the narrative window:

| Source | What to Extract |
|--------|----------------|
| Period compilations | Themes, carry-forwards, decisions, evergreen candidates |
| Review checkpoints (review-state.json) | Stale items surfaced, resurfaced notes, direction questions asked |
| Life entities (entities.json) | Goal status transitions, new/completed/abandoned goals, area changes |
| Decision entities | Decisions made, outcomes, lessons learned |
| Direction history (personal-profile.json) | direction changes, last_direction_review dates |
| Memory observations | direction-shift and work-change signals |
| Values alignment data | Work distribution patterns (if available from Phase 22B) |
| Energy pattern trends | Monthly energy trends (if available from Phase 22E) |

## Synthesis Principles

1. **Evidence-grounded**: Every narrative claim must cite a source.
   Use [[wikilinks]] for vault notes.
2. **Vault-native voice**: Scribe writes in the user's voice (precedent ladder from existing notes).
3. **Chronological backbone, thematic layers**: Tell the story in time order, but group related threads.
4. **Direction as through-line**: The user's stated direction is the narrative spine.
   Show how events aligned or diverged.
5. **Decisions as turning points**: Decision entities are natural chapter markers.
6. **Themes emerge from evidence**: Don't impose themes — identify them from recurring patterns across compilations.
7. **Open questions are valuable**: Unresolved threads are narrative forward-momentum, not failures.

## Synthesis Workflow

1. **Collect**: Gather all input sources for the narrative window.
2. **Timeline**: Build a chronological timeline of key events (goal transitions, decisions, direction shifts, milestones).
3. **Thread identification**: Group related events into narrative threads (e.g., "career pivot", "health journey", "learning arc").
4. **Narrative draft**: Scribe synthesizes threads into the life-narrative.md template sections.
5. **Evidence check**: Verify every claim traces to a source.
   Remove ungrounded assertions.
6. **Theme extraction**: Identify 3-5 recurring patterns across threads.
7. **Open questions**: Collect unresolved threads, pending decisions, carry-forward items.

## Minimum Data Requirements

| Requirement | Threshold | If Below |
|-------------|-----------|----------|
| Period compilations | 2+ in window | Narrative feasible but thin — note sparse evidence |
| Review checkpoints | 1+ in window | Direction evolution section will be limited |
| Decision entities | 0 (optional) | Skip Key Decisions section |
| Entities with status changes | 3+ | Narrative feasible |
| Total sources | 5+ across all types | Below this, suggest accumulating more data first |

## Common Pitfalls

| Pitfall | Why Wrong | Prevention |
|---------|-----------|------------|
| Inventing events not in the vault | Narrative becomes fiction | Every claim must cite a source |
| Prescribing what the user should do | Narrative is retrospective, not advisory | Present trajectory, not recommendations |
| Forcing a redemption arc | Real life is messy | Let the narrative include ambiguity |
| Ignoring abandoned goals | Abandonment is a valid outcome | Include with neutral framing |
| Over-weighting recent events | Recency bias distorts the period view | Weight by significance, not freshness |

## Validation Checklist

- [ ] Every narrative claim points to a source note, entity, decision, or review artifact in the selected window.
- [ ] The draft keeps a vault-native voice that matches existing notes instead of generic coaching language.
- [ ] Decision entities are used as turning points or chapter markers when the period includes them.
- [ ] Direction remains the through-line, with clear evidence for alignment, divergence, and shifts.
- [ ] Themes are extracted from recurring evidence across compilations and reviews rather than imposed in advance.
- [ ] Open questions and unresolved threads are preserved instead of being smoothed away for narrative neatness.
- [ ] Sparse evidence is called out explicitly instead of being padded with invented continuity.

## See Also

| Component | Relationship |
|-----------|-------------|
| `templates/pa/life-narrative.md` | Output template |
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill |
| `skills/pa/review-and-journaling/references/fractal-journaling.md` | Single-period compilation (input) |
| `agents/pa/scribe.md` | Narrative writer |
| `commands/pa/review.md` | Consumer — year+ --narrative flag |
