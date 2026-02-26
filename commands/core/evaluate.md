---
description: Evaluate plugin component quality — static definition scoring, output quality assessment, or before/after comparison
argument-hint: <file-path|module-name> [--output <output-path>] [--before <path>] [--after <path>] [--multi [--unanimous]] [--save] [--compare [<baseline>]]
allowed-tools: Read, Glob, Grep, Task, Bash
---

# Evaluate — Plugin Component Quality Assessment

Assess the quality of plugin components using structured criteria and the evaluator agent.

Target: $ARGUMENTS

## Agents & Tools Used

| Phase | Agent/Tool | Role |
|-------|-----------|------|
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

| Flag | Effect |
|------|--------|
| `--save` | Persist evaluation results to `dev/evaluations/` as JSON |
| `--compare [<baseline>]` | Compare with previous run (implies `--save`). Optional baseline path |

If `--compare` is used, `--save` is automatically enabled.

### Multi-Model Flags

| Flag | Effect |
|------|--------|
| `--multi` | Enable multi-model evaluation (Claude + external models) |
| `--unanimous` | Require unanimous agreement across models (only with `--multi`) |

If `--unanimous` without `--multi`: warn "⚠ --unanimous requires --multi. Ignoring." and continue single-model.

### CLI Availability Check (only when `--multi`)

Check `codex` and `gemini` CLI availability and versions via Bash. Store: `codex_available` (bool + version), `gemini_available` (bool + version), `failure_count` ({ codex: 0, gemini: 0 }).

### Session Temp Directory (only when `--multi`)

Generate a short session ID (first segment of UUID) and ensure `.tmp/` directory exists. All temp files use the pattern `.tmp/{SESSION_ID}_{purpose}.txt`. Files are cleaned up at the end of the command run (see Rules).

Log availability:

- Both: "Multi-model: Claude + Codex v{ver} + Gemini v{ver}"
- Codex only: "Multi-model: Claude + Codex v{ver} (Gemini unavailable)"
- Gemini only: "Multi-model: Claude + Gemini v{ver} (Codex unavailable)"
- Neither: "No external CLIs found. Proceeding single-model." → disable `--multi`

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

## Phase 3: Evaluation (Parallel when --multi)

This phase runs Claude evaluation and external model evaluation. When `--multi` is active, both run in parallel for ~50% wall-clock reduction. See `skills/core/routing/references/parallel-execution-pattern.md` for the general pattern.

### Step 1: Build Relay Prompt (--multi only, before fan-out)

Skip if `--multi` is not active or no external CLIs are available.

Construct a 4-section prompt following the Prompt Relay pattern (`skills/core/routing/references/invocation-protocol.md`).

**Critical**: Sections 2-3 are verbatim file content. Claude must NOT summarize, paraphrase, or add commentary to these sections.

#### Mode A/B: Static Evaluation Prompt

**Section 1 — Role** (fixed template):

```text
You are an independent evaluator. Your task is to assess the quality of a plugin component using the criteria provided below. Score each criterion independently with detailed reasoning. Do not assume any prior context — evaluate based solely on the content and criteria given.
```

**Section 2 — Content**: Raw target file content (verbatim from disk, no summarization).

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema A from `skills/core/routing/references/relay-response-schemas.md`.

Assemble: `{Section 1}\n\n{Section 2}\n\n{Section 3}\n\n{Section 4}`. Save to `.tmp/{SESSION_ID}_relay.txt`.

#### Mode C: Comparative Evaluation Prompt

**Section 1 — Role**: "You are an independent comparative evaluator..." (assess two versions, score independently, identify regressions, determine verdict).

**Section 2 — Content**: Both versions verbatim, separated by `=== BEFORE VERSION ===` and `=== AFTER VERSION ===` markers.

**Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema C from `skills/core/routing/references/relay-response-schemas.md`.

Assemble and save to `.tmp/{SESSION_ID}_relay.txt`.

#### Mode D: Output Evaluation Prompt

**Section 1 — Role**: "You are an independent output quality evaluator..." (assess actual output using output criteria).

**Section 2 — Content**: Component definition + collected output verbatim, separated by `=== COMPONENT DEFINITION ===` and `=== COLLECTED OUTPUT ===` markers.

**Section 3 — Criteria**: Raw output criteria reference content (`skills/core/evaluation/references/{type}-output-criteria.md`, verbatim).

**Section 4 — Response Format**: Use Schema A from `relay-response-schemas.md` (same 5-criterion flat scoring).

Assemble and save to `.tmp/{SESSION_ID}_relay.txt`.

### Step 2: Fan-Out — Parallel Execution

**Model selection** (from routing table — DR-035):

- Codex: `gpt-5.3-codex` with `xhigh` reasoning effort (consistently strict on borderline criteria, 2.6× faster than gpt-5.2 xhigh, no coding-model bias on non-code evaluation)
- Gemini: excluded until Gemini 3.1 CLI support (current models lack discrimination — factually incorrect reasoning on E1/E2)

#### When `--multi` is active (parallel):

Launch both evaluations simultaneously:

1. **Background**: Start external model via Bash with `run_in_background: true`:

   ```bash
   ${CLAUDE_PLUGIN_ROOT}/scripts/invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh
   ```

   **Timeout**: 600 seconds. Store the background task ID for later collection.

2. **Foreground**: Launch Claude **evaluator** agent via Task tool (runs concurrently while Codex processes):
   - **Input**: Component file content + component type
   - **Instructions**: "Load `skills/core/evaluation/references/{type}-criteria.md`. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Return structured evaluation report."
   - **Expected output**: Evaluation report with criteria table, strengths, improvements

For Mode B: run both evaluations per component sequentially across components (parallel within each component).

For Mode C: run both evaluations for before and after versions (4 evaluations: 2 Claude sequential + 2 Codex background).

#### When `--multi` is not active (sequential, single-model):

Launch the **evaluator** agent via Task tool only:

- **Input**: Component file content + component type
- **Instructions**: "Load `skills/core/evaluation/references/{type}-criteria.md`. Apply tiered criteria (F→Q→E) with CoT-first scoring and severity gate. Return structured evaluation report."
- **Expected output**: Evaluation report with criteria table, strengths, improvements

For Mode B: launch evaluator for each component (sequential — one at a time for reasoning quality).

For Mode C: launch evaluator twice (before version, then after version).

#### Evaluator Recovery (all modes, single-model and multi-model Claude path)

If the evaluator agent fails (timeout, error, or unparseable output):

| Failure | Action |
|---------|--------|
| Agent timeout/error | Retry once with simplified instructions ("Score each criterion 0 or 1 with brief reasoning"). If retry fails: "Evaluation failed for {component}. Check evaluator agent definition or try again." |
| Malformed report (missing criteria table, partial output) | Extract partial scores from available output — look for criterion IDs, score patterns, reasoning sections. Report partial result: "Partial evaluation ({n}/{total} criteria recovered)." |
| Mode B component failure | Skip failed component, continue remaining. Note in summary: "{component}: evaluation failed — excluded from module average." |

### Step 3: Fan-In — Collect Results (--multi only)

After Claude evaluator completes (foreground), collect the background Codex result.

Check the background task output. Handle by exit code:

| Exit | Meaning | Action |
|------|---------|--------|
| 0 | Parse success | Read `.tmp/{SESSION_ID}_{model}_eval.json` — use directly |
| 1 | Parse failed | **LLM fallback**: Read `.tmp/{SESSION_ID}_{model}_eval.json.raw`, extract scores intelligently (see below) |
| 2 | CLI error | Skip model, log error from stderr |
| 124 | Timeout | Skip model, log: "{model}: timed out after 600s. Skipping." |

**LLM fallback** (exit code 1):

1. Read the raw output file via Read tool
2. Identify the model's response section (skip metadata, logs, error traces)
3. Extract evaluation scores — look for `"C1"`, `"score"`, `"reasoning"` patterns, even in prose
4. Construct a partial result with whatever is recoverable
5. Log: "{model}: partial result ({n} criteria recovered via LLM fallback)"

Partial scores are valid in consensus — missing criteria are marked `"-"` in the report.

For parsing details, see `skills/core/routing/references/parsing-strategy.md`.

### Step 4: Circuit Breaker (Mode B)

If a CLI fails (parse error, timeout, non-zero exit, empty response):

- Increment `failure_count[model]`
- If `failure_count[model] >= 2`: skip all remaining invocations for that model in this run
- Log: "{model} CLI failed {n} times (v{version}). Skipping for remainder."

For Mode B: apply circuit breaker across components within the parallel execution loop.

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

## Phase 6: Report

### Single-Model Reports (default, no --multi)

#### Mode A: Single Static

Present evaluator's report directly. Highlight:

- Overall Level and Score
- Specific improvement directions for 0-score criteria
- "Run `/evaluate` again after improvements to verify changes."

#### Mode B: Module Scan

Aggregate all component reports into summary:

```markdown
## Module Evaluation Summary: {module}

| Component | Type | Level | Score | Key Issue |
|-----------|------|-------|-------|-----------|
| {name} | {type} | {1-4} | {n}/5 | {most important improvement} |

**Module Average**: {avg}/5 (Level {avg_level})
**Weakest Component**: {name} — {reason}
**Recommendation**: {module-level improvement suggestion}
```

#### Mode C: Before/After

Present both evaluations + pairwise verdict:

- Side-by-side score comparison
- Regression warnings (if any criteria dropped)
- Verdict: improved / degraded / lateral
- "Use this result for `/evolve` validation."

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

- "Run `/evaluate --output <output-path> {path}` after changes to track improvement."

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

### Step 2: Collect Content Hashes

For each component, run:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/regression.sh hash <component-path>
```

Store the returned `sha256:{hex}` as `content_hash`.

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
- **Multi-model is additive** — Claude evaluation always runs regardless of external model availability
- **Parallel execution** — when `--multi` is active, Codex runs in background (Bash `run_in_background`) while Claude evaluator runs in foreground (Task). Relay prompt is built from Phase 2 output only — no dependency on Claude's result. See `skills/core/routing/references/parallel-execution-pattern.md`
- **Prompt Relay integrity** — Sections 2-3 of the relay prompt must be verbatim file content, never summarized or annotated by Claude
- **Circuit breaker** — 2 consecutive failures per CLI → skip that model for the rest of the command run. For single-invocation modes (A, C, D), each model gets one chance; circuit breaker primarily applies in Mode B (multiple components)
- **Self-enhancement bias flags are advisory** — they do not change scores, only alert the user
- **Settings requirement** — `--multi` requires `Bash(codex *)` and/or `Bash(gemini *)` patterns in `settings.json` allow list
- **Temp file lifecycle** — all temp files go to `.tmp/{SESSION_ID}_*` within the workspace (not `/tmp`). Clean up at command end: `bash scripts/session.sh cleanup {SESSION_ID}`. The `.tmp/` directory itself persists (gitignored)
- **`--save` result format** — JSON schema defined in `skills/core/evaluation/references/regression-format.md`. One file per run
- **`--compare` implies `--save`** — comparison always produces a new saved result alongside the regression report
- **Evaluator variance** — content_hash unchanged + score changed = evaluator inconsistency, not regression. Label accordingly
- **`--save`/`--compare` compatibility** — works with Mode A (single) and Mode B (module scan). Mode C with `--save` saves the evaluation but comparison is not yet supported. Mode D with `--save` includes the `output_evaluation` field in the persisted JSON
