# Evolution Bias Patterns

> Reference for the evolution-methodology skill. Detailed bias patterns, detection signals, and countermeasures.

## Why Bias Awareness Matters

Evolution involves an AI modifying artifacts and then another AI (or the same AI) evaluating the result. This creates systemic bias risks that differ from human-only workflows. Awareness of these patterns is the first line of defense.

## Bias Catalog

### 1. Over-Improvement

**Definition**: Adding changes beyond the requested scope during the Apply stage.

**Symptoms**:

- Plan says "fix C2 and C4" but the diff also changes C3-related content
- "While I'm here" additions that weren't discussed
- New sections or features appear that weren't in the plan

**Root Cause**: The optimizer mindset — when improving one area, adjacent areas feel like easy wins.

**Countermeasures**:

- Define explicit scope in Planning (Stage 3): what changes AND what stays
- Review diff against plan before validation — every change must trace to a plan item
- Preservation list in plan acts as a contract

**Detection Checklist**:

- [ ] Every changed line traces to a specific plan item
- [ ] No new sections/features were added outside the plan
- [ ] Preserved items in the plan remain unchanged

---

### 2. Score Optimization

**Definition**: Modifying a component to satisfy criteria mechanically without genuine quality improvement.

**Symptoms**:

- Word count padding: adding filler text to reach a word threshold
- Superficial references: creating reference files with minimal content just to have them
- Checkbox compliance: satisfying the letter of criteria while violating their spirit

**Root Cause**: Binary criteria create clear targets. Optimizing for the target (score) diverges from optimizing for the goal (quality).

**Countermeasures**:

- After improvement, verify the component still serves its original purpose effectively
- Cross-check: "Would a user of this skill actually benefit from these additions?"
- Quality gate's pairwise comparison catches some cases (evaluator judges holistic quality, not just criteria)

**Detection Checklist**:

- [ ] Added content provides genuine value to the component's users
- [ ] Reference files each cover substantive, non-trivial topics
- [ ] Word count increase comes from meaningful content, not padding

---

### 3. Regression Blindness

**Definition**: Focusing only on total score improvement while missing per-criterion regressions.

**Symptoms**:

- Celebrating "3/5 → 4/5" without noticing a criterion flip (1→0)
- Reporting improvement based on total score only
- Not performing per-criterion before/after alignment

**Root Cause**: Total scores are easier to process than criterion-level breakdowns. Summary statistics hide detail.

**Countermeasures**:

- Mandatory per-criterion before/after comparison table
- Explicit regression check: list all criteria where Before=1 and After=0
- Quality gate treats any regression as a warning even when total improves

**Detection Checklist**:

- [ ] Per-criterion before/after table was generated
- [ ] No criterion went from 1→0 (or if so, explicitly acknowledged)
- [ ] Verdict accounts for regressions, not just total score

---

### 4. Anchoring Bias

**Definition**: The baseline evaluation disproportionately influences the improvement direction, even when the evaluation itself may be flawed.

**Symptoms**:

- Blindly following evaluation suggestions without verifying them
- Not questioning whether a 0-score criterion was correctly evaluated
- Treating the evaluation report as ground truth

**Root Cause**: Evaluations are produced by an LLM judge, which can make errors. Treating them as infallible anchors all subsequent work to potentially flawed assessments.

**Countermeasures**:

- Researcher should independently read the component and verify evaluation claims
- If a criterion score seems wrong, note it and proceed with corrected understanding
- During Analysis (Stage 2), quote specific evidence — this naturally surfaces evaluation errors

**Detection Checklist**:

- [ ] Researcher independently verified 0-score claims against the actual file
- [ ] No evaluation claim was accepted without evidence review
- [ ] Questionable evaluations are flagged in the analysis report

---

### 5. Preservation Neglect

**Definition**: Failing to maintain existing quality while pursuing improvements.

**Symptoms**:

- Rewriting entire sections when only a paragraph needed change
- Restructuring the component's organization as a side effect
- Changing terminology, formatting, or style inconsistently

**Root Cause**: Edit scope is harder to control than creation scope. When modifying an existing file, adjacent content is easily perturbed.

**Countermeasures**:

- Preservation list in the plan explicitly names what must not change
- Prefer targeted edits (Edit tool with specific old/new strings) over full rewrites
- After applying changes, diff against original to verify only planned areas changed

**Detection Checklist**:

- [ ] Preservation list items are verified unchanged after apply
- [ ] Edit scope matches plan scope — no unplanned structural changes
- [ ] Writing style and terminology remain consistent with the original

---

## Bias Interaction Patterns

Biases can compound. Common interactions:

| Bias A | + Bias B | Effect |
|--------|----------|--------|
| Over-improvement | + Preservation neglect | Rewriting entire file when fixing one criterion |
| Score optimization | + Regression blindness | Padding content to raise one score while breaking another |
| Anchoring | + Score optimization | Mechanically following a flawed evaluation's suggestions |

**Defense**: Apply all detection checklists, not just the one for the suspected bias.

## Summary: Universal Pre-Flight Checklist

Before finalizing any evolution cycle, verify:

- [ ] Every change traces to the approved plan
- [ ] Added content provides genuine value (not padding)
- [ ] Per-criterion before/after comparison is complete
- [ ] Evaluation claims were independently verified
- [ ] Preserved items remain unchanged
- [ ] Writing style and structure are consistent
