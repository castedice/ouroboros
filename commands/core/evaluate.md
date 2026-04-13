---
name: core:evaluate
description: "Use when you need to assess a plugin component or module, compare before-and-after changes, or score output against evaluation criteria"
argument-hint: <file-path|module-name> [--output <output-path>] [--before <path>] [--after <path>] [--single] [--unanimous] [--no-save] [--compare [<baseline>]]
allowed-tools: Read, Glob, Grep, Task, Bash
---

# Evaluate — Plugin Component Quality Assessment

Assess the quality of plugin components using structured criteria and the evaluator agent.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
| 2.5 | — (command) | Structural validation (Mode A/B only, informational) |
| 3 | evaluator (agent) + Bash background (--multi) | Claude evaluation (foreground) + Codex evaluation (background, parallel) |
| 4, 5, 6 | evaluator (agent) | Criteria-based scoring (read-only) |
| 5.5 | — (command) | Consensus integration (--multi only) |
| 6.5 | Bash (tool) | Content hashing + result persistence (--save/--compare) |
| 7 | — (command) | Baseline loading + regression comparison (--compare) |

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass evaluator artifact paths and inline file contents on every call.
Use named return payloads rather than prose-only summaries.
The command owns temp files, normalization, consensus state, and saved results.
The evaluator stays read-only.
Internal evaluator calls use `Agent(subagent_type: "ouroboros:core:evaluator")`.
The Bash Codex relay path is additive evidence only.

| Agent | Phases | Input | Expected Output |
|-------|--------|-------|-----------------|
| `ouroboros:core:evaluator` | 3, 4, and 5 | `component_path`, mode-specific artifact paths, inline component or output contents, matching criteria reference paths, `depth_level`, prior learnings when present, and temp output path | `level`, `criteria[]`, `improvements[]`, `strengths[]`, `unresolved_questions[]`, and mode-specific fields such as `verdict`, `regressed_criteria[]`, or `output_score` |

## Output Contracts

| Output Mode | Condition | Contract |
|-------------|-----------|----------|
| Usage error | Phase 1 parse failure or a required file is missing | Emit a one-line error with the failing precondition and the exact usage string, then abort with no report sections |
| Mode A static report | Single component, no `--multi` | Ordered sections: `## Evaluation: {path}`, optional `### Structural Validation`, `### Score Summary`, `### Zero-Score Criteria`, and `### Next Actions` |
| Mode B module summary | Module scan, no `--multi` | Ordered sections: `## Module Evaluation Summary: {module}`, optional `### Structural Validation`, summary table, `### Weakest Component`, and `### Next Actions` |
| Mode C comparison | `--before` and `--after` provided | Ordered sections: `## Before/After Evaluation: {path}`, `### Score Comparison`, `### Regression Analysis`, `### Verdict`, and `### Next Actions` |
| Mode D output report | `--output <output-path>` provided | Ordered sections: `## Output Evaluation: {path}`, `### Output Score`, `### Criterion Breakdown`, optional `### Dual-Axis Summary`, and `### Next Actions` |
| Multi-model augmentation | Any mode with external results | Use `templates/core/multi-model-report.md` as the base wrapper, then append the mode-specific ordered sections above plus `### Agreement` and `### Bias Alerts` |
| Regression report | `--compare` with baseline present | Use `skills/core/evaluation/references/regression-format.md` Comparison Report Format exactly |
| Comparison skipped | `--compare` without a baseline | Emit `### Comparison Skipped` with the reason and continue without regression sections |
| Actionable handoff | Phase 8 Mode A only | Emit either a single `/evolve ...` command block or omit the phase entirely when `saved_result_path` is unavailable |


## Phase 1: Parse Input

Determine evaluation mode from $ARGUMENTS:

| Pattern | Mode | Description |
|---------|------|-------------|
| `<file-path>` | **A: Single Static** | Static evaluation of a single file |
| `<module-name>` (directory) | **B: Module Scan** | Scan entire module |
| `--before <path> --after <path>` | **C: Before/After** | Compare two versions |
| `<file-path> --output <output-path>` | **D: Output** | Dynamic evaluation of results |

### Persistence Flags

| Flag | Default | Effect |
|------|---------|--------|
| `--save` | **on** | Persist evaluation results to `dev/evaluations/` as JSON |
| `--no-save` | — | Disable persistence (skip JSON output) |
| `--compare [<baseline>]` | — | Compare with previous run (implies `--save`). If no baseline path, auto-discover `dev/evaluations/{module}-latest.json` |

Persistence is on by default — results are always saved unless `--no-save` is specified. If `--compare` is used without a baseline path, auto-discover the latest baseline via `dev/evaluations/{module}-latest.json` symlink (managed by `scripts/regression.sh`).

### Multi-Model Flags

| Flag | Default | Effect |
|------|---------|--------|
| `--multi` | **auto** | Auto-detect: if codex CLI installed, enable multi-model. Explicit flag forces multi even on first check |
| `--single` | — | Force single-model evaluation (skip external CLIs) |
| `--unanimous` | off | Require deliberative consensus on any split criterion or verdict via Advocate, Devil's Advocate, and Judge roles (only with multi-model) |
| `--sequential` | off | Disable batch parallelism in Mode B (evaluate components one at a time) |

If `--unanimous` without multi-model active: warn "⚠ --unanimous requires multi-model. Ignoring." and continue single-model.

## Branch Summary

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Positional target | missing | 1 abort | Emit the usage error and stop |
| Parse pattern | single file | 2-8 | Run Mode A static evaluation |
| Parse pattern | module directory | 2-8 | Run Mode B module scan |
| Parse pattern | `--before` plus `--after` | 2-8 | Run Mode C comparative evaluation |
| Parse pattern | `<file> --output <path>` | 2-8 | Run Mode D output evaluation |
| `--output <path>` | missing in Mode D | 2 abort | Emit the output-path usage error and stop |
| Structural validation | Mode A or B | 2.5, 6 | Run informational structural validation and prepend the conditional validation section when needed |
| Structural validation | Mode C or D | 2.5 skipped, 6 | Skip structural validation entirely |
| `--single` | present | 1, 3, 5.5 | Force Claude-only execution and skip external fan-out |
| Codex CLI or writable temp dir | unavailable | 1, 3, 5.5 | Fall back to Claude-only execution even without `--single` |
| `--unanimous` | active with multi-model | 5.5 | Use the unanimous deliberative consensus path |
| `--unanimous` | active without multi-model | 1, 5.5 | Warn once and ignore the flag |
| `--sequential` | active in Mode B | 3 | Run module evaluations one at a time instead of batched background execution |
| External model payload | parse failure | 3, 3.5, 5.5 | Attempt LLM fallback, then exclude the model result from consensus if normalization still fails |
| `--no-save` | active and `--compare` absent | 6.5 skipped | Skip result persistence |
| `--save` or `--compare` | active | 6.5 | Persist normalized result payloads via `eval-save.sh` |
| `--compare <baseline>` | explicit path provided | 7 | Use the named baseline file |
| `--compare` | no explicit path and baseline found | 7 | Auto-discover the latest baseline and run comparison |
| `--compare` | baseline missing | 7 | Emit `### Comparison Skipped` and continue without regression sections |
| Phase 8 handoff | Mode A plus `saved_result_path` available | 8 | Emit the `/evolve ... --eval ...` handoff block |
| Phase 8 handoff | any other case | 8 skipped | Omit actionable handoff output |

### CLI Availability Check (auto-detect)

Check `codex` CLI availability and version via Bash. Store: `codex_available` (bool + version), `failure_count` ({ codex: 0 }).

- If `--single` specified: skip check, use single-model
- Otherwise: auto-detect CLIs

### Session Temp Directory

Always generate a short session ID (first segment of UUID) and ensure `.tmp/` directory exists.
All temp files use the pattern `.tmp/{SESSION_ID}_{purpose}`.
Files are cleaned up at the end of the command run (see Rules).
Both Claude and Codex evaluation results are persisted here — Claude agents write JSON to `.tmp/{SESSION_ID}_{idx}_claude_eval.json`, Codex results land in `.tmp/{SESSION_ID}_{idx}_codex_eval.json`.
Normalized result files use the sibling pattern `.tmp/{SESSION_ID}_{idx}_{model}_eval.normalized.json`.

Log availability:

- Codex available: "Multi-model: Claude + Codex v{ver}"
- Codex unavailable: "Single-model mode (no external CLIs found)"

If no argument provided:

- Output error: "Error: No target specified. Usage: `/evaluate <file-path|module-name> [--output <output-path>] [--before <path>] [--after <path>] [--multi [--unanimous]]`"
- Abort

## Phase 2: Context Gathering

### Mode A: Single Static

1. Read target file
2. Detect component type from frontmatter/filename
3. Verify type is valid (agent, skill, command, hook, template, claudemd)

### Mode B: Module Scan

1. Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`, `templates/{module}/` for .md files
2. Build component list with detected types
3. Log: "Found {N} components. Evaluating all (static only)."

### Mode C: Before/After

1. Read both --before and --after files
2. Verify both are the same component type
3. Confirm to user: "Proceeding with before/after comparison of {type} component."

### Mode D: Output

1. Read the component definition file (the positional argument)
2. Detect component type
3. Read the output file specified by `--output <output-path>`
4. If output-path is missing or file not found: error with usage — "Error: Output file required. Usage: `/evaluate <file-path> --output <output-path>`"
5. Load `skills/core/evaluation/references/{type}-output-criteria.md`
6. Log: "Output evaluation: {component-name} ({type}). Output: {output-path}"

## Phase 2.5: Structural Validation (Mode A/B only)

> Informational gate — validates structural correctness before evaluation. Warnings do not block evaluation.

Skip this phase for Mode C (Before/After) and Mode D (Output) — these modes evaluate quality differences or output behavior, where structural issues are not the focus.

For Mode A (Single Static) and Mode B (Module Scan), apply the validation-methodology skill (`skills/core/validation/SKILL.md`) Steps 1-4:

1. **Identify component type** from Phase 2 context (frontmatter/filename detection)
2. **Run type-specific checks** per `skills/core/validation/references/frontmatter-and-fields.md`:
   - Required frontmatter fields present and valid
   - Recommended fields checked (warnings only)
3. **Run cross-cutting checks** per `skills/core/validation/references/naming-and-collision.md`:
   - Naming convention compliance (regex validation)
   - Path constraints (no `../` traversal, `./` prefix)
   - Command name collision against built-in list
   - Inter-component reference integrity
4. **Check common pitfalls** per `skills/core/validation/references/common-pitfalls.md`

### Validation Report

Produce a Validation Report per the validation-methodology SKILL (Step 4):

- **PASS** (0 errors): Log "Structural validation: PASS ({m} warnings)" → proceed to Phase 3. Store report for Phase 6
- **FAIL** (1+ errors): Log "⚠ Structural validation: FAIL ({n} errors, {m} warnings). Proceeding with evaluation." → proceed to Phase 3. Store report for Phase 6

Mode B: Run validation for each component in the scan list. Aggregate results into a single report.

## Phase 3: Evaluation (Parallel when --multi)

This phase runs Claude evaluation and external model evaluation. When `--multi` is active, both run in parallel for ~50% wall-clock reduction. See `skills/core/routing/references/parallel-execution-pattern.md` for the general pattern.

### Step 1: Build Relay Prompt + Init Manifest (--multi only, before fan-out)

Skip if `--multi` is not active or no external CLIs are available.

Construct the relay prompt using the mode-specific template from `skills/core/evaluation/references/evaluator-relay-prompts.md`. Insert dynamic content (target file, criteria reference) into the template sections. Save assembled prompt to `.tmp/{SESSION_ID}_relay.txt`.
Before assembling any evaluator relay or Claude evaluator input, call `bash ${CLAUDE_PLUGIN_ROOT}/scripts/learning-load-context.sh "{component-path}"`; if it returns content, include it as a `Prior Learnings` block alongside the component and criteria context so the evaluator can explicitly check whether known issues were addressed, preserved, or regressed.

**Manifest init** (resilient collection): Create a manifest declaring expected results via `scripts/parallel.sh`:

```bash
bash scripts/parallel.sh init "$SESSION_ID" '[{"idx":0,"model":"codex","file":".tmp/{SESSION_ID}_codex_eval.json"}]'
```

For Mode B, include all batch entries: `[{"idx":0,...}, {"idx":1,...}, ...]` with idx-based file paths.

### Step 2: Fan-Out — Parallel Execution

**Model selection**: Per `skills/core/routing/references/routing-table.md` — Codex `gpt-5.4` with `xhigh` reasoning (DR-035).

#### When `--multi` is active (parallel):

Launch both evaluations simultaneously:

1. **Background**: Start external model via Bash with `run_in_background: true`:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/codex-relay.sh .tmp/{SESSION_ID}_relay.txt --output .tmp/{SESSION_ID}_codex_eval.json --effort xhigh
   ```

   **Timeout**: 600 seconds. Store the background task ID for later collection.

2. **Claude evaluator**: Launch via Agent tool (subagent_type: `ouroboros:core:evaluator`).
   - **Instructions** (all modes): "Evaluate `{component_path}` ({type}). Read the component file and load `skills/core/evaluation/references/{type}-criteria.md`. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Write result as JSON to `.tmp/{SESSION_ID}_{idx}_claude_eval.json`."
   - Agent always writes JSON to file and returns compact summary only: `"{component_path}: Level {N}, F:{a}/{b} Q:{a}/{b} E:{a}/{b} → {output_path}"`. Main context reads JSON files for Phase 6 reporting and consensus
   - If agent stdout includes the terminal completion status block from `skills/core/routing/references/completion-status-protocol.md`, ignore or strip it. The JSON file on disk remains the authoritative payload
   - **Mode A/D**: foreground
   - **Mode B**: `run_in_background: true`

For Mode C: run both evaluations for before and after versions (4 evaluations: 2 Claude sequential + 2 Codex background).

#### Mode B: File-Based Parallel Execution

Per `skills/core/routing/references/parallel-execution-pattern.md`, launch all evaluations as background tasks in batches. Main context handles launch, collection, consensus, and reporting only.

When `--sequential` is set: fall back to one-at-a-time foreground processing. Results are reported in Phase 2 discovery order regardless of completion order.

#### When `--multi` is not active (single-model):

Launch Claude evaluator only — same instructions as above (always writes JSON to `.tmp/{SESSION_ID}_{idx}_claude_eval.json`). Mode A: foreground agent. Mode B: background agents. Mode C: foreground, twice (before then after). All modes produce file output.

#### Evaluator Recovery (all modes, single-model and multi-model Claude path)

If the evaluator agent fails (timeout, error, or unparseable output):

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions ("Score each criterion 0 or 1 with brief reasoning"). If retry fails: "Evaluation failed for {component}. Check evaluator agent definition or try again." |
| Malformed report (missing criteria table, partial output) | Extract partial scores from available output — look for criterion IDs, score patterns, reasoning sections. Report partial result: "Partial evaluation ({n}/{total} criteria recovered)." |
| Mode B component failure | Skip failed component, continue remaining. Note in summary: "{component}: evaluation failed — excluded from module average." |

### Step 3: Fan-In — Collect Results

After all background tasks complete (notified automatically), collect results from files.

**Resilient collection**: Verify all results arrived via `scripts/parallel.sh`:

```bash
bash scripts/parallel.sh collect "$SESSION_ID"
```

If exit 0 (all present), proceed normally. If exit 1 (gaps), check gap report and fall through to per-model exit code handling below.

Check the background task output. Handle by exit code:

| Exit | Meaning | Action |
|------|---------|--------|
| 0 | Parse success | Read `.tmp/{SESSION_ID}_{model}_eval.json` — use directly |
| 1 | Parse failed | **LLM fallback**: Read `.tmp/{SESSION_ID}_{model}_eval.json.raw`, extract scores intelligently (see below) |
| 2 | CLI error | Skip model, log error from stderr |
| 124 | Timeout | Skip model, log: "{model}: timed out after 600s. Skipping." |

**LLM fallback** (exit code 1): Apply the LLM extraction strategy from `skills/core/routing/references/parsing-strategy.md` — read raw output, extract score patterns, construct partial result.
Partial scores are valid in consensus.
Missing criteria are marked `"-"` in the report.

### Step 3.5: Normalize Evaluation JSON

After each Claude or Codex result is collected, normalize it before any consensus or persistence logic:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/eval-normalize.sh .tmp/{SESSION_ID}_{idx}_claude_eval.json > .tmp/{SESSION_ID}_{idx}_claude_eval.normalized.json
bash ${CLAUDE_PLUGIN_ROOT}/scripts/eval-normalize.sh .tmp/{SESSION_ID}_{idx}_codex_eval.json > .tmp/{SESSION_ID}_{idx}_codex_eval.normalized.json
```

Use the normalized files as the authoritative per-model payloads in Phase 5.5 and Phase 6.5. If LLM fallback reconstructs a partial result from raw output, write that JSON first and then pass it through `eval-normalize.sh`. If normalization fails, treat that model result as unparseable and exclude it from consensus.

### Step 4: Circuit Breaker (Mode B)

Apply circuit breaker per `skills/core/routing/references/invocation-protocol.md` — 2 consecutive failures per CLI triggers skip for the remainder of this command run. In batch parallel mode, check at batch boundaries (after fan-in, before launching next batch).

## Phase 4: Pairwise Comparison (Mode C only)

> Agent: **evaluator**

After both static evaluations complete:

- **Input**: Both evaluation reports + both file contents
- **Instructions**: "Perform pairwise comparison with position swap. Check for regressions (criteria that dropped from 1→0). Return verdict: improved/degraded/lateral."
- **Expected output**: Pairwise verdict + regression analysis

## Phase 5: Output Evaluation (Mode D, or Mode B with output option)

> Agent: **evaluator**

- **Input**: Component definition + collected output/results
- **Instructions**: "Load `skills/core/evaluation/references/{type}-output-criteria.md`. Apply 5 output criteria with CoT-first scoring. Return structured output evaluation report."
- **Expected output**: Output evaluation report

## Phase 5.5: Consensus Integration (--multi only)

Skip if `--multi` is not active or no external model results were obtained.

Apply consensus integration per `skills/core/routing/references/consensus-protocol.md`:

| Mode | Consensus Protocol | Notes |
|------|-------------------|-------|
| A, B, D | Mode B — per-criterion majority/unanimous rule | Standard scoring consensus |
| C | Mode B applied separately to before/after scores, then verdict consensus | See consensus-protocol.md Before/After Consensus |

With `--unanimous`: apply the single-round deliberative consensus flow from `consensus-protocol.md` Unanimous (Quality Path).
Use fresh Codex Advocate, Devil's Advocate, and Judge sessions.
Blind the Judge to model names and raw numeric scores.
If the Judge agrees with brief A or brief B and no escalation trigger fires, use the mapped score or verdict.
If any escalation trigger fires, escalate to the user with both briefs.

Calculate and store: `agreement_rate`, `consensus_scores`, `consensus_total`, `bias_flags`, `divergent_criteria`. For Mode C additionally: `verdict_consensus`, `verdict_agreement`, `regression_consensus`.

Record model details in `multi_model.models` as structured objects:

```json
"models": [
  {"name": "claude", "model_id": "<current-claude-model>"},
  {"name": "codex", "model_id": "gpt-5.4", "effort": "xhigh"}
]
```

Use the actual Claude model ID (e.g., `claude-opus-4-6`) and the Codex model/effort from the codex-relay.sh call above.

## Phase 6: Report

### Structural Validation Section (Mode A/B, conditional)

When Phase 2.5 ran and produced results, prepend to the mode report:

```markdown
### Structural Validation

**Result**: {PASS|FAIL} ({n} errors, {m} warnings)

{If FAIL — error table:}
| # | Check | Expected | Actual | Fix |
|---|-------|----------|--------|-----|
| 1 | {check name} | {expected} | {actual} | {fix instruction} |

{If warnings — warning table:}
| # | Check | Issue | Recommendation |
|---|-------|-------|----------------|
| 1 | {check name} | {issue} | {suggestion} |
```

Omit this section entirely when Phase 2.5 was skipped (Mode C/D) or when validation passed with 0 warnings.

### Report Assembly Matrix

Use the matrix below instead of separate prose branches.

| Mode | Single-Model Body | Multi-Model Body | Required Focus |
|------|-------------------|-----------------|----------------|
| A | `### Score Summary`, `### Zero-Score Criteria`, and `### Next Actions` | Base wrapper from `templates/core/multi-model-report.md` plus the same three sections | Highlight the weakest criteria and the best next `/evolve` or `/evaluate --output` follow-up |
| B | `## Module Evaluation Summary: {module}` with component table, module average, weakest component, and `### Next Actions` | The same summary table plus `Agreement Rate` and `Bias Alerts` columns | Keep the output compact and ordered by weakest component first |
| C | `### Score Comparison`, `### Regression Analysis`, `### Verdict`, and `### Next Actions` | Base wrapper plus `### Verdict Consensus` before `### Regression Analysis` | Surface any 1→0 regression before the overall verdict |
| D | `### Output Score`, `### Criterion Breakdown`, optional `### Dual-Axis Summary`, and `### Next Actions` | Base wrapper plus the same sections | Compare static promise versus dynamic delivery when a recent static evaluation exists |

Prepend the conditional `### Structural Validation` section only for Mode A or Mode B when Phase 2.5 produced warnings or errors.
Populate wording from the authoritative payloads produced in Phases 3, 5.5, 6.5, and 7 instead of restating mode-specific prose.

## Phase 6.5: Persist Results (`--save` or `--compare`)

Skip if neither `--save` nor `--compare` is active.

Pipe the normalized consensus result(s) to `eval-save.sh` and capture stdout as `saved_result_path`:

```bash
saved_result_path="$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/eval-save.sh <module> .tmp/{SESSION_ID}_consensus.json --models claude-opus-4-6 gpt-5.4:xhigh)"
```

Use `auto` for `<module>` whenever the run should infer the persistence bucket from the component path.
Pass every normalized consensus file when the run produced more than one persisted artifact.
Add `--criteria-version <ver>` when the rubric version is explicitly pinned for the run.
`eval-save.sh` restores canonical criterion names, computes `content_hash` and `eval_hash`, infers the module when needed, saves via `regression.sh save`, triggers `hook-eval-result.sh`, ingests through `learning-ingest-eval.sh`, and prints the saved file path.
Use `saved_result_path` in Phase 7 comparisons and Phase 8 report handoff.

## Phase 7: Regression Comparison (`--compare`)

Skip if `--compare` is not active.

### Step 1: Load Baseline

If `--compare <path>` specifies an explicit baseline path, use that file.

Otherwise, run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh latest <module>
```

- If exit code 2 (no previous results): log "No previous results found for '{module}'. Skipping comparison." and end Phase 7
- If exit code 0: Read the returned file path via Read tool

### Step 2: Compare

Load the baseline JSON and current JSON. Compare at 3 levels following the methodology in `skills/core/evaluation/references/regression-format.md`:

Before score comparison, compare `criteria_version` between baseline and current.
If they differ, warn: "⚠ Baseline used criteria version {old}, current is {new}. Score changes may reflect criteria changes, not component changes."

**Run-level**: Compare total, average level, level distribution.

**Component-level**: For each component present in both runs:

- Compare level, per-tier scores
- Check `content_hash` — unchanged content + changed score = evaluator variance

**Criterion-level**: Only for regressions (score dropped 1→0):

- Show criterion id, name, reasoning from both runs
- Label evaluator variance if content_hash unchanged

**Structural changes**: Components added or removed between runs.

### Step 3: Output Regression Report

Present the comparison in the format specified in `regression-format.md` (Comparison Report Format section).

Highlight:

- Regressions (level or score drops) with specific criteria details
- Evaluator variance warnings
- Structural changes (new/removed components)
- Overall trend (improving / stable / degrading)

## Phase 8: Actionable Handoff

Apply this phase at the end of Mode A reports only.
Skip it when `saved_result_path` is unavailable.

- If the component has any 0-score criteria or the overall level is below 4:
  - Print: `/evolve <component-path> --eval <saved_result_path> --focus <weakest-criterion-id>`
  - Ask once: "Proceed with evolve?"
- If the component is Level 4 and the remaining improvements are only [MED] or [LOW]:
  - Print: `/evolve <component-path> --eval <saved_result_path>`

This is a suggestion only.
Do not auto-execute `/evolve`.

## Rules

- Evaluator agent is read-only — never modifies files
- Require specific evidence for all scores — "good/bad" alone is insufficient
- If module scan finds 10+ components, suggest narrowing scope to user
- Before/After with mismatched types is an error (incomparable)
- Output mode requires `--output <output-path>` — no test set fallback
- **Prompt Relay integrity** — Sections 2-3 of the relay prompt must be verbatim file content, never summarized or annotated by Claude
- **Self-enhancement bias flags are advisory** — they do not change scores, only alert the user
- **Settings requirement** — `--multi` requires `Bash(codex *)` pattern in `settings.json` allow list
- **Evaluator variance** — content_hash unchanged + score changed = evaluator inconsistency, not regression. Label accordingly
- **`--save`/`--compare` compatibility** — works with Mode A (single) and Mode B (module scan). Mode C with `--save` saves the evaluation but comparison is not yet supported. Mode D with `--save` includes the `output_evaluation` field in the persisted JSON
