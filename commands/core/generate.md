---
name: core:generate
description: "Use when you need to create a new plugin module or add a new component to an existing module"
argument-hint: <module-name> "<description>" | <module>/<component-name> "<description>" [--type <command|agent|skill|template>] [--reference <module>] [--single]
allowed-tools: Read, Glob, Write, Edit, Bash, Task
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

## Delegation Contracts

Use the standard runtime contract in `skills/core/collaboration/references/runtime-contract.md`.
Pass artifact paths and inline reference contents on every agent call.
Use named return payloads rather than prose-only summaries.
The command owns all worktree writes, manifest persistence, and quality-gate state.
Internal agent calls use `Agent(subagent_type: "ouroboros:core:{agent}")`.
The Bash Codex relay path is additive evidence only.

| Invocation | Input | Instructions | Expected Output |
|------------|-------|--------------|-----------------|
| Phase 3 generator, Mode A | Module spec from Phase 1, Phase 2 target analysis, relevant knowledge entries, reference module patterns, `skills/core/evaluation/references/command-criteria.md`, `skills/core/evaluation/references/agent-criteria.md`, `skills/core/evaluation/references/skill-criteria.md`, and `templates/core/module-scaffold.md` | Apply `agents/core/generator.md` Procedure 1 and `skills/core/generation/SKILL.md`. Design a module that matches the reference patterns and emit machine-consumable JSON only. | JSON object with `manifest`, `rationale`, `files`, and `readme`. `manifest` lists `path`, `type`, and `description` for every generated file, and `files` carries the full contents keyed by `path`. |
| Phase 3 generator, Mode B | Component spec from Phase 1, full target-module context, same-type reference components, relevant knowledge entries, and `skills/core/evaluation/references/{type}-criteria.md` | Apply `agents/core/generator.md` Procedure 3 and `skills/core/generation/SKILL.md`. Match the existing module conventions and emit machine-consumable JSON only. | JSON object with `path`, `type`, `rationale`, and `content`. `path` must match the final repository location. |
| Phase 6 evaluator | Generated component content from the worktree, detected component type, structural-validation findings from Phase 5.5, and the matching criteria reference under `skills/core/evaluation/references/` | Apply the quality gate from `skills/core/validation/references/quality-gate-procedure.md` plus the static evaluation method in `commands/core/evaluate.md` Phase 3. Score the component against the criteria, keep reasoning evidence-based, and return a machine-consumable evaluation result. | Evaluation payload with overall level, per-tier scores, per-criterion judgments, and the pass or fail verdict for the Level >= 2 gate. |
| Phase 6 retry generator | Failed component content, evaluator findings, the failing criterion IDs, and the same generation references used in Phase 3 | Apply `agents/core/generator.md` for targeted regeneration only. Preserve passing structure and address the cited criteria without broad redesign. | Replacement component content plus a brief rationale naming the repaired criteria IDs. |

Before machine-parsing any generator or evaluator payload, strip the trailing status block per `skills/core/routing/references/completion-status-protocol.md`.

## Shared Procedures & Payload Contracts

| Artifact | Path | Role |
|----------|------|------|
| Relay assembly guide | `skills/core/external-models/references/relay-assembly.md` | Four-section external-model relay contract for Phase 3 |
| Scaffold and quality gate | `skills/core/generation/references/scaffold-and-quality-gate.md` | Minimum-viable module rule, scaffold-first generation, and pre-quality checks |
| Regeneration loop | `skills/core/generation/references/regeneration-loop.md` | Shared retry boundaries after quality-gate failures |
| Validation check matrix | `skills/core/validation/references/validation-check-matrix.md` | Cross-cutting structural and relationship checks for Phase 5.5 |

Machine-consumed payloads:
- Phase 3 relay prompt writes `.tmp/{SESSION_ID}_generator_relay.txt`.
- Phase 3 Claude generation writes `.tmp/{SESSION_ID}_claude_gen.json`.
- Phase 3 Codex generation writes `.tmp/{SESSION_ID}_codex_gen.json`.
- Phase 5.5 structural validation writes `.tmp/{SESSION_ID}_structural_validation.md`.
- Phase 6 quality-gate verdicts write `.tmp/{SESSION_ID}_quality_gate_{slug}.json`.

Status-handling and parse rules:
- Strip any trailing completion status block before parsing a generator or evaluator summary.
- When both a summary and an on-disk JSON payload exist, the JSON payload is authoritative.
- Mode A parses `manifest`, `files`, and `readme` from the authoritative payload.
- Mode B parses `path`, `type`, and `content` from the authoritative payload.


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

### Branch Summary

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| Target | `<module-name>` and module absent | 1-9 | Mode A module generation |
| Target | `<module>/<component-name>` and module present | 1-9 | Mode B component generation |
| Target | `<module-name>` but module already exists | 1 abort | Error and suggest `/evolve` or Mode B |
| Target | `<module>/<component-name>` but the module is missing or the component already exists | 1 abort | Error and stop |
| Description | missing or empty | 1 abort | Usage error and stop |
| `--type` | provided in Mode B | 1-3 | Use the explicit component type |
| `--type` | omitted in Mode B | 1 | Infer from description and default to `command` on ambiguity |
| `--reference` | provided | 2 | Read patterns from the selected reference module |
| `--reference` | omitted | 2 | Default to `core` as the reference module |
| `--single` | true | 3, 6 | Claude-only generation and quality validation |
| `--single` | false (default) + Codex available | 3, 6 | Parallel Claude + Codex generation and evaluation |
| `--single` | false (default) + Codex unavailable | 3, 6 | Claude-only fallback with no external merge step |
| Existing worktree | found | 4 | User chooses Resume, Discard, or Merge before file writes |
| Plan approval | adjusted or declined | 3.5 | Revise the plan before entering the worktree |
| Structural validation | residual errors remain after auto-fix | 5.5, 6, 8, 9 | Continue to the quality gate and surface the residual issues in review and report |


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

### Relay Assembly

Assemble `.tmp/{SESSION_ID}_generator_relay.txt` using the four-section contract in `skills/core/external-models/references/relay-assembly.md`.
Use the section-source matrix below instead of restating the relay body inline.

| Section | Source |
|---------|--------|
| Role | Fixed generator role from `relay-assembly.md` |
| Content | Phase 2 context. Mode A uses module spec, reference patterns, knowledge entries, and scaffold template. Mode B uses component spec, target-module context, same-type references, and knowledge entries |
| Methodology or Criteria | `skills/core/generation/SKILL.md`, `skills/core/generation/references/scaffold-and-quality-gate.md`, and the criteria files loaded in Phase 2c |
| Response Format | The matching JSON contract from the Delegation Contracts table above |

### Execution Matrix

| Execution Mode | Generator Runs | Authoritative Payload | Merge Behavior |
|----------------|----------------|-----------------------|----------------|
| `--multi` active | Claude generator task + Codex relay | `.tmp/{SESSION_ID}_claude_gen.json` unless the orchestrator promotes cherry-picked Codex additions into the final merged payload | Keep Claude structure primary and cherry-pick Codex sections only when they improve criteria coverage, completeness, or integration fit |
| Single-model | Claude generator task only | `.tmp/{SESSION_ID}_claude_gen.json` | Use the Claude payload directly |

When `--multi` is active, launch Codex via `scripts/codex-relay.sh .tmp/{SESSION_ID}_generator_relay.txt --output .tmp/{SESSION_ID}_codex_gen.json --effort high` and launch Claude via Task tool, writing `.tmp/{SESSION_ID}_claude_gen.json`.
When single-model is active, launch only the Claude generator and write `.tmp/{SESSION_ID}_claude_gen.json`.
Mode A uses the Procedure 1 contract from the Delegation Contracts table.
Mode B uses the Procedure 3 contract from the same table and repeats once per actionable gap.
After collection, parse the authoritative payload and build the unified manifest for Phase 5.

### Phase 3.5: Plan Approval

Present the generation plan:

```text
Generating {n} components for {module}: {component list}. Proceed with generation?
```

Wait for user confirmation before writing any files.

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

Apply the shared pre-quality procedure from `skills/core/generation/references/scaffold-and-quality-gate.md` plus `skills/core/validation/SKILL.md`.
Record the aggregated findings in `.tmp/{SESSION_ID}_structural_validation.md` for Phase 6 and Phase 8.

### Validation Procedure

| Substep | Reference | Behavior |
|---------|-----------|----------|
| Type-specific validation | `skills/core/validation/SKILL.md` Steps 1-4 plus `frontmatter-and-fields.md` | Validate each generated file's frontmatter, required sections, and type-specific structure |
| Cross-cutting validation | `skills/core/validation/references/naming-and-collision.md` and `common-pitfalls.md` | Check naming, path constraints, collisions, and common command or agent issues |
| Inter-component consistency | `skills/core/generation/references/scaffold-and-quality-gate.md` plus `validation-check-matrix.md` | Verify Agent → Skill, Command → Agent, and Skill → Reference path integrity across generated and existing components |
| Auto-fix pass | Bounded by the error-type table below | Apply only the listed safe fixes with Edit tool |
| Re-validation | Same references as above | Re-run only the affected checks when auto-fixes were applied |

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

If any auto-fixes were applied in Step 3, re-run the Validation Procedure checks touched by those edits. Skip if no fixes were applied.

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
   - **Background**: `Bash(codex-relay.sh .tmp/{SESSION_ID}_relay.txt --output .tmp/{SESSION_ID}_codex_eval.json --effort xhigh, run_in_background=true)`
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
