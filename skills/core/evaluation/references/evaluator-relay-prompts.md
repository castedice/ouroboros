# Evaluator Relay Prompt Templates

> Templates for constructing external model relay prompts in `/evaluate` Phase 3 (--multi).
> Each mode has a 4-section prompt assembled and saved to `.tmp/{SESSION_ID}_relay.txt`.
> All prompts follow the Prompt Relay pattern from `skills/core/routing/references/invocation-protocol.md`.

## Shared Response Schema (`eval-model-result.v1`)

Use this exact Section 4 block for every evaluator relay prompt.
Do not ask the model to compute level, tier totals, labels, verdicts, or regressions.
The evaluation pipeline derives those deterministically after normalization.

```text
Respond ONLY with a JSON object (no markdown and no explanation outside JSON) using this exact schema:
```

```json
{
  "schema_version": "eval-model-result.v1",
  "criteria": [
    {
      "id": "F1",
      "score": 0,
      "evidence": ["Quoted or paraphrased evidence from the component or output"],
      "reasoning": "Why the evidence does or does not satisfy the criterion."
    }
  ],
  "strengths": ["One concrete strength"],
  "improvements": [
    {
      "priority": "HIGH",
      "criterion_id": "F1",
      "description": "One concrete improvement."
    }
  ]
}
```

## Mode A/B: Static Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent evaluator.
Your task is to assess the quality of a plugin component using the criteria provided below.
Judge each criterion independently with explicit evidence and reasoning.
Do not assume any prior context.
Evaluate only from the provided content and criteria.
```

**Section 2 — Content**: Raw target file content (verbatim from disk, no summarization).

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use the exact `eval-model-result.v1` block above.

## Mode C: Comparative Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent evaluator for a before-or-after version of a plugin component.
Your task is to assess the provided version using the criteria below.
Judge each criterion independently with explicit evidence and reasoning.
Do not assume any prior context.
Evaluate only from the provided content and criteria.
```

**Section 2 — Content**: One version verbatim per relay prompt, labeled as either `=== BEFORE VERSION ===` or `=== AFTER VERSION ===`.

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use the exact `eval-model-result.v1` block above.

The command runs one relay per version and performs verdict/regression analysis after both normalized results are available.

## Mode D: Output Evaluation

**Section 1 — Role** (fixed):

```text
You are an independent output quality evaluator.
Your task is to assess the actual output of a plugin component against the output quality criteria provided below.
Judge each criterion independently with explicit evidence and reasoning.
Do not assume any prior context.
Evaluate only from the provided component definition, output, and criteria.
```

**Section 2 — Content**: Component definition + collected output verbatim, separated by `=== COMPONENT DEFINITION ===` and `=== COLLECTED OUTPUT ===` markers.

**Section 3 — Criteria**: Raw output criteria reference content (`skills/core/evaluation/references/{type}-output-criteria.md`, verbatim).

**Section 4 — Response Format**: Use the exact `eval-model-result.v1` block above.

## Deliberative Consensus Roles (`--unanimous`)

Use these follow-up prompts only for the deliberative consensus path in `skills/core/routing/references/consensus-protocol.md`.

### Advocate

**Role** (fixed):

```text
You are the Advocate in a deliberative consensus check.
Defend the current score assignment for one criterion using only the evidence provided.
Cite the strongest evidence, acknowledge the main weakness, and do not mention model names or raw numeric scores.
```

**Evidence Format**:

```text
Criterion: {criterion_name}
Current assignment: {plain-language claim to defend}
Evidence for the claim:
- {fact}
- {fact}
Evidence to answer:
- {counterpoint}
```

**Response Schema**:

```text
brief: {3-5 sentence defense of the current assignment}
key_evidence:
- {fact}
main_weakness: {largest remaining uncertainty}
```

### Devil's Advocate

**Role** (fixed):

```text
You are the Devil's Advocate in a deliberative consensus check.
Argue against the current score assignment for one criterion using only the evidence provided.
Challenge weak reasoning, surface overlooked evidence, and do not mention model names or raw numeric scores.
```

**Evidence Format**:

```text
Criterion: {criterion_name}
Current assignment: {plain-language claim to challenge}
Evidence against the claim:
- {fact}
- {fact}
Evidence to rebut:
- {supporting point}
```

**Response Schema**:

```text
brief: {3-5 sentence challenge to the current assignment}
key_evidence:
- {fact}
strongest_rebuttal: {most damaging overlooked point}
```

### Judge

**Role** (fixed):

```text
You are the Judge in a deliberative consensus check.
You receive only a criterion name and two blinded evidence briefs labeled A and B.
Do not infer model identity or raw scores.
Choose the better-supported brief, or return insufficient-evidence if neither brief is reliable enough.
```

**Evidence Format**:

```text
Criterion: {criterion_name}
Evidence brief A:
{brief_a}

Evidence brief B:
{brief_b}
```

**Response Schema**:

```json
{
  "verdict": "agree-with-A | agree-with-B | insufficient-evidence",
  "reasoning": "2-4 sentences explaining which brief is better supported and why."
}
```

## Assembly

Evaluation modes A-D: `{Section 1}\n\n{Section 2}\n\n{Section 3}\n\n{Section 4}`.

**Critical**: In evaluation modes A-D, Sections 2-3 are verbatim file content.
The assembler must NOT summarize, paraphrase, or add commentary to these sections.
