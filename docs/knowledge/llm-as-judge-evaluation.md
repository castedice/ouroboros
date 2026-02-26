---
title: LLM-as-Judge Evaluation Methods
tags: [evaluation, llm-as-judge, methodology, scoring, rubric]
source: multiple (MT-Bench, G-Eval, Prometheus, Anthropic Agent Eval Guide)
created: 2026-02-17
status: active
related: [evaluation-scoring-design.md]
---

# LLM-as-Judge Evaluation Methodology

Research synthesis for designing ouroboros `/evaluate`.

## Scoring Methods

### Additive Scoring — Recommended

Decompose evaluation into atomic criteria, each awarded 0 or 1 point. Easy to parse, partial scores are natural.
Best suited for component evaluation — enables specific feedback on where things fall short.

### Pointwise Scoring

Score a single response. G-Eval's 3 steps: evaluation criteria → evaluation steps → log-probability weighted average.
1-4 integer scale is optimal (30% improvement in human agreement vs. float/10-point scales).

### Pairwise Comparison

Compare two responses side by side. Relative judgment is more stable than absolute scoring.
Suitable for: pre/post evolve comparison, A/B testing. Constraint: O(n^2).

### Reference-Guided

Provide a reference answer to improve accuracy. Prometheus's 4-part format:
Instruction → Response → Reference Answer → Score Rubric.

## Rubric Design Essentials

1. **Single-criterion principle**: Evaluate only one criterion per evaluation
2. **Integer scale**: 1-4 or binary (Pass/Fail). 10+ points not recommended
3. **Concrete description required for each score level**: Define what "Score 3" means with examples
4. **CoT before score**: Always reason before scoring. Explanation after score degrades quality
5. **Validation**: Create a test set of 20-50 known good/bad examples and verify repeated consistency

## Known Biases & Mitigations

| Bias | Phenomenon | Mitigation |
|------|------|------|
| Position | Order bias in pairwise (10%+ variance) | Position swap + agreement verification (2x cost) |
| Verbosity | Favors longer responses | Explicitly include conciseness criterion in rubric |
| Self-enhancement | 10% higher win rate for own model output | Use a different model as judge, ensemble |
| Authority | Over-rates responses that cite sources | Use reference-guided for actual verification |

## Practical Frameworks

- **G-Eval**: Auto-CoT + probability weighting, strong at subjective judgment
- **Prometheus**: Custom rubric-based, 4-part input format is the most systematic
- **MT-Bench**: Defines 3 judge types (pointwise, pairwise, reference-guided)
- **Anthropic Agent Eval**: 3 grader types (code-based, model-based, human), pass@k/pass^k

## Prompt Quality Evaluation Dimensions

| Dimension | Description |
|------|------|
| Clarity | Clear instructions without ambiguity |
| Specificity | Concrete and narrow scope |
| Structure | Logical organization, section separation |
| Grounding | Degree of context information provided |
| Constraint Definition | Explicit constraints (format, length, tone, prohibitions) |
| Failure Mode Awareness | Presence of instructions addressing common errors |
| Measurability | Existence of verifiable success criteria |
