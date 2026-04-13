# Evaluation Operating Model

## Two Evaluation Axes

All components can be evaluated on definition quality and, when relevant, output quality.
Definition quality answers whether the artifact itself is well made.
Output quality answers whether the artifact produces the right behavior or result when used.

| Axis | Question | Input | Use When |
|------|----------|-------|----------|
| Static evaluation | Is the component definition well structured and high quality | File path and file contents | Default mode for every component |
| Dynamic evaluation | Does the component produce good output or behavior when executed | Test set, observed output, or simulation results | Only when execution or output quality is the actual question |

Static evaluation is always available because it only requires the file.
Dynamic evaluation is more expensive and should be added only when execution provides material information.

## Tiered Binary Scoring

Criteria are scored as binary 0 or 1 judgments.
The goal is consistency and explicit justification, not fine-grained impression scoring.

| Tier | Name | Question | Count per Type |
|------|------|----------|----------------|
| F | Foundation | Does it exist | 5 for every type |
| Q | Craft | Is it well made | 5 to 7 depending on the type |
| E | Excellence | Is it exemplary | 3 to 4 depending on the type |

### Scoring Procedure

1. Write the reasoning before assigning the score.
2. Evaluate one criterion at a time.
3. Keep the criterion binary, and avoid partial-credit language.
4. Cite specific evidence for both 0 and 1 decisions.
5. Score all Foundation criteria first.
6. Skip Craft and Excellence when Foundation is below 5.
7. Score Craft only when Foundation is complete.
8. Skip Excellence when Craft is below `Q_high`.
9. Apply the severity gate after all allowed tiers are scored.

### Boundary Guide

| Situation | Judgment | Rationale |
|-----------|----------|-----------|
| Criterion is almost satisfied | 0 | Binary scoring treats "almost" as not met |
| Criterion meets the intent but not the written rule | 0 | The written rule is the scoring boundary |
| Criterion meets the letter but misses the spirit | 1 plus improvement note | Record the pass, then flag the qualitative gap |
| Criterion passes but could be better | 1 | Improvement belongs in the improvement list, not the score |

When in doubt, score 0.
False positives hide real work and weaken later evolution cycles.

## Severity Gate

Foundation caps the maximum level.
Perfect higher-tier work cannot compensate for missing fundamentals.

| Foundation | Craft | Excellence | Level |
|------------|-------|------------|-------|
| 0 to 3 | - | - | 1 - Poor |
| 4 | - | - | 2 - Needs Work |
| 5 | At or below `Q_low` | - | 2 - Needs Work |
| 5 | Between `Q_low + 1` and `Q_high - 1` | - | 3 - Good |
| 5 | At or above `Q_high` | Below `E_high` | 3 - Good |
| 5 | At or above `Q_high` | At or above `E_high` | 4 - Excellent |

Per-type thresholds are fixed by component type.

| Type | Q Count | `Q_low` | `Q_high` | E Count | `E_high` |
|------|---------|---------|----------|---------|----------|
| Agent | 7 | 3 | 6 | 4 | 3 |
| Command | 7 | 3 | 6 | 4 | 3 |
| Skill | 7 | 3 | 6 | 4 | 3 |
| Hook | 5 | 2 | 4 | 3 | 2 |
| CLAUDE.md | 6 | 2 | 5 | 3 | 2 |

## Before and After Comparison

Comparative evaluation is a three-part sequence.

1. Evaluate the before version independently.
2. Evaluate the after version independently.
3. Run a pairwise comparison with the order swapped once.

The comparison verdict is `improved`, `lateral`, or `degraded`.
Position swap is mandatory because order effects are a real bias source.
If the verdict changes after the swap, treat the comparison as unreliable and explain why.

## Target Type Map

### Static Evaluation Types

| Type | Criteria File | Focus |
|------|---------------|-------|
| Agent | `references/agent-criteria.md` | Trigger, prompt, model, tools, persona, integration |
| Skill | `references/skill-criteria.md` | Trigger, disclosure, reproducibility, bias, integration |
| Command | `references/command-criteria.md` | Phases, delegation, recovery, separation of concerns, integration |
| Hook | `references/hook-criteria.md` | Event matching, safety, performance, portability |
| CLAUDE.md | `references/claudemd-criteria.md` | Actionability, workflow, prohibitions, alignment, efficiency |

### Dynamic Evaluation Types

| Type | Criteria File | Test Method |
|------|---------------|-------------|
| Agent | `references/agent-output-criteria.md` | Test prompt and collect results |
| Skill | `references/skill-output-criteria.md` | Query with the skill loaded and compare behavior |
| Command | `references/command-output-criteria.md` | Execute with test input and observe workflow |
| Hook | `references/hook-output-criteria.md` | Simulate trigger conditions and inspect the effect |

If a markdown file sits outside the normal directories, use its frontmatter to classify it.
If the frontmatter does not settle the type, stop and ask the user.
