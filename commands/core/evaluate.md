---
description: Evaluate plugin component quality — static definition scoring, output quality assessment, or before/after comparison
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
| `--unanimous` | off | Require unanimous agreement across models (only with multi-model) |
| `--sequential` | off | Disable batch parallelism in Mode B (evaluate components one at a time) |

If `--unanimous` without multi-model active: warn "⚠ --unanimous requires multi-model. Ignoring." and continue single-model.

### CLI Availability Check (auto-detect)

Check `codex` CLI availability and version via Bash. Store: `codex_available` (bool + version), `failure_count` ({ codex: 0 }).

- If `--single` specified: skip check, use single-model
- Otherwise: auto-detect CLIs

### Session Temp Directory

Always generate a short session ID (first segment of UUID) and ensure `.tmp/` directory exists. All temp files use the pattern `.tmp/{SESSION_ID}_{purpose}`. Files are cleaned up at the end of the command run (see Rules). Both Claude and Codex evaluation results are persisted here — Claude agents write JSON to `.tmp/{SESSION_ID}_{idx}_claude_eval.json`, Codex results land in `.tmp/{SESSION_ID}_{idx}_codex_eval.json`.

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
3. Verify type is valid (agent, skill, command, hook, claudemd)

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
   ${CLAUDE_PLUGIN_ROOT}/scripts/invoke-model.sh codex gpt-5.4 .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh
   ```

   **Timeout**: 600 seconds. Store the background task ID for later collection.

2. **Claude evaluator**: Launch via Agent tool (subagent_type: `ouroboros:core:evaluator`).
   - **Instructions** (all modes): "Evaluate `{component_path}` ({type}). Read the component file and load `skills/core/evaluation/references/{type}-criteria.md`. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Write result as JSON to `.tmp/{SESSION_ID}_{idx}_claude_eval.json`."
   - Agent always writes JSON to file and returns compact summary only: `"{component_path}: Level {N}, F:{a}/{b} Q:{a}/{b} E:{a}/{b} → {output_path}"`. Main context reads JSON files for Phase 6 reporting and consensus
   - **Mode A/D**: foreground
   - **Mode B**: `run_in_background: true`

For Mode C: run both evaluations for before and after versions (4 evaluations: 2 Claude sequential + 2 Codex background).

#### Mode B: File-Based Parallel Execution

Launch all evaluations as background tasks with file-based result collection. This protects the main context window from 10+ component evaluation outputs.

- **Codex**: All relay prompts built upfront → background Bash in waves of 6 → results in `.tmp/{SESSION_ID}_{idx}_codex_eval.json`
- **Claude**: All evaluator agents launched as background Agent with `run_in_background: true` → results in `.tmp/{SESSION_ID}_{idx}_claude_eval.json`
- **Main context**: only handles launch, collection, consensus, and reporting

Temp files use component index: `.tmp/{SESSION_ID}_{idx}_relay.txt`, `.tmp/{SESSION_ID}_{idx}_codex_eval.json`, `.tmp/{SESSION_ID}_{idx}_claude_eval.json`. All evaluations are read-only — no shared state between components.

Apply circuit breaker per `skills/core/routing/references/invocation-protocol.md` — 2 consecutive failures per model triggers skip for remainder.

When `--sequential` is set: fall back to one-at-a-time foreground processing. Results are stored and reported in Phase 2 discovery order regardless of completion order.

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

**LLM fallback** (exit code 1): Apply the LLM extraction strategy from `skills/core/routing/references/parsing-strategy.md` — read raw output, extract score patterns, construct partial result. Partial scores are valid in consensus; missing criteria are marked `"-"` in the report.

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

With `--unanimous`: apply convergence prompts per consensus-protocol.md Unanimous (Quality Path). Maximum 2 iterations per criterion, then escalate to user.

Calculate and store: `agreement_rate`, `consensus_scores`, `consensus_total`, `bias_flags`, `divergent_criteria`. For Mode C additionally: `verdict_consensus`, `verdict_agreement`, `regression_consensus`.

Record model details in `multi_model.models` as structured objects:

```json
"models": [
  {"name": "claude", "model_id": "<current-claude-model>"},
  {"name": "codex", "model_id": "gpt-5.4", "effort": "xhigh"}
]
```

Use the actual Claude model ID (e.g., `claude-opus-4-6`) and the Codex model/effort from the invoke-model.sh call above.

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

### Single-Model Reports (default, no --multi)

#### Mode A: Single Static

Present evaluator's report directly. Highlight:

- Overall Level and Score
- Specific improvement directions for 0-score criteria
- Context-aware next actions:
  - If Level < 4 with 0-score criteria: "`/evolve {target_path} --focus {lowest_criterion_id}` — improve the weakest area"
  - If Level = 4: "`/evaluate --output <output-path> {target_path}` — verify output quality matches definition"
  - Always: "`/evaluate {target_path} --multi` — cross-validate with external model"

#### Mode B: Module Scan

Aggregate all component reports into summary:

```markdown
## Module Evaluation Summary: {module}

| Component | Type | Level | Score | Key Issue |
|-----------|------|-------|-------|-----------|
| {name} | {type} | {1-4} | {n}/5 | {most important improvement} |

**Module Average**: {avg}/5 (Level {avg_level})
**Weakest Component**: {name} — {reason}

### Next Actions
- `/evolve {weakest_component_path}` — improve the weakest component
- `/evaluate {module} --multi --compare` — track improvement over baseline
```

#### Mode C: Before/After

Present both evaluations + pairwise verdict:

- Side-by-side score comparison
- Regression warnings (if any criteria dropped)
- Verdict: improved / degraded / lateral
- Context-aware next actions:
  - If improved: "`/evaluate {after_path} --save` — persist the improvement"
  - If degraded: "Review regressions above. `/evolve {after_path} --focus {regressed_criteria}` — fix regressions"
  - If lateral: "No change detected. Consider `/evolve {after_path}` with different focus areas"

#### Mode D: Output

Present output evaluation report:

- Score: {n}/5 (C1-C5 flat scoring)
- Per-criterion breakdown with reasoning

If the component has a recent static evaluation (from `--save` or `dev/evaluations/`), present dual-axis summary:

**Dual-Axis Summary:**

| Axis | Score | Level | Top Issue |
|------|-------|-------|-----------|
| Static (definition) | F:{n}/{max} Q:{n}/{max} E:{n}/{max} | Level {1-4} | {top improvement} |
| Dynamic (output) | {n}/5 | — | {top criterion failure} |

**Gap Analysis**: If static >> dynamic, the definition promises more than it delivers — focus on improving execution. If dynamic >> static, the component works well despite a rough definition — clean up the definition. Suggest: "Improve the lower axis first."

- Context-aware next actions:
  - If static >> dynamic: "`/evolve {target_path}` — improve execution quality to match the strong definition"
  - If dynamic >> static: "`/evolve {target_path} --focus F` — clean up the definition to match the good output"
  - Always: "`/evaluate --output <new-output-path> {target_path}` — re-evaluate after changes"

### Multi-Model Reports (--multi active)

Use the base report structure from `templates/core/multi-model-report.md`. Mode-specific additions:

| Mode | Base Report | Additional Sections |
|------|-------------|-------------------|
| A: Single Static | Full base template | — |
| B: Module Scan | Summary table (same as single-model Mode B) with Agreement Rate and Bias Alerts columns | No base template — compact summary only |
| C: Before/After | Base + Verdict Consensus table (prepended) + Regression Analysis (appended) | See template Mode C section |
| D: Output | Base + Dual-Axis Summary (if static evaluation available, same gap analysis as single-model Mode D) | See template Mode D section |

## Phase 6.5: Persist Results (`--save` or `--compare`)

Skip if neither `--save` nor `--compare` is active.

### Step 1: Extract Structured Data

For each evaluated component, extract from the evaluator's markdown report:

- **Level**: Overall level (1-4) from the "Overall Level" line
- **Scores**: Per-tier scores — F: [achieved, max], Q: [achieved, max], E: [achieved, max]. Skipped tiers are omitted
- **Criteria**: Per-criterion array — id, name, score (0/1), reasoning
- **Strengths**: Array of positive observations
- **Improvements**: Array of { priority, criterion, description }

Claude Code parses the evaluator's markdown output directly — no evaluator agent changes needed.

### Step 2: Collect Hashes

For each component, compute two hashes:

```bash
# Content hash — tracks file changes only
${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh hash <component-path>

# Eval hash — tracks file + all judge models used
# Single model:
${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh eval-hash <component-path> claude-opus-4-6
# Multi model:
${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh eval-hash <component-path> claude-opus-4-6 gpt-5.4:xhigh
```

Store the returned values as `content_hash` and `eval_hash` respectively. Model specs are sorted internally, so argument order does not matter.

### Step 3: Build JSON Result

Construct the result object following the schema in `skills/core/evaluation/references/regression-format.md`:

- `version`: `"1"`
- `run_id`: Optional. Populated from the saved file path after `regression.sh save` returns (extract NNN from the filename)
- `timestamp`: Current ISO 8601 with timezone
- `git_sha`: Short SHA from `git rev-parse --short HEAD`
- `module`: Module name (for Mode B) or `"single"` (for Mode A)
- `components`: Array of per-component results
- `summary`: `{ total, level_distribution: { "1": n, "2": n, "3": n, "4": n } }`

### Step 4: Save

Pipe the JSON to:

```bash
echo '<json>' | ${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh save <module>
```

Log: "Results saved to {returned-path}"

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
