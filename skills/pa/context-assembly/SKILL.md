---
name: context-assembly
description: This skill provides retrieval orchestration methodology for QMD-backed vaults. It should be activated when an agent needs to "look up active memory facts before QMD", "plan QMD queries from a user question", "control retrieval breadth", "filter and rank search results", "compress retrieved documents for LLM context", "format citations from QMD results", or "assemble a context pack for synthesis".
summary: Builds citation-safe context packs from memory, QMD retrieval, session support, filtering, and excerpt compression.
version: 1
tags: [pa, retrieval, context-packs, citations, qmd]
preamble_tier: 2
---

# Context Assembly

## Core Rule

**"Retrieve what the question needs, not what the vault contains."**

A context pack exists to answer one question or support one synthesis task.
Over-retrieval floods the caller with irrelevant text, and under-retrieval pushes the caller toward hallucination.
Every claim the caller makes must trace to a retrieved document, so citation discipline matters as much as recall.

## Gotchas

| Risk | Phase | Prevention |
|------|-------|------------|
| Over-retrieving "just to be safe" | Retrieval | Respect `max_context_docs` and filter aggressively after fusion |
| Under-retrieving and trusting the first few hits | Query planning | Use the intent and lane strategy before judging sufficiency |
| Biasing hyde passages toward a preferred answer | Query planning | Keep hypothetical passages generic and factual |
| Re-ranking by recency when the question is not temporal | Filtering | Let relevance dominate unless the intent is explicitly time-based |
| Passing full documents instead of excerpts | Compression | Select verbatim sections only, targeting 100 to 300 words per document |
| Stripping wikilinks or markdown structure from excerpts | Compression | Preserve links and headings that carry meaning |
| Retrying zero-result queries in a loop | Retrieval | Broaden once, then report honest absence |
| Citing notes that were never retrieved | Citation | Build the index only from the final retrieved set |
| Treating memory facts as a replacement for note retrieval | Retrieval | Use memory first for fact lookup, then reinforce with QMD excerpts from `source_note` paths |
| Session hits as primary evidence | Retrieval | Keep session lane as supporting context only — vault notes remain primary |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "More retrieved notes will make the answer safer" | Over-retrieving beyond the context budget and passing broad note dumps forward | Respect `max_context_docs` and filter after fusion |
| "The first few hits answer it well enough" | Skipping intent classification and lane planning before judging sufficiency | Classify the intent, plan the lanes, then decide whether retrieval is enough |
| "The session archive remembers this, so cite it as evidence" | Treating session hits as primary vault evidence or fabricated note coverage | Keep session hits supporting only and cite retrieved vault notes for final claims |

## Workflow

### 1. Intent Classification

Input: the user question or topic plus request type.
Output: an intent label and retrieval strategy.
Classify whether the job is factual, conceptual, dossier, temporal, exploratory, neighborhood, or graph-driven before planning any query.

### 2. Memory-First Lookup

Input: intent, question or topic, optional `graph_context`, and `.pa/memory-heads.json` when present.
Output: matching active facts plus deduplicated `source_note` seeds.
Read active memory heads before planning any QMD query.
If the target entity, topic, or predicate can be resolved, collect matching facts and carry their `source_note` paths forward as preferred note seeds.
If memory is missing, empty, or yields no matches, continue with normal QMD planning.

### 3. Query Planning

Input: intent, matching memory facts, vault-profile defaults, retrieval-profile overrides, and optional `graph_context`.
Output: a lane-aware query plan.
Select literal, semantic, situational, and session lanes as needed, choose sub-query types, determine `k` and `minScore`, resolve the collection, and prepare any memory-seeded, graph-seeded, or session-archive candidates.

### 4. Retrieval And Filtering

Input: query plan.
Output: a fused and filtered ranked list plus carried memory facts and optional session hits.
Use any `source_note` seeds from memory before broadening with normal QMD queries, apply lane-specific decay, fuse four retrieval lanes by rank-based RRF, enforce diversity limits on vault notes only, and fetch full content only for the final ranked vault set.

### 5. Compression

Input: full document contents plus the original question.
Output: verbatim excerpts.
Extract only the sections that answer the question, keep headings and relevant frontmatter when needed, and never paraphrase during compression.

### 6. Citation Index Assembly

Input: ranked excerpts.
Output: numbered citations with paths and scores.
Assign citation numbers in relevance order and treat that index as the only ground truth the caller may cite.

## Decision Rules

### Intent And Retrieval Planning

| Intent | Use when |
|--------|----------|
| `factual` | The user asks for a specific fact, definition, or note |
| `conceptual` | The user asks about relationships, patterns, or reasoning |
| `dossier` | The user wants a briefing on a person, project, or topic |
| `temporal` | The request explicitly depends on time |
| `exploratory` | The user wants discovery over a broad topic |
| `neighborhood` | The user asks what connects to a known note |
| `graph` | The request targets ontology relations around a known entity |

Use a lex title query when the question names a specific note, raise `k` to about `1.5x` default for exploratory "everything on X" queries, and use `mcp__qmd__status` instead of document retrieval for vault-stat questions.
Start `k` from `vault-profile.json` and apply retrieval-profile overrides when present.
Default `minScore` is `0.3` for lex and `0.25` for vec or hyde unless the retrieval profile overrides it.
If `.pa/memory-heads.json` exists and the question names a likely entity, topic, or predicate, read it before planning QMD queries.
Filter heads by `subject_id` when graph or entity resolution exists, by `predicate` when the question asks for a fact type, and by topic tokens when only a topic string is available.
Carry matching facts into the context pack and deduplicate their `source_note` paths as high-priority QMD seeds.
If memory is missing, empty, or has no matches, skip directly to standard QMD retrieval.
QMD remains required for note excerpts, citations, and broader reinforcement.
If `graph_context.seed_resolved` is false, ignore graph seeding and continue with QMD-only retrieval.
Activate the session lane when temporal-recall trigger phrases appear or when `dossier` and `exploratory` intent can benefit from prior conversation context.
Honor `retrieval_profile.session_lane.enabled=false` as a hard disable, and honor `enabled=true` as a force-on override.
Use `k=3`, `max_excerpt_chars=400`, `project=current`, and `agent=main` as session lane defaults unless the profile overrides them.
Treat missing or failing session archive lookups as fail-open `unavailable`, not as a QMD retrieval failure.

### Filtering, Compression, And Citation

Allow at most 2 results per folder unless the query is explicitly folder-scoped.
If QMD returns zero results, try one broader vec query and then report that no relevant vault content was found.
For notes under 200 words, include the full text, otherwise target 100 to 300 words of verbatim excerpt.
Include frontmatter only when it is directly relevant to the question.
Every citation must include the title, path, optional QMD docid, and relevance score from the retrieved set.

Validation checks: classify intent before querying, run memory lookup before QMD when active heads are available, include an `intent` parameter on every QMD call, remove sub-threshold results before ranking, keep excerpts verbatim, cap context size, and never fabricate citations or unstored coverage.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/query-patterns.md` — Intent classification rules, query templates, lane strategy, and compression guidance.
- `${CLAUDE_SKILL_DIR}/references/memory-retrieval.md` — Fact-first lookup order, `source_note` seeding, and memory-plus-QMD merge rules.
- `${CLAUDE_SKILL_DIR}/references/graph-query-patterns.md` — Graph-seeded retrieval patterns and seed-resolution behavior.
- `${CLAUDE_SKILL_DIR}/references/loading-strategy.md` — Tiered loading rules for controlling retrieval breadth and caller context cost.
- `${CLAUDE_SKILL_DIR}/references/qmd-gate.md` — Command-level QMD requirement versus degradation rules across PA retrieval consumers.
- `skills/core/session-archive/references/retrieval-contract.md` — Session archive consumer contract and fail-open lookup rules.

## See Also

- `agents/pa/librarian.md` — Primary consumer of this retrieval methodology.
- `commands/pa/ask.md` — Uses context assembly to answer vault-backed questions.
- `commands/pa/brief.md` — Uses context assembly to build dossier-style briefs.
- `skills/pa/vault-modeling/SKILL.md` — Supplies vault-profile defaults and retrieval constraints.
- `skills/pa/trust-and-boundaries/SKILL.md` — Governs honest handling of missing or low-confidence coverage.
