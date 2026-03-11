---
description: Create a new plugin module or add a component to an existing module — design, generate, validate quality, and scaffold into the codebase
argument-hint: <module-name> "<description>" | <module>/<component-name> "<description>" [--type <command|agent|skill|template>] [--reference <module>] [--single]
allowed-tools: Read, Glob, Grep, Write, Bash, Task
---

# Generate — Module & Component Creation

Create a new plugin module (Mode A) or add a component to an existing module (Mode B), using knowledge base patterns and reference structures.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | generator + Bash background (--multi) | Module spec (Procedure 1, Mode A) or component spec (Procedure 3, Mode B); parallel with Codex when --multi |
| 5.5 | — (command) | Structural validation + inter-component consistency + auto-fix |
| 6 | evaluator, generator + Bash background (--multi) | Quality gate — validate + retry. See [procedure reference](../../skills/core/validation/references/quality-gate-procedure.md) |

## Phase 1: Parse Input

Determine generation mode from $ARGUMENTS (DR-025):

| Input pattern | Condition | Mode | Action |
|---------------|-----------|------|--------|
| `<module-name> "desc"` | Module doesn't exist | **Mode A**: Module Generation | Create full module |
| `<module>/<name> "desc"` | Module exists | **Mode B**: Component Generation | Add single component to existing module |

Extract arguments from $ARGUMENTS:

| Argument | Required | Description |
|----------|----------|-------------|
| `target` | Yes | Module name (`research`) or component path (`core/absorb`) |
| `description` | Yes | Quoted description of domain/component purpose |
| `--type` | Mode B only | Component type: `command`, `agent`, `skill`, `template` (default: inferred from description) |
| `--capabilities` | Mode A only | Comma-separated list of desired capabilities |
| `--reference` | No | Reference module to pattern-match (default: `core`) |
| `--single` | No | Force single-model mode (skip external CLIs). By default, multi-model is auto-detected — if codex CLI is installed, Codex runs in parallel for generation (Phase 3) and evaluation (Phase 6) |

### Mode Detection

1. **Parse target**: Check if `target` contains `/`
   - Contains `/` → split into `{module}` + `{component-name}` → candidate Mode B
   - No `/` → candidate Mode A

2. **Validate mode**:

   **Mode A candidate**:
   - Scan `commands/{module-name}/`, `agents/{module-name}/`, `skills/{module-name}/`, `templates/{module-name}/`
   - If none exist → **Mode A confirmed**
   - If any exist → Error: "Module '{module-name}' already exists. Use `/evolve {module-name}` to improve it, or `/generate {module-name}/<component> \"desc\"` to add a component."
   - Abort

   **Mode B candidate**:
   - Scan `commands/{module}/`, `agents/{module}/`, `skills/{module}/`, `templates/{module}/`
   - If module exists → check component doesn't exist yet (scan all type directories for `{component-name}.md`)
     - Component doesn't exist → **Mode B confirmed**
     - Component exists → Error: "Component '{module}/{component-name}' already exists. Use `/evolve {module}/{component-name}` to improve it."
     - Abort
   - If module doesn't exist → Error: "Module '{module}' doesn't exist. Use `/generate {module} \"desc\"` to create it first."
   - Abort

3. **Description**: Must be provided. If empty → Error with usage example

4. **Type determination (Mode B only)**:
   - If `--type` provided → use it
   - Else infer from description keywords: "command that..." → command, "agent for..." → agent, "skill about..." → skill, "template for..." → template
   - If ambiguous → default to `command`

Log parsed input, detected mode, and proceed.

## Phase 2: Context Gathering

Collect all inputs the generator agent needs.

### 2a: Target Analysis + Knowledge Base

1. **Target module analysis:**

   > **Mode B only:** Scan and read all existing components of the target module to extract patterns, conventions, and inter-component references: `Glob: commands/{module}/*.md`, `agents/{module}/*.md`, `skills/{module}/**/*.md`, `templates/{module}/*.md`

2. **Knowledge base scan** (both modes):
   - `Glob: docs/specs/knowledge/*.md` — list all knowledge entries
   - Read frontmatter of each entry (title, tags)
   - Identify entries relevant to the target domain by tag and title matching
   - Read full content of relevant entries (up to 5 most relevant)

### 2b: Reference Patterns

Gather structural references for generation:

> **Mode A:** Scan the reference module (default: `core/`): `commands/{reference}/*.md`, `agents/{reference}/*.md`, `skills/{reference}/*.md`, `templates/{reference}/*.md`. Read 1-2 representative files from each component type to capture patterns.

> **Mode B:** Identify 1-2 existing components of the **same type** as the target component (prefer same module first, then `core/`). Read them fully as structural references.

### 2c: Evaluation Criteria

Read the criteria reference for the target component type(s):

- **Mode A**: Read all applicable: `skills/core/evaluation/references/{command,agent,skill}-criteria.md`
- **Mode B**: Read only the target type: `skills/core/evaluation/references/{type}-criteria.md`

### 2d: Scaffold Template (Mode A only)

Read `templates/core/module-scaffold.md` for structure conventions.

(Mode B skips this — the existing module IS the scaffold.)

## Phase 3: Generation

> Agent: **generator** + Bash background (when `--multi`)

Generation runs Claude generator for deep knowledge-base-integrated content creation. When `--multi` is active, Codex generator runs in parallel for a fresh perspective — cherry-pick mode combines the best output from both. See `skills/core/routing/references/parallel-execution-pattern.md`.

**IMPORTANT**: The generator agent is read-only. All file writes happen in Phase 5 by the command orchestrator — the generator outputs text content only.

### When `--multi` is active (parallel):

1. **Build generator relay prompt**: Construct from Phase 2 context + generation instructions. Save to `.tmp/{SESSION_ID}_generator_relay.txt`

   **Section 1 — Role** (fixed template):

   ```text
   You are an independent plugin component generator. Your task is to design and generate plugin components based on the specification, reference patterns, and criteria provided below. Produce complete, production-ready component content. Do not assume any prior context — generate based solely on the inputs given.
   ```

   **Section 2 — Content**: All Phase 2 context verbatim:

   | Mode | Content |
   |------|---------|
   | A | Module spec (name, description, capabilities) + reference module patterns + relevant knowledge entries + scaffold template |
   | B | Component spec (module, name, description, type) + existing module components + same-type reference components + relevant knowledge entries |

   **Section 3 — Criteria**: Raw criteria reference content (`skills/core/evaluation/references/{type}-criteria.md`, verbatim). For Mode A, include all applicable criteria (command, agent, skill).

   **Section 4 — Instructions + Response Format**:

   Mode A:

   ```text
   Generate a complete plugin module with the following structure. Analyze the reference patterns, then design and generate all component file contents.

   Respond ONLY with a JSON object (no markdown, no explanation outside JSON):
   {
     "manifest": [
       { "path": "commands/{module}/{name}.md", "type": "command", "description": "what this component does" }
     ],
     "rationale": "architectural decisions and design reasoning",
     "files": [
       { "path": "commands/{module}/{name}.md", "content": "full file content" }
     ],
     "readme": "module README content"
   }
   ```

   Mode B:

   ```text
   Generate a single plugin component that integrates seamlessly with the existing module. Analyze the existing module patterns and reference components, then generate the component content.

   Respond ONLY with a JSON object (no markdown, no explanation outside JSON):
   {
     "path": "{type-directory}/{module}/{name}.md",
     "type": "command|agent|skill|template",
     "rationale": "design decisions and integration reasoning",
     "content": "full file content"
   }
   ```

2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.4 .tmp/{SESSION_ID}_generator_relay.txt .tmp/{SESSION_ID}_codex_gen.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **generator** agent (via Task tool) with all Phase 2 context

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both generation outputs and build the final component content:
   - Use Claude's output as the primary structure (Claude has full knowledge base context)
   - Cherry-pick from Codex output: sections with stronger criteria coverage, novel patterns, or better structural completeness
   - If Codex generated content that addresses criteria Claude missed, incorporate it
   - If Codex generation failed or is partial, proceed with Claude-only output
   - The merged content feeds into Phase 5 (Write Files) — the orchestrator writes the final files

### When `--multi` is not active (single-model):

Launch the **generator** agent via Task tool with all context gathered in Phase 2:

| | Mode A (Procedure 1) | Mode B (Procedure 3) |
|---|---|---|
| **Input** | Module spec (name, domain, capabilities) + reference module patterns + knowledge entries + criteria + scaffold template | Component spec (module, name, description, type) + existing module components + same-type reference components + knowledge entries + criteria |
| **Instructions** | "Perform Module Generation (Procedure 1). Analyze reference patterns, design module architecture, generate all component file contents. Output a complete Module Spec with manifest, rationale, and file contents." | "Perform Component Generation (Procedure 3). Analyze existing module patterns, generate a single component that integrates seamlessly. Output a Component Spec with path, rationale, and file content." |
| **Expected output** | Module Spec (manifest + rationale + all file contents) | Component Spec (path + rationale + file content) |

Parse the output:

- **Mode A**: Extract component manifest, each file's content, and Module README content
- **Mode B**: Extract the file path and file content

## Phase 4: Worktree Setup

### Session Recovery

Before creating a new worktree, check for existing generate worktrees:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status
```

If the JSON output contains entries with `"operation": "generate"`:

1. Report to user: "Found existing generate worktree: `{path}` (branch: `{branch}`, {commits_ahead} commits ahead, {dirty_files} dirty files)"
2. Present options:
   - **Resume**: Continue working in the existing worktree (skip worktree creation, use existing `$WORKTREE` path)
   - **Discard**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and proceed with fresh worktree
   - **Merge**: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "Generate: resume merge"` and proceed with fresh worktree
3. Wait for user choice before proceeding

Also run prune to clean up stale worktrees silently:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune
```

### Create Worktree

Create an isolated worktree for the generation target:

1. Derive slug: Mode A → `{module-name}`, Mode B → `{module}-{component-name}`
2. Create worktree:

   ```bash
   WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create generate {slug})
   ```

   The script handles branch conflicts (prior aborted generation) by appending timestamps automatically.

## Phase 5: Write Files in Worktree

### Mode A: Full Module

For each component in the manifest:

1. Scaffold directories for all component paths:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh scaffold "$WORKTREE" {component-path-1} {component-path-2} ...
   ```

2. Write each component file using the Write tool:
   - `$WORKTREE/{component-path}`

3. Write the Module README:
   - `$WORKTREE/commands/{module-name}/README.md`

Log: "{N} files written to worktree."

### Mode B: Single Component

1. Scaffold the target directory:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh scaffold "$WORKTREE" {component-path}
   ```

2. Write the single component file using the Write tool:
   - `$WORKTREE/{component-path}`

Log: "1 file written to worktree: {component-path}"

## Phase 5.5: Structural Validation & Auto-Fix

> Validates generated files for structural correctness and inter-component consistency before quality evaluation.

Apply the validation-methodology skill (`skills/core/validation/SKILL.md`) to each file written in Phase 5:

### Step 1: Type-Specific Validation

For each generated file in the worktree, run the validation workflow (Steps 1-4):

1. **Identify component type** from file location and frontmatter
2. **Run type-specific checks** per `skills/core/validation/references/frontmatter-and-fields.md`
3. **Run cross-cutting checks** per `skills/core/validation/references/naming-and-collision.md`
4. **Check common pitfalls** per `skills/core/validation/references/common-pitfalls.md`

### Step 2: Inter-Component Consistency

Validate references between generated components and existing module components:

| Check | Condition | Validation |
|-------|-----------|------------|
| Agent → Skill reference | Agent was generated or exists in module | Agent's Read instructions or procedure steps reference the correct skill path (`skills/{module}/{skill-name}.md`) |
| Command → Agent invocation | Command was generated or exists in module | Command's agent delegation uses the correct agent name matching `agents/{module}/{agent-name}.md` |
| Skill → Reference files | Skill was generated | All files listed in skill's `references/` directory paths exist (or are being generated in the same batch) |

For each failed check: log as error with the specific mismatched reference and expected value.

### Step 3: Auto-Fix Errors

For each error found (Steps 1-2), attempt automatic repair via Edit tool on the worktree file:

| Error Type | Auto-Fix Action |
|------------|----------------|
| Missing required frontmatter field | Add field with appropriate default value |
| Command name collision with built-in | Add `name: {module}:{command}` override in frontmatter |
| `../` path traversal | Replace with `./` relative path |
| Absolute filesystem path | Convert to relative path from plugin root |
| Missing `color` in agent | Add `color` field with contextually appropriate value |
| Incorrect agent/skill/reference path | Fix to correct path based on module structure |

Errors not in this table: log as warning, do not attempt fix.

### Step 4: Re-Validate (if fixes applied)

If any auto-fixes were applied in Step 3, re-run validation (Steps 1-2) on the fixed files to confirm resolution. Skip if no fixes were applied.

### Step 5: Report

- **PASS** (0 errors after fixes): Log "Structural validation: PASS ({n} auto-fixed, {m} warnings)" → proceed to Phase 6
- **FAIL** (residual errors): Log "⚠ Structural validation: {n} residual errors ({k} auto-fixed, {m} warnings). Proceeding to quality gate." → proceed to Phase 6. Store report for Phase 8

## Phase 6: Quality Validation

> Agent: **evaluator**, **generator** (on retry) + Bash background (when `--multi`)

Apply the [Quality Gate Procedure](../../skills/core/validation/references/quality-gate-procedure.md) to validate generated components. When `--multi` is active, Claude and Codex evaluate in parallel for consensus scoring. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

For each generated command, agent, and skill (templates excluded):

1. **Build relay prompt**: Construct Mode A static evaluation prompt from component content + criteria reference. Save to `.tmp/{SESSION_ID}_relay.txt`
2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.4 .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent (via Task tool) for static evaluation
3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3
4. **Consensus**: Apply per-criterion majority rule (same as `evaluate.md` Phase 5.5). Consensus score determines pass/fail

For Mode A (multiple components), process sequentially with circuit breaker across components (2 consecutive Codex failures → skip Codex for remaining components).

Quality gate threshold remains Level >= 2 (same as single-model). On failure, retry uses Claude generator only (Codex retry adds complexity with diminishing returns).

### When `--multi` is not active (single-model):

Evaluate each generated command, agent, and skill (templates excluded). Mode A evaluates all manifest components; Mode B evaluates the single component.

Apply the Quality Gate Procedure as defined.

Log quality validation results and proceed to Phase 7.

## Phase 7: Record Decision

Create a generate decision entry in the worktree using template from `templates/core/decision-generate.md`:

- **Path**: Mode A → `docs/decisions/{date}-generate-{module-name}.md`, Mode B → `docs/decisions/{date}-generate-{module}-{component-name}.md`
- **target-display**: Mode A → `{module-name}`, Mode B → `{module}/{component-name}`

Entry must include:

- type: generate, mode: module | component
- date, module, component (Mode B), type (Mode B), intent
- evaluation-summary (pass/fail counts and scores)
- Background (why the module/component was created)
- Decisions (architectural choices from generator rationale)
- Generated Components table (all files with types and scores)
- Verification results

Stage and commit in worktree:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "Generate {mode}: {target-display}"
```

## Phase 8: Review

Present the generation results for user review:

```markdown
## Generation Draft: {target-display}

**Branch**: ouroboros/generate/{target}
**Mode**: {Module Generation | Component Generation}
**Domain/Purpose**: {description}
**Capabilities**: {capability list} (Mode A) | **Type**: {type} (Mode B)

### Component Manifest

| # | Path | Type | Score |
|---|------|------|-------|
| 1 | `{component-path}` | {type} | {score}/5 |
| ... | ... | ... | ... |

**Quality**: {pass-count}/{total} passed (>= 3/5)

{If Phase 5.5 applied fixes or has residual errors:}
### Structural Validation

**Result**: {PASS|FAIL} ({n} auto-fixed, {k} residual errors, {m} warnings)

{If auto-fixed:}
| # | File | Fix Applied |
|---|------|-------------|
| 1 | `{path}` | {description of fix} |

{If residual errors:}
| # | File | Error | Manual Fix Needed |
|---|------|-------|-------------------|
| 1 | `{path}` | {error} | {fix instruction} |

### Diff

{git diff main...ouroboros/generate/{target} output}

### Decision Entry

- `docs/decisions/{date}-generate-{target-display}.md`

**Merge** into main, or **Discard** the draft?
```

### On Merge

1. Merge and cleanup:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "Generate {mode}: {target-display}"
   ```

2. Confirm: "'{target-display}' merged to main."

### On Discard

1. Discard: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`
2. Confirm: "Draft discarded. No changes made to main."

## Phase 9: Report

```markdown
## Generation Complete: {target-display}

**Mode**: {Module Generation | Component Generation}
**Domain/Purpose**: {description}
**Components**: {count} file(s) generated
**Quality**: {pass-count}/{total} passed (>= 3/5)

### Generated Files

| Path | Type | Score |
|------|------|-------|
| ... | ... | ... |

### Next Actions

Populate from Phase 6 quality gate results:
1. **Weakest component**: the component with the lowest score → populate `/evolve` path and `--focus`
2. **Knowledge gap**: if any component scored 0 on Q5 (Skill/Reference Integration) → suggest `/research` with domain topic

- Run `/evolve {lowest-score-path} --focus {lowest-criteria}` to improve the weakest component ({score}/{max} on {criterion-name})
- Run `/evaluate {module-name}` to re-assess all generated components
- {If knowledge gap detected:} Run `/research {domain-topic}` to build knowledge base coverage
- Decision entry: `docs/decisions/{date}-generate-{target-display}.md`
```

## Rules

- **Mode A**: Never generate into an existing module — use `/evolve` or Mode B instead
- **Mode B**: Never generate an existing component — use `/evolve` instead
- All file operations happen in the worktree — never write directly to main branch
- User reviews the final result (Phase 8) before merge — this is the only checkpoint
- Generator agent is read-only — this command handles all file I/O
- No WebFetch or WebSearch — generate uses only internal knowledge (DR-017)
- Quality gate is 3/5, not 5/5 — generate creates a "starting point" that `/evolve` improves
- Maximum 1 retry round per component on quality gate failure
- On any error during worktree operations, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting
