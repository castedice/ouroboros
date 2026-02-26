# Ouroboros — Development Guidelines

> Guidelines for developing the ouroboros codebase itself.
> For philosophy and architecture, see `dev/VISION.md`. For design decisions, see `dev/DECISIONS.md`.

## Core Principles

1. **Co-Evolution**: User + AI + process improve together through every cycle
2. **Compound Growth**: Every task makes the next one easier — codify learnings
3. **Right-sized Abstraction**: No excessive layers, no hardcoding

## Plugin Development Conventions

> Rules for plugin structure — both ouroboros itself and modules it generates.

### Modular Monolith Layout (DR-012)

```text
ouroboros/
├── .claude-plugin/plugin.json
├── commands/{module}/        # User-invoked slash commands
├── agents/{module}/          # Specialized sub-agents (Task tool workers)
├── skills/{module}/          # Auto-triggered methodology knowledge
├── templates/{module}/       # Document templates
├── hooks/hooks.json          # Event-driven hooks
├── scripts/                  # Hook execution scripts
├── CLAUDE.md                 # This file — AI behavioral guidelines
└── README.md                 # User documentation
```

Modules: `core/` (meta-plugin capabilities), `dev/` (software development), `research/`, `assistant/`

### Language Rule

- **All implementation files in English** — no Korean in committed files (commands, agents, skills, templates, scripts, hooks)

### Format Rules

- **Agent frontmatter**: `name`, `description`, `model`, `tools`, `color`
- **Skill description**: third-person trigger phrases (auto-triggered, not user-invoked)
- **Command frontmatter**: `description`, `allowed-tools`, `argument-hint`
- **Hooks**: `hooks.json` requires `description` and `timeout` fields
- **Commands are orchestration** (what/when), **Skills are knowledge** (how), **Agents are execution** (do)

### Generated Module Guidelines

- Plugin keeps `CLAUDE.md` (auto-injected by Claude Code)
- User projects get `AGENTS.md` (multi-model compatible: Claude, Gemini CLI, Codex CLI)
- `${CLAUDE_PLUGIN_ROOT}` works in hooks and commands for relative paths

> Coding conventions (Python/TS/Rust) and document templates archived in `dev/references/coding-conventions.md`. Restore when coding phase begins.

## Operational Rules

### Skill Invocation

Ouroboros skills require fully qualified names: `ouroboros:{module}:{command}`. Short names fail.

- `Skill: ouroboros:core:evaluate` — correct
- `Skill: ouroboros:swe:spec` — correct
- `Skill: evaluate` — fails ("Unknown skill")

### Plan Mode Integration

Use Claude Code's built-in plan mode (`EnterPlanMode`) actively for non-trivial implementation tasks on ouroboros itself:

- **Use plan mode**: before editing commands, agents, scripts, or skills (multi-file changes with design decisions). Explore the codebase, understand existing patterns, then present a plan
- **Skip plan mode**: when running ouroboros commands (`/evaluate`, `/evolve`, `/swe spiral`, etc.) — these commands have their own exploration and planning phases built in
- **Principle**: plan mode for "how to change ouroboros code", ouroboros commands for "how to use ouroboros methodology"

### Model Routing — Cost Efficiency

Opus is the default for design, analysis, and synthesis. Route lightweight operations to sonnet to save cost:

| Operation | Model | How |
|-----------|-------|-----|
| Web search / content fetch | sonnet | `Task(model: "sonnet", subagent_type: "general-purpose")` — search and summarize |
| Codebase exploration | sonnet | `Task(model: "sonnet", subagent_type: "Explore")` — file/pattern searching |
| Mechanical fixes | sonnet | `Task(model: "sonnet")` — formatting, simple refactoring, hook warning fixes |
| Design decisions, evaluation, synthesis | opus | Direct in main conversation — requires judgment |

When in doubt, keep opus. Rework from low quality costs more than the opus premium.

### Safe Deletion (DR-044)

- AI must not use `rm` directly — `Bash(rm *)` is denied in settings.json
- For temp file cleanup: use `bash scripts/session.sh cleanup {SESSION_ID}`
- All scripts use `scripts/safe-rm.sh` internally — deleted files go to project-local `.trash/` (recoverable)
- Recovery: `bash scripts/safe-rm.sh list` to find, `bash scripts/safe-rm.sh restore <name>` to recover
- Periodic cleanup: `bash scripts/safe-rm.sh purge --days 7`

## Session Workflow

### Session Start

1. Read `dev/STATUS.md` — current state, detailed tasks, and what to do next
2. Read `dev/PLAN.md` — roadmap context (which phase, which feature)
3. If architectural context needed, read `dev/VISION.md` and `dev/DECISIONS.md`

### During Session

- Work in **small, focused units** — one task at a time, commit per unit. Keeps context manageable across sessions
- **Top-down approach**: vision and architecture first, then implementation details
- **Evaluate-first mindset**: measure before improving, prove before expanding
- **Dogfooding — mandatory tool-first approach**: Always use ouroboros commands, agents, skills, and scripts before resorting to manual work. This is not a suggestion — it is a core development principle
  - **Commands** (`/generate`, `/evaluate`, `/evolve`, `/research`, `/absorb`, `/brainstorm`): use for all module and component lifecycle operations. Never hand-write components that `/generate` can scaffold. Never manually score quality that `/evaluate` can measure
  - **Agents** (`generator`, `evaluator`, `researcher`, `reconciler`, `brainstormer`): delegate via Task tool with proper `subagent_type` (e.g., `ouroboros:core:evaluator`). Never inline evaluation logic or generation logic in the main conversation
  - **Skills**: let auto-triggered methodology knowledge guide decisions. Reference skill files in agent instructions rather than re-explaining methodology inline
  - **Scripts** (`worktree.sh`, `invoke-model.sh`, `format.sh`): use for worktree lifecycle, multi-model invocation, and formatting. Never manually create branches or run ad-hoc git operations that scripts already handle
  - Fall back to Claude Code built-in features only when ouroboros has no coverage for the task. Document gaps in `dev/STATUS.md` backlog for future plugin improvement
- Work through the detailed tasks in `STATUS.md`
- Discuss with the user before making significant design decisions
- Record new design decisions in `dev/DECISIONS.md`

### Hook Response

PostToolUse hook (`format.sh`) runs after every Write/Edit. When it produces output:

- **No output** → clean, continue
- **Lint warnings** → act on them before proceeding:
  - Mechanical fixes (formatting, whitespace, line structure): apply directly via Edit
  - Judgment-needed fixes (code block content, structural issues): delegate to sonnet via Task tool
- Do not ignore hook output — treat warnings as work items until resolved

### Session End

- Update `dev/STATUS.md`:
  - What was done this session
  - Detailed tasks for next session (specific enough for a fresh AI to continue)
  - Any blockers or open questions
- Update `dev/PLAN.md` checkboxes if roadmap-level items were completed
- Update `MEMORY.md` only if platform gotchas or user environment changed (see Memory Policy below)
- If workflow itself improved, reflect in this section
- Notify the user that changes are ready to commit (do NOT commit or ask to commit — just inform)

### Commit Rules

- All commit messages in **English**
- Update documents (STATUS.md, PLAN.md, etc.) **before** committing — docs are part of the commit
- One meaningful commit per logical unit of work, not per file
- When only doc/meta changes remain after a commit, amend rather than creating a noise commit
- **Never propose commits unprompted** — show document updates to the user, commit only when they ask

### Memory Policy

`MEMORY.md` (auto memory) is for **repeated injection only** — things the AI needs every session but that don't belong in Git-managed documents.

**What goes in MEMORY.md:**

- Claude Code platform gotchas (tool constraints, permission quirks, restart requirements)
- User environment specifics (personal paths, setup commands)

**What does NOT go in MEMORY.md:**

- Project state, progress, next tasks → `dev/STATUS.md`
- Architecture decisions, design rationale → `dev/DECISIONS.md`
- Roadmap, phase tracking → `dev/PLAN.md`
- Lessons learned, backlog items → `dev/STATUS.md` backlog section
- Session workflow, coding style, commit rules → this file (`CLAUDE.md`)

**Principle:** If it's worth remembering across sessions, it belongs in a Git-managed document. MEMORY.md supplements — it never duplicates.

### Document Roles

| Document | Role | Read frequency |
|----------|------|----------------|
| `dev/STATUS.md` | **Handover** — where we are, detailed next tasks | Every session start |
| `dev/PLAN.md` | **Roadmap** — phase/feature-level checkboxes | When needing big picture |
| `dev/VISION.md` | **Architecture** — philosophy, capabilities, module structure | When making design choices |
| `dev/DECISIONS.md` | **Decision log** — why we chose X over Y | When revisiting past decisions |
