---
title: Project Dossier
description: Comprehensive dossier template for a goal, project, or entity — rendered from weaver graph analysis and librarian context pack
---

# Project Dossier Template

PA commands use this template when generating a comprehensive dossier centered on a goal, project, or entity. The weaver agent provides graph analysis (entities, relations, connections); the librarian agent provides retrieved content context. The calling command renders this template from both inputs.

This dossier is stored in `.pa/dossiers/` as assistant state — not in the user's visible vault. It is presented in conversation and persisted for reference by future commands.

## Rendering Rules

1. **Subject**: The subject line comes from the caller's goal or entity argument. Use it verbatim — do not rephrase or expand.
2. **Summary**: Synthesize a 3-5 sentence overview combining graph analysis (what entities and relations were found) with content analysis (what the vault says about the subject).
Ground every claim in graph evidence, note citations, or visible fact provenance.
3. **Entity Profile**: The central entity's canonical name, kind, aliases, dedicated note (if any), and confidence. From the weaver's entity data.
4. **Related Entities**: List entities connected to the central entity, grouped by relation type. Show confidence and evidence for each. Respect `link_density` for display limits.
5. **Related Facts**: If a librarian context pack includes memory facts, render them as the dossier's structured "what we know" section before the note excerpts.
Show `claim_key`, `predicate`, `object`, `confidence`, and `source_note` for each fact.
If temporal grounding is available, append it inline.
6. **Key Content**: If a librarian context pack is available, include the top retrieved documents with compressed excerpts. Identical to the focus-brief Key Notes section.
7. **Connections Map**: If the entity has 5+ relations, include a relationship map using the `templates/pa/relationship-map.md` structure. Otherwise, include an inline connection list.
8. **Timeline**: Temporal markers extracted from related notes — dates, deadlines, milestones, events. Sorted chronologically.
9. **Open Items**: Unresolved wikilinks, incomplete tasks, coverage gaps, and stale waiting-fors related to the entity.
10. **Sources**: Combined citation index from both weaver (entity/relation evidence) and librarian (retrieved documents).
11. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Output Format

```markdown
# {{subject}} — Dossier

> Generated: {{timestamp}} | Entities: {{entity_count}} | Relations: {{relation_count}} | Sources: {{source_count}} | Confidence: {{confidence}}

## Summary

{{synthesized_summary — 3-5 sentences grounding claims in entity evidence and content citations}}

## Entity Profile

- **Canonical name**: {{canonical_name}}
- **Kind**: {{kind}}
- **Aliases**: {{alias_list or "none"}}
- **Dedicated note**: [[{{canonical_note}}]] or "none"
- **First seen**: {{first_seen_date}}
- **Confidence**: {{entity_confidence}}

## Related Entities

### {{relation_type}} ({{count}})

| Entity | Confidence | Evidence |
|--------|------------|----------|
| [[{{entity}}]] | {{confidence}} | {{evidence_summary}} |

### {{relation_type}} ({{count}})
...

## Related Facts

- `{{claim_key}}` — `{{predicate}}` → `{{object}}` | confidence: {{fact_confidence}} | source: {{fact_source_note}}{{temporal_grounding_suffix}}

## Key Content

### [[{{note_title}}]] (relevance: {{score}})

{{compressed_excerpt}}

### [[{{note_title}}]] (relevance: {{score}})
...

## Connections Map

{{relationship_map_or_inline_list}}

## Timeline

| Date | Event | Source |
|------|-------|--------|
| {{date}} | {{event_description}} | [[{{source_note}}]] |

## Open Items

- [ ] {{unresolved_link_or_task}}
- [ ] {{coverage_gap}}

## Sources

| # | Title | Path | Type |
|---|-------|------|------|
| 1 | {{title}} | {{path}} | {{entity_evidence|retrieved_content}} |
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `subject` | Caller-provided goal or entity argument | Required — do not render without a subject |
| `timestamp` | Current date/time at render | ISO 8601 format |
| `entity_count` | Total entities in the dossier's scope | `1` (the central entity alone) |
| `relation_count` | Total relations involving the central entity | `0` if isolated |
| `source_count` | Combined sources from weaver and librarian | `0` if no evidence |
| `confidence` | Lower of entity confidence and content confidence | `low` if either source is weak |
| `canonical_name` | Weaver's canonical entity name | Subject argument verbatim |
| `kind` | Entity kind from weaver | `topic` as safe default |
| `alias_list` | Comma-separated aliases | "none" |
| `canonical_note` | Path to entity's dedicated note | "none" if no dedicated note exists |
| `entity_confidence` | Weaver's confidence for the central entity | `low` if evidence is thin |
| `claim_key` | Matching memory fact key from the librarian context pack | Omit Related Facts section if no memory facts exist |
| `predicate` | Fact predicate from the matching memory fact | Required when rendering a fact row |
| `object` | Fact object from the matching memory fact | Required when rendering a fact row |
| `fact_confidence` | Fact confidence from the matching memory fact | `low` if unavailable |
| `fact_source_note` | Fact provenance path from the matching memory fact | Show as a vault path or wikilink according to caller style |
| `temporal_grounding_suffix` | Optional ` | temporal: ...` text derived from the fact when available | Empty string |
| `compressed_excerpt` | Verbatim excerpt from librarian context pack | Omit Key Content section if no context pack |
| `relationship_map` | Rendered from `templates/pa/relationship-map.md` | Inline list if < 5 relations |
| `linking_style.prefer_wikilinks` | `vault-profile.json` → `linking_style.prefer_wikilinks` | `true` |

## Person Entity Presentation Rules

1. Persist dossier state with mask identifiers or canonical assistant-state identifiers in `.pa/dossiers/`.
2. Unmask person entities only in user-facing presentation when `mask_map` provides a stable display name.
3. Apply the same presentation rule to the central entity, related entities, sources, and timeline labels.
4. If a person has `trust_level: inner-circle`, compress the display to relationship type and broad area only, and omit private interaction details.
5. If no stable display name is available, keep the assistant-state identifier and note the unresolved display issue in `Open Items` rather than guessing.

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Related Facts | No memory facts are available |
| Key Content | No librarian context pack provided |
| Connections Map | Fewer than 3 relations |
| Timeline | No temporal markers found in related notes |
| Open Items | No unresolved links, tasks, or gaps found |
| Individual relation type tables | No relations of that type exist |

When a section is omitted, do not include its heading. The dossier should flow naturally without empty placeholder sections.

## Dossier Storage

Dossiers are persisted in `.pa/dossiers/` as JSON files:

```json
{
  "subject": "{{subject}}",
  "generated": "{{timestamp}}",
  "entity_count": {{entity_count}},
  "relation_count": {{relation_count}},
  "central_entity": "{{canonical_name}}",
  "confidence": "{{confidence}}",
  "rendered_markdown": "{{full rendered content}}"
}
```

The calling command is responsible for writing the dossier file. The weaver and template do not write files.

## Usage by Commands

Commands reference this template when rendering a project dossier.

The calling command (`/pa focus`) is responsible for:

- Providing both weaver analysis and librarian context pack as input
- Resolving the central entity from the goal description
- Rendering the librarian's memory facts as the dossier's structured fact section when available
- Applying `link_density` to limit displayed relations
- Writing the dossier to `.pa/dossiers/` after rendering
- Presenting the rendered dossier in conversation
