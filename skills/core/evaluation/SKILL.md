---
name: evaluation-methodology
description: This skill provides evaluation methodology knowledge. It should be activated when an agent needs to "evaluate a component", "score plugin quality", "assess an agent definition", "judge a command's effectiveness", "compare before and after versions", or "rate output quality".
summary: Guides evidence-first component scoring with binary criteria, tier gates, comparison checks, and reproducible reporting.
version: 1
tags: [core, methodology, evaluation, scoring, quality-gates]
preamble_tier: 4
---

# Evaluation Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"You can't improve what you can't measure."**

Evaluation is evidence-first, binary, and reproducible.
Write the reasoning before the score, cite concrete evidence, and let the tier gates decide how far the evaluation proceeds.
Use this file for operating rules, and load the mapped references when you need the detailed scoring model, report schema, or criteria text.
The goal is consistency across runs, not cleverness in individual judgments.

## Gotchas

These are the failure modes most likely to corrupt an otherwise careful evaluation.

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Scoring before reasoning | Scoring | Write the evidence first, then assign the score |
| Vague evidence like "looks good" | Scoring | Quote or cite the exact section, field, or behavior that justifies the score |
| Wrong criteria file loaded | Type ID | Verify the path and frontmatter before loading criteria |
| Skipping position swap in before/after work | Comparison | Treat position swap as mandatory whenever the task is comparative |
| Score inflation across a batch | Module scan | Re-read the criteria for each component and avoid relative scoring |
| Evaluating higher tiers after Foundation fails | Tier scoring | Stop at the gate and mark higher tiers as skipped |
| Missing improvement priorities | Reporting | Tag every improvement as HIGH, MED, or LOW |

Rationalization red flags:

| Red Flag | What It Means | Correct Response |
|----------|---------------|------------------|
| No quote, no score | Reasoning lacks specific evidence from the component | Score 0 for that criterion |
| Overall score up but criterion regressed | Aggregate improvement hides local damage | Flag the regression explicitly |
| Close enough | Borderline case is being rationalized as passing | Binary criteria mean "almost" still scores 0 |
| Prior score anchoring | Current judgment is drifting toward a previous result | Re-evaluate from scratch and ignore history |
| Severity inflation | LOW work is being framed as HIGH to justify action | Use the evidence threshold, not urgency language |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The component clearly feels L4" | Assigning a level before criterion-by-criterion evidence is written | Write evidence and scores first, then let the gate determine the level |
| "This criterion mostly passes" | Awarding a binary criterion without exact supporting evidence | Score 0 or 1 according to the stated threshold and cite the decisive section or behavior |
| "The last run scored this high" | Letting historical results anchor the current evaluation | Reload criteria and re-score the current component from scratch |
| "The aggregate improved, so the comparison passes" | Hiding a criterion regression inside a higher total | Report the regression explicitly and reflect it in the verdict |
| "The static pass is enough" | Skipping dynamic checks when runtime output quality is the actual question | Add dynamic evaluation only for the behavior under test, then keep the static and dynamic evidence separate |

## Workflow

Run the sequence in order and do not skip the classification or gating steps.

1. Identify the component type and the evaluation mode from the path, frontmatter, and user goal.
2. Load the matching criteria files and the operating-model reference before scoring anything.
3. Score Foundation first, stop higher tiers when the gate says stop, and keep every 0 or 1 tied to explicit evidence.
4. For before/after work, evaluate each version independently, then run the position-swapped comparison check.
5. Produce the standard report with per-criterion reasoning, strengths, prioritized improvements, and a clear level or verdict.

## Decision Rules

Use these rules whenever the task leaves room for evaluator judgment.

| Decision Point | Rule |
|----------------|------|
| Static vs dynamic | Start with static evaluation, and add dynamic evaluation only when output quality or runtime behavior is the actual question |
| Type detection | Use location plus frontmatter, and ask the user if the file still does not classify cleanly |
| Tier gating | Foundation below 5 skips Craft and Excellence, and Craft below `Q_high` skips Excellence |
| Boundary cases | "Almost met" scores 0, while "meets the letter but not the spirit" scores 1 plus an improvement note |
| Comparative verdicts | Criterion regressions never disappear inside an aggregate improvement |
| Batch discipline | Re-load criteria for each component to avoid anchoring and fatigue drift |

## Reference Map

Load only the references the current task actually needs.

| Need | Reference |
|------|-----------|
| Scoring model, severity gates, comparison rules, target-type map | `${CLAUDE_SKILL_DIR}/references/evaluation-operating-model.md` |
| Report template, priority tags, and bias controls | `${CLAUDE_SKILL_DIR}/references/evaluation-reporting.md` |
| Static criteria by type | `${CLAUDE_SKILL_DIR}/references/agent-criteria.md`, `${CLAUDE_SKILL_DIR}/references/skill-criteria.md`, `${CLAUDE_SKILL_DIR}/references/command-criteria.md`, `${CLAUDE_SKILL_DIR}/references/hook-criteria.md`, `${CLAUDE_SKILL_DIR}/references/claudemd-criteria.md` |
| Dynamic criteria by type | `${CLAUDE_SKILL_DIR}/references/agent-output-criteria.md`, `${CLAUDE_SKILL_DIR}/references/skill-output-criteria.md`, `${CLAUDE_SKILL_DIR}/references/command-output-criteria.md`, `${CLAUDE_SKILL_DIR}/references/hook-output-criteria.md` |
| Saved regression result schema and run comparison format | `${CLAUDE_SKILL_DIR}/references/regression-format.md` |

## See Also

These are the components most likely to invoke or depend on this methodology.

- **evaluator agent** (`agents/core/evaluator.md`) - Primary consumer of this methodology during scoring work
- **evaluate command** (`commands/core/evaluate.md`) - Orchestrates static, comparative, and output evaluation modes
- **evolution-methodology** (`skills/core/evolution/SKILL.md`) - Uses evaluation results to choose and validate improvements
- **validation-methodology** (`skills/core/validation/SKILL.md`) - Runs the structural gate that should precede quality scoring
