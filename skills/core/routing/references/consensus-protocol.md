# Consensus Protocol — Multi-Model Result Integration

This reference defines how to integrate results from multiple models.
Three modes are available, each suited to different task types.

## Mode A: Cherry-pick

Select the single best output from multiple models.
Used when outputs vary in quality and one will clearly be superior, or when the task benefits from breadth rather than agreement.

### When to Use

- Pattern extraction (different models notice different patterns)
- Research analysis (broader coverage from multiple perspectives)
- Any task where outputs are complementary, not competing

### Protocol

```text
1. Collect all model outputs
2. Claude reviews each output against the task requirements
3. Select the most thorough/accurate output
4. Optionally combine unique insights from non-selected outputs
5. Report which model was selected and why
```

### Report Format

```text
**Selected**: {model name}
**Reason**: {why this output was best}
**Notable from other models**: {any unique insights worth preserving}
```

## Mode B: Consensus (Independent Scoring)

Multiple models score the same target independently.
Results are compared for agreement.
This is the primary mode for `/evaluate --multi`.

Mode B has two sub-modes: **majority rule** (fast) and **unanimous** (quality).

### When to Use

- Static evaluation (well-defined criteria, structured output)
- Before/after comparison (all models judge the same pair)
- Any task with a rubric or scoring framework

### Protocol — Majority Rule (Fast Path)

Use when speed matters more than perfect agreement.
Suitable for routine evaluations.

```text
Step 1: Independent Scoring
  - Claude evaluator scores via Task tool (existing flow, always runs first)
  - Codex scores via Bash relay prompt
  - No model sees any other model's results

Step 2: Score Alignment
  For each criterion (`F*`, `Q*`, `E*`, or `C*`):
    Compare Claude score vs Codex score
    If both agree → "unanimous" (high confidence)
    If they disagree → "split" (low confidence)

Step 3: Divergence Analysis
  For each non-unanimous criterion:
    - Extract reasoning from each model
    - Identify the substantive disagreement
    - For mechanical or structural criteria (F1-F5): use the lower score by default unless the higher scorer cites direct satisfying evidence
    - For qualitative criteria (Q1-Q7, E1-E4): treat the split as unresolved, use the stricter score by default, and escalate only when the models present contradictory factual evidence rather than different thresholds, subject to the boundary criteria exception below
    - If a single default must be chosen, the stricter score wins and the split remains flagged in the report
    - **Boundary criteria exception (F3, Q5, E1, E2, E3):** For these criteria, do not apply the stricter-score default merely because the criterion is qualitative. Score the criterion from criterion-local evidence. Use the score backed by stronger local evidence. If both readings remain defensible on unchanged local evidence and the disagreement is threshold interpretation rather than contradictory facts, record the criterion as unresolved variance instead of forcing the stricter score

Step 4: Self-Enhancement Bias Check
  For each criterion where Claude scored 1 and ALL external models scored 0:
    Flag as "potential self-enhancement bias"
    This does not change the score, but alerts the user to examine this criterion

Step 5: Composite Report
  - Final score: sum of consensus scores (majority rule per criterion)
  - Per-criterion: consensus score + agreement level + divergence flag
  - Model agreement rate: (unanimous criteria / total criteria)
  - Include reasoning from the model that best articulated the consensus position
```

### Protocol — Unanimous (Quality Path)

Use for high-stake decisions where a split criterion should not be resolved by a simple controller-side tiebreak.
The initial scoring still happens independently.
Any split then goes through a single deliberative round run by fresh external Codex sessions only, so Claude does not participate in the resolution step.

```text
Step 1-2: Same as Majority Rule (independent scoring + alignment)

Step 3: Deliberative Consensus
  For each split criterion:
    a. Define the current score assignment to defend.
       - This is the provisional score the controller would otherwise carry forward for the criterion.
    b. Assemble two evidence packets from the original evaluator outputs.
       - Packet FOR supports the current assignment with direct evidence.
       - Packet AGAINST challenges the current assignment, surfaces overlooked evidence, and attacks weak reasoning.
    c. Launch 3 independent Codex sessions:
       - Advocate argues FOR the current assignment using Packet FOR.
       - Devil's Advocate argues AGAINST the current assignment using Packet AGAINST.
       - Judge receives only the criterion name, evidence brief A, and evidence brief B.
    d. Apply strict Judge blinding:
       - Remove model names.
       - Remove raw numeric scores.
       - Do not reveal which brief supports the current assignment.
    e. Judge output schema:
       - verdict: agree-with-A | agree-with-B | insufficient-evidence
       - reasoning: concise justification tied to the briefs
    f. Auto-escalate immediately if any trigger fires:
       - Judge says insufficient-evidence.
       - All 3 roles disagree after normalization, so no stable two-role alignment remains on the outcome or factual framing.
       - The criterion has real-world safety implications.
       - Evidence brief A and evidence brief B contradict each other on facts.
       - A prior round already escalated the same criterion.
       - The component is a meta skill (`preamble_tier: 4`).
    g. Maximum 1 deliberation round per criterion

Step 4: Resolution
  - If the Judge agrees with brief A or brief B and no escalation trigger fired: use the score mapped to that brief.
  - If escalated: present the criterion to the user with both briefs and the Judge reasoning.

Step 5: Same bias check and report as Majority Rule
```

### Choosing Between Majority and Unanimous

| Factor | Majority (Fast) | Unanimous (Quality) |
|--------|----------------|-------------------|
| Speed | 1 round | 1 round + 1 deliberation round per split criterion |
| Cost | N model calls | N model calls + (split criteria × 3 fresh Codex sessions) |
| Confidence | Medium (majority agreement) | High (blinded adversarial ruling or user escalation) |
| Best for | Routine evaluations, module scans | Architecture decisions, evolution validation |
| Default | Yes (when `--multi` specified) | When `--multi --unanimous` specified |

### Agreement Rate Interpretation

| Rate | Criteria Agreement | Confidence | User Action |
|------|-------------------|------------|-------------|
| 5/5 (100%) | All unanimous | High | Use consensus score directly |
| 4/5 (80%) | 1 divergent | Good | Use consensus, note the divergent criterion |
| 3/5 (60%) | 2 divergent | Moderate | Use consensus, recommend human review of divergent criteria |
| 2/5 (40%) | 3 divergent | Low | Flag entire evaluation for human review |
| 1/5 (20%) | 4+ divergent | Very Low | Evaluation unreliable — investigate criteria interpretation |

Low agreement rates (below 60%) may indicate:

- Ambiguous criteria definitions (fix the criteria, not the models)
- Component at a boundary quality level, where most criteria default stricter but the named boundary criteria require criterion-local evidence review
- Prompt relay issue (framing bias causing systematic divergence)

Rationale:
A split usually means the component is on the boundary.
Most boundary cases should be treated as not-yet-passing to drive improvement.
For the named boundary criteria exception above, criterion-local evidence outranks the generic stricter-score default because those criteria are intended to distinguish real regressions from evaluator variance at stable boundaries.

### Self-Enhancement Bias Detection

The LLM-as-judge literature shows ~10% self-enhancement bias, so models rate their own output higher.
In ouroboros, Claude may have authored the component being evaluated, creating a conflict of interest.

Detection rule:

```text
IF Claude.score[Cx] == 1
AND Codex.score[Cx] == 0
THEN flag Cx as "potential self-enhancement bias"
```

This flag appears in the report as a warning.
It does NOT automatically change the score.
The user decides whether Claude's or external models' judgment is more appropriate.

### Report Format (Mode B)

Report template extracted to `templates/core/multi-model-report.md`.
The template defines the base structure, namely header, Per-Criterion Consensus table, Divergence Analysis, Strengths or Improvements, and Context Verification, plus any mode-specific additions.

### Before/After Consensus (Mode C Extension)

When Mode B is used for before or after comparison, such as `/evaluate --before X --after Y --multi`:

```text
Step 1: Apply standard Mode B consensus to BEFORE scores (per-criterion majority rule)
Step 2: Apply standard Mode B consensus to AFTER scores (per-criterion majority rule)
Step 3: Verdict Consensus
  - Each model provides a verdict: improved | degraded | lateral
  - If both agree → unanimous verdict
  - If split: use the stricter verdict as the default (`degraded` > `lateral` > `improved`), flag in report
Step 4: Regression Consensus
  - Union of all models' regression findings
  - A regression is confirmed if flagged by either model
Step 5: With --unanimous, apply the standard deliberative consensus path to:
  - Non-unanimous per-criterion scores
  - Non-unanimous verdicts, with Advocate defending the current verdict and Devil's Advocate challenging it
  - The same Judge blinding rules, output schema, and 6 auto-escalation triggers
  - Maximum 1 deliberation round per score or verdict
  - If escalated: present the user with both blinded briefs
```

Store additionally: `verdict_consensus`, `verdict_agreement` (unanimous or majority or split), `regression_consensus` (confirmed regressions).

## Mode C: Synthesis

Combine the strongest aspects from each model's output into a unified result.
Used for complex, multi-faceted tasks where each model contributes unique value.

### When to Use

- Architectural decision analysis (different models surface different trade-offs)
- Complex research synthesis (broader coverage than any single model)
- Gap analysis in `/absorb` (different models find different gaps)

### Protocol

```text
1. Collect all model outputs
2. Claude identifies unique contributions from each model:
   - What did Codex mention that Claude missed?
   - What did Claude itself contribute uniquely?
3. Synthesize a unified output preserving all unique insights
4. Attribute contributions: "[from Codex]", "[from Claude]"
5. Highlight contradictions between models (if any) as open questions
```

### Report Format

```text
**Synthesized from**: Claude + Codex
**Unique contributions**: {model}: {n} insights, ...

{Synthesized content with attribution markers}

**Open contradictions**:
- {Claude says X, Codex says Y — user should decide}
```

## Integration Mode Selection Guide

| Situation | Mode | Rationale |
|-----------|------|-----------|
| Scoring with rubric | B-majority (Consensus) | Structured output enables direct score comparison |
| High-stake scoring | B-unanimous (Consensus) | Full agreement or user escalation |
| Choosing between approaches | A (Cherry-pick) | Select the most compelling option |
| Comprehensive analysis | C (Synthesis) | No single model captures everything |
| Quick validation | A (Cherry-pick) | Speed over thoroughness |
| Adversarial review | A (Cherry-pick) | External model as devil's advocate, Claude evaluates critique |
