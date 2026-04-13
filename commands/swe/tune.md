---
name: swe:tune
description: "Use when implementation exists and you need to evaluate it, improve it, and capture lessons for the next iteration"
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

- Output: "Error: Task description required. Usage: `/swe tune <task-description> [--depth <global|E:level I:level R:level>] [--artifact <path>] [--single]`"
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

### Mode Detection

Resolve the operating mode from repository state before Phase 2 so Tune reacts to the codebase and artifact chain, not just the flags.
Store the following execution-state fields once and reuse them in later phases instead of rechecking the same logic inline.

| Field | Values | Resolution Rule | Used In |
|-------|--------|-----------------|---------|
| `entry_artifact` | `provided`, `auto`, `none` | Use `--artifact` when present, otherwise the newest `.swe/active/09-ship.md`, `08-optimize.md`, or `07-verify.md`, otherwise `none` | 3-7 |
| `source_state` | `present`, `absent` | Detect whether source files exist for the task scope | 3-4 |
| `context_tier` | `full`, `reduced`, `codebase-only`, `artifact-free` | `09-ship.md` = `full`, `08-optimize.md` or `07-verify.md` = `reduced`, source without artifact = `codebase-only`, neither = `artifact-free` | 3-7 |
| `improve_mode` | `eligible`, `skip-light`, `skip-clean`, `skip-no-source`, `skip-no-tests` | Improve runs only when source exists, depth is not Light, evaluation found actionable targets, and a runnable test command exists | 4-5 |
| `model_mode` | `single`, `multi` | `--single` forces `single`, otherwise require both Codex availability and a writable `.tmp/{SESSION_ID}_*` directory for `multi` | 3, 6 |

### Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `task` is empty | 1 | Abort with the usage error and do not continue. |
| `--artifact` is provided and readable | 1 | Use it as the entry artifact. |
| No entry artifact is found but source files exist | 1-7 | Continue with reduced codebase-only context. |
| No entry artifact and no source files are found | 1-7 | Run artifact-free Retrospect only and skip Evaluate and Improve. |
| `--single` is present | 1, 3, 6 | Force single-model mode and skip Codex evaluation. |
| Codex CLI or writable temp directory is unavailable | 1, 3, 6 | Fall back to single-model mode even without `--single`. |
| `--depth` is provided | 2 | Use the parsed global or per-stage depths. |
| `--fast` is provided without `--depth` | 2 | Force Light depth across stages and enable relaxed skip behavior. |
| Neither `--depth` nor `--fast` is provided | 2 | Build the default per-stage depth plan from task and artifact complexity. |
| Source files exist | 3 | Run Evaluate. |
| No source files exist | 3, 4 | Skip Evaluate and Improve, and proceed to artifact-only Retrospect. |
| `model_mode = multi` | 3, 6 | Add Codex evaluation alongside the Claude evaluator. |
| Evaluate returns a clean result with no findings | 3, 4 | Skip Improve and continue with Retrospect. |
| Improve is ineligible because tests cannot be run or no actionable targets remain | 4 | Skip Improve and continue with Retrospect. |
| Standard+ depth with actionable findings and runnable tests | 4 | Run Improve and Retrospect in parallel. |
| Light depth | 4 | Skip Improve and run Retrospect only. |
| Improve or Retrospect fails once | 4 | Retry once with the simplified fallback scope for that task. |
| All improvements regress tests | 4, 5, 6 | Revert the failed improvements, keep the retrospect output, and report that no safe code changes were retained. |
| `.swe/active/spiral-state.json` exists | 5, 6.5 | Generate `learning-delta.json` and skip standalone archival because Spiral owns final archiving. |
| Archive succeeds in standalone mode | 6.5, 7 | Update the living project model from archived summaries. |

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

### Multi-Model Evaluate (when `model_mode = multi`)

When `model_mode = multi`, build the SWE Quality Evaluate relay from `skills/swe/methodology/references/swe-relay-prompts.md` and save it to `.tmp/{SESSION_ID}_eval_relay.txt`.
Run the Codex side through `scripts/codex-relay.sh` using the direct-relay mechanics from `skills/core/external-models/references/direct-relay-pattern.md`.
Use the background fan-out and result collection rules from `skills/core/routing/references/parallel-execution-pattern.md`.
Merge Claude and Codex improvement targets with `skills/core/routing/references/consensus-protocol.md` and log the agreement rate.

### Phase 3 Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instruction: "List the top 3 code quality issues in {primary source file}." If retry fails: proceed to Phase 4 (Retrospect only) — improvement without evaluation targets is lower value |
| No source code found | Error: "No source code found for evaluation." Proceed to Phase 4 with artifact-only retrospect |
| Clean evaluation (no findings) | Log: "Code quality is satisfactory. No improvements needed." Skip Improve in Phase 4, proceed with Retrospect only |
| Codex background fails (multi-model) | Skip Codex results. Claude evaluation is always sufficient |

## Phase 4: Improve ‖ Retrospect

When `improve_mode = eligible`, Improve and Retrospect execute as parallel Tasks.
Improve modifies source code while Retrospect analyzes the artifact chain, so the tasks stay on different file domains.
When `improve_mode` is any skip state, Tune runs Retrospect only.

### Parallel Execution (Standard+ depth)

Fan-out: Launch both stages simultaneously as independent Tasks.

**Task 1 — Improve** (implementer agent):

> Agent: **implementer** (via Task tool with `subagent_type: "ouroboros:swe:implementer"`)

- **Input**: Evaluation findings + source code files + test suite + depth level for Improve
- **Instructions**: Follow the Improve instruction template from `skills/swe/methodology/references/agent-instructions.md`. Bind: improvement_targets={improvement targets from Phase 3}. Prioritize correctness before performance and readability, and keep the existing test suite Green.
- **Expected output**: Modified source code + improvement summary + Green state confirmation

After the implementer returns, run the full test suite via Bash to independently confirm Green state.
Log: "Improve complete. {n} improvements applied. Tests: {pass}/{total} passing."

**Task 2 — Retrospect** (core researcher agent):

> Agent: **core researcher** (via Task tool with `subagent_type: "ouroboros:core:researcher"`)

- **Input**: Full artifact chain from `.swe/active/` + evaluation results from Phase 3 + depth level
- **Instructions**: Follow the Retrospect instruction template from `skills/swe/methodology/references/agent-instructions.md`. Bind: task={task}. Keep the output aligned to `templates/swe/retrospect-report.md`.
- **Expected output**: Retrospect analysis with patterns, learnings, decisions, and improvement suggestions

Log: "Retrospect complete. {n} patterns, {m} learnings, {k} next-cycle suggestions extracted."

Fan-in: Both Tasks produce independent results and feed the Phase 5 report assembly.
Improve contributes `Improvement Results`.
Retrospect contributes the remaining template-backed sections, including `Patterns Identified`, `Learnings`, `Decision Log`, and `Feedback for Next Cycle`.
Retrospect remains valid without Improve output because it analyzes the artifact chain rather than the applied changes.

### Light Depth Behavior

If `improve_mode = skip-light`, execute Retrospect only and let the report template omit `Improvement Results`.
Log: "Improve skipped (Light depth). Proceeding to Retrospect."

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

Assemble the tune artifact by filling `templates/swe/retrospect-report.md`.
Use only the sections enabled for the current depth instead of restating Light, Standard, and Deep content inline.
Populate `Evaluation Summary` from Phase 3, `Improvement Results` from Phase 4 when `improve_mode = eligible`, and the remaining sections from the Retrospect output.
Treat the template's `Feedback for Next Cycle` section as the authoritative next-turn handoff for reporting, archival, and spiral reuse.

### Learning Delta Generation (spiral only)

When `.swe/active/spiral-state.json` exists, derive the learning-delta payload from the completed retrospect report using `skills/swe/methodology/references/spiral-state-patterns.md`.
Use neutral `team_effectiveness` defaults when the turn did not run a team policy.
Save via `Bash: scripts/spiral-state.sh learning-delta save`.
Log: "Learning delta saved for next turn."
Skip this step for standalone tune runs.

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

When `model_mode = multi`, append to the report:

```markdown
### Multi-Model Evaluation Summary

| Model | Quality Rating | Improvement Targets | Agreement |
|-------|---------------|--------------------|-----------|
| Claude | {rating} | {n} | — |
| Codex | {rating} | {m} | {rate}% |

Consensus improvement targets used for Improve phase.
```

Persist the completed Retrospect Report to `.swe/active/10-tune.md` using the Phase 5 template-backed assembly.

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
