---
description: Create a new plugin module or add a component to an existing module — design, generate, validate quality, and scaffold into the codebase
argument-hint: <module-name> "<description>" | <module>/<component-name> "<description>" [--type <command|agent|skill|template>] [--reference <module>] [--multi]
allowed-tools: Read, Glob, Grep, Write, Bash, Task
---

# Generate — Module & Component Creation

Create a new plugin module (Mode A) or add a component to an existing module (Mode B), using knowledge base patterns and reference structures.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Mode | Role |
|-------|-------|------|------|
| 3 | generator + Bash background (--multi) | A | Module spec generation (Procedure 1), parallel with Codex generator when --multi |
| 3 | generator + Bash background (--multi) | B | Component spec generation (Procedure 3), parallel with Codex generator when --multi |
| 6 | evaluator, generator + Bash background (--multi) | A+B | Quality gate — validate + retry (parallel evaluator with Codex when --multi). See [procedure reference](../../skills/core/validation/references/quality-gate-procedure.md) |

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
| `--multi` | No | Enable multi-model generation in Phase 3 (Claude + Codex parallel generator, cherry-pick merge) and Phase 6 (Claude + Codex parallel evaluator, consensus) |

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

Collect all inputs the generator agent needs. Steps vary by mode.

### 2a: Module Context (Mode B) / Knowledge Base Scan (Mode A+B)

**Mode B — Existing Module Analysis:**

1. Scan the target module:
   - `Glob: commands/{module}/*.md`
   - `Glob: agents/{module}/*.md`
   - `Glob: skills/{module}/**/*.md`
   - `Glob: templates/{module}/*.md`
2. Read **all** existing components to extract patterns, conventions, and inter-component references

**Both modes — Knowledge Base Scan:**

1. `Glob: docs/knowledge/*.md` — list all knowledge entries
2. Read frontmatter of each entry (title, tags)
3. Identify entries relevant to the target domain by tag and title matching
4. Read full content of relevant entries (up to 5 most relevant)

### 2b: Reference Structure (Mode A) / Reference Components (Mode B)

**Mode A — Reference Module Structure:**

1. Scan the reference module (default: `core/`):
   - `Glob: commands/{reference}/*.md`
   - `Glob: agents/{reference}/*.md`
   - `Glob: skills/{reference}/*.md`
   - `Glob: templates/{reference}/*.md`
2. Read 1-2 representative files from each component type to capture patterns

**Mode B — Same-Type Reference Components:**

1. Identify 1-2 existing components of the **same type** as the target component
   - Prefer components from the same module first, then from `core/`
2. Read them fully as structural references for the generator

### 2c: Evaluation Criteria

Read the criteria reference for the target component type(s):

**Mode A:** Read all applicable criteria:

- `skills/core/evaluation/references/command-criteria.md`
- `skills/core/evaluation/references/agent-criteria.md`
- `skills/core/evaluation/references/skill-criteria.md`

**Mode B:** Read only the criteria for the target type:

- `skills/core/evaluation/references/{type}-criteria.md`

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
   - Mode A: module spec (name, description, capabilities) + reference module patterns + relevant knowledge entries + scaffold template
   - Mode B: component spec (module, name, description, type) + existing module components + same-type reference components + relevant knowledge entries

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
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_generator_relay.txt .tmp/{SESSION_ID}_codex_gen.json high, run_in_background=true)`
   - **Foreground**: Launch Claude **generator** agent (via Task tool) with all Phase 2 context

3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3

4. **Cherry-pick merge**: Review both generation outputs and build the final component content:
   - Use Claude's output as the primary structure (Claude has full knowledge base context)
   - Cherry-pick from Codex output: sections with stronger criteria coverage, novel patterns, or better structural completeness
   - If Codex generated content that addresses criteria Claude missed, incorporate it
   - If Codex generation failed or is partial, proceed with Claude-only output
   - The merged content feeds into Phase 5 (Write Files) — the orchestrator writes the final files

### When `--multi` is not active (single-model):

### Mode A: Module Spec Generation

Launch the **generator** agent via Task tool:

- **Input**: All context gathered in Phase 2:
  - Module spec: name, domain description, capabilities
  - Reference module patterns (representative files)
  - Relevant knowledge entries
  - Evaluation criteria for each component type
  - Scaffold template
- **Instructions**: "Perform Module Generation (Procedure 1). Analyze reference patterns, design module architecture, generate all component file contents. Output a complete Module Spec with manifest, rationale, and file contents."
- **Expected output**: Module Spec (component manifest + rationale + all file contents)

Parse the Module Spec output:

1. Extract the component manifest (list of files to create)
2. Extract each file's content
3. Extract the Module README content

### Mode B: Component Spec Generation

Launch the **generator** agent via Task tool:

- **Input**: All context gathered in Phase 2:
  - Component spec: module name, component name, description, type
  - Existing module components (all files — for pattern extraction)
  - Same-type reference components (1-2 structural models)
  - Relevant knowledge entries
  - Evaluation criteria for the target component type
- **Instructions**: "Perform Component Generation (Procedure 3). Analyze existing module patterns, generate a single component that integrates seamlessly. Output a Component Spec with path, rationale, and file content."
- **Expected output**: Component Spec (path + rationale + file content)

Parse the Component Spec output:

1. Extract the file path
2. Extract the file content

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

1. Derive slug:
   - Mode A: `{module-name}`
   - Mode B: `{module}-{component-name}`
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

## Phase 6: Quality Validation

> Agent: **evaluator**, **generator** (on retry) + Bash background (when `--multi`)

Apply the [Quality Gate Procedure](../../skills/core/validation/references/quality-gate-procedure.md) to validate generated components. When `--multi` is active, Claude and Codex evaluate in parallel for consensus scoring. See `skills/core/routing/references/parallel-execution-pattern.md`.

### When `--multi` is active (parallel):

For each generated command, agent, and skill (templates excluded):

1. **Build relay prompt**: Construct Mode A static evaluation prompt from component content + criteria reference. Save to `.tmp/{SESSION_ID}_relay.txt`
2. **Fan-out** (parallel):
   - **Background**: `Bash(invoke-model.sh codex gpt-5.3-codex .tmp/{SESSION_ID}_relay.txt .tmp/{SESSION_ID}_codex_eval.json xhigh, run_in_background=true)`
   - **Foreground**: Launch Claude **evaluator** agent (via Task tool) for static evaluation
3. **Fan-in**: Collect Codex result after Claude completes. Handle exit codes per `evaluate.md` Phase 3.5 Step 3
4. **Consensus**: Apply per-criterion majority rule (same as `evaluate.md` Phase 5.5). Consensus score determines pass/fail

For Mode A (multiple components), process sequentially with circuit breaker across components (2 consecutive Codex failures → skip Codex for remaining components).

Quality gate threshold remains Level >= 2 (same as single-model). On failure, retry uses Claude generator only (Codex retry adds complexity with diminishing returns).

### When `--multi` is not active (single-model):

**Mode A:** Evaluate each command, agent, and skill in the manifest (templates excluded).

**Mode B:** Evaluate the single generated component.

Apply the Quality Gate Procedure as defined.

Log quality validation results and proceed to Phase 7.

## Phase 7: Record Decision

Create a generate decision entry in the worktree:

- Mode A: `.worktrees/generate-{target}/docs/decisions/{date}-generate-{module-name}.md`
- Mode B: `.worktrees/generate-{target}/docs/decisions/{date}-generate-{module}-{component-name}.md`

Use template from `templates/core/decision-generate.md`.

Entry must include:

- type: generate
- mode: module | component
- date, module, component (Mode B), type (Mode B), intent
- evaluation-summary (pass/fail counts and scores)
- Background (why the module/component was created)
- Decisions (architectural choices from generator rationale)
- Generated Components table (all files with types and scores)
- Verification results

Stage and commit in worktree (`{target-display}` is `{module-name}` for Mode A, `{module}/{component-name}` for Mode B):

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
