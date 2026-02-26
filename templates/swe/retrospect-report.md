# Retrospect Report Template (Tune Composite)

Depth markers: `[Light+]` = Light, Standard, Deep. `[Standard+]` = Standard, Deep. `[Deep]` = Deep only.

---

## Header <!-- [Light+] -->

```markdown
# Retrospect Report: {title}

**Composite**: Tune (Feedback Pipeline)
**Depth**: E:{level} I:{level} R:{level}
**Task**: {task description}
**Entry Artifact**: {path to ship report or upstream artifact}
**Date**: {YYYY-MM-DD}
```

---

## Evaluation Summary <!-- [Light+] -->

Code quality assessment results. At Light depth: rating and top findings only.

```markdown
### Quality Assessment

**Overall Rating**: {rating — e.g., 4/5, Good, Satisfactory}
**Source Files Evaluated**: {count}
**Improvement Targets Identified**: {count}

### Top Findings

| # | Category | Finding | Severity |
|---|----------|---------|----------|
| 1 | {quality dimension — correctness, performance, readability, etc.} | {brief description} | High / Medium / Low |
```

If evaluation was skipped or failed:

```markdown
**Evaluation**: {Skipped (reason) / Failed (error)}
```

---

## Improvement Results <!-- [Standard+] -->

Code improvements applied based on evaluation findings. Skipped at Light depth.

```markdown
### Improvements Applied

| # | Target | Change | Tests | Status |
|---|--------|--------|-------|--------|
| 1 | {evaluation finding addressed} | {what was changed} | {pass/total after change} | Applied / Reverted |

### Green State

**Before improvements**: {pass}/{total} tests passing
**After improvements**: {pass}/{total} tests passing
**Regressions**: {count} (all reverted)
```

If no improvements applied:

```markdown
**No improvements applied.** {Reason — evaluation clean, all improvements caused regressions, or improve phase skipped}
```

---

## Patterns Identified <!-- [Light+] -->

Recurring approaches that worked well during this engineering cycle.

```markdown
| # | Pattern | Where Applied | Reusable? |
|---|---------|--------------|-----------|
| 1 | {pattern name — e.g., "Result type for all fallible operations"} | {stage or file where pattern appeared} | Yes / Context-specific |
```

At Light depth: 3-5 patterns. At Standard+: comprehensive pattern inventory.

---

## Learnings <!-- [Light+] -->

Insights discovered during the engineering process.

```markdown
### What Worked Well
- {approach or decision that proved effective, with evidence}

### What Could Improve
- {area where the process was suboptimal, with specific observation}

### Surprises
- {unexpected discovery — requirement gap, performance characteristic, integration issue}
```

---

## Decision Log <!-- [Standard+] -->

Key choices made during the cycle with rationale and outcomes.

```markdown
| # | Decision Point | Stage | Options Considered | Choice Made | Rationale | Outcome |
|---|---------------|-------|-------------------|-------------|-----------|---------|
| 1 | {what was decided} | {pipeline stage} | {alternatives} | {selected option} | {why} | {result — good/bad/neutral} |
```

---

## Process Metrics <!-- [Deep] -->

Quantitative measurements across the pipeline.

```markdown
### Pipeline Metrics

| Metric | Value |
|--------|-------|
| Total stages executed | {count} |
| Stages at Light depth | {count} |
| Stages at Standard depth | {count} |
| Stages at Deep depth | {count} |
| Backward transitions | {count} |
| Artifacts produced | {count} |

### Code Metrics

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Test count | {n} | {n} | {+/-n} |
| Test pass rate | {%} | {%} | {+/-pp} |
| Lines of code | {n} | {n} | {+/-n} |
| P1 findings | {n} | {n} | {+/-n} |
| P2 findings | {n} | {n} | {+/-n} |

### Depth Accuracy <!-- [Standard+] -->

| Stage | Planned Depth | Actual Effort | Calibration | Notes |
|-------|--------------|---------------|-------------|-------|
| {stage} | {planned} | {actual — was the depth appropriate?} | Over / Under / Correct | {what would have been better and why} |
```

---

## Technical Debt Tracker <!-- [Deep] -->

Accumulated technical debt with tracking across spiral turns.

```markdown
| # | Item | Source Stage | Priority | Turn Introduced | Status |
|---|------|-------------|----------|----------------|--------|
| 1 | {debt item} | {stage where identified — e.g., Stage 8 Optimize} | High / Medium / Low | {this turn or previous} | New / Carried / Resolved |
```

---

## Feedback for Next Cycle <!-- [Light+] -->

Actionable input for the next spiral turn. At Light depth: suggested next task only. At Standard+: comprehensive feedback.

```markdown
### New Constraints Discovered <!-- [Standard+] -->
{Constraints to add to the next Constraint Profile}

### Interface Gaps <!-- [Standard+] -->
{Contract gaps for the next Interface stage}

### Architecture Recommendations <!-- [Standard+] -->
{Structural improvements for the next Design stage}

### Process Improvements <!-- [Standard+] -->
{Pipeline improvements — depth adjustments, tool gaps, methodology refinements}

### Suggested Next Task <!-- [Light+] -->
**Task**: {recommended focus for the next spiral turn}
**Rationale**: {why this task should be next — based on retrospect findings}
**Recommended Depth**: {S:level D:level H:level N:level}
```

---

## Exit Criteria Checklist <!-- [Light+] -->

```markdown
- [ ] Evaluation summary with quality rating
- [ ] Patterns identified (minimum 3)
- [ ] Learnings documented (what worked, what to improve)
- [ ] Suggested next task with rationale
- [ ] {At Standard+} Improvements applied with Green state confirmation
- [ ] {At Standard+} Decision log with rationale and outcomes
- [ ] {At Standard+} Comprehensive feedback for next cycle (constraints, interfaces, architecture, process)
- [ ] {At Deep} Process metrics collected
- [ ] {At Deep} Technical debt tracked across turns
- [ ] {At Standard+} Depth calibration assessment (Over/Under/Correct per stage)
```
