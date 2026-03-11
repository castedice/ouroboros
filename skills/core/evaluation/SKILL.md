---
name: evaluation-methodology
description: This skill provides evaluation methodology knowledge. It should be activated when an agent needs to "evaluate a component", "score plugin quality", "assess an agent definition", "judge a command's effectiveness", "compare before and after versions", or "rate output quality".
---

# Evaluation Methodology

## Core Principle

**"You can't improve what you can't measure."**

Evaluation is a prerequisite for improvement. All evaluations are grounded in specific, reproducible criteria, and **why a score was given** matters more than the score itself. A score without reasoning is noise — reasoning without a score is still useful.

This principle drives every design choice: CoT-first scoring ensures reasoning precedes judgment, binary criteria prevent ambiguous middle-ground scores, and specific evidence requirements force concrete justification rather than vague impression.

## Evaluation Workflow

The standard workflow for evaluating any plugin component, from input to report:

### Step 1: Identify Component Type

Determine the target's type from its location and structure:

| Location Pattern | Type | Key Indicator |
|-----------------|------|---------------|
| `agents/{module}/*.md` | Agent | Has `model`, `tools` in frontmatter |
| `skills/{module}/SKILL.md` | Skill | Has `name`, `description` in frontmatter, `references/` directory |
| `commands/{module}/*.md` | Command | Has `allowed-tools`, `argument-hint` in frontmatter |
| `hooks/hooks.json` entries | Hook | JSON with `event`, `matcher`, `command` fields |
| `CLAUDE.md` | CLAUDE.md | Root-level project instructions file |

When the type is ambiguous (e.g., a markdown file outside standard directories), check the frontmatter fields — they are the definitive type indicator. If no frontmatter exists, ask the user.

### Step 2: Load Criteria

Load the appropriate criteria reference file based on the identified type. Each criteria file contains 3 tiers (Foundation, Craft, Excellence) with per-type thresholds and severity gate table.

Each type has separate static and dynamic criteria:

- **Static criteria**: Evaluate the definition file quality (structure, content, conventions)
- **Dynamic criteria**: Evaluate the component's actual output quality (execution results)

See the Evaluation Target Types section below for the full criteria file mapping.

### Step 3: Score Each Criterion (Tier Order)

Apply the Scoring Procedure for each criterion, following tier order:

1. Score **Foundation (F1-F5)** first. Write reasoning before each score
2. If Foundation < 5: stop. Report F scores only, mark Q/E as "skipped — Foundation incomplete"
3. If Foundation = 5: score **Craft (Q1-Qn)**
4. If Craft < Q_high: stop. Report F+Q scores, mark E as "skipped — Craft below threshold"
5. If Craft ≥ Q_high: score **Excellence (E1-Em)**
6. Apply Severity Gate to determine Overall Level

### Step 4: Generate Report

Produce the evaluation report in the standard format (see Report Format section).
Include per-tier scores, per-criterion reasoning, strengths, improvements with priority tags, and recommendations.

## Two-Axis Evaluation

All components are evaluated on two independent axes. Static evaluation assesses the definition
(what was written), dynamic evaluation assesses the output (what it produces when used).
A component can have a perfect definition but poor output, or vice versa.

| | Static Evaluation (Definition) | Dynamic Evaluation (Output) |
|---|---|---|
| **What** | Quality of the component definition file itself | Quality of results from executing the component |
| **How** | Read file → criteria scoring | Run test set → score results |
| **Input** | File path | Automatic (test set) or user-provided |
| **Criteria** | 3-tier criteria per type (F+Q+E, 13-16 total) | Separate dynamic criteria per type |

Static evaluation is always available — it requires only the file. Dynamic evaluation requires execution or test data, making it more expensive but more informative. Start with static, add dynamic when the component is mature enough to execute.

## Tiered Binary Scoring

Decompose evaluation into atomic criteria, each scored binary (0 or 1). Binary scoring has higher inter-rater reliability than Likert scales — there is less ambiguity about whether a criterion is met versus "how much" it is met.

Criteria are organized in 3 tiers per component type, progressing from existence checks to craft quality to excellence:

| Tier | Name | Question | Count per type |
|------|------|----------|---------------|
| **F** | Foundation | Does it exist? | 5 (all types) |
| **Q** | Craft | Is it well-made? | 5-7 (varies by type) |
| **E** | Excellence | Is it exemplary? | 3-4 (varies by type) |

**Tier evaluation order**: Always score Foundation first. Craft is only evaluated if Foundation = 5/5. Excellence is only evaluated if Craft ≥ Q_high. This prevents wasting evaluation effort on higher tiers when fundamentals are missing.

### Scoring Procedure

1. **CoT first**: Always write reasoning before assigning a score
2. **Single criterion rule**: Evaluate only one aspect per criterion
3. **Binary scoring**: Each criterion is 0 (not met) or 1 (met)
4. **Specific evidence**: State exactly what is lacking (for 0) or what satisfies the criterion (for 1)
5. **Tier order**: Score F1-F5 first. If Foundation < 5, skip Craft and Excellence. If Foundation = 5, score Q1-Qn. If Craft < Q_high, skip Excellence

### Score Boundary Guide

Binary scoring creates edge cases where a criterion is partially met. Guidelines for boundary decisions:

| Situation | Judgment | Rationale |
|-----------|----------|-----------|
| Criterion nearly met with minor gap | **0** | Binary means binary — "almost" is still not met |
| Criterion met in spirit but not letter | **0** | Criteria are written precisely; meeting intent without form is insufficient |
| Criterion met in letter but not spirit | **1 with improvement note** | Score the letter, flag the spirit gap as [MED] improvement |
| Criterion met with room for enhancement | **1** | Met is met — enhancement goes in Improvements section |

The key principle: when in doubt, score **0**. False positives (scoring 1 when not met) are more harmful than false negatives because they hide real quality gaps. A 0-score triggers improvement; a false 1-score creates complacency.

### Severity Gate Level Mapping

Foundation gates cap the maximum achievable level. A perfect Craft score cannot compensate for missing fundamentals.

| Foundation | Craft | Excellence | Level |
|---|---|---|---|
| ≤ 3 | — | — | **1 — Poor** |
| 4 | — | — | **2 — Needs Work** (cap) |
| 5 | ≤ Q_low | — | **2 — Needs Work** |
| 5 | Q_low+1 to Q_high-1 | — | **3 — Good** |
| 5 | ≥ Q_high | < E_high | **3 — Good** |
| 5 | ≥ Q_high | ≥ E_high | **4 — Excellent** |

Per-type thresholds (Q_low, Q_high, E_high vary by component type — see criteria reference files for exact values):

| Type | Q count | Q_low | Q_high | E count | E_high |
|---|---|---|---|---|---|
| Agent | 7 | 3 | 6 | 4 | 3 |
| Command | 7 | 3 | 6 | 4 | 3 |
| Skill | 7 | 3 | 6 | 4 | 3 |
| Hook | 5 | 2 | 4 | 3 | 2 |
| CLAUDE.md | 6 | 2 | 5 | 3 | 2 |

### Pairwise Comparison (Before/After mode)

When comparing two versions (used by `/evolve` to validate changes):

1. Independently evaluate each version statically (2 separate evaluations)
2. Position-swapped comparison judgment (1 evaluation) — mitigates position bias
3. Verdict: `improved` | `degraded` | `lateral` (includes per-criterion regression check)

Position swap means evaluating "A vs B" and then "B vs A" — if the verdict flips, position bias is present and the comparison is unreliable. Consistent verdicts across both orderings indicate a robust judgment.

## Evaluation Target Types

### Static Evaluation (5 types)

Each type has a dedicated criteria file in `references/` with 3 tiers (F, Q, E) and severity gate thresholds.

| Type | Criteria File | Criteria Count | Focus |
|------|--------------|---------------|-------|
| Agent | `references/agent-criteria.md` | F5 + Q7 + E4 = 16 | Trigger, prompt, model, tools, persona, integration |
| Skill | `references/skill-criteria.md` | F5 + Q7 + E4 = 16 | Trigger, disclosure, reproducibility, bias, integration |
| Command | `references/command-criteria.md` | F5 + Q7 + E4 = 16 | Phases, delegation, recovery, SoC, integration |
| Hook | `references/hook-criteria.md` | F5 + Q5 + E3 = 13 | Event/matcher, exit codes, safety, performance, security |
| CLAUDE.md | `references/claudemd-criteria.md` | F5 + Q6 + E3 = 14 | Actionability, workflow, prohibitions, alignment, efficiency |

### Dynamic Evaluation (4 types — CLAUDE.md excluded)

Dynamic criteria assess output quality. CLAUDE.md is excluded because it has no executable output.

| Type | Criteria File | Test Method |
|------|--------------|------------|
| Agent | `references/agent-output-criteria.md` | Test prompt → collect results |
| Skill | `references/skill-output-criteria.md` | Query with skill loaded → A/B comparison |
| Command | `references/command-output-criteria.md` | Execute with test input → observe workflow |
| Hook | `references/hook-output-criteria.md` | Simulate trigger conditions |

## Report Format

Every evaluation produces a report in this standardized format. Consistency enables comparison across evaluations and over time.

```markdown
## Evaluation Report: {component name}

**Type**: {type}
**Mode**: {static|output|before-after}
**Overall Level**: {1-4} — {Poor|Needs Work|Good|Excellent}
**Score**: F: {n}/5 | Q: {n}/{max} | E: {n}/{max}

### Foundation (F)

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| F1 | {name} | {0|1} | {specific evidence} |
| ... | ... | ... | ... |

### Craft (Q)

{If Foundation < 5: "Skipped — Foundation incomplete (F: {n}/5)"}

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| Q1 | {name} | {0|1} | {specific evidence} |
| ... | ... | ... | ... |

### Excellence (E)

{If Craft < Q_high: "Skipped — Craft below threshold (Q: {n}/{max}, need ≥ {Q_high})"}

| # | Criterion | Score | Reasoning |
|---|-----------|-------|-----------|
| E1 | {name} | {0|1} | {specific evidence} |
| ... | ... | ... | ... |

### Strengths

- {positive points — explicit praise}

### Improvements

- **[HIGH]** {potential score-changing improvement — specify which criterion}
- **[MED]** {substantive quality enhancement}
- **[LOW]** {nice-to-have refinement}

### Recommendations

- {next step suggestions}
```

Improvements must be tagged with priority: **[HIGH]** for potential score impact, **[MED]** for quality enhancement, **[LOW]** for nice-to-have. This prioritization directly feeds into the evolution workflow's improvement priority system.

## Bias Mitigation

Evaluation by an LLM judge carries systematic bias risks. Three primary biases and their countermeasures:

| Bias | Symptom | Countermeasure |
|------|---------|----------------|
| Position bias | Verdict changes based on order in pairwise comparison | Position swap + consistency check |
| Verbosity bias | Longer definitions rated higher regardless of quality | Conciseness criterion in rubric |
| Self-enhancement | Overrating own model's output | CoT first + specific evidence required |

Additional bias risks in module-wide scans:

- **Fatigue drift**: Scoring becomes more lenient in later evaluations within a batch. Countermeasure: evaluate each component independently with fresh criteria loading.
- **Anchoring**: First component's score influences subsequent scores. Countermeasure: sequential evaluation with explicit criteria re-reading per component.

## Common Pitfalls

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Scoring before reasoning | Scoring | Enforce CoT-first — write reasoning, then assign score |
| Vague evidence ("looks good") | Scoring | Require specific file content quotes or section references |
| Wrong criteria file loaded | Type ID | Verify frontmatter fields match the assumed type |
| Skipping position swap in before/after | Comparison | Position swap is mandatory — inconsistency reveals bias |
| Score inflation in batch evaluation | Module scan | Re-read criteria fresh for each component, avoid comparisons between components |
| Evaluating higher tiers when Foundation fails | Tier scoring | Foundation < 5 → skip Craft/Excellence. Report only Foundation scores |
| Missing improvement priorities | Reporting | Every improvement needs a [HIGH/MED/LOW] tag |

## Validation Checklist

Use this checklist to verify that evaluation methodology is being applied correctly:

- [ ] Component type correctly identified from location and frontmatter
- [ ] Correct criteria reference file loaded for the type
- [ ] Tier order respected: F first, Q only if F=5, E only if Q≥Q_high
- [ ] CoT reasoning written before each score assignment
- [ ] Each criterion evaluated independently (single criterion rule)
- [ ] Specific evidence cited for every score (quotes or section references)
- [ ] Score boundary decisions follow the guide (when in doubt, score 0)
- [ ] Severity gate applied correctly for level determination
- [ ] Improvements tagged with [HIGH/MED/LOW] priorities
- [ ] For before/after: position swap performed with consistency check
- [ ] Report follows the standard per-tier format

## See Also

- **evaluator agent** (`agents/core/evaluator.md`) — Primary consumer; executes this skill's workflow directly for tiered scoring and report generation
- **evaluate command** (`commands/core/evaluate.md`) — Orchestrates Phase 3-6 evaluation pipeline, invokes evaluator agent, manages multi-model coordination
- **evolve command** (`commands/core/evolve.md`) — Phase 6 quality gate; uses before/after pairwise comparison to validate improvements
- **absorb command** (`commands/core/absorb.md`) — Phase 8 quality gate; evaluates generated components before finalizing absorption
- **upgrade command** (`commands/core/upgrade.md`) — Phase 7 validation; evaluates reconciled components to verify no quality regression
- **validation-methodology** (`skills/core/validation/SKILL.md`) — Structural correctness checks that run before evaluation; evaluation assumes validation has passed
