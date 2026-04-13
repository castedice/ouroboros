# Query Patterns — Intent Classification, QMD Templates, and Compression Guidelines

> Purpose: Detection and execution reference for `context-assembly` — use it to classify question intent, select QMD sub-query strategies, and apply compression rules. This reference is standalone and can be consulted without the parent skill. For the end-to-end retrieval procedure, see `skills/pa/context-assembly/SKILL.md`.

## Scope

This reference covers three concerns: how to classify what the user is asking, how to translate that classification into QMD queries, and how to compress the results for LLM context. It does not cover citation formatting (handled in the parent skill) or vault-profile interpretation (handled by `vault-modeling`).

## Intent Classification

Classify the user's input before planning any query. The intent drives sub-query selection, k value adjustment, and compression depth.

### Classification Signals

| Intent | Trigger Phrases | Structural Cues | Example Questions |
|--------|----------------|------------------|-------------------|
| `factual` | "what is", "where is", "find", "show me" | References a specific note, name, or term | "What's in my reading list?", "Find notes about Python" |
| `conceptual` | "how does", "why", "what's the relationship", "compare" | Asks about connections or reasoning between entities | "How do these projects relate?", "Why did I choose this approach?" |
| `dossier` | "brief me on", "tell me about", "what do I know about" | Subject is a person, project, topic, or area | "Brief me on Project Alpha", "What do I know about machine learning?" |
| `temporal` | "today", "this week", "recently", "last month", "what changed", "prior decision", "previous attempt", "regression", "we already discussed", "last time", "dead end", "abandoned branch", "unresolved objection" | References time periods, recency, or prior conversation state | "What happened this week?", "What did I write recently?", "What was the abandoned branch last time?" |
| `exploratory` | "what's in my vault", "explore", "everything about", "overview" | Broad scope, discovery-oriented | "What topics are in my vault?", "Give me an overview of my notes" |
| `neighborhood` | "related to", "connected to", "links to", "neighbors of" | Subject is a note or entity, asks about connections | "What's related to my meta-prompts MOC?", "What connects to this note?" |
| `graph` | "related to {entity}", "connected to {entity}", "{entity}의 관계", "{entity} 연결" | Subject resolves to a known ontology entity and asks for graph context | "What's related to Project Alpha?", "Project Alpha와 연결된 것은?" |

### Disambiguation Rules

When a question matches multiple intents:

| Ambiguity | Resolution |
|-----------|------------|
| "What do I know about X?" — factual or dossier? | **dossier** — implies a comprehensive briefing, not a single fact |
| "What changed about X recently?" — temporal or dossier? | **temporal** — time reference takes priority |
| "Tell me everything about X" — dossier or exploratory? | **exploratory** — "everything" signals broad discovery |
| "Find notes about X from last week" — factual or temporal? | **temporal** — time constraint narrows the search |
| "How is X doing?" — conceptual or dossier? | **dossier** — asks for status, not relationships |
| "What's related to X?" — neighborhood or dossier? | **neighborhood** — asks about connections, not comprehensive briefing |
| "What's related to X?" — graph or neighborhood? | **graph** when X resolves to a known ontology entity, otherwise **neighborhood** |

When still ambiguous after applying these rules, prefer the broader category.

## QMD Query Templates

### Sub-Query Type Reference

| Type | QMD Parameter | Strength | Best For |
|------|--------------|----------|----------|
| `lex` | `type: 'lex'` | Exact term matching, fast, precise | Known names, titles, specific terms |
| `vec` | `type: 'vec'` | Semantic similarity, meaning-based | Conceptual questions, topic exploration |
| `hyde` | `type: 'hyde'` | Hypothetical document embedding | Complex questions where the answer shape is predictable |

### Intent-to-Strategy Matrix

| Intent | Primary Sub-Queries | Hyde | Session | k Multiplier | minScore |
|--------|-------------------|------|---------|---------------|----------|
| `factual` | lex (exact terms) + vec (semantic expansion) | off | optional when prior-context triggers match | 1.0x | 0.30 |
| `conceptual` | vec (semantic) + hyde (ideal answer passage) | on | optional when prior-context triggers match | 1.0x | 0.25 |
| `dossier` | lex (subject name) + vec (subject role/context) | on | secondary | 1.25x | 0.25 |
| `temporal` | lex (date patterns, "YYYY-MM-DD") + vec (activity terms) | off | primary for prior-conversation recall, otherwise secondary | 1.0x | 0.20 |
| `exploratory` | vec (topic terms) + hyde (overview passage) | on | secondary | 1.5x | 0.20 |
| `neighborhood` | lex (entity name) + vec (entity context + "related") | off | off | 1.5x | 0.20 |
| `graph` | graph-seeded candidate notes + vec (entity context + neighbors) | off | off | 1.5x | 0.20 |

## Multi-lane Retrieval

The librarian uses a 4-lane broker architecture for comprehensive retrieval.

| Lane | Source | Decay | Purpose |
|------|--------|-------|---------|
| Literal | QMD lex | None | Exact matches — names, tags, paths |
| Semantic | QMD vec or hyde | Mild (`half_life=180d`, `floor=0.55`) | Conceptual similarity |
| Situational | Temporal windows plus `graph_context` | Strong, horizon-dependent for temporal intent | Recency bias and entity relationships |
| Session | `scripts/session-archive.sh search` | None | Prior conversation recall |

### Temporal Decay Formula

```text
decayed_score = base_score * max(floor, 0.5 ^ (days / half_life))
```

| Context | half_life | floor |
|---------|-----------|-------|
| Semantic lane (all intents) | 180 days | 0.55 |
| Situational lane (today horizon) | 3 days | 0.80 |
| Situational lane (week horizon) | 7 days | 0.80 |
| Situational lane (month horizon) | 30 days | 0.80 |
| Literal lane | ∞ (no decay) | 1.0 |

### Fusion Rules

1. Rank each lane independently after lane-local adjustment and decay.
2. Apply heterogeneous reciprocal-rank fusion by rank across literal, semantic, situational, and session lanes.
3. Use `rrf_score = sum(1 / (k_rrf + rank_in_lane))`, with `k_rrf=60`, across every lane that returned the item.
4. Use note path as the item key for vault lanes and `segment_id` as the item key for the session lane.
5. Deduplicate vault results by note path and keep the fused rank score plus the best adjusted score for display.
6. Do not apply a vault/session cross-lane bonus, because session segments and vault notes are different item namespaces.
7. Apply the diversity filter with a maximum of 2 notes per folder to vault results only.
8. Render vault results under `### Retrieved Documents` and session results under `### Session Hits`.

### Session Query Construction

Use the session lane only through the read-only `search` and `status` actions.
The default search command is:

```text
bash scripts/session-archive.sh search "{question}" --project current --agent main --top {k} --format json
```

Default `k` is 3 and default `max_excerpt_chars` is 400.
Default filters are `project=current`, `agent=main`, no `since`, no `component`, and `include_meta=false`.
Profile overrides may set `filters.project`, `filters.agent`, `filters.since`, `filters.component`, and `filters.include_meta`.
If the archive is missing, empty, or returns a command error, set `session_lookup.status` to `unavailable` or `no_hits` and continue with normal QMD retrieval.

### Retrieval Profiles Schema

Document the nested `session_lane` object in `.pa/retrieval-profiles.json` without editing `.pa/` runtime files directly.

```json
{
  "ask": {
    "session_lane": {
      "enabled": true,
      "k": 3,
      "max_excerpt_chars": 400,
      "filters": {
        "project": "current",
        "since": "30d",
        "agent": "main",
        "component": null,
        "include_meta": false
      }
    }
  },
  "brief": {
    "session_lane": {
      "enabled": true,
      "k": 3,
      "max_excerpt_chars": 400,
      "filters": {
        "project": "current",
        "agent": "main"
      }
    }
  },
  "day": {
    "session_lane": {
      "enabled": false
    }
  }
}
```

Missing `session_lane` uses the intent-based default.
`enabled=false` disables the lane for that command.
`enabled=true` forces the lane on even when the intent mapping would normally keep it off.
The `day` command defaults to `session_lane.enabled=false`; users can opt in by setting it to true in the profile.

### Query Construction Examples

**Factual** — "What's in my reading list?"
```json
{
  "searches": [
    {"type": "lex", "query": "reading list"},
    {"type": "vec", "query": "reading list books to read recommendations"}
  ],
  "intent": "find notes about reading list",
  "collection": "engram"
}
```

**Conceptual** — "How do my meta-prompts relate to each other?"
```json
{
  "searches": [
    {"type": "vec", "query": "meta prompts relationships connections between prompts"},
    {"type": "hyde", "query": "The meta prompts in this vault are connected through shared themes and complementary purposes. Several prompts build on each other to form a coherent system."}
  ],
  "intent": "understand relationships between meta-prompt notes",
  "collection": "engram"
}
```

**Dossier** — "Brief me on meta-prompts"
```json
{
  "searches": [
    {"type": "lex", "query": "meta-prompts"},
    {"type": "vec", "query": "meta-prompts system purpose design methodology"}
  ],
  "intent": "comprehensive briefing on meta-prompts topic",
  "collection": "engram"
}
```

**Temporal** — "What did I write this week?"
```json
{
  "searches": [
    {"type": "lex", "query": "2026-03-09 2026-03-10 2026-03-11 2026-03-12 2026-03-13 2026-03-14 2026-03-15"},
    {"type": "vec", "query": "recent notes written this week new content"}
  ],
  "intent": "find notes created or modified this week",
  "collection": "engram"
}
```

**Neighborhood** — "What's related to my meta-prompts MOC?"
```json
{
  "searches": [
    {"type": "lex", "query": "\"meta-prompts\" moc"},
    {"type": "vec", "query": "meta-prompts MOC related notes connections links"}
  ],
  "intent": "find notes related to or connected with meta-prompts MOC",
  "collection": "engram"
}
```

**Exploratory** — "What topics are in my vault?"
```json
{
  "searches": [
    {"type": "vec", "query": "main topics themes areas of knowledge"},
    {"type": "hyde", "query": "This vault covers several key topics including personal knowledge management, project planning, and reference materials organized across different areas."}
  ],
  "intent": "discover main topics and themes in the vault",
  "collection": "engram"
}
```

### Hyde Passage Guidelines

When composing a hyde passage for `type: 'hyde'`:

1. Write 30-50 words describing what an ideal answer note would contain.
2. Use neutral, factual language — do not embed assumptions about the answer.
3. Include domain-relevant vocabulary that would appear in a real vault note.
4. Do not include the user's question verbatim — rephrase as a statement.

**Good hyde**: "The meta-prompts in this vault are connected through shared themes and complementary purposes. Several prompts build on each other to form a coherent system."

**Bad hyde**: "The answer is that meta-prompts are definitely related because the user said so and they are very important." (Speculative, opinionated, not note-like.)

## Compression Guidelines

### Excerpt Length Targets

| Note Size | Compression Strategy |
|-----------|---------------------|
| < 200 words | Include full content — no compression needed |
| 200-1000 words | Extract 1-3 relevant sections (100-300 words total) |
| > 1000 words | Extract the most relevant section only (200-300 words) |

### Section Extraction Rules

1. **Heading-guided**: Prefer complete heading-delimited sections. Include the heading as context.
2. **Paragraph-guided**: When headings are absent, extract complete paragraphs that contain query-relevant terms.
3. **Boundary markers**: Use `...` to indicate omitted content between excerpts from the same document.
4. **Frontmatter selection**: Include only query-relevant frontmatter fields. Always include `tags` if present. Strip `created`, `updated`, and other metadata unless the query is temporal.
5. **List items**: When a list partially matches, include the relevant items plus 1 surrounding item for context.

### What to Preserve

- Wikilinks (`[[note name]]`) — they carry semantic relationships
- Code blocks — if the query involves technical content
- Block quotes — often contain key insights
- Markdown formatting (bold, italic, headers) — carries emphasis meaning

### What to Strip

- Irrelevant frontmatter fields (dates, aliases, unless query-relevant)
- Boilerplate sections (table of contents, navigation footers)
- Duplicate content (same paragraph appearing in multiple retrieved notes)
- Image embed syntax (`![[image.png]]`) unless the query is about images

## Edge Cases

| Situation | Handling |
|-----------|----------|
| Vault has < 5 notes | Set k = total note count; skip diversity filter; include all results |
| Query is about PA itself ("how does PA work?") | Not a vault retrieval question — caller should answer from knowledge |
| Query language differs from vault language | QMD vec handles cross-lingual similarity; lex may miss — prefer vec-heavy strategy |
| Query contains a note title in wikilink syntax | Extract the title from `[[...]]` and add as lex query term |
| All results from one folder | Allow if the query naturally scopes to that folder; otherwise warn about narrow coverage |
| Query term contains hyphens (e.g., "meta-prompts") | QMD interprets bare hyphens as negation across all query types (lex, vec, hyde). For lex: wrap in double quotes (`"meta-prompts"`). For vec/hyde: replace hyphens with spaces (`meta prompts`) |
| QMD collection not registered | Cannot proceed — report error and suggest `/pa survey` |
