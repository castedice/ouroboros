---
description: "Tune composite — orchestrate Evaluate, Improve, and Retrospect to refine code quality and extract learnings for the next spiral turn"
argument-hint: "<task-description> [--fast] [--depth <global|per-stage>] [--artifact <ship-report-path>] [--single]"
allowed-tools: Read, Glob, Grep, Write, Edit, Task, Bash
---

# Tune — Tune Composite (Feedback Pipeline)

Orchestrate the tune stages — Evaluate, Improve ‖ Retrospect — to refine code quality and produce learnings that feed the next spiral turn. At Standard+ depth, Improve and Retrospect execute as parallel Tasks (different file domains, no conflict).

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | core evaluator | Code quality evaluation (SWE-adapted) |
| 4 | implementer + researcher | Improve ‖ Retrospect (parallel Tasks at Standard+ depth) |

## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `task` | Positional text (everything not a flag) | Required — abort if empty |
| `--fast` | Shortcut for `--depth Light` with relaxed skip conditions | Off |
| `--depth` | Depth specification | Standard (global) |
| `--artifact` | Path to Ship Report or entry artifact | None (auto-discovered) |
| `--single` | Force single-model mode (skip external CLIs). Multi-model auto-detected by default | — |

**`--fast` mode**: Sets all stages to Light depth and enables relaxed skip conditions. If both `--fast` and `--depth` are present, `--depth` takes precedence.

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All tune stages at Deep depth |
| Per-stage | `--depth E:Std I:Std R:Deep` | Individual stage depths (E=Evaluate, I=Improve, R=Retrospect) |

Parsing rules per `skills/swe/methodology/references/depth-system.md`: single word applies globally, colon-separated pairs apply per-stage (missing stages default to Standard). Invalid abbreviations or values abort with error.

If `task` is empty:

- Output: "Error: Task description required. Usage: `/swe tune <task-description> [--depth <global|E:level I:level R:level>] [--artifact <path>] [--multi]`"
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

### Multi-Model Setup (auto-detect)

Skip if `--single` is specified.

1. **CLI availability check**: Check `codex` CLI availability and version via Bash. Store: `codex_available` (bool + version), `failure_count: 0`.
2. **Session temp directory**: If codex available, initialize session temp directory (`.tmp/{SESSION_ID}_*` pattern).

Log availability:

- Codex found: "Multi-model: Claude + Codex v{ver}"
- Codex not found: "Single-model mode (no external CLIs found)"

### Decision Matrix

| Condition | Evaluate | Improve | Retrospect | Multi-Model |
|-----------|----------|---------|------------|-------------|
| Standard (default) | Run | Run | Run | Off |
| `--fast` / Light | Run | **Skip** | Run | Off |
| Deep | Run (Deep) | Run (Deep) | Run (Deep) | Off |
| `--multi` | Run + Codex | Run | Run | Evaluate only |
| `--multi` + Light | Run + Codex | **Skip** | Run | Evaluate only |
| Clean evaluation | Run | **Skip** | Run | — |
| No source code | **Skip** | **Skip** | Run (artifact-only) | — |

## Phase 2: Depth Planning

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all stages to Light and enable `fast_mode=true` — skip depth analysis
3. If neither, apply depth defaults:
   - Evaluate: Standard for production code; Light for internal tooling
   - Improve: Standard when evaluation produces actionable findings; Light when evaluation is clean
   - Retrospect: Light for simple tasks; Standard for multi-stage pipelines; Deep for projects with recurring patterns
4. Build Depth Plan:

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

Evaluate code quality by delegating to the core evaluator agent.

### Single-Model Evaluate (default)

> Agent: **core evaluator** (via Task tool with `subagent_type: "ouroboros:core:evaluator"`)

- **Input**: Source code file paths + upstream artifact chain (Constraint Profile for quality boundaries, Interface Contracts for contract adherence, Verification Report for known issues, Ship Report for review findings) + depth level
- **Instructions**: Follow the Evaluate instruction template from `skills/swe/methodology/references/agent-instructions.md`. Bind: task={task}.
- **Expected output**: Quality assessment with specific improvement targets

1. Gather source code files and upstream artifacts from `.swe/active/`
2. Delegate to core evaluator with SWE context
3. Collect quality assessment and improvement recommendations
4. Log: "Evaluate complete. Quality: {rating}. {n} improvement targets identified."

### Multi-Model Evaluate (--multi only)

When `--multi` is active, run Claude and Codex evaluations in parallel:

1. **Build relay prompt**: Construct SWE Quality Evaluate relay prompt using the template from `skills/swe/methodology/references/swe-relay-prompts.md`. Save to `.tmp/{SESSION_ID}_eval_relay.txt`.

2. **Fan-out** (per `skills/core/routing/references/parallel-execution-pattern.md`):
   - Background: Codex evaluator via `scripts/invoke-model.sh` (relay → `_codex_eval.json`)
   - Foreground: Claude core evaluator (same Task as single-model above)

3. **Fan-in**: After Claude evaluator completes, collect Codex background result. Handle by exit code per parallel-execution-pattern.md.

4. **Consensus**: Merge improvement targets per `skills/core/routing/references/consensus-protocol.md` — union unique targets, use higher priority for shared targets. Log agreement rate.

### Phase 3 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instruction: "List the top 3 code quality issues in {primary source file}." If retry fails: proceed to Phase 4 (Retrospect only) — improvement without evaluation targets is lower value |
| No source code found | Error: "No source code found for evaluation." Proceed to Phase 4 with artifact-only retrospect |
| Clean evaluation (no findings) | Log: "Code quality is satisfactory. No improvements needed." Skip Improve in Phase 4, proceed with Retrospect only |
| Codex background fails (--multi) | Skip Codex results. Claude evaluation is always sufficient |

## Phase 4: Improve ‖ Retrospect

At Standard+ depth (when Improve runs), Improve and Retrospect execute as parallel Tasks — Improve modifies source code while Retrospect analyzes the artifact chain. These operate on different file domains (source code vs. `.swe/active/` artifacts) with no conflict. At Light depth, only Retrospect runs (Improve is skipped).

### Parallel Execution (Standard+ depth)

Fan-out: Launch both stages simultaneously as independent Tasks.

**Task 1 — Improve** (implementer agent):

> Agent: **implementer** (via Task tool with `subagent_type: "ouroboros:swe:implementer"`)

- **Input**: Evaluation findings + source code files + test suite + depth level for Improve
- **Instructions**: Follow the Improve instruction template from `skills/swe/methodology/references/agent-instructions.md`. Bind: improvement_targets={improvement targets from Phase 3}.
- **Expected output**: Modified source code + improvement summary + Green state confirmation

Steps:
1. Extract improvement targets from Phase 3 evaluation
2. Prioritize: correctness fixes first, then performance, then readability
3. Delegate to implementer with improvement targets and test suite
4. Run full test suite via Bash to independently confirm Green state
5. Log: "Improve complete. {n} improvements applied. Tests: {pass}/{total} passing."

**Task 2 — Retrospect** (core researcher agent):

> Agent: **core researcher** (via Task tool with `subagent_type: "ouroboros:core:researcher"`)

- **Input**: Full artifact chain from `.swe/active/` + evaluation results from Phase 3 + depth level
- **Instructions**: Follow the Retrospect instruction template from `skills/swe/methodology/references/agent-instructions.md`. Bind: task={task}.
- **Expected output**: Retrospect analysis with patterns, learnings, decisions, and improvement suggestions

Steps:
1. Gather all artifacts from `.swe/active/` for this task
2. Include evaluation results from Phase 3
3. Delegate to core researcher
4. Collect retrospect analysis
5. Log: "Retrospect complete. {n} patterns, {m} learnings, {k} next-cycle suggestions extracted."

Fan-in: Both Tasks produce independent results. Merge into Phase 5 (Feedback Synthesis):
- Improve results: code changes applied, Green state status
- Retrospect results: patterns, learnings, next-cycle suggestions
- Retrospect runs without Improve results when parallel — this is acceptable because Retrospect primarily analyzes the artifact chain (01-09), not the improvements. Feedback Synthesis integrates both.

### Light Depth Behavior

At Light depth, skip Improve entirely. Execute Retrospect only (single Task, no parallelism). Log: "Improve skipped (Light depth). Proceeding to Retrospect."

### Recovery

| Failure | Action |
|---------|--------|
| Improve Task fails | Retry once with reduced scope: "Apply only the top improvement." If retry fails: log warning, proceed with Retrospect results only |
| Retrospect Task fails | Retry once with simplified instruction: "List top 3 learnings from the artifacts in .swe/active/." If retry fails: produce minimal retrospect from available data |
| Both Tasks fail | Retry each once. If both retries fail: produce minimal retrospect from evaluation results only |
| Test regression after improvement | Revert the failing improvement. Log: "Improvement {n} caused regression — reverted." Continue with remaining improvements |
| All improvements cause regressions | Revert all. Log: "No improvements could be applied without regression." Retrospect results remain valid |
| No artifacts found for Retrospect | Produce minimal retrospect based on evaluation results only |

## Phase 5: Feedback Synthesis

Synthesize results from both Improve and Retrospect into actionable input for the next spiral turn:

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

### Learning Delta Generation (team policy spiral only)

When tune is running inside a spiral with team or team+probe policy (detected by: `.swe/active/spiral-state.json` exists and policy contains "team"), generate a structured learning delta for cross-turn optimization:

1. **Extract calibration signals** from the retrospect analysis:
   - Depth calibration: was each composite over-engineered ("over") or under-specified ("under") or well-matched ("ok")?
   - Team effectiveness: how valuable were cross-reviews? How many backtracks occurred?
   - Process improvements: specific suggestions for the next turn's team workflow

2. **Save delta**: `Bash: scripts/spiral-state.sh learning-delta save`

   Content written to `.swe/active/learning-delta.json`:

   ```json
   {
     "turn": 1,
     "depth_calibration": { "spec": "ok", "dev": "under", "ship": "ok", "tune": "over" },
     "team_effectiveness": { "cross_review_value": "high", "backtrack_count": 0, "specialist_failures": 0 },
     "process_improvements": ["Builder should pre-analyze test infrastructure", "Critic early scan was not timely enough"]
   }
   ```

3. **Log**: "Learning delta saved for next turn."

Skip this step when tune is not running inside a team spiral (standalone tune or linear/probe spiral).

## Phase 6: Review

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
{Summary of next-cycle suggestions from Phase 5}
```

When `--multi` is active, append to the report:

```markdown
### Multi-Model Evaluation Summary

| Model | Quality Rating | Improvement Targets | Agreement |
|-------|---------------|--------------------|-----------|
| Claude | {rating} | {n} | — |
| Codex | {rating} | {m} | {rate}% |

Consensus improvement targets used for Improve phase.
```

Write Retrospect Report to `.swe/active/10-tune.md` following the template at `templates/swe/retrospect-report.md`.

## Phase 6.5: Archive

After the Retrospect Report is written, archive the current turn's artifacts to the record directory.

1. Derive task slug from the tune report's task summary (lowercase, hyphens, max 30 chars)
2. Archive via `scripts/artifact-lifecycle.sh archive "{slug}"`. If archive fails: warn user but do not abort — artifacts remain in active/
3. Log: "Archived turn to `docs/specs/record/{package}/{NNN}-{slug}/`"

### Archive Skip Conditions

- If `.swe/active/` is empty or does not exist, skip archival silently. This handles the case where tune is run standalone on already-archived artifacts.
- If `.swe/active/spiral-state.json` exists, skip archival — tune is running inside a spiral, and the spiral's Phase 10.5 will handle archiving after finalizing the state machine. Archiving here would move the state file before spiral can mark tune as completed.

### Project Model Update (standalone only)

If archive succeeded AND `spiral-state.json` does NOT exist (standalone mode), update the project model with this turn's findings. Follow the same merge logic as `spiral.md` Phase 10.6:

1. If `docs/specs/project/` does not exist: run `Bash: scripts/artifact-lifecycle.sh init-project`
2. Read archived artifacts' `## Summary` sections from the archive path
3. Merge into project model files, update Summary and Change Log
4. Skip if running inside a spiral — spiral handles this at Phase 10.6

## Phase 7: Report

Summary of Phase 6 with actionable next steps:

- **Next spiral**: `/swe spiral "{next task from feedback}"` — uses Phase 5 suggestion
- **Revisit spec**: `/swe spec "{task}"` (with new constraints from retrospect)
- **Direct fix**: `/swe implement "{task}"` (apply specific improvements)
- **Pipeline**: `/swe dev`, `/swe ship`, `/swe spiral` for other stages

### See Also
- **Core Evaluator** (`agents/core/evaluator.md`) — executes code quality evaluation
- **Implementer agent** (`agents/swe/implementer.md`) — executes code improvements
- **Core Researcher** (`agents/core/researcher.md`) — executes retrospect analysis
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **SWE Relay Prompts** (`skills/swe/methodology/references/swe-relay-prompts.md`) — external model evaluation templates

## Rules

- Each stage delegates to the appropriate agent — the command orchestrates, not executes
- Core module agents (evaluator, researcher) are used via Task tool — no SWE-specific agents created for evaluation or retrospect
- The implementer agent handles code improvements — the command does not modify code directly
- Artifact paths follow `.swe/active/10-tune.md` convention
- User checkpoint occurs at Phase 6 (Review) — individual stages do not pause for user review when run as part of tune
- Green state invariant: any code improvements must maintain the existing test suite Green state
- Failure isolation: each stage can fail independently. Evaluation failure skips improvement. Retrospect runs regardless of Improve outcome
- The tune composite consumes Ship Report as its preferred entry artifact and produces a Retrospect Report consumed by the spiral meta-composite for next-turn seeding
- Feedback synthesis connects the output of this cycle to the input of the next — the spiral's self-improving mechanism
- Graceful degradation: missing artifacts reduce retrospect depth but do not abort. Missing evaluation skips improvement but retrospect still runs
