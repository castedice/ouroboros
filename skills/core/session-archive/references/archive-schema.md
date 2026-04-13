# Session Archive Schema

## Storage Root

The archive root is `${CLAUDE_PLUGIN_DATA}/session-archive/`.
The canonical SQLite file is `${CLAUDE_PLUGIN_DATA}/session-archive/index.sqlite`.
The queue file is `${CLAUDE_PLUGIN_DATA}/session-archive/queue.jsonl`.

## SQLite DDL

```sql
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS sources (
  source_path TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  parent_session_id TEXT,
  project_slug TEXT NOT NULL,
  project_cwd TEXT,
  agent_kind TEXT NOT NULL,
  source_mtime INTEGER NOT NULL,
  source_size INTEGER NOT NULL,
  source_hash TEXT,
  indexed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS segments (
  segment_id TEXT PRIMARY KEY,
  source_path TEXT NOT NULL REFERENCES sources(source_path) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  parent_session_id TEXT,
  project_slug TEXT NOT NULL,
  agent_kind TEXT NOT NULL,
  speaker TEXT NOT NULL,
  segment_kind TEXT NOT NULL,
  ts TEXT,
  line_no INTEGER NOT NULL,
  item_no INTEGER NOT NULL,
  turn_no INTEGER,
  tool_name TEXT,
  tool_use_id TEXT,
  is_error INTEGER NOT NULL DEFAULT 0,
  is_meta INTEGER NOT NULL DEFAULT 0,
  command_hint TEXT,
  component_hint TEXT,
  task_key TEXT,
  raw_uuid TEXT,
  content TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_segments_filters
ON segments(project_slug, agent_kind, component_hint, ts);

CREATE INDEX IF NOT EXISTS idx_segments_tool_use
ON segments(tool_use_id);

CREATE VIRTUAL TABLE IF NOT EXISTS segments_fts USING fts5(
  content,
  command_hint,
  component_hint,
  tool_name,
  content='segments',
  content_rowid='rowid',
  tokenize='unicode61'
);
```

## FTS Maintenance

The archive uses explicit `INSERT INTO segments_fts(segments_fts) VALUES ('rebuild')` after each source replace transaction.
This avoids trigger-based virtual-table writes that fail on defensive SQLite builds.

## Source Fields

- `source_path` is the absolute transcript file path for either the main transcript or a subagent transcript.
- `session_id` is the parent Claude session id for the transcript.
- `parent_session_id` is empty for main transcripts and repeats the parent Claude session id for subagent transcripts because current Claude subagent JSONL files do not expose a distinct child session id.
- `project_slug` is the Claude project directory slug under `~/.claude/projects/`.
- `project_cwd` is the first non-empty `cwd` discovered in the JSONL stream.
- `agent_kind` is `main` or `subagent`.
- `source_mtime`, `source_size`, and `source_hash` drive idempotent skip logic during `sync`.
- `indexed_at` is the UTC timestamp of the last successful replace.

## Segment Fields

- `segment_id` uses `main:<session-id>:<line-no>:<item-no>` for main transcripts.
- `segment_id` uses `subagent:<session-id>:<subagent-file-stem>:<line-no>:<item-no>` for subagent transcripts.
- `speaker` is `user`, `assistant`, or `tool`.
- `segment_kind` is `text`, `tool_use`, `tool_result`, or `meta`.
- `ts` is copied from the raw record timestamp when present.
- `line_no` is the JSONL line number in the source file.
- `item_no` is the block index inside the raw record content array, or `0` for scalar content records.
- `turn_no` is the archive-local visible-segment order grouped by source line.
- `tool_name` is populated for `tool_use` and resolved `tool_result` segments.
- `tool_use_id` links `tool_result` records back to the originating `tool_use`.
- `is_error` is reserved for explicit tool-result error flags.
- `is_meta` marks wrapper noise that should be excluded by default.
- `command_hint`, `component_hint`, and `task_key` reuse `learning_extract_route_hint`.
- `raw_uuid` is the raw transcript record UUID when present.
- `content` is normalized visible text only, never the raw line payload.

## Segment Rules

### `segment_kind='text'`

- User string content that does not start with a local-command wrapper becomes a `text` segment.
- Assistant `message.content[]` blocks with `type="text"` become `text` segments.
- User array blocks with `type="text"` become `text` segments.

### `segment_kind='meta'`

- User string content that matches the local-command wrapper regex becomes a `meta` segment with `is_meta=1`.
- System records with `subtype="local_command"` become `meta` segments with `speaker='tool'`.
- Meta segments remain searchable only when `--include-meta` is set.

### `segment_kind='tool_use'`

- Assistant `message.content[]` blocks with `type="tool_use"` become `tool_use` segments.
- The stored content is a summarized input view with binary-like keys stripped before serialization.
- The raw tool input is still used for route-hint extraction and for later tool-result interpretation.

### `segment_kind='tool_result'`

- User array blocks with `type="tool_result"` become `tool_result` segments.
- `Bash`, `Grep`, `Agent`, and `Task*` results keep capped stdout-like text at 2 KB.
- `Read`, `Write`, `Edit`, and `Glob` results store metadata only as `path=<...> size=<...>`.
- Other tools keep normalized result text with a smaller default cap.

## Ignored Raw Record Types

- `summary`
- `queue-operation`
- `file-history-snapshot`
- `agent-name`
- `custom-title`
- `last-prompt`
- `progress`
- `system` with subtype `bridge_status`
- `system` with subtype `stop_hook_summary`
- `system` with subtype `turn_duration`
- Any assistant `thinking` block

## Local-Command Detection

Use this wrapper-start regex for Phase 1 parsing guidance.

```regex
^<(local-command-[^>]+|command-[A-Za-z0-9_-]+)>
```

This deliberately treats both `<local-command-*>` and `<command-*>` wrappers as archive meta noise.

## Session Anchor Rule

When a source has no route hint on its first non-meta visible segment, assign `command_hint="session"` and `task_key="session:<session-id>"`.
This creates exactly one generic lexical anchor per source without adding synthetic rows.

## Wiki Proposal Surface (Phase 3)

The archive schema remains raw-only.
Wiki page shape, proposal bundle layout, citation format (`[SA<n>]`), and grouping cascade live in `wiki-schema.md`.
The proposal-only gate, preimage hash check, and ledger append rules live in `wiki-gate.md`.
Phase 3 never mutates `segments` or `sources` tables from the propose, apply, reject, or lint flows.
