# Source-Packet Schema

> Purpose: Reference for `content-pipeline` skill — defines the uniform data contract between format-specific extraction and format-agnostic triage. Every external content source must be normalized into this schema before entering the ingest pipeline.

## Schema

```json
{
  "source_type": "url | file | paste | youtube | voice-transcript | screenshot",
  "source_format": "pdf | docx | pptx | epub | image | audio | youtube | screenshot | null",
  "source_url": "https://... | null",
  "source_title": "Document or video title",
  "source_path": "/path/to/file | null",
  "raw_content": "Extracted markdown text",
  "fetch_date": "2026-03-24",
  "document_date": "2026-03-20 | null",
  "event_date_start": "2026-03-14 | null",
  "event_date_end": "2026-03-14 | null",
  "event_date_precision": "day | week | month | quarter | year | unknown | null",
  "temporal_confidence": "0.0-1.0 | null",
  "extractor": "markitdown | pandoc | pdftotext | yt-dlp | mlx-whisper | whispree | claude-vision | webfetch | null",
  "metadata": {}
}
```

All five temporal fields are optional for backward compatibility.
Readers must accept packets that omit them entirely.

## Field Definitions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `source_type` | enum | yes | The input category: `url` (web page), `file` (local document), `paste` (raw text), `youtube` (video), `voice-transcript` (user-initiated voice capture), or `screenshot` (user-selected screenshot file) |
| `source_format` | enum | conditional | The specific format within the type. Required for `file` and `youtube`, recommended as `audio` for `voice-transcript` from a file, and recommended as `image` or `screenshot` for screenshots. Null for `url`, `paste`, and clipboard-origin `voice-transcript` |
| `source_url` | string | conditional | The original URL. Required for `url` and `youtube` types |
| `source_title` | string | yes | Human-readable title. From document metadata, page title, video title, or filename |
| `source_path` | string | conditional | Local file path. Required for `file` and `screenshot` types, and recommended for `voice-transcript` when transcribed from an audio file |
| `raw_content` | string | yes | The extracted text content in markdown format. For screenshot packets, command-layer vision extraction populates this field after the capture helper records the file path. For stub notes, may be a brief description |
| `fetch_date` | string | yes | ISO 8601 date when extraction occurred |
| `document_date` | string | optional | ISO 8601 date when the artifact itself was created, published, or captured. Nullable when unknown |
| `event_date_start` | string | optional | ISO 8601 start date for the real-world event described by the source. Nullable when unknown |
| `event_date_end` | string | optional | ISO 8601 end date for the real-world event described by the source. Nullable when unknown |
| `event_date_precision` | enum | optional | One of `day`, `week`, `month`, `quarter`, `year`, or `unknown`. Nullable when event timing is unknown |
| `temporal_confidence` | float | optional | Confidence score from `0.0` to `1.0` for the temporal extraction. Nullable when no temporal extraction was made |
| `extractor` | string | recommended | Which tool performed the extraction, such as `markitdown`, `pandoc`, `pdftotext`, `yt-dlp`, `mlx-whisper`, `whispree`, `claude-vision`, or `webfetch`. Aids debugging and provenance |
| `metadata` | object | optional | Format-specific metadata (see below) |

## Format-Specific Metadata

### PDF / DOCX / PPTX / EPUB

```json
{
  "page_count": 42,
  "file_size_bytes": 1048576,
  "author": "Author Name",
  "original_filename": "report.pdf"
}
```

### YouTube

```json
{
  "video_id": "dQw4w9WgXcQ",
  "channel": "Channel Name",
  "duration": 1234,
  "duration_human": "20:34",
  "publish_date": "2026-03-20",
  "view_count": 12345,
  "has_subtitles": true,
  "subtitle_lang": "ko",
  "transcription_method": "auto-subs | mlx-whisper"
}
```

### Image

```json
{
  "image_format": "png",
  "original_filename": "scan.png",
  "description_method": "claude-vision"
}
```

### Voice Transcript

```json
{
  "capture_mode": "clipboard | file",
  "capture_ts": "2026-03-24T14:30:00+09:00",
  "audio_path": "/path/to/audio.m4a | null"
}
```

### Screenshot

```json
{
  "capture_ts": "2026-03-24T14:30:00+09:00",
  "vision_extraction": "pending | claude-vision"
}
```

### Bookmark (Connector)

```json
{
  "connector": "raindrop",
  "bookmark_id": 123456,
  "service_tags": ["ai", "productivity"],
  "collection_name": "Articles",
  "highlights_count": 3,
  "highlights": [
    {"text": "Key insight about transformers", "note": "Relates to my project", "color": "blue"}
  ]
}
```

## Examples

### PDF Source-Packet

```json
{
  "source_type": "file",
  "source_format": "pdf",
  "source_url": null,
  "source_title": "2026 AI Landscape Report",
  "source_path": "/Users/user/Downloads/ai-landscape-2026.pdf",
  "raw_content": "# 2026 AI Landscape Report\n\n## Executive Summary\n\nThe AI industry...",
  "fetch_date": "2026-03-24",
  "document_date": "2026-03-20",
  "event_date_start": null,
  "event_date_end": null,
  "event_date_precision": null,
  "temporal_confidence": null,
  "extractor": "markitdown",
  "metadata": {
    "page_count": 42,
    "file_size_bytes": 2097152,
    "original_filename": "ai-landscape-2026.pdf"
  }
}
```

### YouTube Source-Packet

```json
{
  "source_type": "youtube",
  "source_format": "youtube",
  "source_url": "https://www.youtube.com/watch?v=abc123",
  "source_title": "Understanding Transformer Architecture",
  "source_path": null,
  "raw_content": "[00:00] Introduction to transformers...\n[03:45] The attention mechanism...",
  "fetch_date": "2026-03-24",
  "document_date": "2026-03-15",
  "event_date_start": null,
  "event_date_end": null,
  "event_date_precision": null,
  "temporal_confidence": null,
  "extractor": "yt-dlp",
  "metadata": {
    "video_id": "abc123",
    "channel": "AI Explained",
    "duration": 1847,
    "duration_human": "30:47",
    "publish_date": "2026-03-15",
    "has_subtitles": true,
    "subtitle_lang": "en",
    "transcription_method": "auto-subs"
  }
}
```

### Voice Transcript Source-Packet

```json
{
  "source_type": "voice-transcript",
  "source_format": null,
  "source_url": null,
  "source_title": "Voice capture 2026-03-24 14:30",
  "source_path": null,
  "raw_content": "User dictated note text...",
  "fetch_date": "2026-03-24",
  "document_date": "2026-03-24",
  "event_date_start": null,
  "event_date_end": null,
  "event_date_precision": null,
  "temporal_confidence": null,
  "extractor": "whispree",
  "metadata": {
    "capture_mode": "clipboard",
    "capture_ts": "2026-03-24T14:30:00+09:00",
    "audio_path": null
  }
}
```

### Screenshot Source-Packet

```json
{
  "source_type": "screenshot",
  "source_format": "image",
  "source_url": null,
  "source_title": "Screenshot 2026-03-24 14:30",
  "source_path": "/Users/user/Desktop/screenshot.png",
  "raw_content": "Vision description populated by the command layer...",
  "fetch_date": "2026-03-24",
  "document_date": "2026-03-24",
  "event_date_start": null,
  "event_date_end": null,
  "event_date_precision": null,
  "temporal_confidence": null,
  "extractor": "claude-vision",
  "metadata": {
    "capture_ts": "2026-03-24T14:30:00+09:00",
    "vision_extraction": "claude-vision"
  }
}
```

## Capture Helper Packets

`scripts/pa-multimodal-capture.sh` emits compact capture packets before command-layer normalization.
For voice capture, it emits `{"type":"voice-transcript","extractor":"whispree|mlx-whisper","content":"...","ts":"..."}`.
For screenshot capture, it emits `{"type":"screenshot","path":"/path/to/image","ts":"..."}`.
The command layer maps `type` to `source_type`, `content` to `raw_content`, `path` to `source_path`, and `ts` to `metadata.capture_ts`.
Screenshot vision extraction happens in the command layer, not in the capture helper.

## Source Shape Derivation

The `source_shape` dimension used by `templates/pa/ingest-digest.md` is derived from the source-packet fields. This mapping is applied by the ingest command before rendering.

| `source_type` | `source_format` | `source_shape` |
|---------------|-----------------|----------------|
| `url` | — | `url` |
| `url` (via connector) | — | `bookmark` |
| `file` | `pdf` | `pdf` |
| `file` | `docx`, `pptx`, `epub` | `document` |
| `file` | `image` | `image` |
| `file` | — (`.md`, `.txt`) | `file` |
| `youtube` | `youtube` | `youtube` |
| `paste` | — | `paste` |
| `voice-transcript` | —, `audio` | `transcript` |
| `screenshot` | `image`, `screenshot` | `image` |

Derivation logic: if `metadata.connector` is present, `source_shape = bookmark` regardless of `source_type`.

Transcripts (from curator classification) retain `source_shape: transcript` regardless of source_type.

## Downstream Consumers

The source-packet is consumed by:

| Consumer | What It Uses |
|----------|-------------|
| Curator agent | `raw_content` for triage, `source_type`/`source_format` for routing, and temporal fields for event grounding |
| Ingest-digest template | `source_type`, `source_format`, temporal fields, and `metadata` for rendering path classification |
| Deduplication (librarian) | `source_title`, `raw_content` for QMD overlap check |
| Derivation state | `source_path` or `source_url` for dirty_path tracking |
| Connector queue | `metadata.connector`, `metadata.bookmark_id` for queue event tracking |
