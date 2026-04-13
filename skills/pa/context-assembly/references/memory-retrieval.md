---
name: memory-retrieval
description: This reference defines how PA queries the memory layer before note retrieval. It should be consulted when an agent needs to "look up active facts for an entity", "seed QMD from memory hits", "combine fact lookup with note retrieval", or "treat the memory layer as the fact authority while QMD remains the note authority".
---

# Memory Retrieval

> Purpose: Reference for fact-first retrieval planning in PA.
> Use it when the caller needs known facts plus the source notes that justify them.

## Core Rule

Query memory first for normalized facts.
Query QMD second for note text and broader context.
The memory layer is the authority for active atomic facts.
QMD remains the note-retrieval engine.

## Retrieval Order

### 1. Resolve The Query Target

Resolve the target entity or topic into a likely `subject_id`, predicate, or both.
If entity resolution fails, skip memory lookup and use normal QMD retrieval.

### 2. Read `.pa/memory-heads.json`

Start from active heads, not the raw append log.
Filter heads by `subject_id` when the query targets a known entity.
Filter heads by `predicate` when the query asks for a fact type such as `works_at` or `lives_in`.
Use both filters when the question is specific enough.

### 3. Collect Matching Facts

Return the matching head entries as the fact set.
Treat those heads as the current claim state unless the caller explicitly asks for history.
When a fact is derived, keep its `claim_key` and source lineage available for explanation.

### 4. Gather `source_note` Paths

Collect the `source_note` value from each matching fact.
Deduplicate the note paths before any note retrieval step.
These paths become the preferred seeds for downstream context assembly.

### 5. Reinforce With QMD

Use the `source_note` paths as high-priority seeds for full-text retrieval.
Fetch note excerpts through QMD so the caller can quote or cite the underlying note text.
If memory hits are sparse, expand with normal QMD lexical or semantic queries around the same entity or predicate.

### 6. Merge Facts With Notes

Present memory facts as the normalized answer surface.
Present QMD excerpts as supporting evidence and nuance.
If a retrieved note disagrees with the active memory head, surface the conflict instead of silently choosing one source.

## Practical Rules

- Prefer `memory-heads.json` for current fact lookup speed.
- Use `memories.jsonl` only when the caller needs historical versions or audit detail.
- Use `memory-links.jsonl` only when the caller needs support, contradiction, supersession, or derivation context.
- Keep citations anchored to note paths, not just claim keys, unless the task is purely state inspection.
- If there are no matching memory heads, continue with standard QMD retrieval instead of failing.

## Output Expectations

- Fact lookup returns normalized claims keyed by `claim_key`.
- Note retrieval returns excerpts from the matched `source_note` paths.
- Final synthesis should make it clear which statements come from active memory heads and which come from retrieved note text.
