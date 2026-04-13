---
title: Follow-Up Report
description: This template provides structured sentinel review output for PA follow-up flows. It should be consulted when an agent needs to "render follow-up report", "format stale item findings", "present open loops delta", "summarize knowledge refresh candidates", "display values alignment neutrally", "surface contested facts", "surface serendipity findings", or "report contradictions and tensions".
---

# Follow-Up Report Template

PA commands use this template when rendering sentinel detection output for review-loop flows.
The sentinel agent provides the findings, and the calling command renders this template from the current review pack.

This template is read-only output.
It can be shown directly in the conversation or embedded inside a larger reset or weekly review artifact.
Writing it to the vault requires explicit user request and appropriate automation posture.

## Rendering Rules

1. **Title**: Use the selected horizon as the report label.
   Format the heading as `{{horizon_label}} Follow-Up Report`.
2. **Overview line**: Include `{{timestamp}}`, `{{horizon}}`, `{{finding_count}}`, and `{{confidence}}`.
   Add a short confidence note only when evidence coverage is partial.
3. **Stale Items**: Render only non-waiting open work items that cleared the 14-day threshold.
   Include item id, temporal context, latest source-doc activity date, staleness days, source docs, and a one-line evidence explanation.
   When `event_date` and `document_date` differ, render the temporal context as `committed on {event_date}, noted on {document_date}`.
4. **Stale Waiting-Fors**: Keep waiting-fors in their own section.
   Use the 7-day threshold and include `wait_for` or owner context when available.
   When `event_date` and `document_date` differ, render the temporal context as `committed on {event_date}, noted on {document_date}`.
5. **Contested Facts**: Render only unresolved fact contradictions returned by sentinel.
   Show both versions neutrally, include the evidence for each version, preserve when each version was observed, and leave the choice open for user resolution.
6. **Orphan Notes**: Render note path, latest modified date, and the structural reason the note is orphaned.
   Do not include notes excluded by the vault profile or review methodology.
7. **Unresolved Links**: Group unresolved wikilinks by source note and target.
   Show occurrence count when the same target appears multiple times in the same source note.
8. **Resurfacing Candidates**: List at most 3 notes ranked by sentinel scoring.
   Include staleness days, max similarity, best anchor, and the resurfacing reason string.
9. **Open Loops Delta**: Distinguish `new`, `persistent`, and `resolved`.
   Use stable ids where available and preserve source context.
10. **Knowledge Refresh Candidates**: Render only for `month+` horizons when sentinel returned decay candidates.
   Include note path, days stale, reference count, decay score, and topic signal.
11. **Values Alignment**: Render only for `year+` horizons when sentinel returned a `values_alignment` payload.
   Present area distribution and findings neutrally, using "work item share" language instead of moral judgment.
12. **Serendipity**: Render only for `month+` horizons when sentinel returned `1-3` random candidates.
   Include note title, age, link density, and a short preview.
13. **Contradictions & Tensions**: Render only for `month+` horizons when sentinel returned contradictions.
   Present both sides neutrally and keep severity at `info` or `warning`.
14. **Summary**: End with a compact review-health summary that states the highest-signal drift, healthy areas, and any material evidence gaps.
15. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
# {{horizon_label}} Follow-Up Report

> Generated: {{timestamp}} | Horizon: {{horizon}} | Findings: {{finding_count}} | Confidence: {{confidence}}

## Stale Items

| Item | Temporal Context | Latest Source Activity | Days Stale | Source Docs | Evidence |
|------|------------------|------------------------|------------|-------------|----------|
| {{title}} (`{{id}}`) | {{temporal_context}} | {{last_modified}} | {{staleness_days}} | [[{{source_1}}]], [[{{source_2}}]] | {{why_flagged}} |

## Stale Waiting-Fors

| Item | Waiting On | Temporal Context | Latest Source Activity | Days Stale | Source Docs | Evidence |
|------|------------|------------------|------------------------|------------|-------------|----------|
| {{title}} (`{{id}}`) | {{wait_for}} | {{temporal_context}} | {{last_modified}} | {{staleness_days}} | [[{{source_1}}]] | {{why_flagged}} |

## Contested Facts

| Subject | Predicate | Version A | Version B | Temporal Context | Evidence |
|---------|-----------|-----------|-----------|------------------|----------|
| {{subject}} | {{predicate}} | {{fact_version_a}} | {{fact_version_b}} | {{observed_context}} | A: [[{{fact_source_a}}]]; B: [[{{fact_source_b}}]] |

## Orphan Notes

| Note | Latest Modified | Evidence |
|------|-----------------|----------|
| [[{{note_path}}]] | {{last_modified}} | 0 inbound wikilinks and no MOC or hub reference found |

## Unresolved Links

| Source Note | Unresolved Target | Occurrences | Evidence |
|-------------|-------------------|-------------|----------|
| [[{{source_note}}]] | `[[{{broken_target}}]]` | {{count}} | No current note path or normalized title resolves the target |

## Resurfacing Candidates

| Note | Days Stale | Max Similarity | Anchor | Reason |
|------|------------|----------------|--------|--------|
| [[{{note_path}}]] | {{staleness_days}} | {{max_similarity}} | {{anchor}} | {{reason}} |

## Open Loops Delta

### New

| Item | Since | Source | Note |
|------|-------|--------|------|
| {{loop_title}} (`{{item_id}}`) | {{since}} | {{source}} | {{delta_note}} |

### Persistent

| Item | Since | Source | Note |
|------|-------|--------|------|
| {{loop_title}} (`{{item_id}}`) | {{since}} | {{source}} | {{delta_note}} |

### Resolved

| Item | Since | Prior Source | Note |
|------|-------|--------------|------|
| {{loop_title}} (`{{item_id}}`) | {{since}} | {{source}} | {{delta_note}} |

## Knowledge Refresh Candidates

| Note | Days Stale | References | Decay Score | Topic |
|------|-----------|------------|-------------|-------|
| {{note_path}} | {{days}} | {{ref_count}} | {{score}} | {{tag_or_folder}} |

## Values Alignment

**Review Period**: {{start_date}} — {{end_date}}
**Work Items Analyzed**: {{count}}

### Area Distribution

| Area | Work Items | Share | Aligned Values |
|------|-----------|-------|---------------|
| {{area}} | {{count}} | {{pct}}% | {{value_list_or_dash}} |

### Findings

{If misalignment detected:}
- **{{value}}**: aligned area `{{area}}` has {{pct}}% share ({{count}} items). {{neutral_observation}}

{If all aligned:}
Work distribution appears consistent with stated values.

{If insufficient data:}
Insufficient data for values alignment analysis ({{reason}}).

## Serendipity

{1-3 random notes from the vault's past}

| Note | Days Old | Links | Preview |
|------|---------|-------|---------|
| [[{{title}}]] | {{days}} | {{link_count}} | {{first_sentences}} |

## Contradictions & Tensions

| Type | Entities | Evidence | Severity |
|------|----------|----------|----------|
| {{conflict_type}} | {{entities}} | {{description}} | {{severity}} |

## Summary

- **Total findings**: {{finding_count}}
- **Highest-signal drift**: {{headline_finding_or_healthy_note}}
- **Healthy areas**: {{stable_or_empty_categories}}
- **Detection note**: {{confidence_note_or_qmd_limitation}}
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `horizon_label` | Title-cased label derived from the selected horizon | Title-case `horizon` verbatim |
| `timestamp` | Current date and time at render | ISO 8601 format |
| `horizon` | Caller-selected review horizon | `week` |
| `finding_count` | Total surfaced rows across all included finding sections | `0` |
| `confidence` | Sentinel confidence based on input completeness and evidence quality | `low` when major evidence is missing |
| `title` | Work item title from sentinel output | Required for stale-item rows |
| `id` | Stable work item id from `work.jsonl` | Omit id suffix if unavailable |
| `temporal_context` | Sentinel-supplied date context using `event_date` when available and `document_date` as artifact fallback | "Noted on {{document_date}} (document_date fallback)." |
| `subject` | Canonical subject label for a contested fact group | Required for contested-fact rows |
| `predicate` | Shared predicate for the contested fact group | Required for contested-fact rows |
| `fact_version_a` | First contested fact version, including object and confidence when available | Required for contested-fact rows |
| `fact_version_b` | Second contested fact version, including object and confidence when available | Required for contested-fact rows |
| `observed_context` | Short sentence describing when each fact version was observed using `event_date` first and `document_date` fallback | "A observed on {{document_date_a}}; B observed on {{document_date_b}}." |
| `fact_source_a` | Source note path for contested fact version A | `unknown` |
| `fact_source_b` | Source note path for contested fact version B | `unknown` |
| `event_date` | Event-date anchor that drove the stale assessment when available | Omit from rendered context when missing |
| `document_date` | Artifact date from the source note or packet when available | Omit from rendered context when missing |
| `temporal_source` | Which temporal field drove the stale assessment, such as `event_date` or `document_date` | `document_date` |
| `temporal_gap_note` | Optional note when `event_date` and `document_date` differ by more than 7 days | Omit when no significant gap exists |
| `last_modified` | Latest source-doc modification date from QMD or caller-supplied activity metadata | `unknown` |
| `staleness_days` | Days between `timestamp` and the temporal anchor chosen by `temporal_source` | `unknown` |
| `wait_for` | `wait_for` or owner field from the work item | `unknown` |
| `note_path` | Vault-relative note path from sentinel output | Required for note rows |
| `source_note` | Source note path containing the unresolved wikilink | Required for unresolved-link rows |
| `broken_target` | Wikilink target that does not resolve in the current vault index | Required for unresolved-link rows |
| `count` | Repeated occurrence count for a target inside one source note | `1` |
| `max_similarity` | Highest QMD similarity score for the resurfacing candidate | Omit resurfacing section if unavailable |
| `anchor` | Best-matching active entity or work anchor | `unknown` |
| `reason` | Sentinel resurfacing explanation string | "Eligible stale note with current relevance." |
| `loop_title` | Human-readable loop label from the source overlay or note anchor | Use `item_id` when no better label exists |
| `item_id` | Stable identifier from `work.jsonl` or note anchor | Required for delta rows |
| `since` | When the loop was first opened or first observed | `unknown` |
| `source` | Source overlay or note path for the loop | `unknown` |
| `delta_note` | Short explanation such as `first seen this review`, `still open`, or `absent from current snapshot` | Required for delta rows |
| `days` | Days since last modification for a knowledge decay candidate | `unknown` |
| `ref_count` | Inbound wikilinks plus evidence references for a knowledge decay candidate | `0` |
| `score` | Knowledge decay score from sentinel output | `unknown` |
| `tag_or_folder` | Topic hint from tags, title classification, or folder signal | `unknown` |
| `start_date` | Start date of the values-alignment review window | Horizon-derived review start |
| `end_date` | End date of the values-alignment review window | Current date |
| `area` | Area label from the values-alignment distribution | Required for values-alignment rows |
| `pct` | Percentage share for the area or aligned finding | `0` |
| `value_list_or_dash` | Comma-separated aligned values for the area | `—` |
| `value` | Stated value referenced by a values-alignment finding | Required for values-alignment findings |
| `neutral_observation` | Sentinel-supplied neutral wording for the values-alignment finding | "Low work item share in the aligned area." |
| `reason` | Reason values alignment was skipped or marked insufficient | `unknown` |
| `link_count` | Inbound wikilink count for a serendipity note | `0` |
| `first_sentences` | First 2-3 sentences preview from the selected note | `Preview unavailable.` |
| `conflict_type` | Contradiction type label from sentinel output | Required for contradiction rows |
| `entities` | Compact entity pair or set involved in the contradiction | `unknown` |
| `description` | Neutral evidence summary for the contradiction | Required for contradiction rows |
| `severity` | Contradiction severity from sentinel output | `info` |
| `headline_finding_or_healthy_note` | Caller-synthesized headline from the most important finding or the healthy-vault outcome | "No mechanical drift detected." |
| `stable_or_empty_categories` | Categories with zero findings or clearly healthy signals | "No healthy-area note supplied." |
| `confidence_note_or_qmd_limitation` | Short note about missing inputs, QMD availability, or evidence quality | Omit when confidence is high and no limitation matters |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Stale Items | No non-waiting items cleared the 14-day threshold |
| Stale Waiting-Fors | No waiting-for items cleared the 7-day threshold |
| Contested Facts | Sentinel returned no unresolved contested facts older than the 14-day review threshold |
| Orphan Notes | No valid orphan notes were found after profile-aware exclusions |
| Unresolved Links | No unresolved wikilinks were found |
| Resurfacing Candidates | No candidate cleared the staleness, similarity, and suppression rules, or QMD was unavailable |
| Open Loops Delta | Both the current loop set and the prior snapshot are unavailable |
| Knowledge Refresh Candidates | The horizon is below `month`, or no knowledge decay candidate cleared the candidacy and suppression rules |
| Values Alignment | The horizon is below `year`, or sentinel returned `values_alignment: null` |
| Serendipity | The horizon is below `month`, or sentinel returned no `serendipity_candidates[]` |
| Contradictions & Tensions | The horizon is below `month`, or sentinel returned no `contradictions[]` |
| Individual `New`, `Persistent`, or `Resolved` subsections | That delta bucket is empty |
| Summary | Never omit |

When all finding sections are omitted, render only the header and `Summary`.
The summary must then explicitly say that no actionable mechanical drift was detected.

## Common Mistakes

| Mistake | Why It Fails | Prevention |
|---------|--------------|------------|
| Mixing waiting-fors into `Stale Items` | Hides the stricter 7-day dependency threshold | Keep waiting-fors in their own section |
| Collapsing contested facts into a generic contradiction note | Hides the exact fact versions the user needs to resolve | Render a dedicated `Contested Facts` section with both versions and evidence |
| Collapsing event time into note-write time | Makes stale findings look newer or older than the real commitment | Render `event_date` and `document_date` distinctly when both exist |
| Omitting source-doc dates | Makes the staleness claim unverifiable | Always include the latest source activity date or state that it is unknown |
| Treating every zero-backlink note as an orphan | Generates false positives for journals, inbox notes, and intentional islands | Apply vault-profile and review-methodology exclusions first |
| Listing unresolved links without source context | Breaks traceability and follow-up usefulness | Group unresolved targets by source note and occurrence count |
| Surfacing more than 3 resurfacing candidates | Turns memory refresh into inbox noise | Respect the hard cap of 3 |
| Flattening loop delta into one list | Loses the distinction between new drift and recurring drift | Keep `new`, `persistent`, and `resolved` separate |

## Design Rationale

Why stale waiting-fors are separate from general stale items: external dependencies age differently from self-owned work and need a stricter threshold.
Why stale rows now include temporal context: a commitment can be written down after it was actually made, so event time and note time must stay distinguishable.
Why the report is category-based instead of chronological: review loops exist to detect mechanical drift types, not to retell the week.
Why open-loop delta has its own section: the review is more useful when it distinguishes what is newly slipping from what has been slipping for a while.
Why resurfacing stays capped and ranked: forgotten context helps only when it is selective.
Why the summary stays at the end: the reader should see the evidence categories first and then read the compressed health judgment.

## Bias Mitigation

| Bias | Rendering Risk | Countermeasure |
|------|----------------|----------------|
| Recency bias | Recently touched work dominates the report while long-stale work disappears | Use explicit 14-day and 7-day thresholds across the full current state |
| Cleanup bias | The renderer pushes findings toward closure language instead of detection language | Keep the report detection-only and leave action decisions to the caller |
| False precision bias | Unknown dates or weak evidence are rendered as exact claims | Mark unknown fields explicitly and lower confidence when evidence is partial |
| Nagging bias | The same resurfacing note appears every review | Respect resurfacing suppression from `review-state.json` |
| Alarm bias | A handful of low-signal findings makes the vault sound unhealthy | Use the summary to distinguish isolated findings from broad trust decay |

## Validation Checklist

- [ ] Only sections supported by the selected horizon and returned sentinel payload are rendered.
- [ ] `Stale Items` excludes waiting-fors, uses the 14-day threshold, and renders event-date vs document-date context when provided.
- [ ] `Stale Waiting-Fors` uses the 7-day threshold, includes `wait_for` or owner context when available, and preserves temporal context when provided.
- [ ] `Contested Facts` renders both fact versions, their evidence, and per-version temporal context without choosing a winner.
- [ ] `Resurfacing Candidates` stays capped at 3 and includes similarity, anchor, and reason fields.
- [ ] `Open Loops Delta` preserves separate `New`, `Persistent`, and `Resolved` buckets with stable identifiers.
- [ ] `Values Alignment`, `Serendipity`, and `Contradictions & Tensions` render only at allowed horizons and keep neutral wording.
- [ ] The summary highlights the highest-signal finding, healthy areas, and evidence gaps without adding unsupported claims.

## See Also

| Component | Relationship |
|-----------|-------------|
| `agents/pa/sentinel.md` | Primary producer of the findings rendered by this template |
| `commands/pa/review.md` | Primary consumer for standalone review output |
| `commands/pa/reset.md` | Composite consumer that can embed this report inside a larger reset |
| `templates/pa/weekly-review.md` | Downstream composite template that can incorporate this report |
| `skills/pa/review-and-journaling/SKILL.md` | Parent methodology for thresholds, horizons, and delta semantics |
| `skills/pa/review-and-journaling/references/values-alignment.md` | Year+ alignment methodology for neutral behavior-vs-values reporting |
| `skills/pa/review-and-journaling/references/serendipity-rules.md` | Month+ serendipity and contradiction selection rules |

## Usage by Commands

Commands reference this template when rendering a sentinel detection report.

The calling commands (`/pa review`, `/pa reset`, and `/pa weekly`) are responsible for:

- Providing sentinel findings plus resolved horizon metadata.
- Preserving sentinel evidence fields without rewriting them into unsupported claims.
- Applying vault-profile link style at render time.
- Embedding the report into a larger composite output when the caller is not producing a standalone review.
- Deciding whether the final output remains read-only or is persisted as part of a larger artifact.
