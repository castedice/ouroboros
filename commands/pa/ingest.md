---
name: pa:ingest
description: "Use when you need to bring external content into your vault and turn it into usable notes"
effort: medium
allowed-tools:
  - Read
  - Agent
  - Write
  - Edit
  - Bash
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__status
argument-hint: "<URL, pasted text, or file path>"
---

# Ingest — External Content Import

Import external content into the vault as a source-aware digest note. Normalizes the input into a source-packet, runs deduplication, and renders an ingest-digest note with provenance.

Input: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 3 | curator (agent, sonnet) | Triage source-packet — classify, extract durable units, detect duplicates |
| 4 | librarian (agent, sonnet) | QMD deduplication — search for existing notes that overlap with the ingest |
| 2 | Read (tool) | Load vault-profile.json, settings.json, source file (if file/image import) |
| 2 | Bash (tool) | Run `pa-extract.sh` for document extraction, `pa-youtube.sh` for YouTube transcript/metadata |
| 5 | Write (tool) | Create ingest-digest note in vault |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass source-packet contents, extracted text, and inline state explicitly on every call.
Use named return payloads rather than prose-only summaries.
The command owns digest rendering, note writes, tracker updates, and dirty-path state.
Internal calls use `Agent(subagent_type: "ouroboros:pa:curator")` and `Agent(subagent_type: "ouroboros:pa:librarian")`.
Phase 5 digest rendering stays command-local and must emit named fields before any write.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:curator` | 3 | `raw_content`, `source_packet`, `vault_profile`, `settings`, and optional entity or session state | `triage_report`, `routing_decision`, `extracted_items`, `title_seed`, and `resolved_entities[]` |
| `ouroboros:pa:librarian` | 4 | curator triage result, provenance, QMD status, `settings`, and `vault_profile` | `duplicate_status`, `candidate_notes[]`, `net_new_delta`, and `limitation_note` |
| `command-local digest render` | 5 | curator triage result, deduplication result, `vault_profile`, posture, and template inputs | `rendered_note`, `target_path`, `frontmatter`, and `tracker_entry` |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Naming rules, placement, frontmatter, linking style |
| `.pa/settings.json` | read | Vault path, collection name, posture |
| `.pa/entities.json` | read | Coreference authority for curator entity resolution |
| `.pa/sessions/{id}.json` | read+write | Ephemeral session entity state with `recent_entities` and pending `unresolved_entities` |
| `.pa/integrations-state.json` | read | Check last sync freshness |
| `.pa/derivation-state.json` | write | Record dirty path for new note |
| `.pa/ingest-tracker.jsonl` | append | Track ingested items for reflection follow-up and consumption compilation |
| `.pa/raindrop-queue.jsonl` | read+append | Read next pending entry, append ingested/skipped event |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No input argument | 1 | Ask: "어떤 외부 콘텐츠를 vault에 가져올까요? URL, 텍스트, 또는 파일 경로를 입력해주세요." |
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| `--source raindrop` but no token configured | 1 | Abort: "Raindrop API token이 없습니다. `bash scripts/pa-raindrop.sh config --token <token>`으로 설정해주세요." |
| Input is a YouTube URL | 2 | YouTube path — extract transcript and metadata via `pa-youtube.sh` |
| Input looks like a URL (http/https, non-YouTube) | 2 | URL path — fetch content, normalize as source-packet |
| Input is a document file (.pdf, .docx, .pptx, .epub) | 2 | Document path — extract via `pa-extract.sh`, normalize as source-packet |
| Input is an image file (.png, .jpg, etc.) | 2 | Image path — describe via Claude vision (Read tool) |
| Input looks like a file path (.md, .txt) | 2 | File path — read file, normalize as source-packet |
| Input is plain text (no URL, no file extension) | 2 | Paste path — treat as pasted article/excerpt |
| `--source raindrop` but queue empty after sync | 2 | Inform: "새로운 북마크가 없습니다." and exit gracefully |
| WebFetch fails for URL | 2 | Graceful degradation — create stub note with URL metadata only |
| Document extraction fails | 2 | Graceful degradation — create stub note with file metadata only |
| YouTube transcript fails (no subs + no mlx-whisper) | 2 | Graceful degradation — create stub note with video metadata only |
| QMD unavailable | 4 | Skip deduplication, warn user |
| Duplicate detected (overlap ≥ 0.8) | 4 | Route to `existing-note-proposal` — extract net-new delta only |
| Posture is `observe` or `propose` | 5 | Present proposal without writing |
| Posture is `apply-low-risk` or higher | 5 | Write the ingest-digest note |

### Output Contracts

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `digest-written` | Normal ingest digest was written | Full `templates/pa/ingest-digest.md` render, written path, posture or gate line, and next actions |
| `digest-proposal` | Posture or declassification blocked the write | Full digest render, proposed path, explicit blocking reason, and exact proposal-only status |
| `stub-written` | Fetch or extraction failed but ingestion still produced a note | Minimal digest using `templates/pa/ingest-digest.md` with frontmatter or provenance, `## Acquisition Status`, `## Metadata`, optional `## Extracted Signals`, and `## Retry Notes` |
| `existing-note-proposal` | Deduplication routed to an existing note | Existing note path, duplicate rationale, net-new delta, and no-new-note decision |
| `tracker-only` | Reflection or evening follow-up records state without editing a digest note | Conversation output plus an explicit note that only `.pa/ingest-tracker.jsonl` was updated |
| `abort` | Setup or delegated work failed before a renderable note exists | Short error with the failed phase, exact reason, and the next recovery command or retry suggestion |

### Recovery

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Source normalization or extraction | 1 extractor attempt per source path + 1 stub fallback | The same extractor failure recurs, or a second attempt would use the same unavailable tool | Stop retrying and route to `stub-written` or `digest-proposal` |
| Curator triage | 1 full attempt + 1 timestamp-note downgrade | The retry returns the same timeout or low-confidence class | Stop retrying and use the downgraded route or abort if no renderable packet exists |
| Deduplication | 1 full lookup + 1 title-seed-only retry | The retry returns the same QMD failure or no additional candidate coverage | Stop retrying, mark the semantic dedup limitation, and continue without further lookup |
| Reflection follow-up | 1 immediate prompt only | The user skips, or the note path is not writable or not present | Record tracker-only state and do not re-prompt inside the same invocation |


## Phase 1: Parse Input

Extract the source from `$ARGUMENTS`. Determine source type and format:

| Pattern | Source Type | Source Format |
|---------|------------|--------------|
| YouTube URL (`youtube.com/watch`, `youtu.be/`, `youtube.com/shorts/`, `youtube.com/live/`) | `youtube` | `youtube` |
| Starts with `http://` or `https://` (non-YouTube) | `url` | — |
| Ends with `.pdf` | `file` | `pdf` |
| Ends with `.docx` | `file` | `docx` |
| Ends with `.pptx` | `file` | `pptx` |
| Ends with `.epub` | `file` | `epub` |
| Ends with `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.tiff`, `.tif` | `file` | `image` |
| Ends with `.md`, `.txt`, or contains path separators | `file` | — |
| `--source raindrop` flag or `--source raindrop --id <id>` | `url` (via connector) | — |
| Everything else | `paste` | — |

If no argument provided, ask per the Decision Matrix.

## Phase 2: Source-Packet Normalization

Check vault maturity per `skills/pa/trust-and-boundaries/references/vault-maturity.md`.
If below `intermediate`, present guidance and suggest `/pa capture`.
Continue regardless.
Guidance is advisory.

Normalize the input into a uniform source-packet per `skills/pa/content-pipeline/references/source-packet-schema.md`. The packet is the contract between the command and the curator.
Read `.pa/entities.json` when present and derive the active `session_id` plus `.pa/sessions/{session_id}.json` before curator delegation.
If the session file is missing, initialize an in-memory session object with empty `recent_entities` and `unresolved_entities` arrays.

Handle source type variations:

| Source Type | Source Format | Normalization |
|-------------|--------------|---------------|
| `url` | — (`--source raindrop`) | Run `Bash: scripts/pa-raindrop.sh pull --next` to get next pending queue entry. If no pending items and queue is stale (> 24h since last sync per `.pa/integrations-state.json`), run `Bash: scripts/pa-raindrop.sh sync` first, then retry pull. Build source-packet: `source_type: url`, `source_url: entry.link`, include highlights as `> quote` blocks prepended to `raw_content`. Fetch full content via sonnet agent with WebFetch, append after highlights. `metadata: {connector: "raindrop", bookmark_id, service_tags: entry.tags, collection_name, highlights_count}`. After successful render+write, append `{"event":"ingested","recorded_at":"...","bookmark_id":...,"note_path":"..."}` to `.pa/raindrop-queue.jsonl`. If dedup detects duplicate, append `{"event":"skipped","recorded_at":"...","bookmark_id":...,"reason":"duplicate"}` |
| `url` | — | Fetch content via a sonnet agent with WebFetch. Build packet with `source_url`, fetched content as `raw_content` |
| `file` | — (`.md`, `.txt`) | Read file directly. Build packet with `source_path`, file content as `raw_content` |
| `file` | `pdf`, `docx`, `pptx`, `epub` | Run `Bash: scripts/pa-extract.sh extract <path>` to get markdown. Build packet with `source_path`, extracted text as `raw_content`, `extractor` from tool used. If extraction fails, create stub note with file metadata |
| `file` | `image` | Use Read tool on the image file (Claude vision). Build packet with `source_path`, vision description as `raw_content`, `extractor: "claude-vision"` |
| `youtube` | `youtube` | Run `Bash: scripts/pa-youtube.sh metadata <url>` for video info, then `Bash: scripts/pa-youtube.sh transcript <url>` for transcript. Build packet with `source_url`, transcript as `raw_content`, video metadata in `metadata` field. If transcript fails (no subs + no mlx-whisper), create stub note with metadata only |
| `paste` | — | Use the full argument text as `raw_content` |

For document and YouTube extraction, check `.pa/settings.json` `content_pipeline.extractors` for tool availability. If not present, run the extraction anyway — the scripts handle tool detection internally.

### Temporal Enrichment

After the base packet is assembled, inspect source metadata and `raw_content` for temporal signals using `skills/pa/content-pipeline/references/temporal-grounding.md`.
Populate `document_date` from the strongest artifact-date signal available, such as file mtime, page publish date, YouTube `publish_date`, or `fetch_date` as the last fallback.
Populate `event_date_start`, `event_date_end`, `event_date_precision`, and `temporal_confidence` when the source contains explicit calendar dates, timestamps, or relative references that can be grounded safely.
When the content uses relative references such as `yesterday`, `last week`, `어제`, or `지난 주`, back-calculate against `document_date`, not the current clock.
If no reliable temporal signal exists, leave the five temporal fields absent or `null`.

## Phase 3: Curator Triage

> Agent: **curator**

Delegate source-packet triage to the curator agent.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | source-packet, vault-profile.json contents, settings.json contents, optional `entities_registry` from `.pa/entities.json`, and optional `session_state` from `.pa/sessions/{session_id}.json` |
| Instructions | Apply `skills/pa/capture-distillation/SKILL.md` workflow. Classify `input_form` as `source-digest`. Extract durable units (claims, tasks, decisions). Preserve and refine the source-packet temporal fields when the text supports them. Route to `ingest-digest` for high-confidence sources or `timestamp-note` for low-confidence. Apply `references/triage-taxonomy.md` for routing. Apply `references/distillation-rules.md` for extraction and provenance preservation. When entity mentions are present and `entities_registry` is available, run the lightweight coreference pass from `skills/pa/personal-ontology/references/coreference-rules.md` and return both `resolved_entities` and `unresolved_entities` |
| Expected Output | Triage report with classification, extracted units, temporal grounding, resolved and unresolved entities, routing decision, and title seed |

### Recovery

| Failure | Action |
|---------|--------|
| Curator timeout | Report error, suggest retrying |
| Curator returns low confidence | Route to `timestamp-note` fallback |

## Phase 4: Deduplication Check

> Agent: **librarian**

Delegate duplicate assessment to the librarian instead of scoring overlap inline.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | curator triage result with title seed, key phrases, source-packet provenance, routing decision, settings.json contents, vault-profile.json contents, and QMD availability or collection status |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` only for deduplication-scoped lookup. Search for existing notes that materially overlap the ingest, compare candidate note content conservatively, and return either `duplicate_status: none` or an `existing-note-proposal` with the net-new delta. When QMD is unavailable, return `duplicate_status: unverified-no-qmd` without attempting semantic scoring. Do not write files |
| Expected Output | Deduplication report with `duplicate_status`, candidate existing notes with paths and confidence, optional `net_new_delta`, and any limitation note |

### Recovery

| Failure | Action |
|---------|--------|
| QMD unavailable before lookup starts | Skip semantic deduplication, set `duplicate_status: unverified-no-qmd`, and continue |
| Librarian timeout or QMD/tool failure | Retry once with title seed only and no secondary key phrases |
| Retry returns the same failure class or no additional coverage | Stop retrying, keep the `unverified-no-qmd` limitation, and continue without semantic deduplication |

If the deduplication report returns `duplicate_status: likely`, route to `existing-note-proposal`, present the existing note plus the net-new delta, and do not create a duplicate note.
Otherwise continue to Phase 5.

## Phase 5: Render and Write

### Posture Check

Apply posture check per `skills/pa/trust-and-boundaries/SKILL.md`. Single note creation is a low-risk write — allowed at `apply-low-risk` or higher.

### Declassification Gate

Before writing, run `scripts/pa-write-safe.sh inspect` on the rendered content. If `write_safe: false`, downgrade to proposal-only with blocking reason. If no mask-map exists, skip. Include `declassification` metadata in the ledger entry.

### Rendering

1. Read `templates/pa/ingest-digest.md` and apply its rendering rules.
2. Apply vault-profile conventions: `naming_rules`, `placement_rules`, `frontmatter`, `linking_style`.
3. Render `document_date`, `event_date_start`, and `event_date_end` alongside existing source-specific temporal metadata such as YouTube `publish_date` when those fields are present.
4. Place the note in `placement_rules.clippings_dir` (for URL/paste) or `placement_rules.authored_root` (for file imports).

### Output Example

```markdown
---
source_url: https://example.com/article
source_title: "Understanding Meta-Prompts"
source_type: url
ingested: 2026-03-17
document_date: 2026-03-15
event_date_start: 2026-03-14
event_date_end: 2026-03-14
tags: [meta-prompts, AI]
---

# Understanding Meta-Prompts

> Ingested: 2026-03-17 | Source: url | Confidence: high

## Summary

Meta-prompts are system-level instructions that shape AI behavior...

## Key Claims

- Claim 1 from the article
- Claim 2 from the article

## Related Notes

- [[meta-prompts-moc]] — existing MOC on the same topic

## Source Excerpt

> "The key insight is that meta-prompts operate at a layer above..."

---
Source: https://example.com/article
```

### State Update

After writing, record the new note path as a dirty_path entry in `.pa/derivation-state.json`: `{path: "{ingest_note_path}", event: "ingest", content_hash: "{sha256_first_8}", queued_at: "{ISO_timestamp}", shadow_status: "pending", ontology_status: "pending"}`.
After ingestion completes, rewrite `.pa/sessions/{session_id}.json` with merged session entity state.
Append curator `resolved_entities` to `recent_entities` in most-recent-first order, dedupe by `entity_id` or `canonical_name`, and cap the list at `25`.
Carry forward `unresolved_entities` with `status: "pending_review"` so later curator, weaver, steward, and heartbeat passes can surface them.

## Phase 6: Present and Reflect

Output the rendered digest in conversation regardless of whether it was written to the vault.

### Reflection Prompt (Consumption Journaling)

Apply the post-ingest and evening-follow-up contract from `skills/pa/content-pipeline/references/reflection-prompts.md` instead of restating the tracker procedure inline.

1. Select and present the immediate reflection prompt using the `source_shape` rules in that reference.
2. Classify the user's response using the reference's skip keywords and substantive-response rules.
3. When the response is substantive and the note exists, append `## My Thoughts` via Edit and append the corresponding tracker row.
4. When the response is skipped or the note was only proposed, append the tracker row only and keep the follow-up eligible for `/pa day --mode evening`.
5. Use the reference's append-only `latest-entry-per-path` rule unchanged.

`.pa/ingest-tracker.jsonl` remains the authoritative tracker defined in the main State Contract above.
Do not restate a second tracker schema in this phase.

### Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Related notes found | "`/pa link {ingest_note_path}` — connect the new note to existing vault content" |
| Duplicate detected | "기존 노트 [[{existing}]]에 새 내용을 추가하려면 말씀하세요" |
| Stub created (fetch failed) | "URL에 다시 접근하려면 `/pa ingest {url}`을 재시도하세요" |
| Low confidence answer | "Add more notes on this topic, or try `/pa brief {ingested_topic}`" |

## Composability

| Context | Usage |
|---------|-------|
| `/pa capture` | Capture handles user-generated content, ingest handles external content — complementary |
| `/pa compile` | Ingest digests are eligible compilation sources within their period |
| `/pa link` | After ingest, link discovers connections for the new note |
| `/pa brief` | Brief can synthesize across ingested sources |
| `/pa` router | Router classifies ingest intent and delegates here (always deep path) |
| `pa-scheduler.sh` | Nightly `raindrop-sync` schedule fills the queue; `/pa ingest --source raindrop` processes one item |
| `skills/pa/content-pipeline/SKILL.md` | Source-packet contract, format detection, extractor selection for document/YouTube/image |
| `skills/pa/content-pipeline/references/connector-contracts.md` | Queue entry schema and source-packet mapping for bookmark connectors |

## Rules

- **Single note per invocation**: Ingest creates one digest note (or one stub, or one proposal). No batch ingest in Phase 6
- **Provenance mandatory**: Every ingest note must have `source_url` or `source_path` or "user-pasted text" attribution
- **Dedupe before write**: Always check for duplicates before creating a new note (unless QMD unavailable)
- **No full reproduction**: For URL sources, extract claims and key passages — do not reproduce the full article
- **Graceful degradation**: URL fetch failure produces a stub, not an error
- **Vault-profile faithful**: Respect naming, placement, frontmatter, and linking conventions
