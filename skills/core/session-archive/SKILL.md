---
name: session-archive
description: This skill provides session archive methodology. It should be activated when an agent needs to "initialize the session archive", "sync Claude Code transcripts into SQLite FTS5", "search visible transcript evidence", "retrieve session segment context", "debug dropped transcript records", "rebuild or prune archived sessions", or "wire prior-session recall into PA or RnD workflows".
summary: Governs transcript archiving into SQLite FTS5, retrieval contracts, retention rules, and proposal-only session wiki promotion.
version: 1
tags: [core, session-archive, transcript-indexing, retrieval, session-wiki]
preamble_tier: 2
---

# Session Archive

## Core Rule

Archive only visible transcript evidence into SQLite FTS5.
Thinking blocks are always dropped.
The SessionEnd hook only enqueues transcript paths.
`sync` is the only action that parses and indexes transcript content.

## Gotchas

| Gotcha | Rule |
|--------|------|
| Full-corpus rebuilds are slow | Prefer `rebuild --since 30d`; a full rebuild can take 10+ hours for a 500 MB transcript corpus |
| `prune` is irreversible for indexed archive rows | Default to `prune --older-than 365d` and shorten retention only when intentionally dropping old indexed sources |
| Meta segments are excluded by default | Do not debug by searching local-command or wrapper content unless `--include-meta` is set |
| Missing transcript paths fail open | The hook still exits `0`, and `sync` logs and continues on per-source failures instead of aborting the queue |
| Stale queue entries can hide successful indexing | Use `status` to check pending queue depth, indexed source count, and segment count before treating absent hits as parser failure |
| Target `sqlite3` must support FTS5 | Check FTS5 support before blaming the parser, schema, or retrieval contract |
| `normalize_text` collapses whitespace | Search multi-line segments as text joined with spaces rather than original line breaks |
| Subagent transcripts share the parent session id | Use `agent_kind`, `parent_session_id`, and the subagent-style `segment_id` when distinguishing main and subagent evidence |
| Tool result stdout is capped | See Reference Map -> `archive-schema.md` for tool-result caps before changing ingest behavior |
| Search returns a small result set by default | See Reference Map -> `retrieval-contract.md` for search defaults before widening retrieval |
| Session-wiki drift breaks citations | Keep `[SA<n>]` markers resolvable through `## Source Segments` instead of editing raw archive rows |
| QMD registration stays manual | Print the `qmd collection add session-wiki` hint, but never run it from `init` or archive actions |
| Proposal-only is per bundle | Apply or reject the whole proposal bundle rather than one page at a time |
| Validation is behavioral, not only structural | Confirm `init`, `status`, `sync`, `search`, `get`, and the hook still satisfy the archive checklist before relying on a changed implementation |

### Rationalization Red Flags

Treat these as archive-integrity anti-drift checks before changing ingest, schema, or retrieval behavior.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "We already dropped thinking blocks, one more for debugging is fine" | Re-adding thinking blocks to trace a parser bug | Reproduce on a fixture, not the live index |
| "The current session just needs a quick segment, so open the raw `.jsonl` directly" | Bypassing `sync` with a direct insert | Wait for the SessionEnd hook or run `sync` manually |
| "This `tool_result` text looks important, so widen the cap for one tool" | Removing a stdout cap for one tool path | Add a reference rule in `archive-schema.md` with a measured default, then cap every affected path consistently |
| "Meta is just noise, so delete those rows" | Physically deleting meta segments from `segments` | Keep the rows and rely on `is_meta=1` plus the `--include-meta` toggle |
| "The queue has a stale path, so just empty it" | Manually truncating `queue.jsonl` | Let `sync` drop missing paths on the next run |
| "The wiki draft is already reviewed, so copy it into place" | Bypassing `/session-wiki apply <id>` | Keep the draft under `proposals/` until the user applies the bundle |
| "QMD search would be better if the collection existed now" | Auto-registering QMD without user consent | Print the manual registration hint and stop |

### Bias Mitigation

| Bias | Archive-Specific Risk | Countermeasure |
|------|-----------------------|----------------|
| Recency bias | Recent transcripts can feel more relevant than older matching evidence | Phase 1 scores non-meta segments by BM25 only; caller lanes apply any time decay outside the archive |
| Survivorship bias | Successfully parsed happy paths can hide failed tool runs | `tool_result` segments preserve `is_error`, so failed tool runs stay discoverable |
| Confirmation bias | Searchers can query only for evidence matching the expected story | `segment_kind` exposes whether a hit is `text`, `tool_use`, or `tool_result`, forcing caller awareness of evidence type |

## Workflow

1. Run `bash scripts/session-archive.sh init` before the first sync.
2. Let `hooks/session-archive-ingest.sh` append main-session and subagent transcript paths on SessionEnd.
3. Run `bash scripts/session-archive.sh sync` to process the queue into `index.sqlite`.
4. Run `bash scripts/session-archive.sh search "<query>"` to retrieve lexical hits.
5. Run `bash scripts/session-archive.sh get <segment-id|session-id>` to inspect local context around a hit.
6. Run `bash scripts/session-archive.sh status` to check schema version, pending queue depth, indexed source count, and segment count.
7. Run `bash scripts/session-archive.sh rebuild --since 30d` only when you intentionally want to backfill recent transcripts.
8. Run `bash scripts/session-archive.sh prune --older-than 365d` only when you intentionally want to drop old indexed sources from SQLite.

## Decision Rules

- Treat `<local-command-*>` and `<command-*>` user wrappers as `segment_kind='meta'` with `is_meta=1`.
- Treat `system` records with `subtype="local_command"` as `segment_kind='meta'` with `speaker='tool'`.
- Exclude meta segments by default, and require `--include-meta` to search them.
- Drop all `thinking` blocks instead of storing or summarizing them.
- Store assistant `tool_use` blocks as summarized inputs with `segment_kind='tool_use'`.
- Store `Bash`, `Grep`, `Agent`, and `Task*` tool results as capped stdout-like text with `segment_kind='tool_result'`.
- Store `Read`, `Write`, `Edit`, and `Glob` tool results as metadata only with path and size.
- Reuse `learning_extract_route_hint` from `scripts/learning-lib.sh` for `component_hint`, `command_hint`, and `task_key`.
- Keep the first non-meta segment in a source session-addressable by assigning a fallback `command_hint="session"` only when no stronger route hint exists.
- Keep the archive fail-open by logging and continuing on per-source sync failures instead of aborting the whole queue.
- Default rebuild scope is `rebuild --since 30d`; use broader backfills only when old transcripts are required.
- Default retention cleanup is `prune --older-than 365d`; treat shorter windows as a data-retention decision.
- Keep search results quote-worthy by default; use broader retrieval only for explicit recall sweeps.
- Default meta exclusion stays on; use `--include-meta` only when wrapper or local-command evidence is the target.
- Store session-wiki pages under `wiki/<project_slug>/<page_type>/<slug>.md`, where `page_type` directories are `components`, `topics`, `decisions`, or `patterns`.
- Use `[SA<n>]` citations for session-wiki pages, and keep `[S<n>]` reserved for PA librarian output.
- Group wiki promotion candidates by `task_key`, then `component_hint`, then `topic`.

## Reference Map

| Reference | Purpose And Load Guidance |
|-----------|---------------------------|
| `${CLAUDE_SKILL_DIR}/references/archive-schema.md` | Defines the SQLite schema, segment rules, source fields, ignored raw record types, local-command detection, and session anchor rule; load when designing schema extensions, adding new `segment_kind` values, changing parsing behavior, or debugging why a raw record was dropped |
| `${CLAUDE_SKILL_DIR}/references/retrieval-contract.md` | Defines the search, get, and status contract plus Phase 2 PA and RnD integration boundaries; load when implementing the PA `session` lane, wiring RnD prior-work hints, changing search API arguments, or checking fail-open retrieval behavior |
| `${CLAUDE_SKILL_DIR}/references/wiki-schema.md` | Defines the session-wiki page schema, citation markers, grouping cascade, segment thresholds, and proposal bundle layout; load before designing or reviewing wiki promotion changes |
| `${CLAUDE_SKILL_DIR}/references/wiki-gate.md` | Defines the proposal-only gate, preimage hash check, ledger append sequence, reversal hints, and fail-open rules; load before implementing or reviewing any wiki write path |

## See Also

These components are the most likely producers, consumers, and integration targets for the archive.

| Component | Relationship |
|-----------|--------------|
| `scripts/session-archive.sh` | CLI wrapper around this skill; `init` creates `index.sqlite`, `queue.jsonl`, `state.json`, and `settings.json`; `status` reports `schema_version=1`; `sync` drains successful queue entries idempotently; `search` keeps meta segments excluded by default; `get` returns neighboring visible segments without thinking content |
| `hooks/session-archive-ingest.sh` | Phase 1 enqueue-only producer for the archive queue; returns exit code `0` even when the transcript path is missing or unwritable |
| `scripts/learning-lib.sh` | Source of `learning_extract_route_hint` reused for `component_hint`, `command_hint`, and `task_key` |
| `agents/pa/librarian.md` | Phase 2 consumer that will add a fail-open `session` retrieval lane searching the current project by default and contributing supporting citations only |
| `commands/rnd.md` | Phase 2 consumer that will query the archive before external collection to surface prior attempts, abandoned frames, and unresolved objections as advisory context only |
| `session-wiki` | Live Phase 3 promotion tier under `${CLAUDE_PLUGIN_DATA}/session-archive/wiki/`; use `wiki-schema.md` and `wiki-gate.md` now, and route through upcoming `commands/session-wiki.md` once Stage 3c lands |

## Wiki Promotion

### Core Rule

Wiki pages are proposals until a user approves them, and the raw archive never changes when a wiki page is approved or rejected.

### Workflow Steps

1. Build candidate segment groups with the Stage 3b proposal tooling.
2. Write proposal bundles under `${CLAUDE_PLUGIN_DATA}/session-archive/proposals/`.
3. Review proposals with the future `/session-wiki show <id>` flow.
4. Promote only through the future `/session-wiki apply <id>` flow after the preimage hash check passes.

Full procedure lives in `references/wiki-gate.md`.

### Notes

The Stage 3c synthesis agent is `core/session-synthesizer`.
QMD collection registration for `session-wiki` is manual only.
