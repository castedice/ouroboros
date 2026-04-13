---
name: core:evolve
description: "Use when you need to improve a plugin component, or the weakest component in a module, based on evaluation findings"
argument-hint: <file-path|module-name> [--eval <report>] [--focus <criteria>] [--single]
allowed-tools: Read, Glob, Edit, Write, Bash, Task
---

# Evolve — Plugin Component Improvement

Improve existing plugin components using evaluation feedback, researcher analysis, and validated changes.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 2 | evaluator | Baseline evaluation (if not provided) |
| 3 | researcher | Root cause analysis + improvement direction |
| 6 | evaluator + Bash background (--multi) | Before/after validation (parallel with Codex when --multi) |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass component paths, inline component contents, and any prior evaluation payloads on every agent call.
Use named return payloads rather than prose-only summaries.
The command owns worktree edits, loop state, temp payloads, and decision records.
The default evolve flow invokes `Agent(subagent_type: "ouroboros:core:evaluator")` and `Agent(subagent_type: "ouroboros:core:researcher")`.
The default evolve flow does not invoke generator or brainstormer, but their payload contracts are reserved here for module-specific repair extensions.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:core:evaluator` | 2 and 6 | `component_path`, artifact paths, inline component or before-and-after contents, matching criteria reference paths, focus criteria when present, and prior evaluation payloads | `level`, `criteria[]`, `improvements[]`, `strengths[]`, `verdict`, `regressed_criteria[]`, `before_score`, `after_score`, and `unresolved_questions[]` |
| `ouroboros:core:researcher` | 3 | Evaluation report, component path, inline component content, focus criteria, prior learnings, and relevant improvement references | `analysis_report`, `root_causes[]`, `priorities[]`, `recommendations[]`, and `unresolved_questions[]` |
| `ouroboros:core:generator` | Extension-only targeted repair flow | Failed component content, evaluator findings, failing criteria IDs, and matching generation references | `revised_component_content`, `rationale`, `repaired_criteria[]`, and `unresolved_questions[]` |
| `ouroboros:core:brainstormer` | Extension-only strategy reset | Weakest criteria, degraded attempt summaries, hard constraints, and current research findings | `ideas[]`, `tradeoffs[]`, `recommended_direction`, and `unresolved_questions[]` |

| Artifact | Path | Role |
|----------|------|------|
| Provided evaluation report | `{eval_path}` from `--eval` | Authoritative baseline when the user supplies prior evaluation output |
| Baseline evaluation draft | `.tmp/{SESSION_ID}_baseline_eval.md` | Authoritative Phase 2 baseline when `/evolve` runs its own evaluation |
| Research relay prompt | `.tmp/{SESSION_ID}_researcher_relay.txt` | Codex analysis prompt for Phase 3 |
| Codex analysis payload | `.tmp/{SESSION_ID}_codex_analysis.json` | Additive Phase 3 analysis evidence when `--multi` is active |
| Claude validation payload | `.tmp/{SESSION_ID}_validate_claude.json` | Authoritative Phase 6 Claude comparative verdict payload |
| Codex validation payload | `.tmp/{SESSION_ID}_validate_codex.json` | Additive Phase 6 Codex verdict payload when `--multi` is active |

Status-handling and parse rules:
- Strip any trailing completion status block per `skills/core/routing/references/completion-status-protocol.md` before parsing evaluator or researcher prose.
- If `--eval` points to a saved evaluation JSON, parse that JSON directly.
- If `--eval` points to markdown, or Phase 2 generates `.tmp/{SESSION_ID}_baseline_eval.md`, extract `level`, `scores`, and weakest criteria from the ordered evaluation sections after status stripping.
- Phase 6 always reads `before_score`, `after_score`, `verdict`, and `regressed_criteria` from the validation payload files first.
- When both Claude and Codex payloads exist, the Phase 6 consensus verdict is authoritative.
- When Codex is absent or excluded, `.tmp/{SESSION_ID}_validate_claude.json` is authoritative.

## Phase 1: Parse Input

Determine evolution mode from $ARGUMENTS:

| Pattern | Mode | Description |
|---------|------|-------------|
| `<file-path>` | **A: Single Component** | Improve a single file |
| `<module-name>` (directory) | **B: Module Focus** | Improve the weakest component in the module |

Options:

- `--eval <report>`: Existing evaluation results. Skips Phase 2 if provided
- `--focus <criteria>`: Focus on specific criteria (e.g., C3, C5)
- `--single`: Force single-model mode (skip external CLIs). By default, multi-model is auto-detected — if codex CLI is installed, Codex runs in parallel

If no argument provided:

- Output error: "Error: No target specified. Usage: `/evolve <file-path|module-name> [--eval <report>] [--focus <criteria>]`"
- Abort

### State Verification

**Mode A** (file-path):

1. Verify file exists → else "Error: File '{path}' not found."
2. Verify `.md` extension → else "Error: Not a markdown component. Only `.md` files can be evolved."
3. Verify in plugin structure (`commands/`, `agents/`, `skills/`, `templates/`) → else "Warning: File not in standard plugin directory. Proceeding, but evaluation criteria may not apply."

**Mode B** (module-name):

1. Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`
2. If none exist → "Error: Module '{module}' not found. Available modules: {list from `commands/*/`}."
3. Abort on error

**Ambiguous input** (argument matches both a file and a module name): prefer file (Mode A), log note: "Interpreting as file path. Use directory name for module mode."

## Branch Summary

All conditional branches that affect command behavior, consolidated for quick reference.

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Target | File path (Mode A) | All | Improve a single component |
| Target | Module name (Mode B) | 2 expanded | Evaluate module, select weakest, evolve as Mode A |
| `--eval <report>` | Provided | 2 skipped | Use existing evaluation results |
| `--eval` | Not provided (default) | 2 runs | Run baseline evaluation first |
| `--focus <criteria>` | Provided | 3 | Researcher focuses analysis on specific criteria |
| `--single` | true | 6 | Claude evaluator only for validation |
| `--single` | false (default) | 6 | Auto-detect: if codex CLI installed, parallel validation |
| Ambiguous input | Matches file and module | — | Prefer file (Mode A), log note |
| Existing worktree | Found | 4: Session Recovery | User chooses Resume / Discard / create fresh |
| Validation verdict | `improved` | 6.5, 7, 8 | Select best archive attempt, then proceed to decision record + review |
| Validation verdict | `lateral` | 6.5, 7, 8 | Select best archive attempt, then proceed to review with note |
| Validation verdict | `degraded` + loop says `continue` | 3–6 retry | Auto-rollback, retry with adjusted approach |
| Validation verdict | `degraded` + loop says `{spinning|oscillation|no-drift|diminishing-returns|cap}` | 6.5, 8 | Stop retrying, restore the best non-degraded archive attempt if one exists, and report convergence reason |

## Phase 2: Baseline Evaluation

### Mode A: Single Component

1. Read target file
2. If `--eval` provided → parse and use
3. Otherwise → launch **evaluator** agent for static evaluation (via Task tool)
   - **Input**: component file content + component type
   - **Instructions**: "Load criteria reference, apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate, and return a static evaluation report."
   - **Expected output**: Static evaluation report written to `.tmp/{SESSION_ID}_baseline_eval.md` with `level`, per-tier scores, zero-score criteria, and concise reasoning for the weakest criteria
4. **If Level 4 (Excellent)**: Log "Already at max level. Applying [MED]/[LOW] improvements." → proceed automatically

### Mode B: Module Focus

1. Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`, `templates/{module}/` for .md files
2. Launch **evaluator** agent for each component (sequential):
   - **Input**: Component file content + detected component type
   - **Instructions**: "Load `skills/core/evaluation/references/{type}-criteria.md`. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Return evaluation report."
   - **Expected output**: Evaluation report with level, per-tier scores, and per-criterion reasoning
3. Sort results by score ascending
4. Auto-select the **weakest component**
5. Log: "{name} ({score}/5) is the weakest. Proceeding with improvement."

## Phase 3: Analysis

> Agent: **researcher** + Bash background (when `--multi`)

Analysis runs Claude researcher for deep knowledge-base-integrated analysis. When `--multi` is active, Codex researcher runs in parallel for a fresh perspective — cherry-pick mode combines the best insights from both. See `skills/core/routing/references/parallel-execution-pattern.md`.
Before launching the researcher, call `bash ${CLAUDE_PLUGIN_ROOT}/scripts/learning-load-context.sh "{component-path}"`; if it returns content, include it verbatim as a `Prior Learnings` block in both Claude and Codex analysis inputs so the investigation starts from the current local gotchas and distilled learnings for that scope.
On retry iterations, load the previous iteration trace via `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh trace "$SESSION_ID"` and pass the JSON summary to the researcher agent as additional context.

### When `--multi` is active (parallel):

1. **Build researcher relay prompt**: Construct from template at `skills/core/evolution/references/researcher-relay-prompt.md` — assemble 4 sections (Role, Content, Methodology, Response Format) with evaluation report + component content inserted as Section 2. Save to `.tmp/{SESSION_ID}_researcher_relay.txt`

2. **Fan-out** (parallel):
   - **Background**: `Bash(codex-relay.sh .tmp/{SESSION_ID}_researcher_relay.txt --output .tmp/{SESSION_ID}_codex_analysis.json --effort high, run_in_background=true)`
   - **Foreground**: Launch Claude **researcher** agent (via Task tool) with same inputs

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both analysis reports and build a unified improvement plan:
   - Union of all root causes identified by either model
   - If both models identify the same root cause, prefer the one with more specific fix prescription
   - Novel insights from Codex (root causes or fixes that Claude missed) are highlighted as "External insight"
   - If Codex analysis failed or is partial, proceed with Claude-only analysis

### When `--multi` is not active (single-model):

Launch the **researcher** agent via Task tool:

- **Input**: Evaluation report + component file path + (if provided) focus criteria
- **Instructions**: "Perform Evolution Analysis. Analyze root causes of 0-score criteria, search knowledge base for patterns, produce Improvement Analysis Report with priorities."
- **Expected output**: Improvement Analysis Report (root causes, priorities, recommendations)

## Phase 4: Planning + Worktree Setup

### Session Recovery

Before creating a new worktree, check for existing evolve worktrees:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status
```

If the JSON output contains entries with `"operation": "evolve"`:

1. Report to user: "Found existing evolve worktree: `{path}` (branch: `{branch}`, {commits_ahead} commits ahead, {dirty_files} dirty files)"
2. Present options:
   - **Resume**: Continue working in the existing worktree (skip worktree creation, use existing `$WORKTREE` path)
   - **Discard**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and proceed with fresh worktree
   - **Merge**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "Evolve {component}: resume merge"` and proceed with fresh worktree
3. Wait for user choice before proceeding

Also run prune to clean up stale worktrees silently:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune
```

### Plan

Build improvement plan from researcher's analysis:

```markdown
## Evolution Plan: {component name}

**Current**: {score}/5 (Level {level})
**Target**: {target_score}/5

### Changes
1. {Change 1 — which criterion to improve, what to modify}
2. {Change 2}
...

### Preserved
- {What stays unchanged and why}
```

Log the plan and proceed automatically.

Create an isolated worktree for applying changes:

1. Derive slug from component name (e.g., `evaluator`, `research-skill`)
2. Create worktree:

   ```bash
   WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create evolve {slug})
   ```

   The script handles branch conflicts by appending timestamps automatically.
3. Initialize loop state: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh init "$SESSION_ID" "{component-path}"`
4. Read the trace directory from `.tmp/${SESSION_ID}_evolve-loop.json` as `trace_dir` for attempt archives.

## Phase 5: Apply in Worktree

1. **Attempt directory**: Create `{trace_dir}/attempt-{N}` for the current attempt.
2. **Before snapshot**: Before applying edits, preserve original file content in memory and save it to `{trace_dir}/attempt-{N}/before.md` for Phase 6.
3. **Apply changes**: Modify the component file **in the worktree** (`$WORKTREE/{component-path}`) using Edit tool according to plan
4. Log: "Changes applied in worktree. Proceeding to validation."

## Phase 6: Validate

> Agent: **evaluator** + Bash background (when `--multi`)

Validation runs as before/after comparison — functionally equivalent to `/evaluate` Mode C. When `--multi` is active, Claude and Codex evaluate in parallel. See `skills/core/routing/references/parallel-execution-pattern.md`.

### Evaluator Instructions

1. **Read after file**: Read the modified file from the worktree
2. Launch **evaluator** agent for before/after comparison (via Task tool):
   - **Input**: Before content (from Phase 5 snapshot) + After content (worktree file) + component type
   - **Instructions**: "Evaluate both versions independently with static criteria. Perform pairwise comparison with position swap. Check for regressions. Return verdict: improved/degraded/lateral."
   - **Expected output**: Comparative validation payload written to `.tmp/{SESSION_ID}_validate_claude.json` with `before_score`, `after_score`, `verdict`, `regressed_criteria`, and a short reasoning summary

### `--multi` Extension

When `--multi` is active, run Codex evaluator in parallel:

1. **Build relay prompt + init manifest**: Construct Mode C comparative prompt from template at `skills/core/evaluation/references/evaluator-relay-prompts.md`. Save to `.tmp/{SESSION_ID}_relay.txt`. Init manifest via `bash scripts/parallel.sh init "$SESSION_ID" '[{"idx":0,"model":"codex","file":".tmp/{SESSION_ID}_codex_eval.json"}]'`
2. **Fan-out**: Background Codex (`codex-relay.sh ... --effort xhigh`) + Foreground Claude evaluator (as above)
3. **Fan-in**: Verify results via `bash scripts/parallel.sh collect "$SESSION_ID"`. Then handle exit codes per `evaluate.md` Phase 3 Step 3
4. **Consensus verdict**: Apply majority rule on improved/degraded/lateral across models

### Trace Archive

After evaluation, archive the attempt evidence:

1. Save the modified file to `{trace_dir}/attempt-{N}/after.md`.
2. Save the improvement strategy to `{trace_dir}/attempt-{N}/strategy.md`.
3. Save a one-paragraph evaluation summary to `{trace_dir}/attempt-{N}/eval-summary.md`.
4. Generate a unified diff and save it to `{trace_dir}/attempt-{N}/diff.patch`.
5. Use `{trace_dir}/attempt-{N}` as `attempt_dir` when recording the loop entry.

### Interpret Result

After each verdict, compute `fingerprint=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh hash "$WORKTREE/{component-path}")` and record it with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh record "$SESSION_ID" "$fingerprint" "{verdict}" "{score_after}" --trace-path "$attempt_dir"`.

After recording the attempt outcome, call `bash ${CLAUDE_PLUGIN_ROOT}/scripts/hook-evolve-outcome.sh validated "{component-path}" "{verdict}" "{retry_count}"`.

| Verdict | Action |
|---------|--------|
| `improved` | Proceed to Phase 6.5 |
| `lateral` | Auto-keep: proceed to Phase 6.5 |
| `degraded` | Auto-rollback + retry (see below) |

### Degraded Handling (Automatic)

1. After recording a degraded result, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh similarity "$SESSION_ID"`.
2. If it returns `continue`, restore the worktree file from the before snapshot, include the failure cause, and return to Phase 3 while total attempts remain below 3.
3. If it returns `spinning`, `oscillation`, `no-drift`, `diminishing-returns`, or `cap`, stop retrying, include the stop reason in the Review phase report, report the convergence reason to the user, and continue to Phase 6.5 for archive selection.

## Phase 6.5: Archive Selection

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh select-best "$SESSION_ID"` to select the best non-degraded attempt.
If the best attempt is not the current worktree state, restore the selected `after.md` into `$WORKTREE/{component-path}` before Phase 7.
If multiple non-degraded candidates exist, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/evolve-loop.sh trace "$SESSION_ID"`, present a comparison table with iteration, verdict, score, and strategy summary, and ask the user to choose the attempt before restoring it.
If `select-best` returns an empty string because all attempts degraded, skip Phase 7 and continue to the stalled Review report.

## Phase 7: Record in Worktree

Create an evolve decision entry **in the worktree**: `$WORKTREE/docs/decisions/{date}-evolve-{component-name}.md`

Use template from `templates/core/decision-evolve.md`.

Entry must include:

- type: evolve
- date, module, component, intent
- before-score, after-score, verdict
- Background (why improvement was needed)
- Decisions (what was changed and why)
- Change log (per-file change summary)
- Verification results

Stage and commit in worktree:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Evolve {component-name}: {score_before}/5 → {score_after}/5"
```

## Phase 8: Review

Present the evolution results and diff for user review:

```markdown
## Evolution Draft: {component name}

**Branch**: ouroboros/evolve/{slug}
**Before**: {score}/5 (Level {level}) → **After**: {score}/5 (Level {level})
**Verdict**: {improved|lateral}

### Change Summary
- {Change 1}
- {Change 2}

### Diff
{git diff main...ouroboros/evolve/{slug} output}

### Decision Entry
- `docs/decisions/{date}-evolve-{component-name}.md`

**Merge** these changes into main, or **Discard** the draft?
```

If 2 consecutive degraded failures occurred, report both failure causes and ask user for direction instead of offering merge.

When reporting consecutive degraded failures:

```markdown
## Evolution Stalled: {component name}

**Attempts**: {n} (all degraded)
**Branch**: ouroboros/evolve/{slug}

### Failure Analysis
| Attempt | Score | Cause |
|---------|-------|-------|
| 1 | {score}/5 | {failure cause from evaluator} |
| 2 | {score}/5 | {failure cause from evaluator} |

### Convergence
- Loop status: {stop_reason from evolve-loop.sh}

**Options**: Provide direction for a different approach, or **Discard** the draft?
```

### On Merge

1. Merge and cleanup:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "Evolve {component-name}: {score_before}/5 → {score_after}/5"
   ```

2. Confirm: "Evolution merged to main."

### On Discard

1. Discard: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`
2. Confirm: "Draft discarded. No changes made to main."

## Phase 9: Report

### Mode A: Single Component

```markdown
## Evolution Complete: {component name}

**Before**: {score}/5 (Level {level}) → **After**: {score}/5 (Level {level})
**Verdict**: {improved|lateral}

### Next Actions
- Run `/evolve {path}` again for further improvement
- Run `/evaluate {path}` to assess other components
- Run `/evaluate --output <output-path> {path}` to verify output quality matches definition quality
- Decision entry: `docs/decisions/{filename}.md`
```

### Mode B: Module Focus

```markdown
## Evolution Complete: {module} / {component name}

**Before**: {score}/5 → **After**: {score}/5
**Verdict**: {improved|lateral}

### Next Weakest Component
- {name} ({score}/5) — run `/evolve {module}` to continue

### Next Actions
- Run `/evaluate --output <output-path> {path}` to verify output quality matches definition quality

### Decision Entry
- `docs/decisions/{filename}.md`
```

## System Integration

| Aspect | Contract |
|--------|----------|
| Command-taxonomy role | `/evolve` is the single-component improvement command in the core self-improvement loop |
| Upstream inputs | Consumes a component path or module name, optional saved evaluation output from `/evaluate`, prior learnings from `scripts/learning-load-context.sh`, and the current repository state |
| Produced state | Writes one improved component draft in a worktree, records loop state and trace archive pointers via `scripts/evolve-loop.sh`, emits `hook-evolve-outcome.sh` events, and creates `docs/decisions/{date}-evolve-{component-name}.md` inside the worktree |
| Downstream consumers | `/evaluate` verifies the result, `/upgrade` and `/generate` can target the degraded or weakest paths surfaced here, and the user review step decides whether the draft merges |
| Boundary | One component per invocation. `/evolve` does not edit evaluation criteria, redesign whole modules, or mutate unrelated components outside the selected target |

## Rules

- Never finalize changes without before/after validation
- All file modifications happen in the worktree — never edit files directly on main branch
- User reviews the final result (Phase 8) before merge; Phase 6.5 only asks for a choice when multiple non-degraded attempts exist
- Improve one component at a time — no simultaneous multi-file evolution
- Never modify evaluation criteria (evaluation is independent)
- Never change a component's original purpose — improve how it achieves its goal
- Auto-retry once on degraded validation; after 2 consecutive failures, report to user
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
