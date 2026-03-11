# Multi-Model Evaluation: Model Selection Experiment

> 48 model invocations across 10 configurations to find the optimal external evaluator for a multi-model quality assessment pipeline.

## Experiment Design

**Goal**: Find the optimal external model configuration for `--multi` evaluation. The existing default was unvalidated.

**Benchmark**: 2 components with known weaknesses (E1 and E2 criteria confirmed as failures), used as ground truth.

**Protocol**: Same relay prompt per component. 2 runs per configuration. 16 binary criteria scored independently.

## Results: Codex

| Model | Effort | Avg Score | Avg Time | Parse Rate | E1/E2 Discrimination |
|-------|--------|-----------|----------|------------|---------------------|
| gpt-5.2 | xhigh | 13-15 | 249s | 100% | Yes — but over-strict |
| gpt-5.2 | high | 14-15 | 103s | 100% | Yes |
| gpt-5.2 | medium | 14-15 | 82s | 100% | Yes |
| gpt-5.3-codex | high | 13-15 | 65s | 100% | Yes |
| gpt-5.3-codex | medium | 13-15 | 45s | 100% | Yes |
| gpt-5.3-codex | xhigh | 13-15 | 94s | 100% | Yes — over-strict |

All Codex configurations correctly identify known E1/E2 weaknesses. Zero false negatives on ground truth.

## Results: Gemini

| Model | Avg Score | Avg Time | Parse Rate | E1/E2 Discrimination |
|-------|-----------|----------|------------|---------------------|
| auto (default) | 16 | 128s | 100% | No |
| gemini-3-flash | 16 | 73s | 75% | No |
| gemini-2.5-pro | 15-16 | 68s | 100% | Minimal |
| gemini-2.5-flash | 15-16 | 39s | 100% | No |
| gemini-3.1-pro | 13-16 | 94s | 100% | E1: 100%, E2: 50% |

Gemini models score near-perfect (16/16) regardless of actual quality. Only gemini-3.1-pro shows meaningful discrimination, matching Codex on E1 but lagging on E2.

## Key Findings

### 1. Higher Effort ≠ Better Judgment

The xhigh effort level is the worst Codex configuration: scores lower than high (over-deliberation leads to over-strictness), runs 2.5-3× slower, and penalizes borderline criteria inconsistently. Excessive reasoning is counterproductive.

### 2. Newer Model, Same Discrimination, Much Faster

gpt-5.3-codex matches gpt-5.2 on all discrimination metrics while being 1.6-2.6× faster. No coding-model bias detected in evaluation reasoning.

### 3. Systematic Leniency is Worse than Systematic Strictness

Gemini's near-universal 16/16 scores provide zero signal. A model scoring 13/16 with consistent, evidence-based reasoning is more valuable than one scoring 16/16 with factually incorrect reasoning that claims the component is "a pure orchestrator" when it contains inline shell scripts.

### 4. Parse Stability Matters

Codex: 100% structured output success. Gemini: 87.5% (parse failures and non-standard formats). For automated pipelines, parse reliability is a hard requirement.

### 5. Evaluation Quality Metrics

Score magnitude is not a quality indicator. Evaluation quality should be measured by: (1) agreement with confirmed ground truth, (2) reasoning specificity (cites concrete evidence), (3) run-to-run consistency, (4) factual accuracy of claims.

## Decision

| Setting | Before | After | Rationale |
|---------|--------|-------|-----------|
| Primary external model | gpt-5.2 xhigh | gpt-5.3-codex high | Same discrimination, 1.6× faster |
| Bulk evaluation model | gpt-5.2 medium | gpt-5.3-codex medium | Same discrimination, fastest (45s) |
| Gemini role | Consensus peer | Spot-checker only | Systematic leniency would dilute genuine 0-scores in consensus |

## Gemini 3.1: A Qualitative Leap

The final supplementary experiment (gemini-3.1-pro-preview) showed dramatic improvement over all previous Gemini versions:

| Model Generation | E1 Discrimination | E2 Discrimination | Reasoning Quality |
|-----------------|-------------------|-------------------|-------------------|
| Gemini 2.5 (flash/pro) | 0% | 0% | Generic or incorrect |
| Gemini 3-pro | 50% | 0% | Mixed |
| **Gemini 3.1-pro** | **100%** | **50%** | **Specific, evidence-based** |

Gemini 3.1 also uniquely identified an E3 weakness that both Claude and Codex missed, providing genuine architectural diversity. Viable as a supplementary validator for periodic spot-checks, but not yet consistent enough (E2: 50%) for consensus participation.
