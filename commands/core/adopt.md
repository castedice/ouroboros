---
description: Adopt ouroboros into a project — analyze codebase, generate AGENTS.md, initialize docs/ directories
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

Validate inputs per Branch Summary conditions. On failure, output the corresponding error message and abort.

1. **Resolve project path**: If no path provided, use current working directory
2. **Verify path exists and is a directory**
3. **Safety check**: Verify `{project-path}` is NOT inside the ouroboros plugin directory
4. **Detect existing AGENTS.md**: If `{project-path}/AGENTS.md` exists, present Overwrite/Skip choice. Record user's choice for Phase 6

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

Scan the target project to gather data for the researcher agent. Use detection patterns from `templates/core/project-detection-patterns.md`.

1. **Language & framework detection** (Section 2a): Glob for root manifest files per detection patterns. Read detected manifests for project name, dependencies, scripts
2. **Directory structure**: Scan top-level and one-level deep source/test directories per detection patterns
3. **Convention indicators** (Section 2b): Check for linting, CI/CD, and documentation configs per detection patterns
4. **Git info**: If git repo — recent commit count, active contributors, branch naming patterns
5. **Existing AI configuration** (Section 2c): Check for AI config files per detection patterns. Read any found files
6. **LSP template matching**: Match detected primary language to available LSP templates in `templates/core/lsp-configs/` (typescript.json, python.json, rust.json, go.json). Store matched template path or `null` if no match

Log: "Codebase scan complete. Language: {detected}, Framework: {detected}, {N} convention indicators found. LSP: {matched template name or 'no matching template'}."

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

### Recovery

| Failure | Action |
|---------|--------|
| Researcher agent timeout/error | Retry once with simplified instructions: "Produce a brief Project Profile: language, framework, architecture pattern, 3 key conventions." If retry fails: report error to user with option to provide manual profile |
| Incomplete analysis (missing language or architecture) | Proceed with available data. Log gaps: "Could not detect {field}. AGENTS.md may need manual adjustment." |

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
| 2 | `docs/specs/knowledge/` | Create (if missing) | Knowledge base directory |
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
- **Instructions**: "Perform AGENTS.md Generation (Procedure 4). Use the Project Profile Report and `templates/core/agents-md.md` template. Generate content specific to {language}/{framework}/{architecture}. Include concrete coding conventions, testing workflows, and AI agent guidelines. Output complete AGENTS.md content."
- **Expected output**: Complete AGENTS.md file content

### 5c: Post-Process

1. Verify the generated content contains required sections (from template)
2. If existing AI configs were found, verify key instructions were preserved or adapted
3. Store the final AGENTS.md content for Phase 6

### Recovery

| Failure | Action |
|---------|--------|
| Generator agent timeout/error | Retry once with simplified instructions: "Generate a minimal AGENTS.md with language conventions and testing workflow sections only." If retry fails: offer user to create AGENTS.md manually using template at `templates/core/agents-md.md` |
| Incomplete output (missing required sections) | Log missing sections. If < 50% of template sections present: retry. Otherwise: proceed with partial content, note gaps in Phase 7 report |

Log: "AGENTS.md generated. {N} sections, {language}-specific conventions included."

## Phase 6: Apply

Write files to the target project directory. No worktree — this is an external project, not ouroboros itself.

### 6a: Write AGENTS.md

Based on Phase 1 user choice (or default create):

- **Create/Overwrite**: Write AGENTS.md to `{project-path}/AGENTS.md`
- **Skip**: Do not write AGENTS.md

### 6b: Initialize docs/ Directories

For each directory, create only if it doesn't already exist:

1. `{project-path}/docs/specs/knowledge/` — with a `.gitkeep` file
2. `{project-path}/docs/decisions/` — with a `.gitkeep` file
3. `{project-path}/docs/personal/` — with a `.gitkeep` file

If any directory already exists, skip it and log.

### 6e: Create .lsp.json

If Phase 2 matched an LSP template:

1. If `{project-path}/.lsp.json` does not exist:
   - Read the matched template from `templates/core/lsp-configs/{language}.json`
   - Write to `{project-path}/.lsp.json`
   - Log: "Created .lsp.json for {language} (language server: {command}). Install the server: {install_command}"
2. If `{project-path}/.lsp.json` already exists:
   - Skip, log that file exists

Install commands by language:

| Language | Server | Install command |
|----------|--------|----------------|
| TypeScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| Python | pyright | `pip install pyright` or `npm install -g pyright` |
| Rust | rust-analyzer | See rust-analyzer.github.io |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |

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
| `docs/specs/knowledge/` | {Created|Already existed} |
| `docs/decisions/` | {Created|Already existed} |
| `docs/personal/` | {Created|Already existed} |
| `.lsp.json` | {Created for {language}|No matching template|Already existed} |
| `.gitignore` | {Updated|Already configured|Created} |

### Getting Started

1. Review and customize `AGENTS.md` for your team's conventions
2. If `.lsp.json` was created, install the language server (see command above)
3. Run `/onboard` to explore available ouroboros commands
4. Run `/evaluate AGENTS.md` to assess the generated instructions
5. Run `/evolve AGENTS.md` to improve based on evaluation feedback

### Recommended Workflows

{Project-specific workflow suggestions from researcher's analysis}

### Multi-model Setup

`AGENTS.md` is the shared instruction file, compatible with all major AI coding tools:

- **Claude Code**: `AGENTS.md` is auto-loaded alongside `CLAUDE.md`. No setup needed.
- **Codex CLI**: `AGENTS.md` is natively supported as a first-class instruction file. No setup needed.
- **Cursor / GitHub Copilot**: See their respective docs for instruction file configuration.

For tool-specific rules beyond shared conventions, create the tool's own config file (e.g., `CLAUDE.md` for Claude Code, `.cursorrules` for Cursor).

### Next Actions

- `/onboard` — learn about available ouroboros commands and workflows
- `/evaluate {project_path}/AGENTS.md` — assess the generated instructions quality
- `/evolve {project_path}/AGENTS.md` — improve AGENTS.md based on evaluation feedback
- Customize `AGENTS.md` sections for your team's specific practices
```

## Rules

- **No worktree**: /adopt writes to the target project directly — it's NOT an ouroboros internal change
- **No decision entry**: /adopt doesn't modify ouroboros, so `docs/decisions/` record is unnecessary
- **Idempotent**: Running /adopt twice on the same project is safe — existing files are detected and user chooses
- **Safety boundary**: Never adopt ouroboros into itself
- **Settings are suggestions only**: /adopt never modifies Claude Code settings.json or hooks — it generates AGENTS.md which users can review and apply themselves
- **Multi-model compatible**: AGENTS.md works with Claude Code, Codex CLI, and other AI tools that read project-level instruction files
- **No network access needed**: All analysis uses local file scanning only
- **Generator agent is read-only**: This command handles all file I/O via Write tool
- **Researcher agent is read-only**: This command provides scan data; researcher analyzes it
