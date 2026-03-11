---
name: research-methodology
description: This skill provides research methodology knowledge. It should be activated when an agent needs to "evaluate source credibility", "synthesize findings from multiple sources", "structure knowledge for reuse", "extract patterns from collected content", or "cross-reference research against existing knowledge".
---

# Research Methodology

## Core Principle

**"Collect broadly, synthesize deeply, structure for reuse."**

Research is a three-phase process: collection gathers raw material, synthesis extracts meaning, and structuring makes it actionable. Skipping synthesis produces data dumps — skipping structuring produces insights that cannot be found or applied later. The full pipeline is: **Scope → Collect → Evaluate → Synthesize → Structure**.

The critical transition is from collection to synthesis. A researcher who collects 20 sources but produces a list of summaries has done collection twice, not research. Synthesis requires identifying patterns across sources, resolving contradictions, and mapping findings to the target domain — work that no single source can provide.

## Research Workflow

Five stages executed in order. Each stage has a defined input, process, and output. For detailed source evaluation criteria, see `references/source-evaluation.md`. For synthesis techniques, see `references/synthesis-patterns.md`.

### Step 1: Scope Definition

**Input**: Raw topic, URL, or path from the user.
**Output**: Research question with boundaries and success criteria.

- Clarify the research goal: what question are we answering?
- Identify boundaries: what is in scope vs. out of scope?
- Determine source strategy: local analysis, web search, or both?
- Define success: what would a useful knowledge entry contain?

Scoping prevents both rabbit holes (unbounded exploration) and shallow passes (collecting the first 3 results). A well-scoped research question is specific enough to evaluate completeness but broad enough to discover unexpected patterns.

### Step 2: Source Collection

**Input**: Scoped research question + source strategy.
**Output**: Raw content from 3-10 sources with provenance metadata.

- Gather sources systematically: local files (Glob + Read), web pages (WebSearch + WebFetch), or both
- Record provenance for each source: origin URL/path, date accessed, content type
- Collect breadth-first: gather all sources before deep-reading any single one
- Target 3-10 sources: fewer than 3 risks single-source bias; more than 10 risks diminishing returns without synthesis

**Source selection priority**: Primary sources (original documentation, source code) over secondary sources (blog posts, tutorials) over tertiary sources (aggregators, summaries). When sources of equal tier are available, prefer more recent content.

### Step 3: Source Evaluation

**Input**: Raw content from collected sources.
**Output**: Evaluated sources with credibility and relevance scores.

- Assess each source on three dimensions: credibility, relevance, freshness
- Apply the Source Evaluation Framework (see `references/source-evaluation.md`)
- Discard sources that score low on both credibility and relevance
- Flag contradictions between high-credibility sources for synthesis attention

Evaluation prevents low-quality sources from polluting the synthesis. A single authoritative source is worth more than five blog posts repeating the same unverified claim.

### Step 4: Synthesis

**Input**: Evaluated sources with credibility ratings.
**Output**: Synthesized findings with evidence chains.

- Apply synthesis techniques from `references/synthesis-patterns.md`
- Triangulate: look for claims supported by 2+ independent sources
- Identify gaps: what questions remain unanswered by collected sources?
- Resolve contradictions: when sources disagree, determine which evidence is stronger and why
- Map to target domain: how do findings apply to the ouroboros context?

Synthesis is the stage most often skipped or done superficially. The test of good synthesis is whether the output contains insights that no single source contains — if the synthesis could have been produced by reading only the best source, it's a summary, not a synthesis.

### Step 5: Knowledge Structuring

**Input**: Synthesized findings.
**Output**: Structured knowledge entry with frontmatter, findings, and references.

- Structure findings into the knowledge entry format (title, tags, overview, patterns, applications, trade-offs, references)
- Ensure each finding is actionable: can someone act on it without re-reading the sources?
- Tag for discoverability: choose tags that connect this entry to existing knowledge
- Note related entries: identify existing knowledge base entries that overlap or complement

Structuring transforms research from a one-time activity into a reusable asset. A well-structured entry can be found by tag search, understood without context, and applied directly to generation or evolution tasks.

## Source Evaluation Framework

Three dimensions for assessing source quality. See `references/source-evaluation.md` for the detailed rubric.

| Dimension | Question | High | Low |
|-----------|----------|------|-----|
| **Credibility** | Is this source trustworthy? | Official docs, peer-reviewed, original author | Anonymous blog, no citations, outdated |
| **Relevance** | Does it address our question? | Directly answers the research question | Tangentially related, different context |
| **Freshness** | Is the information current? | Published within relevant timeframe | Outdated for fast-moving topics |

**Composite scoring**: Credibility × Relevance determines whether to include a source. Freshness modulates weight — stale but credible sources are included but down-weighted in synthesis.

## Synthesis Techniques

Four techniques for combining findings across sources. See `references/synthesis-patterns.md` for detailed procedures.

| Technique | Best For | Produces |
|-----------|----------|----------|
| **Triangulation** | Validating claims | Confidence ratings based on independent confirmation |
| **Gap Analysis** | Finding blind spots | List of unanswered questions and missing evidence |
| **Pattern Extraction** | Identifying recurring themes | Named patterns with evidence citations from multiple sources |
| **Contradiction Resolution** | Handling disagreements | Resolved position with reasoning for preference |

**Technique selection**: Start with Pattern Extraction for broad topics, Triangulation for specific claims. Apply Gap Analysis after initial synthesis to identify what's missing. Use Contradiction Resolution when high-credibility sources disagree.

## Bias Mitigation

Research involves selection and interpretation, creating systematic bias risks:

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Confirmation | Collection | Only collecting sources that support initial hypothesis | Search for counterexamples explicitly; include at least one dissenting source |
| Availability | Collection | Over-relying on easily found sources (top search results) | Look beyond first-page results; check primary sources cited by secondary ones |
| Authority | Evaluation | Accepting claims because the source is prestigious | Evaluate evidence quality independently of source reputation |
| Recency | Evaluation | Dismissing older sources as irrelevant | Assess whether the topic is time-sensitive; foundational knowledge ages slowly |
| Anchoring | Synthesis | First source read dominates the synthesis | Write synthesis from notes, not from memory of reading order |

## Common Pitfalls

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Shallow collection (3 blog posts) | Collection | Use source selection priority; seek primary sources first |
| Missing synthesis step (list of summaries) | Synthesis | Output must contain cross-source patterns, not per-source summaries |
| Unstructured output | Structuring | Follow the knowledge entry template; ensure tags and related entries are populated |
| Single-source dependency | Collection | No single source should contribute >50% of findings; triangulate key claims |
| Ignoring contradictions | Synthesis | Contradictions between credible sources are findings, not problems to hide |
| Over-collecting (20+ sources) | Collection | More than 10 sources without synthesis is collection avoidance; stop and synthesize |
| Domain-blind findings | Synthesis | Every pattern must include an applicability assessment to the target domain |

## Validation Checklist

- [ ] Research question is scoped with clear boundaries and success criteria
- [ ] 3-10 sources collected with provenance metadata for each
- [ ] Source evaluation applied: credibility, relevance, and freshness assessed
- [ ] Low-quality sources discarded or down-weighted with explicit reasoning
- [ ] Synthesis contains cross-source patterns (not per-source summaries)
- [ ] Contradictions between sources identified and resolved
- [ ] Gaps in evidence explicitly noted
- [ ] Findings mapped to target domain with applicability assessment
- [ ] Knowledge entry structured with frontmatter, tags, and related entries
- [ ] Each finding is actionable without re-reading original sources
- [ ] No single source contributes >50% of the final output

## See Also

- **researcher agent** (`agents/core/researcher.md`) — Primary consumer; executes source analysis, pattern extraction, and knowledge base cross-referencing
- **research command** (`commands/core/research.md`) — Orchestrates the full research pipeline: collection → analysis → knowledge entry drafting → worktree management
- **evolution-methodology** (`skills/core/evolution/SKILL.md`) — Research findings feed into component improvement via the evolution cycle
- **absorption-methodology** (`skills/core/absorption/SKILL.md`) — Research is the first phase of absorption; findings drive gap analysis and generation
