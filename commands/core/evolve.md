---
description: Improve an existing plugin component — analyze weaknesses, plan changes, apply, and validate with before/after evaluation
argument-hint: <file-path|module-name> [--eval <report>] [--focus <criteria>] [--multi]
allowed-tools: Read, Glob, Grep, Edit, Write, Bash, Task
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

## Phase 1: Parse Input

Determine evolution mode from $ARGUMENTS:

| Pattern | Mode | Description |
|---------|------|-------------|
| `<file-path>` | **A: Single Component** | Improve a single file |
| `<module-name>` (directory) | **B: Module Focus** | Improve the weakest component in the module |

Options:

- `--eval <report>`: Existing evaluation results. Skips Phase 2 if provided
- `--focus <criteria>`: Focus on specific criteria (e.g., C3, C5)
- `--multi`: Enable multi-model validation in Phase 6 (Claude + Codex parallel evaluation)

If no argument provided:

- Output error: "Error: No target specified. Usage: `/evolve <file-path|module-name> [--eval <report>] [--focus <criteria>]`"
- Abort

## Phase 2: Baseline Evaluation

### Mode A: Single Component

1. Read target file
2. If `--eval` provided → parse and use
3. Otherwise → launch **evaluator** agent for static evaluation (via Task tool)
   - Input: component file content + component type
   - Instructions: "Load criteria reference, apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate, return evaluation report."
4. **If Level 4 (Excellent)**: Log "Already at max level. Applying [MED]/[LOW] improvements." → proceed automatically

### Mode B: Module Focus

1. Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`, `templates/{module}/` for .md files
2. Launch **evaluator** agent for each component (sequential)
3. Sort results by score ascending
4. Auto-select the **weakest component**
5. Log: "{name} ({score}/5) is the weakest. Proceeding with improvement."

## Phase 3: Analysis

> Agent: **researcher** + Bash background (when `--multi`)

Analysis runs Claude researcher for deep knowledge-base-integrated analysis. When `--multi` is active, Codex researcher runs in parallel for a fresh perspective — cherry-pick mode combines the best insights from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

1. **Build researcher relay prompt**: Construct from evaluation report + component content + analysis instructions. Save to `.tmp/{SESSION_ID}_researcher_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent research analyst. Your task is to analyze a plugin component that received a quality evaluation, diagnose root causes of low scores, and propose improvement directions. Do not assume any prior context — analyze based solely on the content and evaluation given.
   ```

   **Section 2 — Content**: Evaluation report + target file content (verbatim).

   **Section 3 — Methodology**:

   ```text
   Follow this procedure:
   1. Parse the evaluation report: identify 0-score criteria and [HIGH]/[MED] improvements
   2. For each 0-score criterion, diagnose root cause: Missing (content absent), Format error (wrong form), Insufficient depth (lacks specificity)
   3. For each root cause, prescribe a specific fix with example snippet
   4. Prioritize improvements by score impact
   ```

   **Section 4 — Response Format**: JSON with `root_causes`, `improvements`, `recommendations` arrays.

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_researcher_relay.txt .tmp/{SESSION_ID}_codex_analysis.json high, run_in_background=true)`
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

## Phase 5: Apply in Worktree

1. **Before snapshot**: Preserve original file content in memory (used in Phase 6)
2. **Apply changes**: Modify the component file **in the worktree** (`.worktrees/evolve-{slug}/{component-path}`) using Edit tool according to plan
3. Log: "Changes applied in worktree. Proceeding to validation."

## Phase 6: Validate

> Agent: **evaluator** + Bash background (when `--multi`)

Validation runs as before/after comparison — functionally equivalent to `/evaluate` Mode C. When `--multi` is active, Claude and Codex evaluate in parallel. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

1. **Read after file**: Read the modified file from the worktree
2. **Build relay prompt**: Construct Mode C comparative prompt from before content + after content + criteria reference. Save to `.tmp/{SESSION_ID}_relay.txt`
3. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent for before/after comparison (via Task tool):
     - Input: Before content (from Phase 5 snapshot) + After content (worktree file) + component type
     - Instructions: "Evaluate both versions independently with static criteria. Perform pairwise comparison with position swap. Check for regressions. Return verdict: improved/degraded/lateral."
4. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3 Step 3
5. **Consensus verdict**: Apply majority rule on improved/degraded/lateral across models

### When `--multi` is not active (single-model):

1. **Read after file**: Read the modified file from the worktree
2. Launch **evaluator** agent for before/after comparison (via Task tool):
   - Input: Before content (from Phase 5 snapshot) + After content (worktree file) + component type
   - Instructions: "Evaluate both versions independently with static criteria. Perform pairwise comparison with position swap. Check for regressions. Return verdict: improved/degraded/lateral."

### Interpret Result

| Verdict | Action |
|---------|--------|
| `improved` | Proceed to Phase 7 |
| `lateral` | Auto-keep: proceed to Phase 7 |
| `degraded` | Auto-rollback + retry (see below) |

### Degraded Handling (Automatic)

1. **First failure**: Restore worktree file from before snapshot. Return to Phase 3 with failure cause included for researcher. Log: "Validation failed. Auto-retrying with adjusted approach."
2. **Second consecutive failure**: Stop retrying. Include both failure causes in the Review phase report. Log: "2 consecutive failures. Reporting to user for direction."

## Phase 7: Record in Worktree

Create an evolve decision entry **in the worktree**: `.worktrees/evolve-{slug}/docs/decisions/{date}-evolve-{component-name}.md`

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

## Rules

- Never finalize changes without before/after validation
- All file modifications happen in the worktree — never edit files directly on main branch
- User reviews the final result (Phase 8) before merge — this is the only checkpoint
- Improve one component at a time — no simultaneous multi-file evolution
- Never modify evaluation criteria (evaluation is independent)
- Never change a component's original purpose — improve how it achieves its goal
- Auto-retry once on degraded validation; after 2 consecutive failures, report to user
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
