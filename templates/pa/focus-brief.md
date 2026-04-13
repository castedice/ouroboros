---
title: Focus Brief
description: Structured dossier template for a topic, project, or person — rendered from a librarian context pack
---

# Focus Brief Template

PA commands use this template when generating a focused briefing on a specific subject. The librarian agent provides the context pack; the calling command renders this template from the retrieved content.

This template is read-only output — it is presented in the conversation, not written to the vault. Writing a brief to the vault requires explicit user request and appropriate automation posture.

## Rendering Rules

1. **Subject**: The subject line comes from the caller's topic argument. Use it verbatim — do not rephrase or expand.
2. **Summary**: Synthesize a 2-4 sentence overview from the retrieved documents and matching memory facts.
Ground every claim in the citation index or visible fact provenance.
If confidence is `low` or `none`, state the limitation explicitly.
3. **Known Facts**: Render matching memory facts before the note excerpts.
Show `claim_key`, `predicate`, `object`, `confidence`, and `source_note` for each fact.
If a fact includes temporal grounding, append it inline.
4. **Key Notes**: List each retrieved document with its title, path, relevance score, and the compressed excerpt from the context pack. Preserve the librarian's excerpt verbatim — do not re-compress or rewrite.
5. **Connections**: Identify cross-references between the retrieved notes — shared wikilinks, common tags, or thematic overlap. If no connections are apparent, state "No cross-references detected."
6. **Open Questions**: List aspects of the subject not covered by the retrieved documents. Derive these from the context pack's coverage gaps. If coverage is complete, state "No significant gaps identified."
7. **Sources**: Reproduce the librarian's citation index exactly. Do not add sources that were not retrieved.
8. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
# {{subject}} — Brief

> Generated: {{timestamp}} | Sources: {{source_count}} | Confidence: {{confidence}}

## Summary

{{synthesized_summary — 2-4 sentences grounded in citations}}

## Known Facts

- `{{claim_key}}` — `{{predicate}}` → `{{object}}` | confidence: {{fact_confidence}} | source: {{source_note}}{{temporal_grounding_suffix}}

## Key Notes

### [[{{note_1_title}}]] (relevance: {{score}})

{{compressed_excerpt_1}}

### [[{{note_2_title}}]] (relevance: {{score}})

{{compressed_excerpt_2}}

...

## Connections

{{cross_references_between_notes}}

## Open Questions

{{coverage_gaps_from_context_pack}}

## Sources

| # | Title | Path |
|---|-------|------|
| 1 | {{title}} | {{path}} |
| 2 | {{title}} | {{path}} |
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `subject` | Caller-provided topic argument | Required — do not render without a subject |
| `timestamp` | Current date/time at render | ISO 8601 format |
| `source_count` | Number of documents in citation index | `0` if no results |
| `confidence` | Librarian's coverage assessment confidence | `none` if no results |
| `synthesized_summary` | Caller synthesizes from context pack excerpts | "Insufficient vault content for a summary." |
| `claim_key` | Matching memory fact key from the librarian context pack | Omit Known Facts section if no memory facts exist |
| `predicate` | Fact predicate from the matching memory fact | Required when rendering a fact row |
| `object` | Fact object from the matching memory fact | Required when rendering a fact row |
| `fact_confidence` | Fact confidence from the matching memory fact | `low` if unavailable |
| `source_note` | Fact provenance path from the matching memory fact | Show as a vault path or wikilink according to caller style |
| `temporal_grounding_suffix` | Optional ` | temporal: ...` text derived from the fact when available | Empty string |
| `note_N_title` | Document title from citation index | Filename without extension |
| `score` | Relevance score from context pack | Omit if not provided |
| `compressed_excerpt_N` | Verbatim excerpt from librarian's context pack | "No excerpt available." |
| `cross_references` | Wikilinks or tags shared between retrieved notes | "No cross-references detected." |
| `coverage_gaps` | Gaps field from context pack coverage assessment | "No significant gaps identified." |
| `linking_style.prefer_wikilinks` | `vault-profile.json` → `linking_style.prefer_wikilinks` | `true` |

## Usage by Commands

Commands reference this template when rendering a focus brief.

The calling command (`/pa brief`) is responsible for:

- Providing the librarian's full context pack as input
- Synthesizing the summary section from the context pack excerpts (for `brief`, this is a lightweight synthesis — structured, not conversational)
- Reproducing the context pack's memory facts in the `Known Facts` section before the note excerpts
- Identifying connections by scanning excerpts for shared `[[wikilinks]]` and tags
- Deriving open questions from the context pack's coverage gaps
- Reproducing the citation index without modification
