# Consensus Protocol — Multi-Model Result Integration

This reference defines how to integrate results from multiple models. Three modes are available, each suited to different task types.

## Mode A: Cherry-pick

Select the single best output from multiple models. Used when outputs vary in quality and one will clearly be superior, or when the task benefits from breadth rather than agreement.

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

Multiple models score the same target independently. Results are compared for agreement.
This is the primary mode for `/evaluate --multi`.

Mode B has two sub-modes: **majority rule** (fast) and **unanimous** (quality).

### When to Use

- Static evaluation (well-defined criteria, structured output)
- Before/after comparison (all models judge the same pair)
- Any task with a rubric or scoring framework

### Protocol — Majority Rule (Fast Path)

Use when speed matters more than perfect agreement. Suitable for routine evaluations.

```text
Step 1: Independent Scoring
  - Claude evaluator scores via Task tool (existing flow, always runs first)
  - Codex scores via Bash relay prompt
  - No model sees any other model's results

Step 2: Score Alignment
  For each criterion (C1-C5):
    Compare Claude score vs Codex score
    If both agree → "unanimous" (high confidence)
    If they disagree → "split" (low confidence)

Step 3: Divergence Analysis
  For each non-unanimous criterion:
    - Extract reasoning from each model
    - Identify the substantive disagreement
    - Use Claude's score as the final score on splits, flag in report

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

Use for high-stake decisions where all models must agree. Trades speed for confidence. If unanimous agreement cannot be reached after convergence iterations, escalate to user.

```text
Step 1-2: Same as Majority Rule (independent scoring + alignment)

Step 3: Divergence Resolution Loop
  For each split criterion:
    a. Share Claude's reasoning with Codex:
       "The other evaluator scored this criterion {0|1} because: {reasoning}.
        Do you maintain your score of {score}? Explain why."
    b. If Codex changes its score → unanimous reached
    c. If Codex maintains its score with new reasoning →
       share this reasoning with Claude for reconsideration
    d. Maximum 2 convergence iterations per criterion

Step 4: Resolution
  - If unanimous after convergence: use the agreed score
  - If still divergent after 2 iterations: escalate to user
    "Models disagree on C{n} after deliberation. Claude says {x} because {reason}.
     Codex says {y} because {reason}. Which assessment do you agree with?"

Step 5: Same bias check and report as Majority Rule
```

### Choosing Between Majority and Unanimous

| Factor | Majority (Fast) | Unanimous (Quality) |
|--------|----------------|-------------------|
| Speed | 1 round | Up to 3 rounds per divergent criterion |
| Cost | N model calls | N + (divergent × 2-4) model calls |
| Confidence | Medium (majority agreement) | High (full agreement or user decision) |
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
- Component at a boundary quality level (genuinely hard to judge)
- Prompt relay issue (framing bias causing systematic divergence)

### Self-Enhancement Bias Detection

The LLM-as-judge literature shows ~10% self-enhancement bias: models rate their own output higher. In ouroboros, Claude may have authored the component being evaluated, creating a conflict of interest.

Detection rule:

```text
IF Claude.score[Cx] == 1
AND Codex.score[Cx] == 0
THEN flag Cx as "potential self-enhancement bias"
```

This flag appears in the report as a warning. It does NOT automatically change the score. The user decides whether Claude's or external models' judgment is more appropriate.

### Report Format (Mode B)

Report template extracted to `templates/core/multi-model-report.md`. The template defines the base structure (header, Per-Criterion Consensus table, Divergence Analysis, Strengths/Improvements, Context Verification) and mode-specific additions.

### Before/After Consensus (Mode C Extension)

When Mode B is used for before/after comparison (e.g., `/evaluate --before X --after Y --multi`):

```text
Step 1: Apply standard Mode B consensus to BEFORE scores (per-criterion majority rule)
Step 2: Apply standard Mode B consensus to AFTER scores (per-criterion majority rule)
Step 3: Verdict Consensus
  - Each model provides a verdict: improved | degraded | lateral
  - If both agree → unanimous verdict
  - If split: use Claude's verdict as tiebreaker, flag in report
Step 4: Regression Consensus
  - Union of all models' regression findings
  - A regression is confirmed if flagged by either model
Step 5: With --unanimous, apply convergence prompts to:
  - Non-unanimous per-criterion scores (same as standard unanimous path)
  - Non-unanimous verdict (share majority verdict + reasoning, ask minority to reconsider)
  - Maximum 2 verdict convergence iterations
  - If still divergent: escalate to user
```

Store additionally: `verdict_consensus`, `verdict_agreement` (unanimous/majority/split), `regression_consensus` (confirmed regressions).

## Mode C: Synthesis

Combine the strongest aspects from each model's output into a unified result. Used for complex, multi-faceted tasks where each model contributes unique value.

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
