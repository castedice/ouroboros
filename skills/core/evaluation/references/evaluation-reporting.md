# Evaluation Reporting and Bias Controls

## Report Format

Every evaluation report should follow the same structure.
Consistent structure makes comparisons possible across runs, evaluators, and versions.

```markdown
## Evaluation Report: {component name}

**Type**: {type}
**Mode**: {static|output|before-after}
**Overall Level**: {1-4} - {Poor|Needs Work|Good|Excellent}
**Score**: F: {n}/5 | Q: {n}/{max} | E: {n}/{max}

### Foundation (F)

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| F1 | {name} | {0|1} | {specific evidence} |

### Craft (Q)

{If Foundation < 5: "Skipped - Foundation incomplete (F: {n}/5)"}

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| Q1 | {name} | {0|1} | {specific evidence} |

### Excellence (E)

{If Craft < Q_high: "Skipped - Craft below threshold (Q: {n}/{max}, need >= {Q_high})"}

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| E1 | {name} | {0|1} | {specific evidence} |

### Strengths

- {explicit positive observation}

### Improvements

- **[HIGH]** {potential score-changing improvement}
- **[MED]** {substantive quality improvement}
- **[LOW]** {nice-to-have refinement}

### Recommendations

- {next step suggestion}
```

The reasoning line matters more than the numeric score.
A score without evidence is noise.

## Improvement Priority Tags

| Tag | Meaning | Typical Use |
|-----|---------|-------------|
| HIGH | Likely to change a criterion score or verdict | Missing structure, broken workflow, absent evidence |
| MED | Material quality improvement without a likely score jump | Better clarity, stronger examples, cleaner decision rules |
| LOW | Optional refinement that improves polish or readability | Minor wording, secondary example, extra cross-reference |

Use the smallest defensible priority.
Do not inflate a LOW issue into HIGH just to make it feel urgent.

## Bias Mitigation

Evaluation by an LLM judge carries systematic risks.
These are the primary bias controls that must stay active.

| Bias | Symptom | Countermeasure |
|------|---------|----------------|
| Position bias | Comparative verdict changes when order changes | Use position swap and explain any inconsistency |
| Verbosity bias | Longer components score higher regardless of quality | Apply the conciseness criterion explicitly |
| Self-enhancement | The evaluator over-rates its own model family | Require concrete evidence before every score |

### Batch Scan Risks

- Fatigue drift appears when later components score more generously than early ones.
- Countermeasure: evaluate each component independently and reload criteria every time.
- Anchoring appears when the previous component's score shapes the next one.
- Countermeasure: avoid relative statements like "better than the last file" unless the mode is explicitly comparative.

### Reporting Discipline

- Report skipped tiers explicitly instead of leaving them blank.
- Keep strengths and improvements evidence-based, not impressionistic.
- Call out criterion regressions even when the total score improves.
- Separate what the component did from what the evaluator inferred.
