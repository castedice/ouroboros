# Quality Gate Guide

> Reference for the evolution-methodology skill. Detailed quality gate logic, regression analysis, and retry strategies.

## Quality Gate Overview

The quality gate is the single checkpoint that determines whether evolution changes are accepted or rejected. It operates on the output of before/after evaluation — never on subjective judgment.

### Three Verdicts

| Verdict | Condition | Action |
|---------|-----------|--------|
| **improved** | After score > Before score, no regressions | Accept changes, proceed to Record |
| **lateral** | After score = Before score, no regressions | Ask user — changes may have qualitative value |
| **degraded** | After score < Before score, OR any regression found | Reject changes, analyze cause |

## Regression Analysis

### Definition

A **regression** occurs when a criterion that scored 1 in the Before version scores 0 in the After version.

### Why Regressions Override Total Score

Consider this scenario:

- Before: C1=1, C2=0, C3=1, C4=0, C5=1 → 3/5
- After: C1=1, C2=1, C3=0, C4=1, C5=1 → 4/5

Total score improved (3→4), but **C3 regressed** (1→0). This means the evolution broke something that was working. The quality gate flags this as "improved with regression warning" — the C3 regression must be reviewed.

### Regression Detection Procedure

1. Align criteria results: Before[C1..C5] vs After[C1..C5]
2. For each criterion where Before=1:
   - If After=0 → **regression detected**
3. For each criterion where Before=0:
   - If After=1 → **improvement confirmed**
4. Summarize: `{n} improvements, {m} regressions`

### Regression Response Matrix

| Regressions | Score Change | Verdict | Action |
|-------------|-------------|---------|--------|
| 0 | Increased | `improved` | Accept |
| 0 | Same | `lateral` | Ask user |
| 0 | Decreased | Should not happen (logic error) | Investigate |
| 1+ | Increased | `improved` with warning | Review regression cause, accept if intentional trade-off |
| 1+ | Same | `degraded` | Reject — net zero with breakage |
| 1+ | Decreased | `degraded` | Reject |

## Lateral Verdict Handling

A `lateral` verdict means the score did not change and no regressions occurred. This does NOT mean the changes are valueless. Common scenarios:

| Scenario | Recommendation |
|----------|---------------|
| Changes improve readability but criteria don't capture this | Keep — real quality gain, criteria gap |
| Changes restructure without quality change | Keep if preparation for next evolution |
| Changes attempted improvement but missed the mark | Discard — try a different approach |

Always present the decision to the user with context about what the changes actually did.

## Retry Strategy

### When to Retry

Retry when validation fails (`degraded`) and the evolution target is still valid.

### Retry Procedure

1. **Analyze failure**: Why did the After version score lower?
   - Was the root cause misdiagnosed?
   - Did the fix introduce a new problem?
   - Was the approach fundamentally wrong?
2. **Rollback**: Restore the before snapshot
3. **Re-analyze**: Return to Stage 2 (Analysis) with the failure cause as additional context
4. **Plan differently**: The new plan must use a different approach — repeating the same method violates retry policy
5. **Apply and validate again**

### Retry Limits

| Attempt | Action |
|---------|--------|
| 1st failure | Analyze cause, retry with different approach |
| 2nd consecutive failure | Stop. Ask user for direction |

### Why 2-Failure Limit?

Two consecutive failures suggest a fundamental misunderstanding — either of the component's purpose, the criteria's intent, or the improvement direction. Continuing without human input risks:

- Further degradation
- Wasted context on unproductive cycles
- Compounding misdiagnosis

## Edge Cases

### Already at Level 4 (Excellent)

When a component reaches Level 4 (all tiers passed), the standard quality gate has limited room for improvement.

**Approach**:

1. Inform user: "Already at max level. [MED]/[LOW] improvements available."
2. If user proceeds, evaluate qualitatively rather than by level
3. Use pairwise comparison to detect improvement beyond criteria thresholds

### Single Criterion Focus

When `--focus` restricts evolution to specific criteria:

- Quality gate applies only to the focused criteria
- Other criteria must not regress (regression check still applies globally)

### Module-Wide Evolution

When evolving a module (not a single component):

- Quality gate applies per-component — each component must pass independently
- Module-level improvement is the aggregate of individual component improvements
