---
title: Weekly Review
description: Horizon-aware reset template for composing review findings, period synthesis, priority reset, and new connections into one bounded weekly or longer-horizon review output
---

# Weekly Review Template

PA commands use this template when rendering a reset-style review that combines review findings, period synthesis, priority reset, and new connections.
The sentinel agent provides the review summary, `compile` provides the period synthesis, `agenda` provides the priority reset, and `link` provides new connections.
The calling command renders this template from those component outputs.

This template is read-only by default.
When posture and user intent permit, the caller may persist the rendered review as a vault note or synthesis artifact.
Despite the filename, the structure is horizon-aware and can scale from `week` through `year+`.

## Rendering Rules

1. **Horizon framing**: Resolve the header from the selected horizon and a concrete period label.
   Always show the actual range or anchor window, not just a vague horizon word.
2. **Short-horizon emphasis**: For `week` and `month`, keep the review operational.
   Show stale loops, concrete carry-forward items, recent synthesis, and task-level reset decisions clearly.
3. **Long-horizon emphasis**: For `year` and longer, compress low-level operational noise.
   Shift the review toward goals, direction, enduring commitments, and what should change next.
4. **Quarter as hybrid**: Treat `quarter` as a bridge horizon.
   Keep only the highest-signal mechanical drift and combine it with direction-reset language.
5. **Review Summary**: Summarize sentinel output instead of pasting the full report verbatim.
   Highlight the highest-signal drift, healthy areas, and resurfacing outcomes.
6. **Period Compilation**: Use `compile` output or the nearest lower-layer synthesis that fits the selected horizon.
   Short horizons should show themes, decisions, and carry-forward.
   Long horizons should show major themes and directional evidence, not raw capture detail.
7. **Priority Reset**: Short horizons should show concrete threads, deferrals, and follow-ups.
   Long horizons should show start, stop, recommit, and direction-correction decisions.
8. **New Connections**: Include only connections that materially change retrieval, prioritization, or understanding.
   Do not pad the section with generic graph neighbors.
9. **Next Actions**: For `week` and `month`, render concrete actions.
   For `year+`, render commitments, experiments, or open questions that guide the next period.
10. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
# {{horizon_label}} Review — {{period_label}}

> Generated: {{timestamp}} | Horizon: {{horizon}} | Sources: {{source_count}} | Confidence: {{confidence}}

## Review Summary

{{review_summary_from_sentinel}}

## Period Compilation

{{period_compilation_from_compile_or_lower_layer_synthesis}}

## Priority Reset

{{priority_reset_from_agenda}}

## New Connections

{{new_connections_from_link}}

## Next Actions

1. {{next_action_1}}
2. {{next_action_2}}
3. {{next_action_3}}
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `horizon_label` | Title-cased label derived from the selected horizon | Title-case `horizon` verbatim |
| `period_label` | Caller-supplied date range, cadence window, or named review period | Concrete range derived from the selected horizon |
| `timestamp` | Current date and time at render | ISO 8601 format |
| `horizon` | Caller-selected review horizon | `week` |
| `source_count` | Total distinct sources across sentinel, compile, agenda, and link inputs | `0` |
| `confidence` | Overall confidence from the weakest major input stream | `low` when any major section is missing or weak |
| `review_summary_from_sentinel` | Caller-compressed summary of the follow-up report | "No mechanical drift detected." |
| `period_compilation_from_compile_or_lower_layer_synthesis` | `compile` output or nearest lower-layer synthesis | Omit only when the selected horizon allows omission and no lower-layer synthesis exists |
| `priority_reset_from_agenda` | Chief-of-staff or agenda output for the selected horizon | "No priority reset available." |
| `new_connections_from_link` | Link or weaver output limited to material connections | Omit section if no meaningful new connections exist |
| `next_action_N` | Caller-synthesized action, commitment, experiment, or question | At least one line is required |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Review Summary | Never omit |
| Period Compilation | Omit only when the selected horizon is `year+` and no lower-layer synthesis is available |
| Priority Reset | Never omit |
| New Connections | No material connection or reconnection changes the review outcome |
| Next Actions | Never omit |

For `week`, `month`, and `quarter`, keep `Period Compilation` even when compilation input is partial.
If evidence is partial at those horizons, render the section with a short limitation note instead of omitting it.

## Horizon Variations

| Horizon | Review Summary Emphasis | Period Compilation Input | Priority Reset Shape | New Connections Emphasis | Next Actions Style |
|---------|-------------------------|--------------------------|----------------------|--------------------------|-------------------|
| `week` | Stale commitments, waiting-fors, unresolved links, and top resurfacing notes | This week's compilation, timestamp notes, and daily hubs | 1-3 concrete threads plus follow-ups and deferrals | Neglected note reconnections and actionable graph fixes | Concrete tasks and follow-up moves |
| `month` | Recurring drift, neglected themes, and pattern-level health | Weekly syntheses or monthly compilation | 3-5 priorities plus one stop, defer, or close decision | Project and theme reconnections | Tactical actions plus one direction correction |
| `quarter` | Hybrid of operational drift and strategic alignment | Monthly syntheses and compilation rollups | Start, stop, continue, and capacity reset | Portfolio-level relationships and why current priorities exist | Decisions, experiments, and owner clarifications |
| `year` | Highest-signal drift only, plus what should continue or end | Quarterly or monthly syntheses, not raw captures | Goals, recommitments, and anti-drift direction reset | Enduring themes and deep memory cues | Commitments and strategic questions |
| `3y` and longer | Direction durability, compounding bets, and identity-level drift | Yearly and lower-layer syntheses only | Long-horizon commitments, trade-offs, and what must remain true | Deep memory, enduring entities, and archival resurfacing when useful | Guiding questions, commitments, and life-shaping moves |

## Common Mistakes

| Mistake | Why It Fails | Prevention |
|---------|--------------|------------|
| Letting a weekly review become a diary recap | Repeats chronology instead of producing a reset | Lead with findings, synthesis, and reset decisions |
| Letting a yearly review become a task dump | Treats long-horizon reflection as inbox triage | Shift toward goals, direction, and enduring commitments |
| Pasting the full follow-up report into `Review Summary` | Duplicates detail and makes the composite hard to scan | Compress sentinel output to the highest-signal findings |
| Ignoring lower-layer synthesis at longer horizons | Forces raw note sprawl into a strategic review | Use the nearest lower-layer compilation or synthesis first |
| Filling `New Connections` with generic neighbors | Adds noise without changing understanding | Include only connections that alter retrieval, priority, or framing |
| Inventing ambitious next actions unsupported by evidence | Turns review into aspiration theater | Keep next actions proportional to the horizon and grounded in the inputs |

## Design Rationale

Why this template keeps the same section order across horizons: a stable frame makes review outputs comparable while still allowing the content granularity to change.
Why `Review Summary` and `Period Compilation` are separate: the first detects drift and the second compresses lived evidence.
Why `Priority Reset` is distinct from both: reset decisions should be readable without re-parsing the whole review.
Why `New Connections` has its own section: a useful review should not only notice drift but also refresh the user's map of what connects.
Why `Next Actions` stays last: a reset should end with what changes next, not with more analysis.

## Bias Mitigation

| Bias | Rendering Risk | Countermeasure |
|------|----------------|----------------|
| Recency bias | The latest captures dominate even when the broader period says something else | Use bounded compilation or lower-layer synthesis before writing the composite |
| Productivity bias | Every horizon is forced into short-term task management | Shift `year+` outputs toward goals, direction, and trade-offs |
| Coherence bias | The review is flattened into one tidy story and conflicting evidence disappears | Preserve separate sections for findings, synthesis, reset, and connections |
| Closure bias | Open loops are rewritten as resolved to make the review feel cleaner | Keep unresolved carry-forward explicit unless evidence shows closure |
| Nostalgia bias | Resurfaced old notes overpower present commitments at long horizons | Keep resurfacing selective and subordinate to the horizon's actual purpose |

## See Also

| Component | Relationship |
|-----------|-------------|
| `commands/pa/reset.md` | Primary composite consumer for this template |
| `commands/pa/review.md` | Upstream producer of the review findings summarized here |
| `commands/pa/compile.md` | Upstream producer of the period synthesis |
| `commands/pa/agenda.md` | Upstream producer of the priority reset |
| `commands/pa/link.md` | Upstream producer of the new-connections section |
| `templates/pa/follow-up-report.md` | Embedded or summarized review-finding structure |
| `templates/pa/period-compilation.md` | Upstream synthesis structure for the compilation section |
| `skills/pa/review-and-journaling/SKILL.md` | Horizon logic and Fractal Journaling methodology |

## Usage by Commands

Commands reference this template when rendering a reset-style composite review.

The calling commands (`/pa reset` and `/pa weekly`) are responsible for:

- Choosing the correct horizon and concrete review window.
- Obtaining the review summary from sentinel output.
- Obtaining the period synthesis from `compile` or the nearest lower-layer artifact.
- Obtaining the priority reset from `agenda` or chief-of-staff output.
- Obtaining material new connections from `link` or weaver output.
- Rendering the final `Next Actions` so they match the selected horizon rather than defaulting to a flat task list.
`