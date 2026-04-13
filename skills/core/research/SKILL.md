---
name: research-methodology
description: This skill provides research methodology knowledge. It should be activated when an agent needs to "evaluate source credibility", "synthesize findings from multiple sources", "structure knowledge for reuse", "extract patterns from collected content", or "cross-reference research against existing knowledge".
summary: Guides scoped research from source collection through credibility evaluation, cross-source synthesis, and reusable knowledge structuring.
version: 1
tags: [core, methodology, research, synthesis, source-evaluation]
preamble_tier: 3
---

# Research Methodology

## Core Rule

**"Collect broadly, synthesize deeply, structure for reuse."**

Research is a five-stage pipeline: **Scope → Collect → Evaluate → Synthesize → Structure**.
Collection without synthesis is a data dump, and synthesis without structure creates insights that cannot be found or reused later.
Good research produces cross-source understanding, not a stack of per-source summaries.

## Gotchas

| Risk | Stage | Prevention |
|------|-------|------------|
| Collecting only easy secondary sources | Collection | Prefer primary sources first and go past the first obvious results |
| Stopping at three summaries | Synthesis | Produce cross-source patterns, contradictions, and gaps |
| Letting one source dominate the result | Collection | Keep key claims triangulated and avoid any single source contributing most findings |
| Treating prestige as proof | Evaluation | Judge evidence quality, not just source reputation |
| Discarding older but still-relevant sources | Evaluation | Check whether the topic is actually freshness-sensitive |
| Letting reading order drive the conclusion | Synthesis | Synthesize from notes, not from memory of the first source |
| Hiding contradictions to keep the narrative tidy | Synthesis | Treat contradictions between credible sources as findings that require explanation |
| Publishing an unstructured result | Structuring | Use a reusable knowledge-entry shape with tags, references, and related entries |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The top result already answers it" | Ending collection after one convenient source | Collect enough primary or high-quality sources to triangulate the key claims |
| "These summaries are useful enough" | Returning stacked per-source notes as synthesis | Extract cross-source patterns, contradictions, gaps, and implications for the target domain |
| "This source is prestigious, so it can carry the claim" | Treating reputation as a substitute for evidence quality | Score credibility, relevance, and freshness, then require support for important claims |

## Workflow

### 1. Scope Definition

Input: a raw topic, URL, path, or user question.
Output: a bounded research question with success criteria.
Clarify what is in scope, what is out of scope, and whether the job needs local sources, web sources, or both.

### 2. Source Collection

Input: scoped question plus source strategy.
Output: 3 to 10 sources with provenance.
Collect breadth-first, record origin and access date, and prefer original documentation or source code over commentary when both exist.

### 3. Source Evaluation

Input: collected sources.
Output: credibility, relevance, and freshness judgments.
Discard sources that are weak on both credibility and relevance, and flag disagreements between strong sources for later synthesis.

### 4. Synthesis

Input: evaluated sources.
Output: findings with evidence chains.
Triangulate key claims, extract recurring patterns, note unresolved gaps, resolve contradictions, and map findings back to the target domain.

### 5. Knowledge Structuring

Input: synthesized findings.
Output: a reusable knowledge entry.
Write the entry so another agent can act on it without reopening the original sources, and connect it to the rest of the knowledge base with tags and related entries.

## Decision Rules

### Collection And Evaluation

| Decision | Rule |
|----------|------|
| Source count | Target 3 to 10 sources, because fewer than 3 risks single-source bias and more than 10 usually signals collection avoidance |
| Source priority | Prefer primary over secondary over tertiary sources, and prefer more recent content when source tiers are otherwise equal |
| Inclusion threshold | Credibility and relevance determine inclusion, while freshness changes weight rather than acting as a hard gate |
| Low-quality sources | Discard or down-weight them explicitly instead of blending them into synthesis |

### Synthesis Technique Selection

| Technique | Use when | Produces |
|-----------|----------|----------|
| Triangulation | A claim needs confidence | Multi-source support or uncertainty |
| Pattern extraction | The topic is broad | Named recurring themes with evidence |
| Gap analysis | Coverage is incomplete | Unanswered questions and missing evidence |
| Contradiction resolution | Strong sources disagree | A justified preferred interpretation |

Validation checks: scope the question before collecting, keep provenance for every source, make each finding actionable without re-reading the source set, preserve explicit evidence gaps, and ensure the final output contains cross-source insight instead of stacked summaries.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/source-evaluation.md` — Credibility, relevance, and freshness criteria with scoring guidance.
- `${CLAUDE_SKILL_DIR}/references/synthesis-patterns.md` — Procedures for triangulation, gap analysis, pattern extraction, and contradiction resolution.
- `${CLAUDE_SKILL_DIR}/references/deep-research-procedure.md` — Iterative deep-research loop for goal extraction, gap reporting, and convergence checks.

## See Also

- `agents/core/researcher.md` — Primary consumer of this methodology.
- `commands/core/research.md` — Orchestrates collection, analysis, and knowledge-entry drafting.
- `skills/core/absorption/SKILL.md` — Uses research findings as the first phase of capability mapping and gap analysis.
- `skills/core/evolution/SKILL.md` — Consumes research findings when diagnosing and improving components.
