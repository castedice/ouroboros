# Relay Response Schemas

JSON response schemas for external model invocations via the Prompt Relay pattern. Each schema defines the expected output structure for a specific mode. Referenced by `commands/core/evaluate.md` Phase 3.5, `commands/core/research.md` Phase 3, `commands/core/brainstorm.md` Phase 3, and SWE commands (`commands/swe/ship.md`, `commands/swe/tune.md`) for `--multi` support.

## `eval-model-result.v1`: Evaluation Relay Output

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
      "priority": "HIGH|MED|LOW",
      "criterion_id": "F1",
      "description": "One concrete improvement."
    }
  ]
}
```

Used for all evaluator relay prompts in `/evaluate`.
The pipeline normalizes this thin model-output schema into the canonical internal format before consensus or persistence.
Normalization guarantees `criteria` is an array of `{id, score, evidence, reasoning}` objects and derives tier totals, `level`, `level_label`, `gated`, and `gate_reason` deterministically.

## Schema A: Static Evaluation (Mode A/B, normalized internal shape)

```json
{
  "criteria": [
    { "id": "F1", "score": 0, "evidence": ["..."], "reasoning": "minimum 3 sentences with specific evidence" }
  ],
  "scores": { "F": [5, 5], "Q": [7, 7], "E": [3, 4] },
  "level": 4,
  "level_label": "Excellent",
  "gated": false,
  "gate_reason": null,
  "strengths": ["point 1", "point 2"],
  "improvements": [{ "priority": "HIGH|MED|LOW", "criterion_id": "F1", "description": "suggestion" }]
}
```

This is the normalized internal shape used after `scripts/eval-normalize.sh`.
It is not the raw model-output contract.

## Schema C: Comparative Evaluation (Mode C)

Mode C no longer uses a separate raw relay schema.
The command sends one evaluator relay per version using `eval-model-result.v1`, normalizes both results, and derives verdicts/regressions in the controller flow.

## Schema D: Output Evaluation (Mode D, normalized internal shape)

Same normalized shape as Schema A, except `scores` is flat output scoring such as `{ "C": [4, 5] }`.
The raw relay output still uses `eval-model-result.v1`.

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
  "novel_insights": ["insight not obvious from surface reading"],
  "coverage_assessment": [
    {
      "question": "research question text",
      "coverage": "strong|moderate|weak|unanswered",
      "evidence_summary": "brief description of supporting evidence",
      "gap_type": "collection|knowledge|scope",
      "suggested_query": "targeted follow-up query or null"
    }
  ]
}
```

Used for external model research analysis in `/research --multi`. The orchestrator cherry-picks findings to merge with Claude researcher output. The `coverage_assessment` field is optional — included only when `--deep` mode provides research questions in the relay prompt.

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

## Schema SR: Security Review

```json
{
  "findings": [
    {
      "id": "SR-1",
      "category": "VULN|SECRET|LICENSE",
      "severity": "P1|P2|P3",
      "location": "file:line or dependency name",
      "finding": "description of the issue",
      "remediation": "specific fix suggestion"
    }
  ],
  "summary": {
    "p1": 0,
    "p2": 0,
    "p3": 0
  }
}
```

Used for external model security review in `/swe ship --multi`. Findings are merged with Claude reviewer output using finding union + severity consensus.

## Schema CR: Code Review

```json
{
  "findings": [
    {
      "id": "CR-1",
      "perspective": "Architecture|Safety|Performance|Readability",
      "severity": "P1|P2|P3",
      "location": "file:line",
      "finding": "description of the issue",
      "suggestion": "specific improvement suggestion"
    }
  ],
  "summary": {
    "p1": 0,
    "p2": 0,
    "p3": 0,
    "by_perspective": {
      "Architecture": 0,
      "Safety": 0,
      "Performance": 0,
      "Readability": 0
    }
  }
}
```

Used for external model code review in `/swe ship --multi`. The 4-perspective classification matches the Claude reviewer's methodology.

## Schema SQ: SWE Quality Evaluate

```json
{
  "quality_rating": "High|Medium|Low",
  "improvement_targets": [
    {
      "priority": "HIGH|MED|LOW",
      "target": "what to improve",
      "rationale": "why this matters"
    }
  ],
  "contract_adherence": "description of how well code follows interface contracts",
  "constraint_compliance": "description of how well code respects constraint boundaries"
}
```

Used for external model quality evaluation in `/swe tune --multi`. Improvement targets are merged with Claude evaluator output using priority consensus.

## Common Pitfalls

| Pitfall | Cause | Remedy |
|---------|-------|--------|
| **Markdown-wrapped JSON** | Model wraps response in ` ```json ``` ` code blocks despite "no markdown" instruction | `codex-relay.sh` strips markdown fences before parsing; if still failing, reinforce "raw JSON only" in Section 4 |
| **Missing required fields** | Model omits fields it considers empty | Require `schema_version`, `criteria`, `strengths`, and `improvements` even when arrays are empty |
| **Terse reasoning** | Model writes 1-sentence reasoning despite "minimum 3 sentences" requirement | Repeat the minimum length constraint in both Section 3 (methodology) and Section 4 (format) |
| **Score-reasoning mismatch** | Model assigns score 1 but reasoning describes weaknesses, or vice versa | `eval-normalize.sh` keeps only parseable criterion judgments, and consensus uses the normalized result rather than trusting model-level totals |
| **coverage_assessment without questions** | Model populates `coverage_assessment` in non-deep mode when no research questions were provided | Field is optional; orchestrator ignores it if no research questions exist in the relay prompt |

## Design Rationale

- **Thin evaluator relay schema**: External evaluators emit only per-criterion judgments plus strengths/improvements. Tier totals, labels, and gates are deterministic controller logic, so pushing them into the model output adds noise without adding signal.
- **Separate schemas per task family** (`eval-model-result.v1`, `R`, `BR`, `SR`, `CR`, `SQ`) rather than a unified schema with a `type` field: Evaluation, research, brainstorming, and review outputs have different structures and validation needs. Keeping them separate improves compliance and reduces parsing ambiguity.
- **SWE schemas (SR/CR/SQ) use free-form findings**: Unlike evaluation criteria (binary 0/1 scoring), review findings are inherently variable in count and structure. Finding union + severity consensus is more appropriate than per-criterion agreement for review output.
- **`reasoning` minimum 3 sentences**: Binary scoring (0/1) requires explicit justification to prevent rubber-stamping. 3 sentences is the empirically tested minimum that forces the model to cite specific evidence rather than restate the criterion name. See `dev/experiments/model-optimization/` for calibration data.
- **`coverage_assessment` optional in Schema R**: Only meaningful when `--deep` provides research questions. Making it required would force non-deep relay prompts to fabricate questions, reducing signal quality.
- **`codex-relay.sh` fallback to LLM extraction**: JSON parsing failures are common with less structured models. Rather than failing entirely, the orchestrator extracts key fields from raw text — lower fidelity but preserves the multi-model signal.

## Usage

In the relay prompt Section 4, append:

```text
Respond ONLY with a JSON object (no markdown, no explanation outside JSON):
{schema content}
```

For evaluator relays, use `eval-model-result.v1`.
After parse, run `scripts/eval-normalize.sh` before consensus or persistence.
