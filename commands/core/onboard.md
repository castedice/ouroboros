---
description: Explore ouroboros capabilities — discover installed modules, list available commands, and recommend workflows
argument-hint: [<topic>]
allowed-tools: Read, Glob, Grep, Task
---

# Onboard — Capability Explorer

Discover installed ouroboros modules, list available commands with descriptions, and get workflow recommendations.

Target: $ARGUMENTS

## Agents Used

| Phase | Agent | Role |
|-------|-------|------|
| 3 | researcher | Workflow recommendation — context-aware suggestions based on discovery registry |

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

1. Read the file frontmatter per `skills/core/validation/references/frontmatter-and-fields.md`
2. Extract `description` and `argument-hint`

For each discovered agent file:

1. Read the file frontmatter
2. Extract `name`

### 2c: Build Registry

Organize into a registry structure:

```text
Module: {module-name}
  Commands: [{name, description, argument-hint}, ...]
  Agents: [{name}, ...]
  Skills: [{name}, ...]
  Templates: [{name}, ...]
```

## Phase 3: Workflow Analysis (Overview mode only)

> Agent: **researcher**

Skip this phase in Detail mode — proceed directly to Phase 4.

Delegate workflow recommendation to the researcher agent via Task tool:

- **Input**: Discovery registry from Phase 2 (module list, command counts, agent/skill/template counts per module)
- **Instructions**: "Analyze the installed ouroboros capabilities using synthesis methodology per `skills/core/research/references/synthesis-patterns.md`. Based on the module composition and component distribution, produce: (1) Recommended starter workflows ranked by value, (2) Context-aware next steps identifying the most complex command, the smallest component for a quick evaluation win, and any module gaps. Use frontmatter field definitions from `skills/core/validation/references/frontmatter-and-fields.md` when interpreting component metadata. Keep recommendations concise — 3-5 workflow suggestions."
- **Expected output**: Workflow recommendations with rationale

### Recovery

| Failure | Action |
|---------|--------|
| Agent timeout/error | Fall back to static workflow suggestions (Getting Started, Self-Improvement Cycle, Knowledge Building). Log: "Workflow analysis unavailable — showing standard recommendations." |
| Incomplete output | Use available suggestions, supplement with static fallbacks for missing categories |

## Phase 4: Present

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

{Insert researcher's workflow recommendations from Phase 3. If Phase 3 fell back to static suggestions, use these defaults:}

- **Getting Started**: `/onboard <command>` → `/evaluate <component>` → `/evolve <component>`
- **Self-Improvement Cycle**: `/evaluate` (identify weakest) → `/evolve` (improve) → `/evaluate` (verify)
- **Knowledge Building**: `/research <source>` → `/absorb` → `/evolve`
- **Multi-Model Evaluation**: Install external CLIs → `/evaluate --multi` (routing: `skills/core/routing/SKILL.md`)
- **Staying Current**: `/upgrade --check` → `/upgrade` → `/evaluate`
- **Project Integration**: `/adopt <project-path>` → `/onboard`

### Next Steps

{Insert researcher's context-aware suggestions from Phase 3, or generate from discovery results:}

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

### Usage Examples

{Derive from argument-hint and command structure:}
- `/{command-name} {typical-usage-1}`
- `/{command-name} {typical-usage-2}`

### Related Commands

{Scan other commands in the same module and suggest related workflows:}
- `/{related-command}` — {how it connects to this command}

### Rules & Next Steps

{Extract key rules from the command's Rules section, if present}

- `/evaluate commands/{module}/{command-name}.md` — assess quality
- `/evolve commands/{module}/{command-name}.md` — improve weakest area
- `/onboard {related-command}` — explore related command
```

## Rules

- **Pure read-only**: This command never writes, creates, or modifies any files
- **Minimal agent use**: Only the researcher agent (Phase 3, Overview mode) for context-aware workflow recommendations. Discovery and parsing remain agent-free
- **No network**: All information comes from local file scanning
- **Graceful degradation**: If a module has no commands (empty directory), still list it with count 0
- **Frontmatter parsing**: Only read YAML frontmatter fields — do not parse or execute command body content
- **Command names**: Strip `.md` extension when displaying command names (e.g., `evaluate.md` → `evaluate`)

### Recovery

| Failure | Action |
|---------|--------|
| Missing plugin structure (`commands/` absent/empty) | Output diagnostic listing expected structure (`commands/`, `agents/`, `skills/`, `templates/`). Suggest: "Verify plugin installation path. Run `claude --plugin-dir <path>` to check." |
| Frontmatter parse failure | Skip file, continue remaining. Retry file once with Read(limit: 20). If still fails: append "Partial results" note listing skipped files |
| Inaccessible files (permissions, broken symlink) | Skip and include in partial results note |
| Detail mode: command not found | Suggest closest matches via Grep on available command names. If no close match: fall back to Overview mode |
