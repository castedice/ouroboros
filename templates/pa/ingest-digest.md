---
title: Ingest Digest
description: Source-aware digest template for external content imported into the vault — preserves provenance, extracts claims, tasks, and related notes
---

# Ingest Digest Template

PA commands use this template when creating a vault note from external content.
The curator agent triages the source packet, and the calling command renders this template from that grounded result.
This template creates a new vault note, so callers must apply trust-and-boundaries posture checks before any write.

## Rendering Rules

1. **Title**: Derive from the source title or content.
   Use vault-profile `naming_rules.note_title_style`.
   Never invent a title that overstates or misrepresents the source.
2. **Frontmatter**: Include provenance fields (`source_url` or `source_path`, `source_title`, `source_type`, `ingested`) plus `document_date`, `event_date_start`, and `event_date_end` when available, plus vault-profile `frontmatter.common_fields`.
   Do not invent tags or metadata not supported by the source or vault conventions.
3. **Summary**: Write a 2-4 sentence overview grounded only in the source material.
   Do not supplement with model knowledge.
4. **Key Claims**: List the source's main assertions or findings as bullets.
   Each claim must be a verbatim extraction or faithful paraphrase with a section, timestamp, or speaker anchor when available.
5. **Tasks**: Add checkbox items only when the source contains explicit action items with clear ownership or source-assigned responsibility.
   Do not manufacture tasks from implications, recommendations, or interesting ideas.
6. **Related Notes**: Link only existing vault notes that connect to this source by QMD retrieval evidence or strong structural overlap.
   Respect `create_unresolved_breadcrumbs` and do not link nonexistent notes when it is `false`.
7. **Source Excerpt**: Keep a compact verbatim anchor, usually 100-300 words or an equivalently short speaker exchange.
   For transcripts, preserve speaker labels.
8. **Links**: Use `[[wikilinks]]` when `{{linking_style.prefer_wikilinks}}` is `true`, otherwise markdown links.

## Rendering Path Classification

Classify each render along all four dimensions before filling the template.
No single dimension determines the whole note shape.

| Dimension | Values | Render Effect |
|-----------|--------|---------------|
| `source_shape` | `url`, `file`, `paste`, `transcript`, `pdf`, `document`, `image`, `youtube`, `bookmark` | Chooses provenance field and excerpt style |
| `provenance_strength` | `strong`, `partial`, `minimal` | Strong provenance supports firmer summary phrasing, while minimal provenance requires conservative titles, claims, and attribution |
| `action_density` | `none`, `mixed`, `high` | Controls whether `Tasks` is omitted, short, or a primary section |
| `vault_overlap` | `none`, `some`, `high` | Controls how dense `Related Notes` should be and how cautious deduplication must remain |

## Output Format

```markdown
---
{{source_url_line}}
{{source_path_line}}
source_title: {{source_title}}
source_type: {{url|file|paste|transcript|youtube}}
{{source_format_line}}
{{extractor_line}}
ingested: {{YYYY-MM-DD}}
{{document_date_line}}
{{event_date_start_line}}
{{event_date_end_line}}
{{format_specific_frontmatter}}
{{vault_profile_common_fields}}
---

# {{title}}

> Ingested: {{date}} | Source: {{source_type}} | Confidence: {{confidence}}

## Summary

{{2-4 sentence overview grounded in source material}}

## Key Claims

- {{claim_1}}
- {{claim_2}}
- {{claim_3}}

## Tasks

- [ ] {{task_with_explicit_owner — only if present in source}}

## Related Notes

- [[{{related_note_1}}]] — {{connection reason}}
- [[{{related_note_2}}]] — {{connection reason}}

## Source Excerpt

> {{verbatim passage from source — 100-300 words}}

## My Thoughts

{{User's reflection response — added by ingest command Phase 6 after user answers the reflection prompt. This section is omitted in the initial render and appended via Edit when the user responds.}}

---
Source: {{source_url or source_path or "user-pasted text"}}
```

## Field Resolution

| Placeholder | Source | Fallback |
|-------------|--------|----------|
| `source_url_line` | `source_url` from user input or fetch result when `source_type` is `url` | Omit for non-URL sources |
| `source_path_line` | `source_path` from imported file when `source_type` is `file` | Omit for non-file sources |
| `source_title` | Page title from fetch, filename from import, or first heading | User-provided title or "Untitled ingest" |
| `source_type` | Detected from input: `url`, `file`, `paste`, `transcript`, `youtube` | `paste` as safe default |
| `source_format_line` | `source_format: pdf\|docx\|pptx\|epub\|image\|youtube` when `source_format` is set | Omit when no format detected |
| `extractor_line` | `extractor: markitdown\|pandoc\|pdftotext\|yt-dlp\|mlx-whisper\|claude-vision` | Omit when extractor is unknown |
| `document_date_line` | `document_date` from the source-packet temporal fields, or a normalized publish date captured during packet assembly | Omit when no artifact date is grounded |
| `event_date_start_line` | `event_date_start` from the source-packet temporal fields | Omit when no event start date is grounded |
| `event_date_end_line` | `event_date_end` from the source-packet temporal fields | Omit when no event end date is grounded |
| `format_specific_frontmatter` | For `youtube`: `video_id`, `channel`, `duration_human`, `publish_date`, `transcription_method`. For `pdf`: `page_count`. For `image`: `image_format` | Omit fields not available in source-packet metadata |
| `raindrop_id_line` | `raindrop_id: {id}` mapped from connector metadata `bookmark_id` when `source_shape` is `bookmark` and `metadata.connector` is `raindrop` | Omit for non-bookmark sources |
| `raindrop_tags_line` | `raindrop_tags: [tag1, tag2]` from connector metadata | Omit when no service tags |
| `raindrop_collection_line` | `raindrop_collection: {name}` from connector metadata | Omit when no collection |
| `ingested` | Current date at render time | ISO 8601 date |
| `title` | Derived from `source_title` using vault naming conventions | Source title verbatim |
| `confidence` | Curator's triage confidence | `medium` as default |
| `vault_profile_common_fields` | Fields from `vault-profile.json` -> `frontmatter.common_fields` | Omit if not configured |
| `linking_style.prefer_wikilinks` | `vault-profile.json` -> `linking_style.prefer_wikilinks` | `true` |

## Section Omission Rules

| Section | Omit When |
|---------|-----------|
| Highlights | No highlights in the connector queue entry |
| Tasks | No explicit action items in source material |
| Related Notes | No QMD matches found or overlap is too weak to justify linking |
| Source Excerpt | Source is under 200 words and Summary + Key Claims already preserve the needed evidence |
| My Thoughts | Always omitted in initial render. Added by the ingest command via Edit when the user provides a reflection response |

When a section is omitted, do not include its heading.

## Source Type Variations

| Source Type | Template Adjustments |
|-------------|---------------------|
| `url` | Emit `source_url` in frontmatter and footer. Emit `document_date` and `event_date_*` when the packet grounded them. Use fetched content for the excerpt |
| `file` | Emit `source_path` in frontmatter and footer. Emit `document_date` and `event_date_*` when the packet grounded them. Preserve the imported file's structure where possible |
| `paste` | No URL. Build the excerpt from pasted text. Emit `document_date` and `event_date_*` when the packet grounded them. Use "user-pasted text" for attribution when no other provenance is given |
| `transcript` | Preserve speaker labels in the excerpt. Claims, decisions, and tasks should keep speaker attribution when material. Emit `event_date_*` when the transcript provides enough grounding |
| `pdf` | Emit `source_path`, `extractor`, and `document_date` in frontmatter. Preserve page references as `(p. N)` anchors in claims and excerpt. Include `page_count` in frontmatter when available |
| `document` | Emit `source_path`, `extractor`, and `document_date` in frontmatter. Preserve the document's original heading structure in the excerpt. For PPTX, preserve slide numbers as section markers |
| `image` | Emit `source_path` and `document_date` in frontmatter. The excerpt is the Claude vision description. Include `image_format` in frontmatter. Note that content is AI-described, not OCR-transcribed |
| `youtube` | Emit `source_url`, `document_date`, `video_id`, `channel`, `duration_human`, `publish_date`, and `transcription_method` in frontmatter. Excerpt uses position-anchored key segments (e.g., `### Introduction`, `### Main Argument`, `### Conclusion`) since the transcript extractor outputs plain text without precise timestamps. Include `transcription_method` (`auto-subs` or `mlx-whisper`) in frontmatter |
| `bookmark` | Emit `source_url`, `document_date`, and any grounded `event_date_*` fields in frontmatter and footer. Render `## Highlights` section before `## Source Excerpt` with Raindrop highlights as quote blocks. If a highlight has a user note, render as `> "highlight text"\n> — _user note_`. Include `raindrop_id`, `raindrop_tags`, `raindrop_collection` in frontmatter. Do not merge service tags into vault `tags` field |

## Usage by Commands

The calling command (`/pa ingest`) is responsible for:

- Normalizing input into a source packet before curator triage
- Carrying source-packet temporal fields into frontmatter when the source supports grounding
- Running QMD deduplication before rendering
- Applying posture checks before any vault write
- Supplying the curator's triage result as template input
- Determining placement from vault-profile `placement_rules`

## Common Mistakes

| Mistake | Why It Fails | Prevention |
|---------|--------------|------------|
| Inventing a cleaner title than the source supports | Misstates provenance and weakens deduplication | Derive titles from source wording or neutral content description |
| Turning recommendations or implications into tasks | Creates false commitments | Add `Tasks` only for explicit action items with clear ownership or source-assigned responsibility |
| Over-linking familiar vault notes | Creates graph noise and weak breadcrumbs | Add `Related Notes` only when retrieval evidence or strong structural overlap exists |
| Letting the summary absorb interpretation | Hides what the source actually said | Keep `Summary` source-grounded and move unsupported interpretation out of the note |
| Copying too much of the original source | Bloats the note and over-reproduces the source | Keep `Source Excerpt` compact and choose the densest evidence |
| Dropping speaker labels from transcript evidence | Loses attribution and action ownership | Preserve speaker names in claims and excerpts when they affect meaning |

## Design Rationale

Why summary and key claims are separate: the summary gives fast orientation, while key claims preserve atomic points for later retrieval, linking, and compilation.
Why provenance appears in frontmatter and again in the footer: frontmatter supports automation and filtering, while the footer keeps the source visible when the note is quoted, embedded, or viewed without metadata.
Why tasks require explicit ownership: ingest is an evidence-preservation step, not an idea-to-task converter, so implied recommendations stay as claims instead of becoming commitments.
Why the excerpt is compact instead of exhaustive: the note needs audit anchors without reproducing the full source or overwhelming later compilation passes.
Why related notes are optional: forcing links in a sparse vault creates graph noise and unresolved breadcrumbs without adding real retrieval value.

## Bias Mitigation

| Bias | Rendering Risk | Countermeasure |
|------|----------------|----------------|
| Authority bias | Polished external sources get restated as unquestioned truth | Keep claims attributed to the source and preserve a verbatim excerpt anchor |
| Automation bias | The model turns implications into tasks or commitments | Require explicit task language and clear ownership before rendering `Tasks` |
| Familiarity bias | Only already-prominent vault notes get linked | Base `Related Notes` on retrieval evidence or structural overlap, and allow omission when evidence is weak |
| Compression bias | Summaries smooth over uncertainty, disagreement, or hedging | Preserve qualifiers, quoted wording, and speaker labels when they materially affect meaning |

## See Also

| Component | Relationship |
|-----------|-------------|
| `commands/pa/ingest.md` | Primary consumer — normalizes the source packet, runs deduplication, and renders this template |
| `agents/pa/curator.md` | Upstream triage — classifies source-heavy input and produces digest-ready durable units |
| `skills/pa/capture-distillation/SKILL.md` | Extraction methodology for source packets routed to `ingest-digest` |
| `skills/pa/capture-distillation/references/triage-taxonomy.md` | Routing rules that decide when external content belongs in this template |
| `skills/pa/capture-distillation/references/distillation-rules.md` | Provenance, claim, task, and excerpt rules that shape this note |
| `skills/pa/content-pipeline/SKILL.md` | Source-packet contract and extractor selection for document/YouTube/image formats |
| `skills/pa/trust-and-boundaries/SKILL.md` | Posture and write-safety guardrails for creating the digest note |
| `commands/pa/compile.md` | Downstream consumer — ingest digests become eligible compilation sources |
| `templates/pa/period-compilation.md` | Downstream template — period compilation aggregates multiple ingest digests and captures |
