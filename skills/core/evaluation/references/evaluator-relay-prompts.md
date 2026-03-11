# Evaluator Relay Prompt Templates

> Templates for constructing external model relay prompts in `/evaluate` Phase 3 (--multi).
> Each mode has a 4-section prompt assembled and saved to `.tmp/{SESSION_ID}_relay.txt`.
> All prompts follow the Prompt Relay pattern from `skills/core/routing/references/invocation-protocol.md`.

## Mode A/B: Static Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent evaluator. Your task is to assess the quality of a plugin component using the criteria provided below. Score each criterion independently with detailed reasoning. Do not assume any prior context — evaluate based solely on the content and criteria given.
```

**Section 2 — Content**: Raw target file content (verbatim from disk, no summarization).

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema A from `skills/core/routing/references/relay-response-schemas.md`.

## Mode C: Comparative Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent comparative evaluator. Your task is to assess two versions of a plugin component using the criteria provided. Score each version independently with detailed reasoning. Identify any regressions (criteria that dropped from 1 to 0). Determine a verdict: improved, degraded, or lateral.
```

**Section 2 — Content**: Both versions verbatim, separated by `=== BEFORE VERSION ===` and `=== AFTER VERSION ===` markers.

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema C from `skills/core/routing/references/relay-response-schemas.md`.

## Mode D: Output Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent output quality evaluator. Your task is to assess the actual output of a plugin component against output quality criteria. Score each criterion with detailed reasoning based on how well the output meets the standard.
```

**Section 2 — Content**: Component definition + collected output verbatim, separated by `=== COMPONENT DEFINITION ===` and `=== COLLECTED OUTPUT ===` markers.

**Section 3 — Criteria**: Raw output criteria reference content (`skills/core/evaluation/references/{type}-output-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema A from `relay-response-schemas.md` (same flat scoring).

## Assembly

All modes: `{Section 1}\n\n{Section 2}\n\n{Section 3}\n\n{Section 4}`.

**Critical**: Sections 2-3 are verbatim file content. The assembler must NOT summarize, paraphrase, or add commentary to these sections.
