# Session Archive Retrieval Contract

## Search Action

Use `bash scripts/session-archive.sh search "<query>"` for lexical retrieval over visible session segments.

### Arguments

- `--since <date-or-nd>` filters by indexed source mtime.
- `--project current|all|<slug>` defaults to `current`.
- `--agent all|main|subagent` defaults to `all`.
- `--component <path-or-command>` matches exact `component_hint` or exact `command_hint`.
- `--top <n>` defaults to `5`.
- `--format json|text` defaults to `text`.
- `--include-meta` opt-ins to `is_meta=1` rows.

### Filter Semantics

- `project=current` resolves the current working directory into the Claude project slug form used under `~/.claude/projects/`.
- `since` accepts `YYYY-MM-DD`, full ISO-8601 timestamps, or `<n>d` shorthand such as `30d`.
- `agent=subagent` searches only the `subagents/*.jsonl` surface.
- `component` is exact-match only in Phase 1, not fuzzy path search.
- Meta rows stay excluded unless `--include-meta` is present.

### JSON Response

```json
{
  "query": "friction routing",
  "pending_ingest": 2,
  "count": 1,
  "hits": [
    {
      "segment_id": "main:7e7639fc:183:0",
      "score": 100.0,
      "session_id": "7e7639fc-...",
      "project_slug": "-Users-kibum-park-workspace-ouroboros",
      "agent_kind": "main",
      "speaker": "assistant",
      "segment_kind": "text",
      "component_hint": "scripts/learning-distill.sh",
      "tool_name": null,
      "ts": "2026-04-10T03:12:44Z",
      "snippet": "...",
      "source_ref": "~/.claude/projects/.../session.jsonl:183"
    }
  ]
}
```

`count` is the number of returned hits after all filters and `top` truncation.

## Get Action

Use `bash scripts/session-archive.sh get <segment-id|session-id>` to inspect local context.

### Segment Id Lookup

- When the identifier is a concrete `segment_id`, `get` returns a visible neighbor window from the same source file.
- `--before <n>` and `--after <n>` default to `2`.

### Session Id Lookup

- When the identifier is not a matching `segment_id`, `get` treats it as a session id.
- Session-id lookup returns all visible segments for `session_id=<id>` or `parent_session_id=<id>`.

## Status Action

Use `bash scripts/session-archive.sh status` to read the current local archive state.

### Status Fields

- `schema_version` is fixed at `1` for Phase 1.
- `last_sync_at` is `null` until the first successful `sync`.
- `pending_count` counts non-empty lines still present in `queue.jsonl`.
- `indexed_sources` counts rows in `sources`.
- `segment_count` counts rows in `segments`.

## PA Session Lane Contract

Phase 2 PA integration must remain fail-open.
If the archive is missing, empty, stale, or unreadable, PA should emit “no session hits” and continue with vault retrieval.
PA should search `--project current` by default and keep session excerpts as supporting context, not the primary memory surface.
PA citations should include both `segment_id` and `source_ref`.
Likely triggers are “previous attempt”, “we already discussed”, “last week”, “regression”, and similar temporal-recall cues.

## RnD Prior-Work Usage Pattern

Phase 2 RnD integration should query the session archive before external collection and before novelty claims.
The archive should surface prior framing, dead ends, vocabulary, and unresolved objections as advisory context only.
RnD should prefer `--component rnd` or `--component research` filters when the question is explicitly about prior RnD work.
The session archive must never mutate `.rnd/archive-index.json`, `.rnd/`, or `docs/research/` in Phase 1.

## Session Wiki Retrieval (Phase 3)

The `session-wiki` QMD collection provides the promoted wiki tier under `${CLAUDE_PLUGIN_DATA}/session-archive/wiki/`.
QMD registration is a manual user step; `bash scripts/session-archive.sh wiki-status` prints the exact command.
Proposals under `proposals/` are excluded from the collection pattern `wiki/**/*.md`.

### PA opt-in path

PA librarian does not query `session-wiki` as a default lane in Phase 3.
Users may add the `session-wiki` collection to `retrieval-profiles.json` as a supplementary vault-like collection if they want wiki hits during `/pa ask`, `/pa brief`, or `/pa day`.
Citation markers inside wiki pages use `[SA<n>]`, distinct from librarian raw session `[S<n>]` output.

### RnD prior-work path

RnD Phase 5 queries `session-wiki` via `mcp__qmd__query` when the collection is registered.
Results are packaged as `session_wiki_prior_work[]`, ranked before raw `session_prior_work[]`, and never charged against adapter budget.
Both stay `conversation-session` context-only; see `source-quality.md`.

### Promotion gate

`/session-wiki propose` writes only under `proposals/`.
`/session-wiki apply <id>` is the only promoted-write path, gated by preimage hash check.
`/session-wiki reject <id> --reason "..."` records rejection without mutating the raw archive or the wiki tier.
See `wiki-gate.md` for the full gate protocol.

## Fail-Open Boundary

- The SessionEnd hook may append missing or stale paths and still return exit code `0`.
- `sync` should keep processing other sources when one source fails.
- Search and get should never write to the archive.
