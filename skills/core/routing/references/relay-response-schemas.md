# Relay Response Schemas

JSON response schemas for external model invocations via the Prompt Relay pattern. Each schema defines the expected output structure for a specific mode. Referenced by `commands/core/evaluate.md` Phase 3.5, `commands/core/research.md` Phase 3, and `commands/core/brainstorm.md` Phase 3.

## Schema A: Static Evaluation (Mode A/B)

```json
{
  "criteria": [
    { "id": "C1", "name": "criterion name", "score": 0 or 1, "reasoning": "minimum 3 sentences with specific evidence" }
  ],
  "overall_score": "sum of criteria scores",
  "strengths": ["point 1", "point 2"],
  "improvements": [{ "priority": "HIGH|MED|LOW", "description": "suggestion" }],
  "context_used": ["instructions or skills referenced"]
}
```

Used for single-component static evaluation and module scan (each component individually).

## Schema C: Comparative Evaluation (Mode C)

```json
{
  "before": {
    "criteria": [
      { "id": "C1", "name": "criterion name", "score": 0 or 1, "reasoning": "minimum 3 sentences with specific evidence" }
    ],
    "overall_score": "sum of criteria scores"
  },
  "after": {
    "criteria": [
      { "id": "C1", "name": "criterion name", "score": 0 or 1, "reasoning": "minimum 3 sentences with specific evidence" }
    ],
    "overall_score": "sum of criteria scores"
  },
  "regressions": [
    { "criterion": "C1", "name": "criterion name", "reason": "why the after version is worse" }
  ],
  "verdict": "improved|degraded|lateral",
  "verdict_reasoning": "summary of comparison"
}
```

Used for before/after comparison. Both versions are evaluated independently within a single prompt.

## Schema D: Output Evaluation (Mode D)

Same structure as Schema A. The difference is in the relay prompt content (component definition + collected output) and criteria reference (output criteria instead of static criteria).

## Schema R: Research Analysis

```json
{
  "key_findings": ["finding 1", "finding 2"],
  "patterns": [
    { "name": "pattern name", "evidence": "quoted content from source", "trade_off": "pros vs cons" }
  ],
  "tradeoffs": ["trade-off 1"],
  "component_inventory": ["component 1"],
  "suggested_tags": ["tag1", "tag2"],
  "novel_insights": ["insight not obvious from surface reading"]
}
```

Used for external model research analysis in `/research --multi`. The orchestrator cherry-picks findings to merge with Claude researcher output.

## Schema BR: Brainstorm Analysis

```json
{
  "ideas": [
    { "name": "idea name", "technique": "SCAMPER|What-if|Analogy|First Principles|Constraint Removal|Reverse Engineering", "description": "one sentence", "feasibility": "High|Med|Low", "impact": "High|Med|Low", "rationale": "specific reason for feasibility and impact scores" }
  ],
  "clusters": [
    { "name": "cluster name", "idea_names": ["idea 1", "idea 2"], "theme": "what unites these ideas" }
  ],
  "top_3": [
    { "name": "idea name", "why": "specific rationale", "weakness": "honest weakness", "next_action": "/command args — what this achieves" }
  ],
  "novel_insights": ["insight or idea not obvious from the topic alone"]
}
```

Used for external model brainstorming in `/brainstorm --multi`. The orchestrator cherry-picks novel ideas and perspectives to merge with Claude brainstormer output.

## Usage

In the relay prompt Section 4, append:

```text
Respond ONLY with a JSON object (no markdown, no explanation outside JSON):
{schema content}
```

The `scripts/invoke-model.sh` parser validates the JSON structure. On parse failure (exit code 1), the command falls back to LLM extraction from raw output.
