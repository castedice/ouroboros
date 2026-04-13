---
name: content-pipeline
description: This skill provides content pipeline methodology for external content ingestion. It should be activated when an agent needs to "extract text from PDF or document", "detect document format", "select extraction tool", "normalize YouTube transcript", "handle captionless video transcription", "build source-packet from external content", "choose extractor for a file type", or "check content pipeline tool availability".
summary: Converts external sources into attributed source packets through format detection, extractor fallback, and graceful degradation.
version: 1
tags: [pa, ingest, extraction, source-packets, provenance]
preamble_tier: 1
---

# Content Pipeline

## Core Rule

**"Extract faithfully, attribute precisely, and degrade gracefully."**

Every external source becomes a uniform source-packet before it enters PA's ingest flow.
The pipeline exists to turn format-specific extraction into format-agnostic triage.
When a strong extractor is unavailable, the pipeline falls back to the next safest option and preserves provenance instead of blocking the ingest.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Guessing the format from content instead of stable signals | Detection | Prefer connector flags, URL patterns, and file extensions first |
| Letting extractor choice drift by habit | Selection | Follow the fallback chain for the detected format every time |
| Losing source attribution during cleanup | Assembly | Preserve source URL, path, title, fetch date, and extractor in the packet |
| Treating extraction failure as ingest failure | Degradation | Emit a stub note with metadata when content extraction is unavailable |
| Using image OCR assumptions for Claude vision | Extraction | Treat image reading as vision description unless the output clearly behaves like transcription |
| Forgetting bookmark connectors are still URL sources | Detection | Mark connector items as `source_type: url` with connector metadata |
| Skipping tool preflight checks | Selection | Read the cached extractor status or run the status scripts before choosing a path |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The content looks like this format, so detection is settled" | Guessing format from extracted text instead of stable source signals | Detect from connector flags, URL patterns, file extensions, and URL prefixes first |
| "The extractor failed, so ingest has to fail too" | Aborting ingest when a metadata-only packet is still possible | Move down the fallback chain and emit a stub source-packet if extraction stays unavailable |
| "Cleanup made the text readable, so provenance can be minimal" | Dropping title, URL or path, fetch date, source format, or extractor from the packet | Preserve full source-packet attribution before handing off to ingest |

## Workflow

### 1. Detect The Source Type And Format

Use connector flags, YouTube URL patterns, file extensions, and URL prefixes to determine `source_type` and `source_format`.
Treat non-YouTube HTTP sources as URL content, connector bookmarks as URL content with connector metadata, and unmatched local inputs as paste or file inputs.

### 2. Choose The Extractor

Select the primary extractor for the detected format and prepare the fallback chain before running anything.
Use `markitdown` and `pandoc` for document formats, `yt-dlp` and `mlx-whisper` for YouTube, and the Read tool for images.

### 3. Extract Markdown-Oriented Raw Content

Run the selected tool and capture the output as markdown or text that can be normalized into markdown safely.
For shell-based tools, rely on the pipeline scripts.
For images, read the file directly and capture the returned text output.

### 4. Assemble The Source-Packet

Write the required packet fields: `source_type`, `source_title`, `raw_content`, and `fetch_date`.
Add `source_format`, `source_url`, `source_path`, `extractor`, and format-specific `metadata` when available.

### 5. Degrade Gracefully When Needed

If the primary extractor fails, move to the next defined fallback.
If no extractor succeeds, create a stub note or metadata-only packet so the source stays ingestible and auditable.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| YouTube detection | Any `youtube.com/watch`, `youtu.be/`, `youtube.com/shorts/`, or `youtube.com/live/` URL is `source_type: youtube` |
| Bookmark connectors | Connector imports remain `source_type: url`, and connector provenance lives in `metadata.connector` |
| PDF chain | Prefer `markitdown`, then `pdftotext`, then a stub |
| DOCX and PPTX chain | Prefer `markitdown`, then `pandoc` where supported, then a stub |
| EPUB chain | Prefer `pandoc`, then `markitdown`, then a stub |
| Image handling | Use Claude vision when available, otherwise emit a stub with the file path |
| YouTube fallback | Prefer subtitles through `yt-dlp`, then local transcription through `mlx-whisper`, then metadata-only stub |
| Failure posture | Extraction failure never blocks ingest if provenance and a minimal packet can still be recorded |

## Reference Map

| Need | Reference |
|------|-----------|
| Full source-packet schema and field semantics | `${CLAUDE_SKILL_DIR}/references/source-packet-schema.md` |
| Format-specific fallback chains and installation notes | `${CLAUDE_SKILL_DIR}/references/extractor-selection.md` |
| Bookmark connector routing and queue mapping | `${CLAUDE_SKILL_DIR}/references/connector-contracts.md` |
| Cross-module bridge rules for ingest handoff | `${CLAUDE_SKILL_DIR}/references/bridge-contracts.md` |
| Reflection prompts and post-ingest follow-up | `${CLAUDE_SKILL_DIR}/references/reflection-prompts.md` |

## See Also

- `commands/pa/ingest.md` — Primary caller that turns external inputs into ingestable packets.
- `commands/pa/survey.md` — Uses extractor preflight to report environment readiness.
- `scripts/pa-extract.sh` and `scripts/pa-youtube.sh` — Shell helpers for extractor selection and tool status.
