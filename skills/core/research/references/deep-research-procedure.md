# Deep Research Procedure

Iterative goal-driven research protocol for `--deep` mode. The orchestrator uses this reference to manage the research loop — the researcher agent itself is unchanged.

## Goal Extraction

Before collection begins, derive a research scope from the user's topic or URL:

1. **Generate research questions** (3-5): Each question must be concrete and assessable. Prefer "What are the key design trade-offs of X?" over "What is X?". Questions should be falsifiable — it must be possible to determine whether collected evidence answers them.

2. **Define acceptance criteria** per question using the 4-level coverage framework:
   - **Strong**: 3+ independent sources with direct evidence, no unresolved contradictions
   - **Moderate**: 2 independent sources, or 1 high-credibility primary source with direct evidence
   - **Weak**: Single source, or only indirect/circumstantial evidence
   - **Unanswered**: No collected source addresses this question

3. **Present scope to user**: Display research questions and target coverage (all questions at "moderate" or above). User may adjust, add, or remove questions. Proceed after confirmation.

## Gap Report Format

After each synthesis round, the researcher appends a Coverage Assessment to its analysis output:

```text
## Coverage Assessment

| Research Question | Coverage | Evidence Summary | Gap Type | Suggested Query |
|-------------------|----------|------------------|----------|-----------------|
| {question text}   | strong/moderate/weak/unanswered | {brief evidence} | collection/knowledge/scope | {targeted query or "—"} |
```

Gap types (aligned with `synthesis-patterns.md` § Gap Analysis):

- **Collection gap**: Sources likely exist but were not found — actionable via targeted search
- **Knowledge gap**: Topic is genuinely under-explored — note as open question
- **Scope gap**: Question is outside current research boundaries — note for future research

## Convergence Logic

The orchestrator evaluates after each synthesis round. Stop when **any** condition is met:

| # | Condition | Meaning | Report Note |
|---|-----------|---------|-------------|
| 1 | All research questions at "moderate" or above | Research goals achieved | "Research goals met" |
| 2 | Zero collection gaps remain | No actionable follow-up possible | "No further sources available" |
| 3 | Targeted collection returned 0 new sources | Source pool exhausted | "Source saturation reached" |
| 4 | Round count = 5 | Safety cap | "Max iterations reached — some questions may remain weakly covered" |
| 5 | Coverage scores unchanged from previous round | Stagnation detected | "No progress detected" |

**Priority**: Conditions are evaluated in order. If multiple conditions are true, report the first.

## Gap-to-Query Transformation

Convert collection gaps into targeted search queries for the next round:

1. Extract core keywords from the gap's research question
2. Combine with the original topic for context specificity
3. Exclude already-collected URLs to avoid re-fetching (pass exclusion list to collector)
4. Prefer queries that narrow scope — "X performance benchmarks 2025" over "X performance"
5. Limit to 3 targeted queries per round to control cost

## Iterative Synthesis

Re-synthesis in round 2+ follows cumulative rules:

1. **Input**: Previous round's cumulative findings + newly collected sources only
2. **Instruction**: "Integrate new sources into existing findings. Update coverage levels. Do not re-analyze previously synthesized content — focus on what the new sources add, contradict, or confirm."
3. **Output**: Updated Research Analysis Report with refreshed Coverage Assessment
4. **State carried across rounds**: cumulative_findings, collected_urls (dedup set), per-question coverage scores

## Common Pitfalls

| Pitfall | Cause | Remedy |
|---------|-------|--------|
| **Tunnel vision** | Targeted queries progressively narrow, missing broader context | Include at least 1 "alternative perspective" query per round alongside gap-derived queries |
| **Confirmation bias** | Re-synthesis integrates new sources that confirm existing findings while discounting contradictions | Explicitly instruct researcher to flag contradictions with existing findings before confirming them |
| **Query repetition** | Gap-derived queries rephrase the same search with synonyms, finding the same sources | Track query stems across rounds; skip queries semantically equivalent to previous ones |
| **Premature convergence** | "Moderate" coverage achieved from 2 non-independent sources (e.g., blog post citing same paper) | Apply `source-evaluation.md` independence test before upgrading coverage level |
| **Over-iteration** | Continuing past diminishing returns when remaining gaps are knowledge/scope type, not collection type | Only iterate on collection gaps; knowledge and scope gaps cannot be resolved by more searching |

## Cost and Safety

- **Internal cap**: 5 rounds maximum. Not configurable by user — the convergence logic should stop well before this in most cases.
- **Per-round cost**: ~1 sonnet invocation (targeted collection) + ~1 opus invocation (re-synthesis). Round 1 may include additional sonnet collectors for broad collection.
- **`--multi` interaction**: When `--deep --multi`, round 1 uses Claude + Codex parallel analysis. Round 2+ uses Claude only — iterative refinement benefits from consistency over diversity.
- **Failure handling**: If targeted collection fails (network error, no results), skip to convergence re-evaluation with existing findings. If re-synthesis fails, use previous round's findings as final result.

## Bias Mitigation

Iterative research is susceptible to compounding biases across rounds:

- **Progressive narrowing**: Each round's gap-derived queries focus on what's missing, which can blind the researcher to relevant context discovered tangentially. Mitigation: the researcher instruction includes "note any tangential findings relevant to other research questions, even if not the focus of this round."
- **Source domain concentration**: Targeted queries may repeatedly hit the same domains (e.g., always returning Medium or Stack Overflow). Mitigation: if 3+ collected URLs share the same domain, the next round's queries should include a domain-exclusion operator or alternative phrasing.
- **Availability cascade**: Findings mentioned in multiple sources feel more credible even when sources are not independent. Mitigation: apply `source-evaluation.md` independence test at each coverage level upgrade, not just at final synthesis.
- **Anchoring on initial synthesis**: Round 1 findings anchor all subsequent rounds. Mitigation: round 2+ re-synthesis instruction explicitly states "challenge initial findings if new evidence contradicts them" rather than only integrating confirmations.
