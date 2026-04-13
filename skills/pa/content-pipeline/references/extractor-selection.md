# Extractor Selection — Tool Fallback Chains

> Purpose: Reference for `content-pipeline` skill — defines which extraction tools to use for each format, fallback order, installation commands, and format-specific considerations.

## Tool Inventory

| Tool | Install | Formats | Notes |
|------|---------|---------|-------|
| `markitdown` | `pip install markitdown` | PDF, DOCX, PPTX, XLSX, HTML, images | Microsoft open-source. Best markdown quality for Office formats |
| `pandoc` | `brew install pandoc` | DOCX, EPUB, HTML, LaTeX, many more | Cannot read PDF. Best for EPUB |
| `pdftotext` | `brew install poppler` | PDF only | Fast text extraction, no formatting preservation |
| `yt-dlp` | `brew install yt-dlp` | YouTube subtitles + metadata | No API key needed. Extracts auto-subs and manual subs |
| `mlx-whisper` | `uvx mlx_whisper` (via uv) | Audio → text | Apple MLX native. Requires `ffmpeg` for audio decode |
| `ffmpeg` | `brew install ffmpeg` | Audio/video conversion | Required by mlx-whisper for audio extraction from video |
| Claude vision | Built-in (Read tool) | Images, scans | Multimodal — reads image files directly |

## Fallback Chains

### Document Extraction (`scripts/pa-extract.sh`)

| Format | Chain | Rationale |
|--------|-------|-----------|
| **PDF** | `markitdown` → `pdftotext` → stub | markitdown preserves structure + formatting. pdftotext is fast but loses layout. pandoc cannot read PDF |
| **DOCX** | `markitdown` → `pandoc` → stub | markitdown handles Office natively. pandoc is solid fallback |
| **PPTX** | `markitdown` → `pandoc` → stub | markitdown handles PPTX natively. pandoc has limited PPTX support but can extract text as fallback |
| **EPUB** | `pandoc` → `markitdown` → stub | pandoc is the standard EPUB converter. markitdown can also handle it |
| **Image** | Claude vision → stub with path | Not a shell extraction — the ingest command uses Read tool on the image file. `pa-extract.sh` outputs a message directing to Claude vision |

### YouTube Extraction (`scripts/pa-youtube.sh`)

| Scenario | Chain | Rationale |
|----------|-------|-----------|
| **Has subtitles** | `yt-dlp --write-auto-subs` → parse VTT → text | Fastest, zero compute cost, good quality for manual subs |
| **No subtitles** | `yt-dlp -x` (audio download) → `uvx mlx_whisper` (large-v3) → text | Local transcription, best accuracy for Korean+English. Requires ffmpeg |
| **No subtitles + no mlx-whisper** | metadata-only stub | Preserves video reference for manual processing later |

## Model Selection for mlx-whisper

| Model | Accuracy | Speed | Use Case |
|-------|----------|-------|----------|
| `mlx-community/whisper-large-v3` | Best (lowest WER) | ~2x whisper.cpp | Default — accuracy priority |
| `mlx-community/whisper-large-v3-turbo` | Slightly lower | ~8x whisper.cpp | Long videos when speed matters |

Default model: `large-v3` (accuracy first). Configurable via `.pa/settings.json` `content_pipeline.stt_model`.

## Availability Detection

`scripts/pa-extract.sh status` and `scripts/pa-youtube.sh status` output JSON reporting which tools are installed. Results are cached in `.pa/settings.json`:

```json
{
  "content_pipeline": {
    "extractors": {
      "markitdown": true,
      "pandoc": true,
      "pdftotext": false,
      "yt_dlp": true,
      "ffmpeg": true,
      "mlx_whisper": true
    },
    "stt_model": "mlx-community/whisper-large-v3",
    "supported_formats": ["pdf", "docx", "pptx", "epub", "image", "youtube"]
  }
}
```

### Bookmark Connector (`scripts/pa-raindrop.sh`)

| Scenario | Chain | Rationale |
|----------|-------|-----------|
| Bookmark with highlights | Queue entry → highlights as raw_content prefix → WebFetch for full content | Highlights are the highest-value user signal |
| Bookmark without highlights | Queue entry → WebFetch for full content | Falls back to standard URL ingest path |
| WebFetch fails | Queue entry → stub note with bookmark metadata + highlights only | Graceful degradation preserves the reference |

## Format-Specific Notes

### PDF
- markitdown preserves headings, tables, and lists from well-structured PDFs. Scanned/image-based PDFs produce poor results — consider Claude vision for these.
- pdftotext with `-layout` flag preserves spatial layout as whitespace but loses all formatting.
- Page markers: markitdown may include page break indicators. Preserve these as `<!-- page N -->` comments for section-level provenance.

### YouTube
- Auto-generated subtitles repeat lines and include timing artifacts. The VTT parser in `pa-youtube.sh` deduplicates consecutive lines.
- Korean auto-subs quality varies significantly by channel. Manual subtitles (`ko` without `.auto` suffix) are higher quality.
- For videos longer than 2 hours, mlx-whisper transcription may take 10-30 minutes on Apple Silicon. Consider `large-v3-turbo` for these.

### Image
- Claude vision produces a text description, not OCR output. For documents scanned as images, the description may summarize rather than transcribe.
- For multi-page scanned documents saved as individual images, process each image separately and concatenate.
