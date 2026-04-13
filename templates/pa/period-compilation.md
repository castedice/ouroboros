---
title: Period Compilation
description: Period synthesis template for aggregating timestamp notes and captures into a bounded summary with themes, decisions, carry-forward items, and evergreen candidates
---

# Period Compilation Template

PA commands use this template when synthesizing captures from a bounded time period into a single compilation note.
`skills/pa/executive-assistance/references/compilation-policy.md` decides which window and sources enter the run, and this template decides how the selected material is rendered.
The scribe agent provides vault-native voice, and the calling command renders this template from collected source material.
This template creates a new vault note, so callers must apply trust-and-boundaries posture checks before any write.

## Rendering Rules

1. **Title**: Use the period range as the title base, following vault naming conventions.
   Format as `{start}--{end} compilation` or per vault `note_title_style`.
2. **Frontmatter**: Include `compiled_from`, `source_count`, `compiled`, plus vault-profile `frontmatter.common_fields`.
3. **Period Summary**: Write a 3-5 sentence overview of the period's captured content.
   Ground every claim in the compiled source notes.
4. **Temporal Buckets**: Group source material by `event_date_start` first.
   When `event_date_precision` is `week`, `month`, `quarter`, or `year`, render the whole bounded range in the section header instead of a single day.
   Fall back to `document_date` only when no event-date fields exist, and fall back again to legacy note-date grouping only when no temporal fields exist at all.
5. **Themes**: Within each temporal bucket, group durable units by recurring topic.
   Each theme gets a heading, synthesized content, and supporting source links.
   Themes should emerge from recurrence, decision density, or shared open loops, not arbitrary date slicing.
6. **Key Decisions**: Extract decisions from the compiled sources and keep source attribution.
7. **Carry-Forward**: List unresolved actions, open loops, and waiting-fors that remain relevant beyond this period.
   This is the actionable output of compilation.
8. **Evergreen Candidates**: List topics that appeared 3+ times across sources and may deserve durable note promotion via `/pa draft`.
   Include the topic, occurrence count, and supporting source notes.
9. **Source Index**: List every compiled note with title, path, event date when present, and document date when present.
10. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
---
compiled_from: {{YYYY-MM-DD to YYYY-MM-DD}}
source_count: {{count}}
compiled: {{YYYY-MM-DD}}
{{vault_profile_common_fields}}
---

# {{start}}--{{end}} compilation

> Period: {{start}} — {{end}} | Sources: {{source_count}} | Themes: {{theme_count}}
> Temporal Coverage: {{temporal_coverage}}

## Summary

{{3-5 sentence overview of the period's captured content}}

## {{bucket_header_1}}

### {{theme_1}}

{{synthesized content from captures related to this theme}}

Sources: [[{{capture_1}}]], [[{{capture_2}}]]

### {{theme_2}}

{{synthesized content}}

Sources: [[{{capture_3}}]]

## {{bucket_header_2}}

### {{theme_3}}

{{synthesized content}}

Sources: [[{{capture_4}}]]

## Key Decisions

- {{decision_1}} — from [[{{source_note}}]]
- {{decision_2}} — from [[{{source_note}}]]

## Carry-Forward

- [ ] {{unresolved_action}} — from [[{{source_note}}]]
- {{open_loop}} — from [[{{source_note}}]]

## Consumption Log

{{Rendered from `.pa/ingest-tracker.jsonl` entries within the compilation window. Lists external content consumed during the period with reflection summaries where available.}}

| # | Title | Source Type | Reflected | My Thoughts |
|---|-------|------------|-----------|-------------|
| 1 | {{source_title}} | {{source_type}} | {{yes/no}} | {{reflection_summary or "—"}} |

{{Omit this section entirely when no ingest-tracker entries exist for the compilation window.}}

## Evergreen Candidates

| Topic | Occurrences | Sources | Suggested Action |
|-------|-------------|---------|------------------|
| {{topic}} | {{count}} | [[{{note_1}}]], [[{{note_2}}]] | `/pa draft "{{topic}}"` |

## Source Index

| # | Title | Path | Event Date | Document Date |
|---|-------|------|------------|---------------|
| 1 | {{title}} | {{path}} | {{event_date_or_dash}} | {{document_date_or_dash}} |
| 2 | {{title}} | {{path}} | {{event_date_or_dash}} | {{document_date_or_dash}} |
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `compiled_from` | Compilation window from policy | Required — do not render without a range |
| `source_count` | Number of notes compiled | `0` if no sources, but the caller should usually no-op before rendering |
| `compiled` | Current date at render time | ISO 8601 date |
| `start` / `end` | Window boundaries from `compilation-policy.md` | From user `--from` / `--to` args |
| `theme_count` | Number of themes identified | `0` if no clear themes |
| `temporal_coverage` | Event-date coverage summary when event buckets exist, otherwise document-date coverage summary | "No explicit temporal fields; grouped by legacy note dates." |
| `bucket_header_*` | `event_date_start` / `event_date_end` range plus `event_date_precision` when present | `document_date` or legacy note-date label when event dates are absent |
| `vault_profile_common_fields` | `vault-profile.json` -> `frontmatter.common_fields` | Omit if not configured |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |
| `source_title` (Consumption Log) | `.pa/ingest-tracker.jsonl` entry `source_title` | "Untitled ingest" |
| `source_type` (Consumption Log) | `.pa/ingest-tracker.jsonl` entry `source_type` | "unknown" |
| `reflected` (Consumption Log) | Latest tracker entry for path: `reflected` field | "no" |
| `reflection_summary` (Consumption Log) | Latest tracker entry for path: `reflection_summary` | "—" when `reflected: false` |
| `event_date_or_dash` | Source note `event_date_start` / `event_date_end` rendered as a single day or bounded range | `—` |
| `document_date_or_dash` | Source note `document_date` | `—` |

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Key Decisions | No decisions found in compiled sources |
| Carry-Forward | No unresolved actions or open loops |
| Evergreen Candidates | No topic appeared 3+ times |
| Consumption Log | No `.pa/ingest-tracker.jsonl` entries exist for the compilation window |

When a section is omitted, do not include its heading.

## Usage by Commands

The calling command (`/pa compile`) is responsible for:

- Applying `compilation-policy.md` to determine the window and eligible sources
- Collecting and reading all eligible source notes
- Delegating to `scribe` for vault-native voice using existing compilation notes as exemplars
- Rendering this template from the collected material
- Updating the compile cursor in `derivation-state.json` after write

## Common Mistakes

| Mistake | Why It Fails | Prevention |
|---------|--------------|------------|
| Grouping everything by note-write date | Hides when the underlying event actually happened | Use `event_date_*` first and reserve `document_date` for artifact fallback |
| Using chronology as the theme structure | Produces a diary recap instead of synthesis | Group by recurring topic, decision cluster, or shared open loop |
| Treating tentative mentions as decisions | Invents certainty the sources do not contain | Reserve `Key Decisions` for settled language and attribute each one to a source |
| Letting `Carry-Forward` become a raw task dump | Duplicates inputs without synthesis | Include only unresolved items that matter beyond the current window |
| Promoting any repeated topic to evergreen | Quantity alone can overstate long-term value | Keep the 3+ occurrence threshold and treat the result as a candidate, not an automatic promotion |
| Omitting the source index | Breaks traceability and re-reading | Always include every compiled note in `Source Index` |
| Reusing prior compilations as evidence | Causes recursive synthesis and theme distortion | Compile from eligible raw notes and digests selected by policy, not from prior compilation outputs |

## Design Rationale

Why summary, themes, decisions, carry-forward, and evergreen candidates are separate: each section answers a different retrieval question, so later commands can reuse the note without re-parsing a single blended narrative.
Why temporal buckets lead the body: the compilation should reflect when the underlying event happened, not only when the note about it was written.
Why themes are the core section: compilation creates value by connecting multiple captures into durable topic clusters rather than merely restating the notes in order.
Why evergreen candidates require 3+ occurrences: one or two mentions may be noise, while three distinct appearances are the minimum signal that a topic is persisting across the period.
Why the source index is always retained: a compilation note is a synthesis layer, not a replacement for the underlying notes, so readers need a complete audit trail back to the source set.
Why carry-forward items stay unresolved when the evidence is unresolved: compilation should surface open loops, not manufacture closure to make the period look cleaner.

## Bias Mitigation

| Bias | Rendering Risk | Countermeasure |
|------|----------------|----------------|
| Recency bias | The latest captures dominate the summary and themes | Read the full window first and weight topics by occurrence across the whole period |
| Coherence bias | The renderer forces one tidy narrative and drops conflicting evidence | Preserve multiple themes and keep source attribution visible when notes pull in different directions |
| Closure bias | Open loops are rewritten as resolved outcomes | Require explicit resolution evidence before moving an item out of `Carry-Forward` |
| Quantity bias | A loud or repetitive topic gets treated as inherently evergreen | Mark it only as an evergreen candidate and route actual promotion through `/pa draft` |

## See Also

| Component | Relationship |
|-----------|-------------|
| `commands/pa/compile.md` | Primary consumer — applies policy, collects sources, and renders this template |
| `skills/pa/executive-assistance/references/compilation-policy.md` | Upstream policy — defines window selection, eligibility, and no-op rules |
| `agents/pa/scribe.md` | Synthesis agent — supplies the vault-native rendering plan |
| `skills/pa/writing/SKILL.md` | Voice adaptation methodology for compilation prose |
| `commands/pa/day.md` | Upstream producer — evening mode can provide compile-candidate handoff |
| `templates/pa/ingest-digest.md` | Upstream template — ingest notes can become eligible compilation sources |
| `commands/pa/draft.md` | Downstream consumer — receives evergreen candidates for durable promotion |
