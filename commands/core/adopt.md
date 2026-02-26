---
description: Adopt ouroboros into a project — analyze codebase, generate multi-model compatible AGENTS.md, initialize docs/ directories
argument-hint: [<project-path>] [--dry-run]
allowed-tools: Read, Glob, Grep, Write, Bash, Task
---

# Adopt — Project Integration

Analyze a target project's codebase, generate a multi-model compatible AGENTS.md, and initialize ouroboros documentation directories.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | researcher | Project codebase analysis (Procedure 3) |
| 5 | generator | AGENTS.md content generation (Procedure 4) |

## Phase 1: Parse Input

Extract arguments from $ARGUMENTS:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `project-path` | No | Current working directory | Path to the target project |
| `--dry-run` | No | false | Show analysis and plan without writing files |

### Validation

1. **Resolve project path**: If no path provided, use current working directory
2. **Verify path exists**: If path doesn't exist → Error: "Error: Path '{path}' does not exist."
3. **Verify it's a directory**: If path is a file → Error: "Error: '{path}' is a file, not a project directory."
4. **Detect existing AGENTS.md**: Check for `{project-path}/AGENTS.md`
   - If exists → present choice:

     ```text
     Existing AGENTS.md detected at {project-path}/AGENTS.md.

     1. **Overwrite** — replace with freshly generated version
     2. **Skip** — keep existing, only initialize docs/ directories
     ```

   - Record user's choice for Phase 6

5. **Safety check**: Verify `{project-path}` is NOT inside the ouroboros plugin directory
   - If it is → Error: "Error: Cannot adopt ouroboros into itself. Use `/evolve` to improve ouroboros components."

Log: "Adopting ouroboros into: {project-path} (dry-run: {true|false})"

## Branch Summary

All conditional branches that affect command behavior, consolidated for quick reference.

| Condition | State | Affected Phases | Behavior |
|-----------|-------|-----------------|----------|
| `--dry-run` | true | 5, 6, 7 skipped | Report adoption plan only, no file writes. Execution stops after Phase 4 |
| `--dry-run` | false (default) | All phases run | Full adoption with file writes after user confirmation |
| Project path | Does not exist | Phase 1 abort | Error: "Path '{path}' does not exist." |
| Project path | Is a file, not directory | Phase 1 abort | Error: "'{path}' is a file, not a project directory." |
| Project path | Inside ouroboros plugin dir | Phase 1 abort | Error: "Cannot adopt ouroboros into itself." |
| AGENTS.md | Does not exist | Phase 6a | Create new AGENTS.md |
| AGENTS.md | Exists, user chooses Overwrite | Phase 6a | Replace with freshly generated version |
| AGENTS.md | Exists, user chooses Skip | Phase 5, 6a | Skip generation (Phase 5) and writing; only initialize docs/ |
| `.gitignore` | Does not exist | Phase 6c | Create new `.gitignore` with `docs/personal/` entry |
| `.gitignore` | Exists, missing `docs/personal/` | Phase 6c | Append `docs/personal/` entry to existing file |
| `.gitignore` | Exists, already has `docs/personal/` | Phase 6c | Skip, no changes |
| `docs/{subdir}/` | Does not exist | Phase 6b | Create directory with `.gitkeep` file |
| `docs/{subdir}/` | Already exists | Phase 6b | Skip, log that directory exists |

## Phase 2: Codebase Scan

Scan the target project to gather data for the researcher agent.

### 2a: Project Structure

1. **Root files**: Check for presence of key files:
   - `Glob: {project-path}/package.json` (Node.js)
   - `Glob: {project-path}/Cargo.toml` (Rust)
   - `Glob: {project-path}/go.mod` (Go)
   - `Glob: {project-path}/pyproject.toml` or `{project-path}/setup.py` or `{project-path}/requirements.txt` (Python)
   - `Glob: {project-path}/Gemfile` (Ruby)
   - `Glob: {project-path}/build.gradle*` or `{project-path}/pom.xml` (Java/Kotlin)
   - `Glob: {project-path}/tsconfig.json` (TypeScript)
   - `Glob: {project-path}/Makefile`, `{project-path}/CMakeLists.txt` (C/C++)
   - `Glob: {project-path}/docker-compose.yml`, `{project-path}/Dockerfile` (Docker)

2. **Project metadata**: Read detected manifest files (package.json, Cargo.toml, etc.) for:
   - Project name, description
   - Dependencies and dev dependencies
   - Scripts/tasks

3. **Directory structure**: Scan top-level and one-level deep:
   - `Glob: {project-path}/*` (top-level)
   - `Glob: {project-path}/src/**` or equivalent source directory (one level deep)
   - `Glob: {project-path}/test*/**` or `{project-path}/*test*/**` (test directory)

### 2b: Convention Indicators

1. **Linting/formatting**: Check for config files:
   - `.eslintrc*`, `.prettierrc*`, `biome.json`, `.editorconfig`
   - `rustfmt.toml`, `.golangci.yml`, `ruff.toml`, `.rubocop.yml`

2. **CI/CD**: Check for pipeline configs:
   - `.github/workflows/*.yml`
   - `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`

3. **Documentation**: Check for existing docs:
   - `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`
   - `docs/` directory
   - `CLAUDE.md` (existing Claude Code instructions)

4. **Git info**: If git repo:
   - Recent commit count and active contributors (from git log)
   - Branch naming patterns

### 2c: Existing AI Configuration

Check for existing AI agent configurations:

- `AGENTS.md` (multi-model)
- `CLAUDE.md` (Claude Code)
- `.cursorrules` (Cursor)
- `.github/copilot-instructions.md` (Copilot)
- `codex.md` or `.codex/` (Codex)

Read any found AI config files — these inform how the project currently uses AI tools.

Log: "Codebase scan complete. Language: {detected}, Framework: {detected}, {N} convention indicators found."

## Phase 3: Project Analysis

> Agent: **researcher**

Launch the **researcher** agent via Task tool:

- **Input**: All scan data from Phase 2:
  - Project structure (manifest files content, directory layout)
  - Convention indicators (linting, CI/CD, docs)
  - Existing AI configurations (if any)
  - Project path
- **Instructions**: "Perform Project Analysis (Procedure 3). Analyze the provided codebase scan data. Produce a Project Profile Report covering: (1) Language and framework detection with confidence, (2) Project architecture pattern (monorepo, microservices, monolith, library), (3) Key conventions (naming, testing, documentation), (4) Existing AI tool usage, (5) Recommended ouroboros modules and workflows for this project type."
- **Expected output**: Project Profile Report

Parse the researcher's report to extract:

1. **Language/framework**: Primary language, framework, build tool
2. **Architecture**: Project structure pattern
3. **Conventions**: Naming, testing, documentation patterns
4. **AI usage**: Existing AI configurations and their coverage
5. **Recommendations**: Which ouroboros modules and workflows suit this project

Log: "Project analysis complete. {language}/{framework}, {architecture} pattern."

## Phase 4: Plan & Preview

Before presenting the plan, apply 1-2 techniques from [divergent-techniques.md](../../skills/core/brainstorming/references/divergent-techniques.md) (e.g., What-if on project workflow assumptions, First Principles on which ouroboros modules truly fit) to generate alternative adoption configurations. Include the recommended plan with brief alternatives where meaningful trade-offs exist.

Present the adoption plan:

```markdown
## Adoption Plan: {project-name}

**Path**: {project-path}
**Language**: {language} ({framework})
**Architecture**: {architecture pattern}

### What will be created

| # | File/Directory | Action | Description |
|---|---------------|--------|-------------|
| 1 | `AGENTS.md` | {Create|Overwrite|Skip} | Multi-model AI agent instructions |
| 2 | `docs/knowledge/` | Create (if missing) | Knowledge base directory |
| 3 | `docs/decisions/` | Create (if missing) | Decision log directory |
| 4 | `docs/personal/` | Create (if missing) | Personal notes directory |
| 5 | `.gitignore` | {Update|Skip} | Add `docs/personal/` entry |

### AGENTS.md Preview

- Language-specific conventions for {language}
- {framework} patterns and best practices
- Testing workflow: {detected test framework}
- Recommended ouroboros workflows: {list}

### Recommended Modules

{researcher's module recommendations with brief rationale}

{If --dry-run: "Dry run complete. No files will be written."}
{If not --dry-run: "Proceed with adoption?"}
```

**If `--dry-run`**: Stop here. Report the plan and exit.

**If not `--dry-run`**: Wait for user confirmation, then proceed to Phase 5.

## Phase 5: Generate AGENTS.md

> Agent: **generator**

### 5a: Prepare Template

Read `templates/core/agents-md.md` for the AGENTS.md structure template.

### 5b: Generate Content

Launch the **generator** agent via Task tool:

- **Input**:
  - Project Profile Report (from Phase 3)
  - AGENTS.md template (from 5a)
  - Existing AI configurations (from Phase 2, if any — to preserve useful instructions)
  - Project conventions and patterns
- **Instructions**: "Perform AGENTS.md Generation (Procedure 4). Using the Project Profile Report and template, generate a complete, multi-model compatible AGENTS.md for this project. The content must be specific to the detected language ({language}), framework ({framework}), and architecture ({architecture}). Include concrete coding conventions, testing workflows, and AI agent guidelines. Output the complete AGENTS.md content."
- **Expected output**: Complete AGENTS.md file content

### 5c: Post-Process

1. Verify the generated content contains required sections (from template)
2. If existing AI configs were found, verify key instructions were preserved or adapted
3. Store the final AGENTS.md content for Phase 6

Log: "AGENTS.md generated. {N} sections, {language}-specific conventions included."

## Phase 6: Apply

Write files to the target project directory. No worktree — this is an external project, not ouroboros itself.

### 6a: Write AGENTS.md

Based on Phase 1 user choice (or default create):

- **Create/Overwrite**: Write AGENTS.md to `{project-path}/AGENTS.md`
- **Skip**: Do not write AGENTS.md

### 6b: Initialize docs/ Directories

For each directory, create only if it doesn't already exist:

1. `{project-path}/docs/knowledge/` — with a `.gitkeep` file
2. `{project-path}/docs/decisions/` — with a `.gitkeep` file
3. `{project-path}/docs/personal/` — with a `.gitkeep` file

If any directory already exists, skip it and log.

### 6c: Update .gitignore

Check `{project-path}/.gitignore`:

1. If file exists:
   - Read it
   - Check if `docs/personal/` is already listed
   - If not listed → append `\n# Ouroboros personal notes\ndocs/personal/\n`
   - If already listed → skip
2. If file doesn't exist:
   - Create `.gitignore` with `docs/personal/` entry

Log: "Applied: {N} files written, {M} directories created."

## Phase 7: Report

```markdown
## Adoption Complete: {project-name}

**Path**: {project-path}
**Language**: {language} ({framework})
**Architecture**: {architecture pattern}

### Files Created

| File/Directory | Status |
|----------------|--------|
| `AGENTS.md` | {Created|Overwritten|Skipped} |
| `docs/knowledge/` | {Created|Already existed} |
| `docs/decisions/` | {Created|Already existed} |
| `docs/personal/` | {Created|Already existed} |
| `.gitignore` | {Updated|Already configured|Created} |

### Getting Started

1. Review and customize `AGENTS.md` for your team's conventions
2. Run `/onboard` to explore available ouroboros commands
3. Run `/evaluate AGENTS.md` to assess the generated instructions
4. Run `/evolve AGENTS.md` to improve based on evaluation feedback

### Recommended Workflows

{Project-specific workflow suggestions from researcher's analysis}

### Next Actions

- Run `/onboard` to learn about available commands and workflows
- Customize `AGENTS.md` sections for your team's specific practices
- Start using `/evaluate` on your project's key components
```

## Rules

- **No worktree**: /adopt writes to the target project directly — it's NOT an ouroboros internal change
- **No decision entry**: /adopt doesn't modify ouroboros, so `docs/decisions/` record is unnecessary
- **Idempotent**: Running /adopt twice on the same project is safe — existing files are detected and user chooses
- **Safety boundary**: Never adopt ouroboros into itself
- **Settings are suggestions only**: /adopt never modifies Claude Code settings.json or hooks — it generates AGENTS.md which users can review and apply themselves
- **Multi-model compatible**: AGENTS.md works with Claude Code, Gemini CLI, Codex CLI, and other AI tools that read project-level instruction files
- **No network access needed**: All analysis uses local file scanning only
- **Generator agent is read-only**: This command handles all file I/O via Write tool
- **Researcher agent is read-only**: This command provides scan data; researcher analyzes it
