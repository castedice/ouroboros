---
name: swe:reverse
description: "Use when you need to derive requirements, constraints, architecture, and interfaces from existing code"
argument-hint: "<path> [--scope \"<focus>\"] [--fast] [--depth <global|per-stage>]"
allowed-tools: Read, Glob, Grep, Write, Task, Bash
---

# Reverse — Code-First Specification Recovery

Analyze an existing codebase to produce specification artifacts — Context Document, Constraint Profile, Architecture Spec, and Interface Contracts — in the same format as the forward `/swe spec` pipeline.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 4 | analyst | Procedure 5 — Reverse specification recovery |

## Branch Summary

| Condition | Affected Phases | Behavior |
|-----------|-----------------|----------|
| `path` is empty | 1 | Abort with the usage error and do not continue. |
| `path` does not exist or contains no source files | 1 | Abort with the path error and do not continue. |
| `--depth` is provided | 2 | Use the parsed global or per-stage depths and skip scale-based auto-detection. |
| `--fast` is provided without `--depth` | 2 | Force Light depth for all recovered artifacts. |
| Neither `--depth` nor `--fast` is provided | 2 | Auto-determine depth from codebase scale. |
| `--scope` is provided | 3 | Prioritize scope-matching files during sampling without excluding out-of-scope inventory context. |
| Codebase scale is Small | 2, 3 | Read all source files for the reverse packet. |
| Codebase scale is Medium | 2, 3 | Sample entry points, model files, and API files up to the medium cap. |
| Codebase scale is Large | 2, 3 | Sample entry points, module boundaries, and API surface files up to the large cap. |
| Analyst times out | 4 | Retry once with the reduced-scope fallback for the top 3 modules by file count. |
| Analyst returns fewer than 4 artifacts | 4, 5, 6, 7 | Save completed artifacts, log the missing ones, and present the result as partial. |
| Analyst errors after retry | 4 | Abort and recommend narrowing `--scope`. |
| `.swe/active/` already contains artifacts | 5 | Prompt for overwrite confirmation before writing recovered artifacts. |
| Overwrite is denied | 5 | Abort and recommend archiving or using a narrower scope. |
| `docs/specs/project/` does not exist and the user approves bootstrap | 5.5 | Initialize the living project model from the recovered artifacts. |
| `docs/specs/project/` exists and the user approves update | 5.5 | Merge reverse findings into the existing project model. |
| Project model bootstrap or merge is declined | 5.5 | Skip project-model updates and continue to review/report. |
## Phase 1: Parse Input

Extract from $ARGUMENTS:

| Parameter | Source | Default |
|-----------|--------|---------|
| `path` | Positional path to codebase/module | Required — abort if empty |
| `--scope` | Focus description (e.g., "authentication subsystem") | Entire codebase at `path` |
| `--fast` | Shortcut for `--depth Light` | Off |
| `--depth` | Depth specification | Auto-determined in Phase 2 |

`--depth` accepts two formats:

| Format | Example | Meaning |
|--------|---------|---------|
| Global | `--depth Deep` | All 4 artifacts at Deep depth |
| Per-stage | `--depth U:Std C:Std D:Deep I:Std` | Individual artifact depths (U=Context, C=Constraint, D=Architecture, I=Interface) |

If `path` is empty:

- Output: "Error: Codebase path required. Usage: `/swe reverse <path> [--scope \"<focus>\"] [--depth Light|Standard|Deep]`"
- Abort

If `path` does not exist or contains no files:

- Output: "Error: No files found at `{path}`. Verify the path exists and contains source files."
- Abort

## Phase 2: Depth Determination

Reverse uses codebase scale (not task complexity) to determine depth:

1. If `--depth` was provided, use parsed values
2. If `--fast` was provided (and no `--depth`), set all to Light
3. If neither, auto-determine from codebase scale:

| Factor | Detection | Metric |
|--------|-----------|--------|
| File count | `Glob` at `path` | Source files (exclude .git, node_modules, vendor, __pycache__, .swe) |
| Languages | File extensions | Distinct languages detected |
| Module boundaries | Directory structure depth + naming | Top-level directories with source files |

Scale → Depth mapping:

| Scale | Condition | Default Depth |
|-------|-----------|---------------|
| Small | <20 files, ≤2 languages | Light |
| Medium | 20-100 files, or 3+ languages | Standard |
| Large | >100 files, or >5 module boundaries | Deep |

Log: "Codebase scale: {scale} ({n} files, {m} languages, {k} modules). Depth: {depth}."

Present Depth Plan to user for confirmation:

```markdown
## Depth Plan

| Artifact | Depth | Rationale |
|----------|-------|-----------|
| 1. Context Document | {level} | {reason} |
| 2. Constraint Profile | {level} | {reason} |
| 3. Architecture Spec | {level} | {reason} |
| 4. Interface Contracts | {level} | {reason} |

Scope: {--scope value or "entire codebase"}

Proceed with this plan, or adjust depths?
```

## Phase 3: Codebase Inventory

Build a comprehensive inventory of the codebase at `path`. Unlike forward pipeline's task-driven context gathering, reverse performs exhaustive scanning.

### Step 1: Directory Structure

Use Glob to map the directory tree. Record:

- Top-level directories and their apparent purpose
- Nesting depth and module organization pattern
- Configuration files (package.json, Cargo.toml, go.mod, pyproject.toml, etc.)
- Test directories and test file patterns

### Step 2: Language & Framework Detection

From file extensions and config files:

- Primary language(s) and their proportions
- Framework indicators (import patterns, config files, directory conventions)
- Build system (make, npm, cargo, gradle, etc.)
- Package dependencies (read manifest files)

### Step 3: Module Boundary Identification

Identify logical modules by:

- Directory-based separation (src/auth/, src/api/, etc.)
- Package/namespace boundaries
- Entry points (main files, index files, route definitions)
- Shared/common directories

### Step 4: Key File Sampling

Read a representative sample of source files to understand coding patterns, error handling, data models, and public API surface.

Apply sampling limits based on the scale classification from Phase 2:

- **Small**: All source files
- **Medium**: Entry points + model files + API files (max 30)
- **Large**: Entry points + module boundaries + API surface (max 40)

If `--scope` is set, prioritize files matching the scope description.

### Step 5: Build Inventory Document

Compile findings into a structured inventory (not saved as artifact — passed to analyst):

```
Inventory:
  path: {path}
  scope: {scope or "full"}
  scale: {Small|Medium|Large}
  languages: [{lang}: {count} files]
  frameworks: [{name}: {indicators}]
  modules: [{name}: {path}, {file_count} files, {purpose}]
  entry_points: [{path}: {type}]
  key_patterns: [{pattern}: {evidence}]
  dependencies: [{name}: {version}]
```

## Phase 4: Analyst Delegation — Reverse

Delegate the full reverse analysis to the analyst agent in a single invocation:

> Agent: **analyst**

- **Input**: Codebase inventory from Phase 3 + scope + depth plan + all sampled file contents
- **Instructions**: Execute Procedure 5 (Reverse) from `agents/swe/analyst.md`. Produce all 4 specification artifacts sequentially at the planned depths. Follow templates for each artifact type. Mark all conclusions with confidence level: Explicit (directly in code), Inferred (from patterns), or Assumed (uncertain).
- **Expected output**: Content for all 4 artifacts — Context Document, Constraint Profile, Architecture Spec, Interface Contracts

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout | Retry once with reduced scope: "Focus on the top 3 modules by file count only" |
| Incomplete output (fewer than 4 artifacts) | Save completed artifacts. Log: "Partial recovery: {n}/4 artifacts produced. Missing: {list}." |
| Agent error | "Reverse analysis failed. Try with a narrower scope: `/swe reverse {path} --scope \"{specific module}\"`" |

## Phase 5: Save Artifacts

Write each artifact to `.swe/active/`:

| Artifact | File |
|----------|------|
| Context Document | `.swe/active/01-understand.md` |
| Constraint Profile | `.swe/active/02-constrain.md` |
| Architecture Spec | `.swe/active/03-design.md` |
| Interface Contracts | `.swe/active/04-interface.md` |

Each artifact receives a reverse-specific header:

```markdown
<!-- Stage: {N} | Source: reverse | Depth: {depth} | Path: {path} | Scope: {scope} | Date: {ISO date} -->
```

If `.swe/active/` already contains artifacts:

- Warn: "Existing artifacts found in `.swe/active/`. Overwrite? (Y/N)"
- On N: abort with message "Use `/swe reverse {path} --scope ...` with different scope, or archive existing artifacts first."

Log: "Artifacts written: {n}/4 to `.swe/active/`."

## Phase 5.5: Bootstrap Project Model

After saving artifacts, offer to initialize or update the living project model from the reverse-engineered specifications.

### If `docs/specs/project/` does not exist

Ask user: "Initialize Living Project Model from these reverse-engineered artifacts? This creates `docs/specs/project/` with cumulative specification files that evolve across spiral turns."

- **On Y**:
  1. Run `Bash: scripts/artifact-lifecycle.sh init-project`
  2. For each artifact that was produced, copy its full content (not just Summary) into the corresponding project model file (`domain.md`, `constraints.md`, `architecture.md`, `interfaces.md`)
  3. Set the Change Log entry: `| 000 | reverse-bootstrap | Initial project model from reverse analysis |`
  4. Log: "Project model initialized from reverse artifacts."
- **On N**: skip

### If `docs/specs/project/` already exists

Ask user: "Update existing Project Model with reverse findings?"

- **On Y**: Merge using the same additive strategy as `spiral.md` Phase 10.6 — append new entries, update existing, add Change Log entry
- **On N**: skip

## Phase 6: Review

Present the complete reverse specification for user review:

```markdown
## Reverse Specification: {path} {scope context}

### Artifact Chain

| # | Artifact | Depth | File | Status |
|---|----------|-------|------|--------|
| 1 | Context Document | {depth} | `.swe/active/01-understand.md` | {done/partial} |
| 2 | Constraint Profile | {depth} | `.swe/active/02-constrain.md` | {done/partial} |
| 3 | Architecture Spec | {depth} | `.swe/active/03-design.md` | {done/partial} |
| 4 | Interface Contracts | {depth} | `.swe/active/04-interface.md` | {done/partial} |

### Key Findings
- **Domain**: {key entities and bounded contexts}
- **Architecture**: {primary pattern detected}
- **Constraints**: {key constraints inferred} ({explicit count} explicit, {inferred count} inferred)
- **Interfaces**: {interface count} contracts extracted

### Confidence Summary
- **Explicit** (directly in code): {count} conclusions
- **Inferred** (from patterns): {count} conclusions
- **Assumed** (uncertain): {count} conclusions — review recommended

### Forward Compatibility
These artifacts are forward-pipeline compatible. Next steps:
- `/swe dev "<task description>"` — implement against recovered specs at `.swe/active/`
- `/swe ship` — validate `{path}` codebase against recovered Architecture Spec and Interface Contracts
- Review artifacts in `.swe/active/`, especially **Assumed** conclusions ({assumed_count} items) before proceeding
- `/swe spec "<task description>"` — re-derive specs from requirements (compare with reverse output)
```

## Phase 7: Report

```markdown
## Reverse Complete: {path}

**Scope**: {scope or "full codebase"}
**Depth**: U:{level} C:{level} D:{level} I:{level}
**Artifacts**: {n}/4 files in `.swe/active/`
**Confidence**: {explicit_count} explicit, {inferred_count} inferred, {assumed_count} assumed

Refinement: `/swe understand`, `/swe constrain`, `/swe design` — re-derive individual stages from a task perspective.
Forward pipeline: `/swe dev`, `/swe ship`, `/swe spec`, `/swe spiral` — use recovered artifacts as starting point.
```

### See Also
- **Analyst agent** (`agents/swe/analyst.md`) — executes Procedure 5 (Reverse)
- **SWE Methodology** (`skills/swe/methodology/SKILL.md`) — pipeline methodology reference
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — stage input/output specifications

## Rules

- Reverse produces the same artifact format as forward — consumers (dev, ship, tune) cannot distinguish the source
- The analyst executes all 4 artifacts in a single invocation (unlike forward's 4 separate delegations) — this is more efficient for reverse since the codebase context is shared
- Artifact paths follow the same `.swe/active/{NN}-{stage}.md` convention as forward
- Confidence markers (Explicit/Inferred/Assumed) are mandatory — reverse analysis inherently involves inference
- Existing artifacts in `.swe/active/` require explicit overwrite confirmation
- Codebase sampling respects `.gitignore` patterns — do not analyze vendored or generated code
- `--scope` narrows analysis focus but does not exclude files from inventory — context outside scope informs module boundaries
