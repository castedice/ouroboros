---
name: pa:brief
description: "Use when you need a concise briefing on a topic, project, person, or note cluster from your vault"
effort: low
allowed-tools:
  - Read
  - Glob
  - Grep
  - Agent
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__multi_get
  - mcp__qmd__status
argument-hint: <topic>
---

# Brief — Focus Dossier

Generate a structured briefing on a topic, project, or person by retrieving and synthesizing relevant vault content via QMD.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 3 | librarian (agent, sonnet) | Assemble context pack from vault via QMD retrieval |
| 1 | Read (tool) | Load vault-profile.json, settings.json, retrieval-profiles.json |
| 4 | Read (tool) | Load focus-brief.md template for rendering |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Retrieval defaults (k, max_docs), linking style for output |
| `.pa/settings.json` | read | Collection name, capability tier, automation posture |
| `.pa/retrieval-profiles.json` | read (optional) | Per-command retrieval overrides |
| `.pa/memory-heads.json` | read (optional) | Active facts for structured summary and source-note seeding |
| `docs/specs/project/*.md` | read (optional) | SWE Living Project Model for project-related briefs |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No topic argument | 1 | Ask the user what they want a briefing on |
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| QMD collection not registered | 2 | Abort: "QMD collection not registered. Run `/pa survey` to set up retrieval" |
| `mcp__qmd__status` check fails | 2 | Abort: "QMD is unavailable. Check QMD installation" |
| `retrieval-profiles.json` missing | 2 | Continue with vault-profile.json qmd_defaults |
| `.pa/memory-heads.json` missing or empty | 2 | Continue with QMD-only retrieval |
| Librarian returns zero results | 4 | Report: "No relevant vault content found for '{topic}'" with the queries that were tried |
| Librarian returns low confidence | 4 | Render brief with explicit low-confidence markers |
| Topic matches a specific note title | 3 | Librarian adds a lex query with the exact title |

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| Topic missing or required setup missing | 1, 2 | Ask for the topic or abort before retrieval |
| Topic resolves to a known entity | 3 | Run optional graph-context lookup and pass `graph_context` to the librarian |
| Project-model files exist and match the topic | 3 | Pass `swe_project_context` alongside normal vault retrieval |
| Weaver graph query fails or no entity match exists | 3 | Continue with QMD-only retrieval |
| Librarian returns notes plus citations | 4, 5 | Render the full template-backed brief |
| Librarian returns memory facts but no notes | 4, 5 | Render a facts-first brief with empty `Key Notes` and explicit coverage limits |
| Librarian returns zero notes and zero memory facts | 4, 5 | Render the minimal no-content brief and keep the sources table empty |
| Coverage remains low or partial | 4, 5 | Render explicit low-confidence or gap notes instead of filling gaps with model knowledge |

### Recovery

Use one bounded recovery loop for retrieval work in this command.

| Surface | Budget | Stagnation Signal | Behavior |
|---------|--------|-------------------|----------|
| Weaver graph query | 1 attempt only | The query fails, or it returns no seed entity or no candidate notes | Stop graph enrichment and continue with QMD-only retrieval |
| Librarian retrieval | 1 full attempt + 1 narrowed retry using the simplest viable query | The retry returns the same QMD failure, zero additional coverage, or the same low-confidence result | Stop retrying, report the limitation, and render the matching no-content or facts-only brief |
| User re-invocation guidance | 0 automatic retries after the bounded retrieval budget is exhausted | A further internal retry would reuse the same evidence without improving coverage | Ask the user to retry with a narrower topic or rerun the command in a new invocation |


## Phase 1: Parse Input

Extract the topic from `$ARGUMENTS`.

The topic is a free-text string — it can be a person name, project name, subject area, or any vault-relevant concept. Do not restrict to predefined categories.

If no topic is provided, ask the user: "What topic would you like a briefing on?"

## Phase 2: Load State

1. Read `.pa/settings.json` from the vault path stored in settings.
2. Read `.pa/vault-profile.json` for retrieval defaults and linking style.
3. Read `.pa/retrieval-profiles.json` for per-command overrides — if the file does not exist, fall back to `vault-profile.json` → `qmd_defaults`.
4. Verify QMD availability by checking `mcp__qmd__status` for the registered collection.
5. Read `.pa/memory-heads.json` if it exists — load active facts for topic- or entity-level briefing. If missing or empty, continue with QMD-only retrieval.
6. Read `.pa/soul.md` — load soul layer (frontmatter for render settings, body for soul context). If missing, read `.pa/persona.json` as fallback (render only). If both missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.

If any required state file is missing, abort per the Decision Matrix.

## Phase 3: Librarian Delegation

> Agent: **librarian**

Delegate context assembly to the librarian agent.
The librarian performs memory-head lookup before QMD planning and returns matching facts alongside note excerpts.

### Graph Context (Optional)

Before librarian delegation, check if the topic references a known entity.
1. If `.pa/entities.json` exists, search for entity names matching the topic terms.
2. If a match is found, delegate to the weaver with `analysis_type: "graph-query"` and `query_type: "neighbors"`.
3. Pass the resulting `graph_context` to the librarian as additional input.
4. If no entity match is found or `entities.json` is missing, skip graph context and proceed with QMD-only retrieval.

#### Graph Context Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | matched entity record from `.pa/entities.json`, the raw topic string, available `.pa/relations.json` when present, and vault-profile.json linking defaults |
| Instructions | Apply `skills/pa/personal-ontology/SKILL.md` graph-query workflow with `analysis_type: "graph-query"` and `query_type: "neighbors"`. Resolve the seed entity conservatively, return only directly relevant neighbors and candidate notes, and do not synthesize the brief or write state |
| Expected Output | `graph_context` with `seed_entity`, `neighbor_entities[]`, `candidate_notes[]`, `relation_edges[]`, and `coverage_note` or `confidence` |


### SWE Project Model Context (Optional)

Before librarian delegation, check if the brief target relates to a project with SWE artifacts.

1. Check if `docs/specs/project/` exists via `Glob("docs/specs/project/*")`.
2. If it exists, read available project model files (`domain.md`, `constraints.md`, `architecture.md`).
3. If the brief topic relates to project model content (matching topic terms against headings), pass relevant content as `swe_project_context` to the librarian.
4. If no match or directory absent, skip.

### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | topic string, brief type (`focus`), vault-profile.json contents, settings.json contents, retrieval-profile overrides including optional `session_lane` (if present), `memory-heads.json` contents (if present), graph_context (if available), and `swe_project_context` (if available) |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` workflow. Run memory lookup before QMD planning. Classify intent (likely `dossier` for most topics). Use `references/query-patterns.md` for query templates. Return a structured context pack per the librarian's output format |
| Expected Output | Context pack with query analysis, matching memory facts, retrieved documents with excerpts, optional `session_hits[]`, `session_lookup`, coverage assessment, citation index, and session sources |

### Recovery

| Failure | Action |
|---------|--------|
| Weaver graph query fails | Proceed with QMD-only retrieval |
| Librarian timeout | Report error and suggest retrying with a simpler topic |
| Librarian returns error (QMD failure) | Report the specific QMD error |
| Zero results | Proceed to Phase 4 — the brief will report "no content found" |

## Phase 4: Render Brief

Read `templates/pa/focus-brief.md` for the output structure.

1. **Summary**: Synthesize a 2-4 sentence overview from the context pack's excerpts and matching memory facts.
Every claim must reference a citation number when a supporting note is in the citation index.
If a direct memory fact is used without a retrieved note excerpt, show its `source_note` provenance inline.
If the context pack includes direct memory facts, use them to anchor the first sentence of the summary.
2. **Known Facts**: Render the context pack's matching memory facts in the template's `Known Facts` section before the detailed note excerpts.
Show `claim_key`, `predicate`, `object`, `confidence`, and `source_note` for each fact.
If temporal grounding is available on a fact, show it inline.
These facts are a structured summary that complements the notes, not a replacement for them.
3. **Session Hits**: If `session_hits[]` exist, render an optional `## Session Hits` subsection between `## Known Facts` and `## Key Notes`.
Show `S1`, timestamp, `segment_id`, `source_ref`, and the capped snippet for each hit.
Session citations live in this subsection only and do not enter `## Sources`.
4. **Key Notes**: List each retrieved document with its title (as a wikilink if `linking_style.prefer_wikilinks` is true), relevance score, and the librarian's compressed excerpt verbatim.
5. **Connections**: Scan the excerpts for shared wikilinks, common tags, or thematic overlap between the retrieved notes.
If `swe_project_context` was provided and relevant, add a `### Project Model` subsection under Connections.
6. **Open Questions**: Reproduce the coverage gaps from the context pack's coverage assessment.
7. **Sources**: Reproduce the vault-note citation index from the context pack without modification.

If the context pack has zero documents and zero memory facts, render a minimal brief: summary states "No relevant vault content found for '{topic}'", remaining sections are empty, and the sources table is empty.
If the context pack has memory facts but zero documents, render the summary and Known Facts section from the memory layer, leave Key Notes empty, and keep the gaps explicit.

## Phase 5: Present

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

Output the rendered brief in the conversation. Do not write it to the vault — brief is a read-only command.

### Next Actions

| Condition | Suggested Action |
|-----------|-----------------|
| Brief has high confidence | `/pa ask "{follow-up question}"` — dive deeper into a specific aspect |
| Brief has low confidence | Consider adding more notes on this topic to the vault |
| Brief reveals connections | `/pa brief "{connected_topic}"` — explore a related subject |
| Always | The brief is conversation-only — save it manually if you want it in the vault |

## Composability

| Context | Usage |
|---------|-------|
| `/pa ask` | Ask is conversational Q&A, brief is structured dossier — complementary |
| `/pa survey` | Survey produces the vault profile and QMD registration that brief depends on |
| `/pa focus` (future) | Focus will compose brief + ask + draft around a single objective |
| `/pa day` (future) | Day will use daily-brief template with temporal awareness |

## Rules

- **Read-only**: Brief never writes to the vault. Output is conversation-only
- **Citation-grounded**: Every claim in the summary must trace to a retrieved document or a matching memory fact with visible `source_note` provenance
- **No fabrication**: When retrieval finds nothing, say so — never supplement with model knowledge
- **Verbatim excerpts**: Key Notes excerpts come from the librarian's context pack without rewriting
- **Template-driven**: Output follows `templates/pa/focus-brief.md` structure
- **Session context separated**: Session hits are advisory context only and never count as vault-note sources
