---
name: fractal-journaling
description: This reference provides Fractal Journaling hierarchy, compile-to-review mapping, quantified trigger rules, and validation checks for PA review loops. It should be consulted when an agent needs to "map compile_cadence to the review hierarchy", "determine which lower-level synthesis to read before a review", "integrate /pa compile with /pa reset", "decide what daily, weekly, monthly, or yearly reviews should summarize", "roll timestamp captures into higher-level syntheses", "check whether a synthesis layer is overdue", or "align review scope with Fractal Journaling cadence".
---

# Fractal Journaling - Hierarchy for Capture, Synthesis, and Review

> Purpose: Hierarchy and orchestration reference for `review-and-journaling` - use it to decide which layer of notes should feed a review loop and when `/pa compile` or `/pa reset` should operate at each layer.
> This reference is standalone and can be consulted without the parent skill.
> For the end-to-end review procedure, see `skills/pa/review-and-journaling/SKILL.md`.
> For compile-window policy, see `skills/pa/executive-assistance/references/compilation-policy.md`.

## Scope

This reference defines the Fractal Journaling ladder that PA should follow when it reviews a vault across time.
Each higher layer should read the nearest lower layer first whenever that synthesis exists.
This keeps higher-horizon reviews readable and prevents strategy conversations from drowning in raw notes.
The quantified rules below define when a layer should compile, when sparse evidence justifies fallback, and when a missing synthesis is overdue.

## Review Hierarchy

| Layer | Input Layer | Primary Action | Primary Output |
|-------|-------------|----------------|----------------|
| **Daily** | Raw captures and timestamp notes | Capture and timestamp evidence, already handled by `/pa capture` and `/pa day` | Timestamp notes or a daily link hub |
| **Weekly** | Timestamp notes and daily hubs | Compile the week, review stale items, surface goal-relevant themes, and carry forward open loops | Weekly synthesis plus stale-loop review and goal-relevant themes |
| **Monthly** | Weekly syntheses and carry-forward lists | Compile monthly themes, check goal progress, and run a direction check | Monthly themes, goal progress, neglected threads, and course corrections |
| **Quarterly** | Monthly themes, project dossiers, and unresolved strategic loops | Compile the quarter and review goals, project mix, and capacity | Quarterly goals review and reset decisions |
| **Yearly and longer** | Quarterly or monthly syntheses plus conversation prompts | Run a strategic review about goals, values, and direction alignment | Direction memo, goal-direction alignment questions, and recommitment choices |
| **Narrative** | Yearly syntheses + entity timeline + decision outcomes | Life narrative note | Multi-period coherent story — see `narrative-synthesis.md` |

Daily is the capture layer, not the first heavy review layer.
Weekly is the first true synthesis boundary.
Monthly and quarterly compress what the week was trying to become.
Weekly synthesis should already notice which themes appear to matter for active goals.
Monthly review should check whether those themes are moving active goals forward.
Yearly and longer layers use the lower syntheses as memory prompts, then shift into conversation-driven reflection about whether the active goals still express the intended direction.
The narrative layer is optional and sits above yearly syntheses when enough accumulated evidence exists to tell a multi-period story.
It does not replace the yearly layer.

## Compile Cadence Mapping

`vault-profile.json -> journal_style.compile_cadence` changes which synthesis layer PA expects by default.
It does not remove the hierarchy.
It changes where the default compression boundary lives.

| `compile_cadence` | Mapping to the Fractal Hierarchy |
|-------------------|----------------------------------|
| `rolling` | Keep daily capture continuous and treat weekly as the first hard synthesis boundary at `7` days or `3+` timestamp notes |
| `every-few-days` | Create `3-day` mini-batches that still feed the weekly layer, then continue upward normally |
| `monthly` | Treat monthly compilation as the default evidence packet after `30` days or `3+` weekly syntheses, while weekly review becomes a lighter health check if a weekly synthesis is missing |
| `annual` | Treat yearly compilation as the mandatory strategic packet after `365` days or `3+` quarterly syntheses, and allow month or quarter layers to stay lightweight when the vault is sparse |
| `custom` | Map the explicit window by review posture: `1-14` days -> weekly, `15-45` days -> monthly, `46-135` days -> quarterly, `136+` days -> yearly |

If `compile_cadence` is sparse, do not force missing intermediate syntheses just to satisfy the hierarchy.
Treat a layer as sparse when it has fewer than the minimum evidence threshold in the next section.
Read the nearest available lower-layer summary and continue.
The hierarchy is a guide for compression order, not a rigid gate that blocks review.

## Decision Rule Quantification

Use these thresholds to decide when a layer should compile and when a missing synthesis should be called out as overdue.
Compile when the default time boundary is reached and the minimum evidence trigger is met.
If a higher-layer review is needed early, use the same minimum evidence trigger as the bar for early compilation.
When the time boundary is reached but the evidence trigger is not met, skip forced compilation and review the nearest available lower layer directly.
Long-horizon reviews above `year` do not create a new mandatory compile layer by default.
They reuse the latest yearly packet, or request a fresh yearly packet when that packet is overdue.

| Layer | Default Time Trigger | Minimum Evidence Trigger | Overdue When |
|-------|----------------------|--------------------------|--------------|
| **Daily** | End of the same calendar day | `1+` timestamp note or `1+` explicit carry-forward item | No daily closeout after `2` days when carry-forward still exists |
| **Weekly** | End of a `7-day` window | `3+` timestamp notes, or `1` daily hub that points to `3+` timestamp notes | `10+` days since the last weekly synthesis while qualifying daily evidence exists |
| **Monthly** | End of a `30-day` window | `3+` weekly syntheses, or `9+` timestamp notes spanning `21+` days when weekly syntheses are missing | `40+` days since the last monthly synthesis while qualifying evidence exists |
| **Quarterly** | End of a `90-day` window | `3+` monthly syntheses, or `9+` weekly syntheses spanning `60+` days when monthly syntheses are missing | `100+` days since the last quarterly synthesis while qualifying evidence exists |
| **Yearly** | End of a `365-day` window | `3+` quarterly syntheses, or `9+` monthly syntheses spanning `270+` days when quarterly syntheses are missing | `395+` days since the last yearly synthesis while qualifying evidence exists |

A compilation that misses the minimum evidence threshold is a clean sparse fallback, not a methodology failure.
A compilation that clears the minimum evidence threshold and then remains past the overdue threshold should be surfaced as missing review infrastructure.

## Compile and Reset Integration

| Layer | `/pa compile` role | `/pa reset` role |
|-------|--------------------|------------------|
| **Daily** | Usually no-op because daily captures are already atomic | Close the day, preserve open loops, and prepare the weekly layer |
| **Weekly** | Compile timestamp notes and daily link hubs into a weekly synthesis that already surfaces goal-relevant themes | Review stale commitments, resurfaced notes, goal-relevant patterns, and carry-forward items, then update `review-state.json` |
| **Monthly** | Compile weekly syntheses into monthly themes, recurring concerns, and goal-progress evidence | Decide what to continue, stop, or re-scope across the next month |
| **Quarterly** | Compile monthly themes and dossier summaries into a quarterly packet | Review goals, capacity, project mix, and what should be reset or recommitted |
| **Yearly and longer** | Assemble a strategic packet from quarterly or monthly syntheses | Shift from mechanical drift detection to goal progress, values, and direction-alignment questions |

`/pa reset` should usually call or consume `/pa review` at the same layer.
It should not skip the lower-layer synthesis when the evidence packet is too large to review raw.
When the lower layer does not exist, `/pa reset` should read the nearest available lower layer instead of failing.
When a lower-layer synthesis is overdue by the table above, `/pa reset` should call that out explicitly before climbing to strategy questions.

## Strategic Review Questions

These questions become progressively more conversation-driven as the horizon expands.
At yearly and longer horizons, ask them against the active goal set instead of reviewing direction in the abstract.

| Horizon | Core Question |
|---------|---------------|
| `year` | What actually mattered this year, and what should end before it quietly continues by inertia |
| `3y` | Which capabilities, relationships, and projects are compounding in the right direction |
| `10y` | Which direction still feels durable enough to build around |
| `30y` | What would be costly or tragic to postpone for another decade |
| `lifetime` | What kind of life is this system trying to protect and help build |

Use the lower syntheses as prompts for these questions.
Do not let the prompts become the answer.

## Common Pitfalls

| Pitfall | Prevention |
|---------|------------|
| Jumping from daily raw captures straight into a yearly review | Read the nearest lower synthesis first |
| Treating `compile_cadence` as a mandate instead of a default | Use cadence to pick the default compression layer, not to block other review horizons |
| Running `/pa reset` without a carry-forward view | Always preserve unresolved loops and open commitments before resetting priorities |
| Forgetting goal progress between weekly themes and yearly direction | Let weekly compile surface goal-relevant themes, let monthly review check goal progress, and let yearly review test direction alignment |
| Letting monthly review become a bigger weekly review | Require theme extraction and direction check at the monthly layer |
| Forgetting that yearly and longer reviews are conversation-driven | Use data as prompts and memory refresh, not as strategy by itself |
| Compiling a layer too early just to clear the inbox | Check the numeric trigger and minimum evidence thresholds before writing the synthesis |
| Letting a weekly or monthly compilation expand into the next horizon | Keep the synthesis bounded to the target layer and defer adjacent-layer questions |

## Bias Mitigation

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Recency bias | Compilation | Recent entries dominate the synthesis while earlier evidence inside the same window disappears | Read the full window before summarizing, and verify that earlier entries still appear in the retained themes or carry-forward set |
| Completion bias | Compilation | The reviewer rushes compilation to clear the inbox rather than to compress meaning | Require the time trigger and minimum evidence trigger before compiling, and never mark a loop resolved without explicit evidence |
| Narrative bias | Theme Extraction | Disconnected captures are forced into one clean story that the notes do not actually support | Keep weakly related or contradictory captures in separate theme clusters, and label uncertainty instead of merging it away |
| Scope bias | Layer Boundary | A weekly compile starts doing monthly strategy, or a monthly compile falls back into daily trivia | Use only the target layer's input family and target-layer questions, and defer adjacent-layer issues to their own review |

## Validation Checklist

- [ ] The selected review horizon was mapped to the correct Fractal layer before evidence was read
- [ ] The nearest available lower-layer synthesis was read before moving upward
- [ ] `compile_cadence` was treated as a default, and `custom` windows were mapped by numeric length
- [ ] Weekly compilation required a `7-day` boundary or `3+` timestamp notes, or it was explicitly treated as a sparse fallback
- [ ] Monthly compilation required a `30-day` boundary or `3+` weekly syntheses, or it was explicitly treated as a sparse fallback
- [ ] Weekly synthesis surfaced goal-relevant themes when active goals were in play
- [ ] Monthly review checked goal progress instead of stopping at weekly theme compression
- [ ] Quarterly compilation required a `90-day` boundary or `3+` monthly syntheses, or it was explicitly treated as a sparse fallback
- [ ] Yearly compilation required a `365-day` boundary or `3+` quarterly syntheses, or it was explicitly treated as a sparse fallback
- [ ] Yearly and longer reviews checked direction alignment against active goals instead of asking abstract strategy questions alone
- [ ] Overdue checks used the numeric thresholds (`2`, `10`, `40`, `100`, `395` days) instead of vague staleness language
- [ ] Carry-forward items and open loops were preserved upward rather than silently dropped during synthesis
- [ ] Long-horizon reviews used yearly or quarterly packets as prompts, not as automatic conclusions
- [ ] Bias checks covered recency, completion, narrative, and scope bias before finalizing the review packet

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/review-and-journaling/SKILL.md` | Parent skill - review-loop methodology |
| `skills/pa/executive-assistance/references/compilation-policy.md` | Sibling reference - compile windows and source eligibility |
| `templates/pa/daily-link-hub.md` | Daily link-first layer for Fractal Journaling vaults |
| `templates/pa/weekly-review.md` | Weekly synthesis output that feeds higher layers |
| `commands/pa/compile.md` | Produces the lower-layer syntheses that higher reviews consume |
| `commands/pa/reset.md` | Resets the selected horizon using the hierarchy defined here |
| `commands/pa/day.md` | Daily capture and closeout entry point for the base layer |
