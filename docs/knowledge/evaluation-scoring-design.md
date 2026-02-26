---
title: Evaluation Scoring Design — Score Inflation Mitigation Research
tags: [evaluation, scoring, rubric, tiered-criteria, severity-gate]
source: 50+ sources via 6 parallel research agents (2026-02-20)
created: 2026-02-20
status: active
related: [llm-as-judge-evaluation.md]
---

# Evaluation Scoring Design Research

Phase 3 Step 1 research synthesis for redesigning ouroboros evaluation criteria.

## Problem Statement

Binary (0/1) criteria yield 5/5 too easily because they check "existence" not "quality". All criteria are threshold-based existence checks: "does trigger exist?", "does phase structure exist?", "does checkpoint exist?". Conscious authoring passes everything.

## Key Research Findings

### Scoring Scale

- **0-5 scale achieves highest human-LLM alignment** (ICC=0.853). 0-10 is worst (ICC=0.805). Source: arXiv 2601.03444
- **0-3 or 0-4 integer scale** recommended by multiple practitioners (Databricks, GoDaddy, Cameron Wolfe) — retains precision comparable to 0-10 with simpler rubric definition
- **Binary scoring has best inter-rater reliability** for objective tasks. LLMs cluster on specific integers in Likert scales (Source: EMNLP 2025 Findings)

### Score Inflation Root Cause: Agreeableness Bias

- LLM judges: True Positive Rate 96%, **True Negative Rate < 25%** — they approve almost everything. Source: arXiv 2510.11822
- Adding more scale levels may shift inflation upward (2/3 instead of 1) without solving the fundamental problem
- **Root cause is WHAT we measure, not HOW we score** — existence checks are inherently easy to pass

### Rubric Design Principles

- **Question-specific rubrics >> Question-agnostic rubrics** — domain-specific criteria substantially outperform generic ones. Source: ACM ICER 2025
- **Single criterion per aspect** — decompose, don't bundle. Source: Confident AI
- **Entire rubric as context** — presenting all criteria together is better than evaluating sequentially. Sequential evaluation causes excessive strictness (-0.329 offset)
- **Few-shot examples improve Cohen's κ from 0.54 → 0.74** — calibration anchors are critical
- **Evidence-anchored scoring** (RULERS framework) — require text evidence for every score, lock rubric interpretation

### Industry Tool Patterns

All major LLM eval tools (Promptfoo, DeepEval, Braintrust, Ragas, OpenAI Evals) normalize to 0-1 continuous float. But these evaluate OUTPUT quality, not component DEFINITION quality.

**No public framework evaluates agent/component definitions.** Our system is unique. Closest analogies:
- Google/Microsoft code review — qualitative, no numeric scores
- Education rubrics — 4-point descriptive (Absent/Developing/Proficient/Exemplary)
- CMMI maturity model — levels represent capability type changes, not numeric increments

### SonarQube Severity-Gate Model

Key insight: **Worst severity determines grade, not count.**
- Reliability A: zero bugs. E: one blocker bug. No amount of minor fixes compensates for a blocker.
- Applied to evaluation: Foundation-tier failures cap the maximum achievable level regardless of Craft/Excellence scores.

## Design Decision: Tiered Binary Criteria (DR-034)

### Approach

Keep binary scoring (best reliability) but add higher-difficulty tiers:

- **Tier 1 — Foundation**: Existing 5 criteria. "Does it exist?" Minimum bar.
- **Tier 2 — Craft**: 5-8 new criteria. "Is it well-made?" Quality, precision, completeness.
- **Tier 3 — Excellence**: 2-4 new criteria. "Is it exemplary?" Best practice, integration, calibration.

### Severity Gate

Foundation gates cap the maximum level. SonarQube-inspired:

| Foundation | Craft | Excellence | Level |
|---|---|---|---|
| ≤ 3 | — | — | 1 — Poor |
| 4 | — | — | 2 — Needs Work (cap) |
| 5 | ≤ threshold | — | 2 — Needs Work |
| 5 | mid-range | — | 3 — Good |
| 5 | high | ≤ threshold | 3 — Good |
| 5 | high | high | 4 — Excellent |

### Why Not Other Options

- **4-point rubric (0-3)**: Agreeableness bias shifts inflation to 2/3. Ambiguous middle levels where LLM judges are least reliable.
- **Hybrid (binary + rubric)**: Two scoring systems → complexity. Evaluator agent must switch between judgment modes.
- **Tiered binary wins**: Binary reliability preserved, root cause addressed (measure quality not just existence), simple evaluator logic.

## Key Sources

### Scoring Methodology
- arXiv 2601.03444 — Grading Scale Impact: 0-5 ICC=0.853
- arXiv 2306.05685 — MT-Bench: GPT-4 judge >80% agreement with humans
- arXiv 2310.08491 — Prometheus: custom rubric Pearson r=0.897
- arXiv 2307.10928 — FLASK: 12-skill decomposition, 1-5 per skill
- ACL 2024 — LLM-Rubric: multidimensional calibrated, RMS < 0.5

### Score Inflation & Bias
- arXiv 2510.11822 — Agreeableness bias: TPR 96%, TNR <25%
- arXiv 2506.22316 — Scoring bias: rubric order, score IDs, reference answer
- arXiv 2506.09443 — Pointwise ASR 100% vs pairwise 28%
- arXiv 2410.02736 — 12 bias types systematic classification (CALM)

### Practical Systems
- SonarQube — A-E severity-gate ratings
- CMMI — 5-level capability maturity model
- DORA — 4-cluster relative classification
- Promptfoo/DeepEval/Braintrust/Ragas — 0-1 continuous standard
- ResearchRubrics (Scale AI) — 3-point (0/0.5/1), 101 prompts × 20-43 criteria

### Agent Evaluation
- Anthropic "Demystifying Evals" — evaluate outcomes not paths
- Google ADK — tool trajectory + rubric-based quality (0-1)
- AutoGen AgentEval — CriticAgent + QuantifierAgent + VerifierAgent
- SWE-bench — binary test pass/fail
