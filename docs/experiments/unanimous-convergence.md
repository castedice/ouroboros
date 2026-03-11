# Unanimous Convergence: When Models Must Agree

> Testing whether forcing full agreement between evaluators improves accuracy — or creates new problems.

## Background

The standard multi-model evaluation uses majority consensus (Claude's score wins on ties). The `--unanimous` mode instead requires all models to converge on the same score for every criterion, exchanging reasoning until agreement is reached.

**Test subject**: The component with the lowest inter-model agreement (68.75%) across all evaluated components — chosen specifically to stress-test the convergence mechanism.

## Methodology

1. **Independent evaluation**: Claude + Codex evaluate in parallel (16 binary criteria)
2. **Divergence identification**: Compare per-criterion scores
3. **Fact-checking**: Quantitative criteria verified with actual measurements
4. **Convergence prompts**: Share opposing reasoning, request re-evaluation
5. **Maximum 2 iterations**: Escalate to user if no agreement

## Initial Results

| Criterion | Claude | Codex | Evidence |
|-----------|--------|-------|---------|
| F2 (Progressive Disclosure) | 1 | **0** | Measured: 2,099 words (threshold: 1,500-2,000) |
| F4 (Reference Organization) | 1 | **0** | Measured: 11 reference files (threshold: 2-5) |
| E4 (Integration) | **0** | 1 | Only 1 consumer mentioned, no integration section |

3 divergences out of 16 criteria (81.25% initial agreement).

## Convergence: 1 Round, 100% Resolution

All 3 divergences resolved in a single iteration:

- **F2, F4**: Claude changed 1→0 after receiving measured values. "Factual thresholds exceeded."
- **E4**: Codex changed 1→0 after receiving conjunctive criteria definition. "The criterion requires all three integration signals, not partial coverage."

Factual evidence (word counts, file counts) was decisive — numbers are not debatable.

## The Cliff Effect Problem

| Protocol | Score | Level |
|----------|-------|-------|
| Majority consensus | 14/16 | Level 3 |
| Unanimous | **11/16** | **Level 1** |

The 3-point difference triggers a **2-level drop** due to severity gating: Foundation score falling to 3/5 activates a Level 1 cap. A component exceeding the word limit by 99 words (2,099 vs 2,000) caused a catastrophic level drop.

This reveals binary scoring + rigid thresholds = cliff effects. Small threshold violations can have disproportionate impact through severity gates.

## Key Findings

### 1. Fact-Based Convergence is Fast and Reliable

When divergence involves measurable quantities (word count, file count, feature presence), convergence is immediate — facts are not debatable. This is the clear strength of unanimous mode.

### 2. Majority Consensus Can Hide Factual Errors

The majority protocol had Claude's F2=1 and F4=1 winning over Codex's 0s. Both were factually wrong — the component genuinely exceeded the thresholds. Majority consensus can mask errors when the "majority" model (Claude) is the biased one.

### 3. Rigid Thresholds Need Domain Awareness

11 reference files and 2,099 words aren't excessive for a complex evaluation methodology skill — they reflect domain complexity. Thresholds designed for simple components create false failures on complex ones.

### 4. Self-Enhancement Bias Responds to Instruction

When given an explicit "be vigilant against self-enhancement bias" instruction, Claude self-corrected from 16/16 to 13/16 (3 legitimate corrections). The bias is partially addressable through prompting, not just through external validation.

## Recommendations

1. **Use unanimous mode selectively** — for final validation or resolving sharp disagreements, not for every evaluation (~3× time cost)
2. **Build fact-checking into convergence** — auto-measure quantitative criteria (word count, reference count) before convergence prompts
3. **Review rigid thresholds** — consider type-specific thresholds or graduated scoring near boundaries
4. **Include bias warnings by default** — the self-correction effect is valuable even outside unanimous mode
