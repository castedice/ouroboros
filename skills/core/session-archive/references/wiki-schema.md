# Session Wiki Schema

Purpose: Define the Stage 3 session-wiki page shape, citation format, grouping rules, and proposal bundle layout.
Scope: Reference document only, not a skill.

## Storage And Paths

| Field | Rule |
|-------|------|
| Storage root | `${CLAUDE_PLUGIN_DATA}/session-archive/` |
| Wiki dir | `${CLAUDE_PLUGIN_DATA}/session-archive/wiki/` |
| Proposals dir | `${CLAUDE_PLUGIN_DATA}/session-archive/proposals/` |
| QMD collection | `session-wiki` |
| QMD registration | Manual only, never auto `qmd collection add` from `init` or any archive action |
| Wiki page path | `wiki/<project_slug>/<page_type>/<slug>.md` |
| Page type dirs | `components`, `topics`, `decisions`, `patterns` |

## Page Frontmatter

| Key | Type | Rule |
|-----|------|------|
| `session_wiki_schema` | integer | Use `1` for Phase 3 pages |
| `title` | string | Human title, 60 characters or fewer |
| `wiki_key` | string | `<page_type>/<slug>` using the singular page key family, for example `components/scripts-session-archive` |
| `page_type` | string | Singular frontmatter value `component`, `topic`, `decision`, or `pattern` |
| `project_slug` | string | Same project slug used by Phase 1 archive sources |
| `component_hints` | array of strings | Component paths or commands supporting the page |
| `task_key` | string or null | Task grouping key when available |
| `topic_terms` | array of strings | Topic terms used for recall and drift checks |
| `status` | string | `active`, `superseded`, or `stale` |
| `confidence` | string | `high`, `medium`, or `low` |
| `created_at` | UTC timestamp string | Creation time from `learning_timestamp_utc` |
| `updated_at` | UTC timestamp string | Last page update time from `learning_timestamp_utc` |
| `last_verified` | UTC timestamp string | Last lint or apply verification time from `learning_timestamp_utc` |
| `proposal_id` | string | Proposal bundle id that produced the page |
| `approved_by` | string | Always `user` in Phase 3 |
| `generated_by` | string | Always `ouroboros-session-wiki` for generated pages |
| `source_session_ids` | array of strings | Session ids cited by the page |
| `source_segments` | array of strings | Raw archive `segment_id` values cited by the page |
| `agent_kind_mix` | object | Counts by `main` and `subagent` segment kind |

## Body Skeleton

| Section | Content Rule |
|---------|--------------|
| `# <title>` | Match the frontmatter `title` |
| `## Summary` | Use 1-3 short paragraphs with dense `[SA<n>]` citations |
| `## Current Synthesis` | Store the durable synthesized knowledge in bullets or concise paragraphs |
| `## Decisions and Dead Ends` | Preserve terminal decisions, rejected approaches, and abandoned frames |
| `## Open Questions` | List explicit gaps rather than inventing closure |
| `## Related Pages` | Link only to other session-wiki pages |
| `## Source Segments` | Resolve every `[SA<n>]` marker to a raw archive segment row |

## Citation Format

Use `[SA<n>]` inline inside wiki pages.
Do not use `[S<n>]` because Phase 2 PA librarian output owns that marker family.
Each `[SA<n>]` marker must resolve through the `## Source Segments` table in the same page.
The source table columns are `Marker`, `Segment ID`, `Source Ref`, `Timestamp`, and `Snippet`.
Every factual claim in a generated page must map to at least one `segment_id` in `source_segments`.

## Page Type Typology

| Page Type Dir | Frontmatter `page_type` | Use When |
|---------------|-------------------------|----------|
| `components` | `component` | The evidence clusters around a file, command, agent, script, hook, template, or package boundary |
| `topics` | `topic` | The evidence clusters around a recurring concept that spans components without being a formal decision |
| `decisions` | `decision` | The evidence records a durable choice, rejected alternative, or design record worth finding later |
| `patterns` | `pattern` | The evidence records a reusable implementation, workflow, review, or coordination pattern |

## Grouping Cascade

1. Group by `task_key` when it is non-null.
2. For segments without `task_key`, group by `component_hint`.
3. For segments without either, try topic inference via shared `topic_terms`.
4. Drop segments that remain ungrouped.
5. Exclude pure `command_hint='session'` anchor fallback groups because thin anchors do not warrant pages.

## Segment Selection Thresholds

| Setting | Default | Rule |
|---------|---------|------|
| `min_segments` | `5` | Require at least five supporting segments before proposing a page |
| `min_sessions` | `2` | Require evidence across at least two sessions |
| `min_span_days` | `1` | Require evidence spanning at least one day |
| `min_agent_text_segments` | `1` | Require at least one `segment_kind='text'` segment from an agent |
| `include_subagents` | `true` | Include subagent segments in grouping and evidence counts |
| `is_meta` | `0` | Use visible non-meta segments by default |
| `max_pages_per_proposal` | `3` | Keep each proposal bundle reviewable |
| `hard_cap_pages` | `5` | Split candidates above five target pages into multiple proposals |

## Proposal Bundle Layout

```text
${CLAUDE_PLUGIN_DATA}/session-archive/proposals/
  PROMO-YYYYMMDD-HHMMSS-<slug>/
    manifest.json
    review.md
    bundle.json
    pages/
      <relative-wiki-target>.md
    preimage/
      <relative-wiki-target>.md
```

`manifest.json` stores proposal status, target pages, source segments, source sessions, grouping rule, synthesis confidence, `core/session-synthesizer`, and reversal hints.
`bundle.json` stores the raw segment packet sent to the synthesizer during Stage 3c.
`pages/` stores draft wiki pages that are invisible to the QMD `session-wiki` collection until `/session-wiki apply <id>`.
`preimage/` stores the previous target page only when a proposal would replace an existing wiki page.
`review.md` stores the short human-readable proposal summary shown by `/session-wiki show`.

## Promotion Boundary

Stage 3 follows DR-106 collaboration posture: propose-only, never auto-write.
Nothing lands in `wiki/` until the user explicitly applies a proposal.
Stage 3a creates schema and scaffolding only, with no LLM synthesis and no proposal action.
