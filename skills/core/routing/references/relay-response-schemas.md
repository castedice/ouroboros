# Relay Response Schemas

JSON response schemas for external model invocations via the Prompt Relay pattern. Each schema defines the expected output structure for a specific mode. Referenced by `commands/core/evaluate.md` Phase 3.5, `commands/core/research.md` Phase 3, `commands/core/brainstorm.md` Phase 3, and SWE commands (`commands/swe/ship.md`, `commands/swe/tune.md`) for `--multi` support.

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
| **Markdown-wrapped JSON** | Model wraps response in ` ```json ``` ` code blocks despite "no markdown" instruction | `invoke-model.sh` strips markdown fences before parsing; if still failing, reinforce "raw JSON only" in Section 4 |
| **Missing required fields** | Model omits fields it considers empty (e.g., `regressions: []`) | Schema definitions show all fields including empty arrays; `invoke-model.sh` validates field presence |
| **Terse reasoning** | Model writes 1-sentence reasoning despite "minimum 3 sentences" requirement | Repeat the minimum length constraint in both Section 3 (methodology) and Section 4 (format) |
| **Score-reasoning mismatch** | Model assigns score 1 but reasoning describes weaknesses, or vice versa | Consensus mechanism across models catches most mismatches; single-model mode relies on CoT-first scoring order |
| **coverage_assessment without questions** | Model populates `coverage_assessment` in non-deep mode when no research questions were provided | Field is optional; orchestrator ignores it if no research questions exist in the relay prompt |

## Design Rationale

- **Separate schemas per mode** (A/C/D/R/BR/SR/CR/SQ) rather than a unified schema with a `type` field: Each mode has fundamentally different output structures. A unified schema would require extensive conditional fields, making validation harder and model compliance lower. Separate schemas keep each prompt's Section 4 self-contained.
- **SWE schemas (SR/CR/SQ) use free-form findings**: Unlike evaluation criteria (binary 0/1 scoring), review findings are inherently variable in count and structure. Finding union + severity consensus is more appropriate than per-criterion agreement for review output.
- **`reasoning` minimum 3 sentences**: Binary scoring (0/1) requires explicit justification to prevent rubber-stamping. 3 sentences is the empirically tested minimum that forces the model to cite specific evidence rather than restate the criterion name. See `dev/experiments/model-optimization/` for calibration data.
- **`coverage_assessment` optional in Schema R**: Only meaningful when `--deep` provides research questions. Making it required would force non-deep relay prompts to fabricate questions, reducing signal quality.
- **`invoke-model.sh` fallback to LLM extraction**: JSON parsing failures are common with less structured models. Rather than failing entirely, the orchestrator extracts key fields from raw text — lower fidelity but preserves the multi-model signal.

## Usage

In the relay prompt Section 4, append:

```text
Respond ONLY with a JSON object (no markdown, no explanation outside JSON):
{schema content}
```

The `scripts/invoke-model.sh` parser validates the JSON structure. On parse failure (exit code 1), the command falls back to LLM extraction from raw output.
