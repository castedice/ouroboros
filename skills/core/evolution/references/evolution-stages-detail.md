# Evolution Stages — Detailed Guide

> Reference for the evolution-methodology skill. Covers each stage's purpose, procedure, inputs/outputs, and common pitfalls.

## Stage 1: Baseline (Measure)

### Purpose

Establish a quantitative starting point. Without a baseline, improvement cannot be verified.

### Procedure

1. Check if a recent evaluation report already exists
2. If yes → reuse (avoid redundant evaluation)
3. If no → run `/evaluate` on the target component
4. Record the baseline score and per-criterion breakdown

### Inputs / Outputs

| | Description |
|---|---|
| **Input** | Target component path (or module name) |
| **Output** | Evaluation report with score, per-criterion results, and improvements list |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Reuse existing evaluation if recent and relevant | Re-evaluate unnecessarily — wastes context |
| Record the full per-criterion breakdown | Rely on total score alone — masks criterion-level issues |
| Verify the evaluation used current criteria version | Use outdated evaluation results after criteria changes |

### Common Pitfalls

- **Stale evaluation**: Using results from before a criteria update. Always check criteria version alignment.
- **Score-only focus**: Recording "4/5" without noting which criterion failed. The failing criterion IS the evolution target.

---

## Stage 2: Analysis (Diagnose)

### Purpose

Identify root causes of quality gaps. Surface-level fixes lead to regression; root cause fixes are durable.

### Procedure

1. Researcher agent reads the target component and evaluation report
2. For each 0-score criterion: Observe → Diagnose → Prescribe
3. Search knowledge base (`docs/specs/knowledge/`) for relevant patterns
4. Produce Improvement Analysis Report with prioritized recommendations

### Inputs / Outputs

| | Description |
|---|---|
| **Input** | Evaluation report + component file + optional focus criteria |
| **Output** | Improvement Analysis Report (root causes, priorities, knowledge patterns) |

### Root Cause Categories

| Category | Description | Example |
|----------|-------------|---------|
| **Missing** | Required content is entirely absent | No `references/` directory for a skill |
| **Format error** | Content exists but wrong form | Skill uses second-person "you should" style |
| **Insufficient depth** | Correct form but lacks specificity | Stage descriptions are one-liners without procedure |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Quote specific file content as evidence | Make vague claims ("needs improvement") |
| Classify root cause type for each gap | Prescribe fixes without diagnosing cause |
| Search knowledge base for proven patterns | Ignore existing knowledge — reinventing solutions |

### Common Pitfalls

- **Symptom treatment**: Fixing what the criterion literally says without understanding why it failed. Example: adding words to reach a word count without adding meaningful content.
- **Analysis paralysis**: Spending excessive time diagnosing when the fix is obvious. If a references/ directory is missing, the diagnosis is "Missing" — move on.

---

## Stage 3: Planning (Plan)

### Purpose

Translate analysis into a concrete, user-approved action plan. Planning prevents scope creep and ensures changes are intentional.

### Procedure

1. Select improvement targets from analysis (priority order: 0-score → [HIGH] → [MED])
2. Define specific changes for each target
3. Define what stays unchanged (preservation list)
4. Present plan to user for confirmation
5. User approves → proceed. User rejects → revise or abort

### Plan Structure

```markdown
## Evolution Plan: {component name}

**Current**: {score}/5 (Level {level})
**Target**: {target}/5

### Changes
1. {What to change — which criterion, what modification}

### Preserved
- {What stays unchanged and why}
```

### Scope Rules

- **Single component mode**: All 0-score criteria + [HIGH] improvements in one cycle
- **Module mode**: Focus on the 1 weakest component only
- **Never exceed requested scope**: If user asked to fix C2, do not also rewrite C3

### DO / DON'T

| DO | DON'T |
|----|-------|
| List both changes AND preserved items | Omit preservation list — leads to accidental changes |
| Get explicit user approval before applying | Apply changes without confirmation |
| Define measurable success criteria | Use vague goals ("make it better") |

### Common Pitfalls

- **Scope creep**: While fixing C2, also "improving" C3 wording. Stick to the plan.
- **Vague plan**: "Expand the content" — expand what, how, with what information?
- **Missing preservation**: Not listing what stays unchanged, leading to unintended modifications.

---

## Stage 4: Apply (Execute)

### Purpose

Execute the plan. The key discipline is faithfulness to the plan — no improvisation.

### Procedure

1. Preserve the original file content (before snapshot — used for validation)
2. Apply each change from the plan sequentially
3. After all changes, verify the result matches the plan intent
4. Notify that changes are applied and validation will follow

### DO / DON'T

| DO | DON'T |
|----|-------|
| Preserve before snapshot before any modification | Start editing without saving original state |
| Apply changes that match the plan exactly | Add "bonus" improvements not in the plan |
| Make changes in logical order | Make unrelated changes in the same edit |

### Common Pitfalls

- **Lost before snapshot**: Forgetting to save the original. Without it, validation (Stage 5) cannot function.
- **Plan deviation**: "While I'm here, let me also fix this..." — this is how regressions happen.
- **Incomplete application**: Applying 2 of 3 planned changes and moving on.

---

## Stage 5: Validate (Verify)

### Purpose

Confirm improvement through before/after comparison. This is the quality gate — no changes are accepted without passing validation.

### Procedure

1. Read the modified file (after version)
2. Run evaluator with before/after comparison mode
3. Evaluator independently scores both versions
4. Evaluator performs pairwise comparison with position swap
5. Determine verdict: `improved` / `lateral` / `degraded`
6. Check for per-criterion regressions

### Verdict Decision Tree

```text
Total score increased?
├── Yes → Any criterion regressed?
│   ├── No  → IMPROVED (pass)
│   └── Yes → IMPROVED with warning (review regression)
├── No change → Any criterion regressed?
│   ├── No  → LATERAL (conditional pass — ask user)
│   └── Yes → DEGRADED (fail)
└── Decreased → DEGRADED (fail)
```

### DO / DON'T

| DO | DON'T |
|----|-------|
| Check per-criterion breakdown, not just total | Accept "4/5 → 4/5" without checking criterion shifts |
| Use position swap for pairwise comparison | Skip position swap — position bias is real |
| On failure, analyze cause before retrying | Immediately retry the same approach |

### Common Pitfalls

- **Total-score blindness**: Score stayed 4/5, but C2 went 0→1 while C3 went 1→0. This is a regression masked by total score.
- **Skipping validation**: "The changes are obviously good" — validation exists precisely for cases where intuition fails.

---

## Stage 6: Record (Document)

### Purpose

Create a permanent record of the evolution. Decision entries enable learning from past changes and pattern recognition.

### Procedure

1. Create decision entry in `docs/decisions/` using the evolve template
2. Include: background, decisions made, change log, verification results
3. Record before/after scores and verdict

### Decision Entry Contents

| Field | Description |
|-------|-------------|
| type | `evolve` |
| date | Date of evolution |
| module, component | Target identification |
| intent | Why this evolution was performed |
| before-score, after-score | Quantitative change |
| verdict | `improved` / `lateral` |
| background | Context and motivation |
| decisions | What was changed and rationale |
| changes | Per-file change summary |
| verification | Evaluation results |

### DO / DON'T

| DO | DON'T |
|----|-------|
| Record the full before/after per-criterion breakdown | Record only total scores |
| Note what was tried and what worked | Skip recording failures — they prevent repeating mistakes |
| Link to evaluation reports if available | Create isolated entries without cross-references |

### Common Pitfalls

- **Skipping record**: "It's a small change, no need to document." Evolution records compound — patterns emerge from multiple entries.
- **Vague entries**: "Improved the skill" — what specifically changed and why?
