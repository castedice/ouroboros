---
description: Explore ouroboros capabilities — discover installed modules, list available commands, and recommend workflows
argument-hint: [<topic>]
allowed-tools: Read, Glob, Grep
---

# Onboard — Capability Explorer

Discover installed ouroboros modules, list available commands with descriptions, and get workflow recommendations.

Target: $ARGUMENTS

## Agents Used

None. This command uses only Glob and Read for lightweight discovery.

## Phase 1: Parse Input

Extract arguments from $ARGUMENTS:

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `topic` | No | (none) | Command name or topic to get detailed info about |

### Mode Detection

| Input | Mode | Description |
|-------|------|-------------|
| No argument | **Overview** | List all modules and commands |
| `<command-name>` | **Detail** | Show detailed info about a specific command |

**Detail mode validation**: If topic provided, verify it matches an existing command:

- `Glob: commands/*/{topic}.md`
- If no match → suggest closest matches from available commands, then fall back to overview mode

## Phase 2: Module Discovery

### 2a: Scan Modules

Discover all installed modules by scanning command directories:

1. `Glob: commands/*/` — list module directories
2. For each module directory:
   - `Glob: commands/{module}/*.md` — list commands (exclude README.md)
   - `Glob: agents/{module}/*.md` — list agents
   - `Glob: skills/{module}/**/SKILL.md` — list skills
   - `Glob: templates/{module}/*.md` — list templates

### 2b: Read Frontmatter

Expected frontmatter fields are defined in `skills/core/validation/references/frontmatter-and-fields.md`.

For each discovered command file:

1. Read the file (first 10 lines sufficient for frontmatter)
2. Extract `description` and `argument-hint` from YAML frontmatter

For each discovered agent file:

1. Read the file (first 5 lines sufficient)
2. Extract `name` from YAML frontmatter

### 2c: Build Registry

Organize into a registry structure:

```text
Module: {module-name}
  Commands: [{name, description, argument-hint}, ...]
  Agents: [{name}, ...]
  Skills: [{name}, ...]
  Templates: [{name}, ...]
```

## Phase 3: Present

### Overview Mode (no topic)

```markdown
## Ouroboros — Installed Capabilities

### Modules

| Module | Commands | Agents | Skills | Templates |
|--------|----------|--------|--------|-----------|
| {module} | {count} | {count} | {count} | {count} |
| ... | ... | ... | ... | ... |
| **Total** | **{total}** | **{total}** | **{total}** | **{total}** |

### Available Commands

{For each module:}

#### {module}

| Command | Description |
|---------|-------------|
| `/{command}` | {description} |
| ... | ... |

### Recommended Workflows

#### Getting Started
1. `/onboard <command>` — learn about a specific command
2. `/evaluate <component>` — assess a component's quality
3. `/evolve <component>` — improve based on evaluation

#### Self-Improvement Cycle
1. `/evaluate` → identify weakest component (criteria: `skills/core/evaluation/references/command-criteria.md`)
2. `/evolve` → improve it with researcher + evaluator guidance
3. `/evaluate` → verify improvement (before/after comparison)

#### Knowledge Building
1. `/research <source>` → analyze external patterns
2. `/absorb <source> --into <module>` → integrate into the monolith
3. `/evolve <component>` → apply absorbed knowledge

#### Multi-Model Evaluation
1. Install external CLIs: `npm install -g @openai/codex @google/gemini-cli`
2. Add Bash permissions to `.claude/settings.json`: `"Bash(codex *)"`, `"Bash(gemini *)"`, etc.
3. `/evaluate <component> --multi` → Claude + Codex + Gemini consensus scoring (routing: `skills/core/routing/SKILL.md`)
4. `/evaluate <component> --multi --unanimous` → require all models to agree

#### Staying Current
1. `/upgrade --check` → preview upstream changes
2. `/upgrade` → apply upstream updates safely
3. `/evaluate` → verify nothing regressed

#### Project Integration
1. `/adopt <project-path>` → generate AGENTS.md for a project
2. `/onboard` → explore what's available

### Quick Reference

- **Primitives**: `/evaluate`, `/evolve`, `/research`, `/generate`
- **Composites**: `/absorb`, `/upgrade`, `/adopt`, `/onboard`
- **Multi-model**: `/evaluate --multi` (requires Codex CLI + Gemini CLI)
- **Philosophy**: Co-Evolutionary Self-Improvement — every cycle makes the next one better

### Next Steps

{Generate context-aware suggestions from the discovery results:}

- **Deep dive**: `/onboard {command-with-most-agents}` — the most complex command, worth exploring first
- **Quality check**: `/evaluate commands/{module}/{command-with-fewest-components}.md` — smallest component, quick win for evaluation
- **Gap analysis**: Module `{module-with-fewest-skills}` has only {n} skills — consider `/evolve` to expand coverage
```

### Detail Mode (topic provided)

Read the full command file and present structured details:

```markdown
## Command: /{command-name}

**Module**: {module}
**Description**: {description}
**Usage**: `/{command-name} {argument-hint}`

### What It Does

{Summary derived from the command's title and first section}

### Phases

| # | Phase | Agent | Description |
|---|-------|-------|-------------|
| 1 | {phase-name} | {agent or —} | {brief description} |
| ... | ... | ... | ... |

### Agents Used

| Agent | Role |
|-------|------|
| {agent-name} | {role description} |
| ... | ... |

### Usage Examples

{Derive from argument-hint and command structure:}
- `/{command-name} {typical-usage-1}`
- `/{command-name} {typical-usage-2}`

### Related Commands

{Scan other commands in the same module and suggest related workflows:}
- `/{related-command}` — {how it connects to this command}

### Rules

{Extract key rules from the command's Rules section, if present}

### Next Steps

- `/evaluate commands/{module}/{command-name}.md` — assess this command's quality against criteria
- `/evolve commands/{module}/{command-name}.md --focus {weakest-section}` — improve the area with least detail
- `/onboard {related-command}` — explore the most closely related command
```

## Rules

- **Pure read-only**: This command never writes, creates, or modifies any files
- **No agents**: Module discovery and frontmatter parsing are simple operations — agent delegation would be over-engineering
- **No network**: All information comes from local file scanning
- **Graceful degradation**: If a module has no commands (empty directory), still list it with count 0
- **Frontmatter parsing**: Only read YAML frontmatter fields — do not parse or execute command body content
- **Command names**: Strip `.md` extension when displaying command names (e.g., `evaluate.md` → `evaluate`)

### Recovery

- **Missing plugin structure**: If `commands/` directory does not exist or is empty, output a diagnostic message listing the expected structure (`commands/`, `agents/`, `skills/`, `templates/`) and suggest verifying the plugin installation path
- **Frontmatter parse failure**: If a specific file's frontmatter cannot be parsed (malformed YAML, missing fields), skip that file, continue with remaining files, and append a "Partial results" note listing the skipped files at the end of the output
- **Inaccessible files**: If a file cannot be read (permissions, broken symlink), skip it and include it in the partial results note alongside frontmatter failures
