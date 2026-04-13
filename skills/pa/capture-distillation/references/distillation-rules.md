# Distillation Rules — Extraction, Rendering, and Source Preservation

> Purpose: Reference for `capture-distillation` skill — detailed rules for extracting durable units, rendering vault-native output, and preserving source evidence. This reference is standalone and can be consulted without the parent skill. For the end-to-end distillation procedure, see `skills/pa/capture-distillation/SKILL.md`.

## Scope

This reference covers the extraction, rendering, and source preservation phases of capture distillation. Classification and routing are covered in `references/triage-taxonomy.md`.

## Durable Unit Extraction

Extract the smallest durable units that can survive outside the original capture. A durable unit is something another note can link to, compile later, or act on without rereading the entire raw dump.

### Extraction Rules

1. Identify explicit ideas, actions, decisions, references, and journal observations.
2. Split one segment into multiple units when it clearly contains different durable types.
3. Preserve uncertainty markers such as "maybe", "need to check", or "not sure" instead of converting them into claims.
4. Convert to a checkbox task only when the actor and action are both explicit in the input.
5. If a needed actor, action, date, or factual premise is missing, place the item under `Open loops` or `Questions` instead of inventing it.

### Per-Kind Extraction

| Kind | Extract | Do Not Extract |
|------|---------|----------------|
| `idea` | The insight and its framing, related concepts | Keywords stripped of context |
| `action` | Actor + action + optional deadline/context | Vague mentions of "we should..." without clear ownership |
| `decision` | The choice, scope, and stated rationale | Speculation that preceded the decision |
| `meeting` | Decisions, actions, open loops, attendance | Side conversations and filler |
| `reference` | Source metadata, key claims, attribution | Full content that should stay in the source |
| `journal` | Voice, chronology, felt meaning | Flattened neutral-prose rewrites |

### Fabrication Prohibition

Never invent dates, owners, or factual claims that do not appear in the source material. When the input says "next week" without a specific date, keep "next week" verbatim. When no owner is stated, do not assign one.

## Rendering Rules

### Section Structure

Use headings and bullets to separate `Ideas`, `Actions`, `Decisions`, `References`, `Open loops`, and `Questions` when those sections are present. For single-purpose captures, keep the render minimal instead of emitting empty sections.

### Frontmatter

Include only fields that are explicit in the input or already supported by vault-profile conventions. Do not invent tags, statuses, dates, owners, or aliases to make the note feel more complete.

### Content-Specific Rendering

| Content Type | Rendering Rule |
|-------------|----------------|
| Actions | Checkbox items must read like accountable next steps, not guesses |
| Decisions | Keep the stated rationale if the source provides it |
| Journal | Preserve first-person voice and chronology rather than flattening to neutral prose |
| Clips | Separate source claims from user interpretation; preserve attribution |

## Source Evidence Preservation

Every distilled result must retain enough source evidence for later verification.

### Preservation Rules

| Input Type | Preservation Method |
|-----------|-------------------|
| Transcript / long dump | Include a compact `Raw source` or `Source excerpt` section with key verbatim lines, speaker-tagged snippets, or bullet fragments |
| Short snippet | The rendered body itself may be sufficient evidence if the original wording is still visible |
| Clip with URL | Carry URL and quote markers into the rendered note |
| Ingested URL (fetched) | Preserve original URL in frontmatter `source_url`, page title in `source_title`, fetch date in `ingested`. Include a compact `Source excerpt` with key passages. Do not reproduce the full article |
| Ingested markdown file | Preserve original file path or name in `source_path`. Keep the author's structure and headings. Add `ingested` date to frontmatter |
| Pasted article excerpt | Preserve any attribution the user provided (URL, author, publication). If no attribution provided, note "Source: user-pasted text" in the provenance section |
| Ingested PDF | Preserve `source_path`, `extractor`, `page_count` in frontmatter. Anchor claims and excerpts with page references `(p. N)` when the extractor provides page markers. Keep the document's heading hierarchy in the excerpt |
| Ingested document (DOCX/PPTX/EPUB) | Preserve `source_path`, `extractor` in frontmatter. For PPTX, use slide numbers as section markers. For EPUB, preserve chapter structure. Keep the author's original headings |
| Ingested image/scan | Preserve `source_path` and `image_format` in frontmatter. Note that content is an AI-generated description, not OCR transcription. Include the image path as a reference for future re-reading |
| Ingested YouTube video | Preserve `source_url`, `video_id`, `channel`, `duration_human`, `publish_date`, `transcription_method` in frontmatter. The transcript extractor outputs plain text without timestamps. When the curator segments key claims, use approximate time anchors from video duration and position in transcript (e.g., "early", "midpoint", "near end") rather than precise `[MM:SS]` markers. For auto-subs, note reduced reliability. For mlx-whisper transcriptions, note that output is plain text without timing |

### What to Preserve

- Speaker labels from transcripts
- Quoted text and attribution
- URLs and import provenance
- Relative time expressions (keep verbatim unless an absolute date is explicitly given)
- Uncertainty language ("maybe", "not sure", "need to check")

### What Not to Do

- Do not rewrite verbatim source into polished prose for the evidence section
- Do not drop source attribution from clips or imported text
- Do not convert relative dates to absolute dates by guessing
- Do not strip provenance metadata (source_url, source_title, ingested date) from ingested content
- Do not reproduce full article content from URL fetch — extract claims and key passages only
