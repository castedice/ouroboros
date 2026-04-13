# Ambiguity Rubric Template (Phase 1.5 — Pre-Spec)

Use this rubric before `/swe spec` invests in full specification work.
Score each axis from `0.0` to `1.0`, where lower is clearer.
Composite ambiguity score = `(goal_clarity * 0.40) + (constraint_clarity * 0.30) + (success_criteria_clarity * 0.30)`.

## Scale

| Score | Guidance |
|-------|----------|
| `0.0` | Crystal clear. The task states the needed detail explicitly and leaves little room for interpretation. |
| `0.5` | Moderate gaps. The broad intent is visible, but important assumptions still need confirmation. |
| `1.0` | Completely vague. Key information is missing, contradictory, or too underspecified to act on safely. |

## Axes

| Axis | Weight | Ask | `0.0` | `0.5` | `1.0` |
|------|--------|-----|-------|-------|-------|
| Goal clarity | `0.40` | Is the desired outcome unambiguous? | Outcome, scope, and change target are explicit. | Outcome is partly clear, but scope or target is fuzzy. | No reliable outcome can be inferred. |
| Constraint clarity | `0.30` | Are boundaries, requirements, and non-negotiables stated? | Requirements and guardrails are explicit. | Some guardrails exist, but critical boundaries are missing. | Constraints are absent or contradictory. |
| Success criteria clarity | `0.30` | Can you tell when the task is done? | Done state and acceptance evidence are explicit. | Done state is implied, but verification is incomplete. | No completion test or acceptance signal is available. |

## Output Format

```markdown
# Ambiguity Assessment: {task summary}

## Summary
> Composite ambiguity score: {score} → {PASS | CLARIFY | ABORT}.

| Axis | Weight | Score | Evidence | Missing Information |
|------|--------|-------|----------|---------------------|
| Goal clarity | 0.40 | {0.0-1.0} | {what is explicit} | {gap or "None"} |
| Constraint clarity | 0.30 | {0.0-1.0} | {what is explicit} | {gap or "None"} |
| Success criteria clarity | 0.30 | {0.0-1.0} | {what is explicit} | {gap or "None"} |

## Decision
- PASS when composite ambiguity score is `<= 0.2`.
- CLARIFY when composite ambiguity score is `> 0.2` and `<= 0.5`.
- ABORT when composite ambiguity score is `> 0.5`.

## Clarifying Questions
1. {question for weakest axis}
2. {question for weakest axis}
3. {question for weakest axis}
```
