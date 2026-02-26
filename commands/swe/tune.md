---
description: "Tune composite — orchestrate Evaluate, Improve, and Retrospect to refine code quality and extract learnings for the next spiral turn"
argument-hint: "<task-description> [--depth <global|per-stage>] [--artifact <ship-report-path>]"
allowed-tools: Read, Glob, Grep, Write, Edit, Task, Bash
---

# Tune — Tune Composite (Feedback Pipeline)

Orchestrate the 3 tune stages sequentially — Evaluate, Improve, Retrospect — to refine code quality and produce learnings that feed the next spiral turn.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | core evaluator | Code quality evaluation (SWE-adapted) |
| 4 | implementer | Code improvement based on evaluation findings |
| 5 | core researcher | Artifact chain analysis, pattern extraction, learning documentation |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--depth` | Depth specification | Standard (global) |
| `--artifact` | Path to Ship Report or entry artifact | None (auto-discovered) |

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 3 tune stages at Deep depth |
| Per-stage | `--depth E:Std I:Std R:Deep` | Individual stage depths (E=Evaluate, I=Improve, R=Retrospect) |

Parsing rules:

- If single word (Light/Standard/Deep): apply to all 3 stages
- If colon-separated pairs: parse each. Missing stages default to Standard
- If any stage abbreviation is invalid: error and abort
- If any depth value is invalid: error and abort

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe tune <task-description> [--depth <global|E:level I:level R:level>] [--artifact <path>]`"
- Abort

### Artifact Resolution

If `--artifact` is provided, use that path directly.

If `--artifact` is not provided: search `.swe/active/` for the most recent entry artifact by priority:

1. `09-ship.md` (Ship Report — preferred, means full pipeline was run)
2. `08-optimize.md` (Stage 8 output — when ship was skipped)
3. `07-verify.md` (Stage 7 output — minimal entry point)

Use the most recent file by modification time.

If no entry artifact found:

- Output: "Warning: No upstream artifact found. Tune will operate on codebase state only. For best results, run `/swe ship` or `/swe dev` first."
- Proceed with reduced context

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If no `--depth`, apply depth defaults:
   - Evaluate: Standard for production code; Light for internal tooling
   - Improve: Standard when evaluation produces actionable findings; Light when evaluation is clean
   - Retrospect: Light for simple tasks; Standard for multi-stage pipelines; Deep for projects with recurring patterns
3. Build Depth Plan:

```text
Depth Plan: E:{level} I:{level} R:{level}
Rationale: {key drivers}
```

Log the Depth Plan. Present to user for confirmation:

```markdown
## Depth Plan

| Stage | Depth | Rationale |
|-------|-------|-----------|
| Evaluate | {level} | {reason} |
| Improve | {level} | {reason} |
| Retrospect | {level} | {reason} |

Proceed with this plan, or adjust depths?
```

## Phase 3: Evaluate

Evaluate code quality by delegating to the core evaluator agent:

> Agent: **core evaluator** (via Task tool with `subagent_type: "ouroboros:core:evaluator"`)

- **Input**: Source code file paths + upstream artifact chain (Constraint Profile for quality boundaries, Interface Contracts for contract adherence, Verification Report for known issues, Ship Report for review findings) + depth level
- **Instructions**: "Evaluate the implementation quality of the source code for the task: {task}. Apply SWE-adapted criteria: Does the code satisfy its interface contracts? Does it respect constraint boundaries? Is the TDD cycle evidence complete (Red state → Green state → verified)? Is the code minimal — no gold-plating beyond what constraints require? Rate quality on a scale and produce specific improvement recommendations."
- **Expected output**: Quality assessment with specific improvement targets

1. Gather source code files and upstream artifacts from `.swe/active/`
2. Delegate to core evaluator with SWE context
3. Collect quality assessment and improvement recommendations
4. Log: "Evaluate complete. Quality: {rating}. {n} improvement targets identified."

### Phase 3 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instruction: "List the top 3 code quality issues in {primary source file}." If retry fails: proceed to Phase 5 (Retrospect) — improvement without evaluation targets is lower value |
| No source code found | Error: "No source code found for evaluation." Proceed to Phase 5 with artifact-only retrospect |
| Clean evaluation (no findings) | Log: "Code quality is satisfactory. No improvements needed." Skip Phase 4, proceed to Phase 5 |

## Phase 4: Improve

Improve code based on evaluation findings by delegating to the implementer agent:

> Agent: **implementer** (via Task tool with `subagent_type: "ouroboros:swe:implementer"`)

- **Input**: Evaluation findings + source code files + test suite + depth level for Improve
- **Instructions**: "Apply the following code improvements identified by evaluation: {improvement targets}. For each improvement: apply the change, run the test suite to confirm Green state is maintained, document what changed and why. Do not introduce new features — only improve existing code quality."
- **Expected output**: Modified source code + improvement summary + Green state confirmation

1. Extract improvement targets from Phase 3 evaluation
2. Prioritize: correctness fixes first, then performance, then readability
3. Delegate to implementer with improvement targets and test suite
4. Run full test suite via Bash to independently confirm Green state
5. Log: "Improve complete. {n} improvements applied. Tests: {pass}/{total} passing."

### Phase 4 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with reduced scope: "Apply only the top improvement." If retry fails: log warning, proceed to Phase 5 with partial results |
| Test regression after improvement | Revert the failing improvement. Log: "Improvement {n} caused regression — reverted." Continue with remaining improvements |
| All improvements cause regressions | Revert all. Log: "No improvements could be applied without regression. Proceeding to Retrospect." |

### Light Depth Behavior

At Light depth, skip Improve entirely. Log: "Improve skipped (Light depth). Proceeding to Retrospect."

## Phase 5: Retrospect

Analyze the full artifact chain and extract learnings by delegating to the core researcher agent:

> Agent: **core researcher** (via Task tool with `subagent_type: "ouroboros:core:researcher"`)

- **Input**: Full artifact chain from `.swe/active/` + evaluation results + improvement results + Ship Report findings + depth level
- **Instructions**: "Analyze the complete artifact chain for task: {task}. Extract: (1) Patterns — recurring approaches that worked well, (2) Learnings — what was discovered during the engineering process, (3) Decisions — key choices made and their rationale, (4) Improvements — what could be done better next time. At Standard+ depth, identify specific process improvements and evaluate depth accuracy for each stage that ran in this turn: compare the planned depth against the actual effort needed, mark as Over (too much ceremony — depth could have been lower), Under (gaps found that higher depth would have caught), or Correct, and in Notes explain what would have changed with different depth. Reference the Depth Accuracy section in the retrospect-report template. At Deep depth, track metrics and suggest next-cycle specifications."
- **Expected output**: Retrospect analysis with patterns, learnings, decisions, and improvement suggestions

1. Gather all artifacts from `.swe/active/` for this task
2. Include evaluation results from Phase 3 and improvement results from Phase 4
3. Delegate to core researcher
4. Collect retrospect analysis
5. Log: "Retrospect complete. {n} patterns, {m} learnings, {k} next-cycle suggestions extracted."

### Phase 5 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instruction: "List top 3 learnings from the artifacts in .swe/active/." If retry fails: produce minimal retrospect from available data |
| No artifacts found | Produce minimal retrospect based on evaluation and improvement results only |

## Phase 6: Feedback Synthesis

Synthesize retrospect findings into actionable input for the next spiral turn:

### Next-Cycle Suggestions

From the retrospect analysis, extract:

1. **Refined constraints**: New constraints discovered during implementation that should be added to the Constraint Profile
2. **Interface improvements**: Contract gaps revealed by verification or review
3. **Architecture adjustments**: Structural changes recommended by code review or optimization
4. **Process improvements**: Pipeline stage depth adjustments, tool gaps, methodology refinements

### Feedback Document

```markdown
## Feedback for Next Cycle

### New Constraints Discovered
{List constraints to add to the next Constraint Profile}

### Interface Gaps
{List contract gaps for the next Interface stage}

### Architecture Recommendations
{List structural improvements for the next Design stage}

### Process Improvements
{List pipeline improvements — depth adjustments, tool gaps, etc.}

### Suggested Next Task
{Based on retrospect analysis, what should be the focus of the next spiral turn}
```

At Light depth: produce only the "Suggested Next Task" section.
At Deep depth: include all sections plus metrics tracking (lines changed, test count delta, finding counts across pipeline stages).

## Phase 7: Review

Present the complete tune results:

```markdown
## Tune Report: {task summary}

### Evaluation Summary
- **Quality Rating**: {rating}
- **Improvement Targets**: {n} identified
- **Improvements Applied**: {m} ({k} reverted)

### Retrospect Highlights
- **Patterns**: {n} recurring approaches documented
- **Learnings**: {m} insights extracted
- **Next-Cycle Suggestions**: {k} actionable items

### Artifact Chain Status

| # | Artifact | Status |
|---|----------|--------|
| 1 | Evaluation results | {done/skipped/failed} |
| 2 | Code improvements | {done/skipped/failed} |
| 3 | Retrospect analysis | {done/failed} |
| 4 | Feedback synthesis | {done/skipped} |

### Feedback for Next Cycle
{Summary of next-cycle suggestions from Phase 6}
```

Write Retrospect Report to `.swe/active/10-tune.md` following the template at `templates/swe/retrospect-report.md`.

## Phase 7.5: Archive

After the Retrospect Report is written, archive the current turn's artifacts to the record directory.

1. Derive task slug from the tune report's task summary (lowercase, hyphens, max 30 chars)
2. Run via Bash: `scripts/artifact-lifecycle.sh archive "{slug}" [--package {pkg}]`
   - Package is derived automatically from manifest detection
   - If archive fails (exit code 2): warn user but do not abort — artifacts remain in active/
3. Log: "Archived turn to `.swe/record/{package}/{NNN}-{slug}/`"

### Archive Skip Condition

If `.swe/active/` is empty or does not exist, skip archival silently. This handles the case where tune is run standalone on already-archived artifacts.

## Phase 8: Report

```markdown
## Tune Complete: {task summary}

**Depth Plan**: E:{level} I:{level} R:{level}
**Artifacts**: tune report in `.swe/active/`

### Next Steps
- Start next spiral turn: `/swe spiral "{next task from feedback}"`
- Revisit specification with new constraints: `/swe spec "{task}"`
- Apply specific improvements: `/swe implement "{task}"`

### Full Pipeline Reference
- `/swe spec "{task}"` — specification (Stages 1-4)
- `/swe dev "{task}"` — development (Stages 5-8)
- `/swe ship "{task}"` — release validation
- `/swe spiral "{task}"` — full engineering cycle

### Spiral Feedback
The retrospect analysis suggests the following focus for the next turn:
{next-cycle suggestion from Phase 6}
```

## Rules

- Each stage delegates to the appropriate agent — the command orchestrates, not executes
- Core module agents (evaluator, researcher) are used via Task tool — no SWE-specific agents created for evaluation or retrospect
- The implementer agent handles code improvements — the command does not modify code directly
- Artifact paths follow `.swe/active/10-tune.md` convention
- User checkpoint occurs at Phase 7 (Review) — individual stages do not pause for user review when run as part of tune
- At Light depth, Improve (Phase 4) is skipped — only a quick retrospect is produced
- Green state invariant: any code improvements must maintain the existing test suite Green state
- Failure isolation: each stage can fail independently. Evaluation failure skips improvement. Retrospect runs regardless
- The tune composite consumes Ship Report as its preferred entry artifact, but can operate with any upstream artifact
- The tune composite produces a Retrospect Report consumed by the spiral meta-composite for next-turn seeding
- Feedback synthesis connects the output of this cycle to the input of the next — the spiral's self-improving mechanism
- Graceful degradation: missing artifacts reduce retrospect depth but do not abort. Missing evaluation skips improvement but retrospect still runs
