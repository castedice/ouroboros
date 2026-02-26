---
name: evolution-methodology
description: This skill provides evolution methodology knowledge. It should be activated when an agent needs to "improve a component", "evolve a module", "apply evaluation feedback", "prioritize improvements", or "validate an evolution result".
---

# Evolution Methodology

## Core Principle

**"One at a time, with certainty."**

Evolution is incremental. Small, verifiable improvements repeated are safer and more effective than large changes. Every improvement must be validated before acceptance. No change is final until it passes the quality gate.

The cycle is: **Measure → Diagnose → Plan → Execute → Verify → Record**. Each stage has a clear purpose and a defined output. Skipping stages (especially Verify) is the primary cause of regressions.

## Improvement Priority

Select improvement targets based on evaluation results. The priority order ensures maximum score impact first, then qualitative improvements. This ordering prevents wasted effort on low-impact changes while critical gaps remain.

| Priority | Target | Rationale |
|----------|--------|-----------|
| 1 | **0-score criteria** | Clear improvements that directly raise the score |
| 2 | **[HIGH] improvements** | Potential score-changing improvements |
| 3 | **[MED] improvements** | Substantive quality enhancements |
| 4 | **[LOW] improvements** | Nice-to-have, when time permits |

### How Many Per Cycle?

- **Single component**: All 0-score criteria + [HIGH] improvements (small scope allows batch)
- **Module-wide**: Focus on the 1 weakest component (narrow scope ensures quality)

The rationale: single component evolution has a bounded blast radius — changes affect one file. Module-wide evolution must be narrowed to one component because cross-component changes create unpredictable interactions. Focus on the weakest component yields the highest marginal improvement.

Example: A skill scores 2/5 with C1=1, C2=0, C3=0, C4=0, C5=1, plus one [HIGH] improvement on C1's trigger depth. In single component mode, address C2, C3, C4 (0-score criteria) and the C1 [HIGH] — all in one cycle. The [MED] and [LOW] improvements wait for the next cycle.

## Evolution Modes

The evolution workflow supports two modes, determined by the target argument:

| Mode | Target | Scope | Use When | Output |
|------|--------|-------|----------|--------|
| **A: Single Component** | File path | One file, all failing criteria | Specific component needs improvement | Evolved file + decision entry |
| **B: Module Focus** | Module name | Weakest component in module | Broad quality uplift needed | Scan report + evolved weakest + decision entry |

**Mode A** is the default and most common. The evaluator assesses one component, the researcher analyzes it, and changes apply to that single file. All 0-score criteria and [HIGH] improvements are addressed in one cycle.

**Mode B** scans all components in a module (commands, agents, skills, templates), evaluates each, and auto-selects the weakest. This mode is useful when you need to improve a module's overall quality but don't know which component to start with. After evolving the weakest, re-running Mode B naturally selects the next weakest — creating a systematic quality ladder.

## Evolution Stages

Six stages, each building on the previous. For detailed procedures, inputs/outputs, DO/DON'T lists,
and common pitfalls per stage, see `references/evolution-stages-detail.md`.

### 1. Baseline (Measure)

- Measure current state via `/evaluate`
- Reuse existing evaluation results if recent and relevant
- Record the full per-criterion breakdown, not just the total score

The baseline is the anchor for all subsequent work. Without it, validation (Stage 5) cannot determine whether changes actually improved the component. Reusing existing evaluations is preferred — redundant evaluation wastes context without adding information.

### 2. Analysis (Diagnose)

- Researcher agent performs root cause analysis on 0-score criteria
- Root causes fall into three categories: **Missing**, **Format error**, or **Insufficient depth**
- Search knowledge base (`docs/knowledge/`) for relevant patterns
- Report improvement directions with priorities

Root cause diagnosis prevents surface-level fixes. Example: if C2 (Progressive Disclosure) fails because word count is 484 (need 1,500+), the root cause is not "too few words" — it is "insufficient detail in stage descriptions and missing reference files." The fix targets content depth, not word count.

### 3. Planning (Plan)

- Build improvement plan from analysis results
- Present plan to user for confirmation (mandatory checkpoint)
- Define scope clearly: what changes AND what stays unchanged

The preservation list is as important as the change list. It acts as a contract: items listed under "Preserved" must remain unchanged after Apply. This prevents over-improvement bias (see `references/bias-patterns.md`).

### 4. Apply (Execute)

- Preserve before version in memory (snapshot for validation)
- Apply modifications according to plan using Edit tool
- Verify each change traces back to a specific plan item

Discipline in this stage is critical. The temptation to add "bonus" improvements not in the plan
is the most common source of regressions. Every change must justify itself against the plan.

### 5. Validate (Verify)

- Run `/evaluate` before/after comparison for regression check
- Evaluator independently scores both versions, then performs pairwise comparison with position swap
- Determine quality gate verdict (see Quality Gate section below)

Validation is non-negotiable. Even "obviously good" changes must be validated because evaluation criteria may capture aspects not apparent to the person making changes. For detailed verdict logic and edge cases, see `references/quality-gate-guide.md`.

### 6. Record (Document)

- Create evolve decision entry in `docs/decisions/` using the template
- Record background, decisions, changes, before/after scores, and verdict
- Link to evaluation reports when available

Decision entries compound over time. Individual entries may seem like overhead, but patterns emerge from multiple entries — which improvement approaches work, which criteria are hardest to satisfy, which components need repeated evolution.

## Quality Gate

The quality gate is the single checkpoint that determines whether evolution changes are accepted. It operates on evaluation output, not subjective judgment.

| Verdict | Meaning | Action |
|---------|---------|--------|
| `improved` | Score increased, no regression | **Pass** — accept changes, record decision |
| `lateral` | Score unchanged, no regression | **Conditional pass** — ask user whether to keep changes |
| `degraded` | Score decreased or regression found | **Fail** — analyze cause, retry or rollback |

### Regression Definition

A criterion that scored 1 in Before but scores 0 in After. Even if the total score increased, regression in any criterion requires attention. Total score can mask criterion-level damage.

Example: Before 3/5 (C1=1, C2=0, C3=1, C4=0, C5=1) → After 4/5 (C1=1, C2=1, C3=0, C4=1, C5=1).
Total improved, but C3 regressed. The quality gate flags this for review.

For the full regression response matrix, lateral handling guide, and edge cases (Level 4 ceiling, single criterion focus, module-wide evolution), see `references/quality-gate-guide.md`.

## Retry Policy

On cycle failure (`degraded` verdict):

1. Analyze failure cause — why did the After version score lower?
2. Rollback to before snapshot
3. Retry with a **different approach** (never repeat the same method)
4. After 2 consecutive failures → stop and ask user for direction

"Different approach" means a substantively different strategy, not a minor tweak:

- If the first attempt added content and it degraded readability → try restructuring instead
- If the first attempt restructured and it broke references → try targeted edits instead
- If both structural and content approaches fail → the improvement direction itself may be wrong

Component-type-specific strategies:

- **Skill**: If adding depth bloats SKILL.md past 2,000 words → extract detail into `references/` (progressive disclosure)
- **Agent**: If enriching system prompt degraded focus → add `<example>` blocks instead of prose (concrete over abstract)

The 2-failure limit exists because consecutive failures suggest a fundamental misunderstanding of the component, the criteria, or the improvement direction. Continuing without human input risks compounding the misdiagnosis.

## Bias Mitigation

Evolution involves AI modifying artifacts and AI evaluating the result. This creates systemic bias risks. The three highest-risk biases are summarized below. For the full catalog of 5 bias patterns with detection checklists and interaction patterns, see `references/bias-patterns.md`.

| Bias | Symptom | Countermeasure |
|------|---------|----------------|
| Over-improvement | Adding changes outside requested scope | Define scope in Planning, enforce adherence |
| Score optimization | Fitting criteria without real quality gain | Cross-check component's original purpose after improvement |
| Regression blindness | Looking only at total score, missing per-criterion regression | Mandatory per-criterion before/after comparison |

### Quick Detection Checklist

Before finalizing any evolution cycle:

- [ ] Every change traces to the approved plan
- [ ] Added content provides genuine value (not padding)
- [ ] Per-criterion before/after comparison is complete
- [ ] Preserved items remain unchanged

## Common Pitfalls

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Stale evaluation as baseline | Baseline | Verify evaluation used current criteria version |
| Symptom treatment instead of root cause | Analysis | Classify root cause type: Missing / Format error / Insufficient depth |
| Vague plan ("make it better") | Planning | Require specific change descriptions with measurable outcomes |
| Plan deviation during apply | Apply | Diff against plan before proceeding to validation |
| Total-score-only validation | Validate | Always generate per-criterion before/after table |
| Skipping record for "small" changes | Record | Every evolution gets a decision entry — patterns emerge from accumulation |

## Validation Checklist

Use this checklist to verify that evolution methodology is being applied correctly:

- [ ] Baseline evaluation exists with per-criterion breakdown
- [ ] Root cause analysis performed (not just symptom identification)
- [ ] Plan presented to user and approved before apply
- [ ] Before snapshot preserved before any modification
- [ ] All changes trace to specific plan items
- [ ] Before/after evaluation performed with position swap
- [ ] Quality gate verdict determined with regression check
- [ ] Decision entry created in `docs/decisions/`
- [ ] No bias patterns detected (over-improvement, score optimization, regression blindness)

## See Also

- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) — Scoring criteria, evaluation procedure, and bias mitigation used by Baseline and Validate stages
