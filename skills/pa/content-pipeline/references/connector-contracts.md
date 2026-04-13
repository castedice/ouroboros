# Connector Contracts — Bookmark Services

> Purpose: Reference for `content-pipeline` skill — defines the uniform interface for external bookmark service connectors.

## Core Principle

**"One queue format, many sources."**

Each connector is a shell script that syncs bookmarks from an external service into a per-connector queue file (`.pa/{connector}-queue.jsonl`).
The ingest command reads the queue without knowing which service produced it.

## Queue Entry Schema

Event-based append-only design.
Each entry is one of: `queued`, `ingested`, `skipped`.

### `queued` (written by connector sync)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event` | `"queued"` | yes | Event type |
| `queued_at` | string | yes | ISO 8601 timestamp |
| `connector` | string | yes | Service identifier: `raindrop`, `pocket`, etc. |
| `bookmark_id` | string/number | yes | Service-native unique ID |
| `title` | string | yes | Bookmark title |
| `link` | string | yes | Original URL |
| `excerpt` | string | no | Service-extracted summary |
| `tags` | string[] | no | User-assigned tags from the service |
| `highlights` | object[] | no | User highlights: `{text, note, color}` |
| `collection_name` | string | no | Folder/collection name |
| `created` | string | yes | ISO 8601 creation date in the service |
| `raindrop_id` | number | no | Raindrop-specific: native Raindrop ID (used by ingest-digest template for `raindrop_id` frontmatter). Other connectors may add their own service-specific ID fields |

### `ingested` (written by ingest command after successful render+write)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event` | `"ingested"` | yes | Event type |
| `recorded_at` | string | yes | ISO 8601 timestamp |
| `bookmark_id` | string/number | yes | Same ID as the queued entry |
| `note_path` | string | yes | Vault path of the created digest note |

### `skipped` (written by ingest command when duplicate detected or user declines)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event` | `"skipped"` | yes | Event type |
| `recorded_at` | string | yes | ISO 8601 timestamp |
| `bookmark_id` | string/number | yes | Same ID as the queued entry |
| `reason` | string | yes | `duplicate`, `user_declined`, `fetch_failed` |

## Pending Item Resolution

An item is "pending" when it has a `queued` event but no subsequent `ingested` or `skipped` event for the same `bookmark_id`.
Consumers scan the queue in order and check for the latest event per `bookmark_id`.

## Connector Script Interface

Every connector script (`pa-{connector}.sh`) must implement these actions:

| Action | Purpose |
|--------|---------|
| `config` | Store credentials in `~/.config/ouroboros/integrations.json` |
| `sync` | Fetch new items and append `queued` events to the queue |
| `pull [--next]` | Output next pending queue entry as JSON. If no pending entries, output `{"pending": 0}` and exit 0 |
| `status` | Health check: token validity, API reachability, sync state, queue counts |

## Token Storage

Credentials live in `~/.config/ouroboros/integrations.json` (user-level, never in vault).
Each service gets its own key:

```json
{
  "raindrop": {"token": "...", "collection_id": 0},
  "pocket": {"consumer_key": "...", "access_token": "..."}
}
```

## Sync State

Sync cursors live in `.pa/integrations-state.json` (per-vault).
Each connector tracks its own sync state:

```json
{
  "version": 1,
  "raindrop": {"last_sync_at": "...", "last_sync_count": 5}
}
```

## Source-Packet Mapping

When ingest processes a queue entry, it builds a source-packet:

| Queue Field | Source-Packet Field |
|-------------|-------------------|
| `link` | `source_url` |
| `title` | `source_title` |
| highlights → `> quote` blocks + fetched content | `raw_content` |
| `tags` | `metadata.service_tags` |
| `connector` | `metadata.connector` |
| `bookmark_id` | `metadata.bookmark_id` |
| `collection_name` | `metadata.collection_name` |
| highlights count | `metadata.highlights_count` |

`source_type: url`, `source_format: null`, `extractor: null` (full content fetched via WebFetch during ingest).

## Source Shape

Bookmark connector sources use `source_shape: bookmark`.
This shape renders `## Highlights` prominently before `## Source Excerpt` and preserves service tags in frontmatter as `raindrop_tags` (not merged into vault `tags`).

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/content-pipeline/SKILL.md` | Parent skill |
| `skills/pa/content-pipeline/references/source-packet-schema.md` | Source-packet contract consumed by ingest |
| `commands/pa/ingest.md` | Consumer — reads queue, builds source-packet, renders digest |
| `templates/pa/ingest-digest.md` | Rendering template — `bookmark` source_shape |
| `scripts/pa-scheduler.sh` | Scheduler for nightly sync registration |
