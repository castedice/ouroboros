---
name: pa:ask
description: "Use when you need an answer from your vault with citations to supporting notes"
effort: low
allowed-tools:
  - Read
  - Glob
  - Grep
  - Write
  - Agent
  - mcp__qmd__query
  - mcp__qmd__get
  - mcp__qmd__multi_get
  - mcp__qmd__status
argument-hint: "<question>"
---

# Ask — RAG Q&A with Citations

Ask a question about your vault and receive an answer grounded in retrieved content with full citations.

Question: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2 | Read (tool) | Load vault-profile.json, settings.json, retrieval-profiles.json |
| 2.5 | weaver (agent, sonnet, optional) | Build graph_context when question references a known entity |
| 3 | librarian (agent, sonnet) | Assemble context pack from vault via QMD retrieval |
| 4 | Main context (opus) | Synthesize conversational answer from context pack |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass the raw question, relevant vault state, and retrieved note contents explicitly on every delegated call.
Use named return payloads rather than prose-only summaries.
The command owns QMD tool calls, answer rendering, and ledger writes.
Internal librarian calls use `Agent(subagent_type: "ouroboros:pa:librarian")`.
Phase 4 synthesis stays command-local and must emit named fields instead of freeform notes.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:pa:librarian` | 3 | `question`, `vault_profile`, retrieval overrides, optional `memory_heads`, optional `graph_context`, and QMD status | `context_pack`, `citations`, `coverage_assessment`, `query_analysis`, `session_lookup`, optional `session_hits[]`, and optional `matching_memory_facts[]` |
| `command-local synthesis` | 4 | `question`, `context_pack`, `citations`, optional memory facts, optional `session_hits[]`, `session_lookup`, linking style, and persona render state | `answer_text`, `source_list`, optional `session_source_list`, `confidence_note`, and `next_action` |

## State Contract

| File | Access | Purpose |
|------|--------|---------|
| `.pa/vault-profile.json` | read | Retrieval defaults (k, max_docs), linking style |
| `.pa/settings.json` | read | Collection name, capability tier, vault path |
| `.pa/context-profiles.json` | read (optional) | Approved context budget for `ask` optional state loading |
| `.pa/retrieval-profiles.json` | read (optional) | Per-command retrieval overrides |
| `.pa/memory-heads.json` | read (optional) | Active facts for direct answers and source-note provenance |
| `.pa/assistant-ledger.jsonl` | append | Read-only run telemetry and audit metadata |

## Decision Matrix

| Condition | Phase | Behavior |
|-----------|-------|----------|
| No question argument | 1 | Ask the user what they want to know |
| No `.pa/settings.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| No `.pa/vault-profile.json` | 1 | Abort: "Run `/pa survey` or `/pa init` first" |
| QMD collection not registered | 2 | Abort: "QMD collection not registered. Run `/pa survey` to set up retrieval" |
| `mcp__qmd__status` check fails | 2 | Abort: "QMD is unavailable. Check QMD installation" |
| `retrieval-profiles.json` missing | 2 | Continue with vault-profile.json qmd_defaults |
| `.pa/memory-heads.json` missing or empty | 2 | Continue with QMD-only retrieval |
| Librarian returns zero results | 4 | See Zero-Result Handling |
| Librarian returns low confidence | 4 | See Phase 4 Synthesis Rules point 7 |
| Question is about PA itself | 3 | See Phase 3 Pre-delegation Check |
| Question is a vault meta-query ("how many notes?") | 3 | See Phase 3 Pre-delegation Check |

## Phase 1: Parse Input

Extract the question from `$ARGUMENTS`.

The question is free-text natural language. It can be factual, conceptual, exploratory, or temporal. The librarian will classify the intent.

Handle missing question per the Decision Matrix.

## Phase 2: Load State

1. Read `.pa/settings.json` — extract vault path and QMD collection name.
2. Read `.pa/vault-profile.json` — extract qmd_defaults and linking style.
3. Read `.pa/retrieval-profiles.json` — look for `ask` profile overrides. If the file does not exist, fall back to `vault-profile.json` → `qmd_defaults`.
4. Read `.pa/context-profiles.json` (optional). If present, load the approved `ask` profile and use it to decide whether to skip optional enrichment files such as `soul.md` or `memory/observations.jsonl`. If the file is missing or has no approved `ask` profile, follow the defaults from `skills/pa/context-assembly/references/loading-strategy.md`.
5. Verify QMD availability via `mcp__qmd__status`.
6. Read `.pa/soul.md` — load soul layer (frontmatter for render settings, body for soul context). If missing, read `.pa/persona.json` as fallback (render only). If both missing, use defaults from `skills/pa/persona-response/references/persona-schema.md`.
7. Read `.pa/memory-heads.json` if it exists — load active facts for direct-answer checks and source-note provenance. If missing or empty, continue with QMD-only retrieval.
8. Read `.pa/memory/observations.jsonl` (optional) — load recent unactioned observations as supplementary context for answer synthesis. If missing, continue without memory context.

If any required state file is missing, abort per the Decision Matrix.

## Phase 3: Librarian Delegation

> Agent: **librarian**

Delegate context assembly to the librarian agent.
The librarian performs memory-head lookup before any QMD query planning.
If matching facts are found, it should carry those facts into the context pack and use their `source_note` paths as QMD seeds.

### Pre-delegation Check

If the question is about PA itself ("How does PA work?", "What commands does PA have?"), skip the librarian and answer from system knowledge in Phase 4. If the question is a vault meta-query ("How many notes do I have?", "What collections are indexed?"), use `mcp__qmd__status` directly and answer in Phase 4.

### Graph Context (Optional)

Before librarian delegation, check if the question references a known entity.
1. If `.pa/entities.json` exists, search for entity names matching the question terms.
2. If a match is found, delegate to the weaver with `analysis_type: "graph-query"` and `query_type: "neighbors"`.
3. Pass the resulting `graph_context` to the librarian as additional input.
4. If no entity match is found or `entities.json` is missing, skip graph context and proceed with QMD-only retrieval.

#### Graph Context Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | matched entity record from `.pa/entities.json`, the raw question string, available `.pa/relations.json` when present, and vault-profile.json linking defaults |
| Instructions | Apply `skills/pa/personal-ontology/SKILL.md` graph-query workflow with `analysis_type: "graph-query"` and `query_type: "neighbors"`. Resolve the seed entity conservatively, return only directly relevant neighbors and candidate notes, and do not synthesize an answer or write state |
| Expected Output | `graph_context` with `seed_entity`, `neighbor_entities[]`, `candidate_notes[]`, `relation_edges[]`, and `coverage_note` or `confidence` |


### Delegation Contract

| Contract Part | Content |
|---------------|---------|
| Input | question string, brief type (`ask`), vault-profile.json contents, settings.json contents, retrieval-profile overrides including optional `session_lane` (if present), `memory-heads.json` contents (if present), graph_context (if available) |
| Instructions | Apply `skills/pa/context-assembly/SKILL.md` workflow. Run memory lookup before QMD planning. Classify intent from the question. Use `references/query-patterns.md` for query templates. Return a structured context pack |
| Expected Output | Context pack with query analysis, matching memory facts, retrieved documents with excerpts, optional `session_hits[]`, `session_lookup`, coverage assessment, citation index, and session sources |

### Recovery

Use a single bounded recovery loop for retrieval work in this command.

| Situation | Budget | Stagnation Signal | Behavior |
|-----------|--------|-------------------|----------|
| Weaver graph query | 1 attempt only | The query fails, or it returns no seed entity or no candidate notes | Stop graph enrichment, continue with QMD-only retrieval, and record that graph context was unavailable |
| Librarian retrieval | 1 full attempt + 1 narrowed retry using the simplest query from the first query-analysis pass | The retry returns the same QMD failure, zero additional coverage, or the same low-confidence result | Stop retrying, preserve the best available context, and route to the matching output contract below |
| User-initiated retry | 0 automatic retries after the bounded retrieval budget is exhausted | A further internal retry would reuse the same evidence without improving coverage | Ask the user to rephrase or rerun the command in a new invocation instead of looping inside this run |

### Output Contracts

| Output Mode | Trigger | Required Shape |
|-------------|---------|----------------|
| `vault-answer` | Librarian returned note-backed citations | Conversational answer with inline `[n]` citations, then `---`, then `**Sources:**` list that exactly matches the librarian citation index |
| `memory-answer` | Memory facts answer the question but no note excerpts were retrieved | Direct answer grounded to the memory facts, an explicit note that broader note coverage is limited, then `---`, then `**Sources:**` list containing only the fact `source_note` paths |
| `session-context-only` | Zero vault documents and zero matching memory facts, but session hits exist | Short gap statement saying there is no vault evidence and only session context, optional `[S1]` references to prior conversation snippets, then `---`, then `**Sources:** None` and `**Session Hits:**` list |
| `no-results` | Zero documents and zero matching memory facts after bounded recovery | Short gap statement, `Queries tried:` line from the query analysis, a rephrase or add-notes suggestion, then `---`, then `**Sources:** None` |
| `pa-self-answer` | Phase 3 routes to PA self-knowledge | Direct answer from PA command knowledge, then `---`, then `**Sources:** PA command knowledge (no vault citations)` |
| `vault-meta-answer` | Phase 3 routes to direct QMD or vault-status inspection | Direct answer from the inspected status fields, then `---`, then `**Sources:** QMD status for {collection_name}` |
| `retrieval-error` | Librarian still fails after the bounded retry budget | Short error statement naming the failed retrieval surface, one concrete retry suggestion, then `---`, then `**Sources:** Unavailable due to retrieval failure` |

Apply the output-mode table before Phase 4 synthesis so the answer shape stays reconstructable even when librarian retrieval is skipped or degraded.

## Phase 4: Synthesis

This is the core differentiator from `/pa brief`. Where brief renders a structured template, ask produces a conversational answer.

### Synthesis Rules

1. **Ground every claim**: Every factual statement in the answer must trace to a specific citation from the context pack or to a matching memory fact with visible `source_note` provenance.
Use inline citation format: `[1]`, `[2]`, etc. when note citations exist.
Use `[S1]`, `[S2]`, etc. only for prior conversation context from session hits, and do not treat session citations as vault-note evidence.
2. **Direct memory answers first**: If the context pack includes memory facts that directly answer the question, surface them in the opening sentence before broader note synthesis.
Show fact provenance with the fact's `source_note` when it materially helps the user judge trust.
3. **Conversational tone**: Answer naturally, not in a structured template. The user asked a question — answer it like a knowledgeable colleague.
4. **Acknowledge gaps**: If the context pack has coverage gaps, say what the vault does not cover. Do not fill gaps with model knowledge.
5. **Preserve vault links**: When mentioning vault notes, use `[[wikilinks]]` if `linking_style.prefer_wikilinks` is `true`.
6. **Proportional depth**: Short questions get short answers. Complex questions get detailed answers with multiple citations.
7. **Confidence markers**: When the context pack confidence is `low`, prefix the answer: "Based on limited vault content..." When confidence is `none`, state: "I couldn't find relevant content in your vault."

### Zero-Result Handling

If the librarian returned zero documents and zero matching memory facts:
1. State that no relevant content was found.
2. Mention the queries that were tried (from the context pack's query analysis).
3. If `session_hits[]` exist, state "No vault evidence; session context only" before mentioning any `[S1]` session hit.
4. Suggest: "You might want to add notes about this topic, or try rephrasing your question."
5. Do not answer from model knowledge.

If the librarian returned direct memory facts but no note excerpts:
1. State the direct fact answer first.
2. Make it clear that the answer comes from active memory facts grounded to the listed `source_note` paths.
3. Note that broader note content was not retrieved, so nuance may be limited.

## Phase 5: Present

### Persona Application

Before presenting results to the user, apply the persona render contract from `skills/pa/persona-response/references/render-contract.md`:
- Use the sentence style from `render_hints.sentence_style`
- Apply warmth level from `warmth`
- Apply directness level from `directness`
- Respect emoji setting from `render_hints.emoji`
- Do not alter substance: facts, rankings, evidence, confidence, citations, and action recommendations stay unchanged

Output the synthesized answer followed by the source list.

### Answer Format

```
{conversational answer with inline citations [1], [2], etc.}

---
**Sources:**
1. [[{note_title}]] — {path}
2. [[{note_title}]] — {path}

**Session Hits:**
S1. {agent_kind}/{speaker}/{segment_kind} — {source_ref} — {segment_id}
```

### Next Actions

After the answer, suggest one relevant follow-up when natural:

| Condition | Suggestion |
|-----------|------------|
| Answer references multiple topics | "`/pa ask {specific_aspect}` — dig deeper into {topic_from_answer}" |
| Answer reveals connections | "`/pa brief {connected_topic}` — explore {related_entity} in depth" |
| Low confidence answer | "Your vault has limited content on this — consider adding notes on the topic" |
| Meta-query answered | No follow-up needed |

## Phase 6: Ledger Append

1. Append the ask run entry to `.pa/assistant-ledger.jsonl`.
2. Include `state_files_loaded`, `state_files_used`, and `estimated_context_chars` in the ledger entry per the Context Telemetry section in `skills/pa/trust-and-boundaries/references/ledger-schema.md`.

## Composability

| Context | Usage |
|---------|-------|
| `/pa brief` | Brief is structured dossier, ask is conversational Q&A — complementary |
| `/pa survey` | Survey produces the vault profile and QMD registration that ask depends on |
| `/pa focus` (future) | Focus will compose ask + brief + draft around a single objective |
| Follow-up asks | Users can ask follow-up questions naturally — each invocation is independent |

## Rules

- **Read-only**: Ask never writes to the vault. Output is conversation-only
- **Citation-grounded**: See Synthesis Rules point 1
- **No model knowledge substitution**: See Synthesis Rules point 4 and Zero-Result Handling
- **Librarian assembles, opus synthesizes**: See Agents & Tools Used table — never reverse these roles
- **Sources list is authoritative**: The sources list at the end must exactly match the librarian's citation index. No additions, no omissions
- **Session sources are separate**: Session hits, if present, go under `**Session Hits:**` with `[S1]` ids and never enter the vault `**Sources:**` list
