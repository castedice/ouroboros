# Ouroboros — Development Guidelines

> Guidelines for AI agents developing the ouroboros codebase.
> For philosophy and architecture, see `dev/VISION.md`. For design decisions, see `dev/DECISIONS.md`.
> Core principles (Co-Evolution, Compound Growth, Right-sized Abstraction) are defined in `dev/VISION.md`.

## Plugin Development Conventions

- **All implementation files in English** — commands, agents, skills, templates, scripts, hooks, dev docs
- Frontmatter and format conventions: follow existing files as reference
- `CLAUDE.md` is for Claude Code-specific operational rules. `AGENTS.md` (this file) contains shared development guidelines for all AI agents
- **One sentence per line** — do not break a single sentence across multiple lines (no semantic line breaks)

## Coding Style

- Prefer concise, readable code
- No over-abstraction, unnecessary error handling, or future-proofing
- Make only the minimal changes needed for the current task
- Do not add features, refactor code, or make improvements beyond what was asked

## Dual-Model Collaboration

- In multi-model work, separate controller and executor responsibilities explicitly
- The controller sets goals, constraints, boundaries, verbatim invariants, and acceptance criteria
- The executor owns the delegated slice after handoff and chooses implementation details within that contract
- Pass user-stated invariants verbatim, but do not over-specify the implementation
- Avoid shadow ownership, where the controller silently retakes delegated work instead of reviewing it
- Avoid mid-flight steering, because it creates oscillation without a clean ownership reset
- Bound review to two rounds of issues and reasoning for unresolved disagreements
- Escalate to the user only for genuine ambiguity, irreducible trade-offs, or persistent bounded disagreement
- Summarize resolved disagreements instead of dumping full inter-model transcripts

## Versioning

This project uses [Semantic Versioning](https://semver.org/). Current version is in `.claude-plugin/plugin.json`.

- **When to bump**: after completing a version milestone defined in `dev/MILESTONES.md`
- **What to update together**: `plugin.json` version + `CHANGELOG.md` (move Unreleased items to new version section)
- **CHANGELOG format**: [Keep a Changelog](https://keepachangelog.com/) — Added/Changed/Fixed/Removed categories
- **During development**: new changes accumulate under `[Unreleased]` in CHANGELOG.md
- **MILESTONES.md alignment**: backlog items are grouped by target version. When a version is complete, items move to CHANGELOG.md via ROADMAP.md

## Session Workflow

### Session Start

1. Read `dev/STATUS.md` — current state, immediate next tasks
2. Read `dev/MILESTONES.md` — backlog and upcoming work
3. If project history needed, read `docs/ROADMAP.md`
4. If architectural context needed, read `dev/VISION.md` and `dev/DECISIONS.md`

### During Session

- Work in **small, focused units** — one task at a time, commit per unit. Keeps context manageable across sessions
- **Top-down approach**: vision and architecture first, then implementation details
- **Evaluate-first mindset**: measure before improving, prove before expanding
- Work through the detailed tasks in `STATUS.md`
- Discuss with the user before making significant design decisions
- Record new design decisions in `dev/DECISIONS.md`

### Session End

- Update `dev/STATUS.md`:
  - What was done this session
  - Detailed tasks for next session (specific enough for a fresh AI to continue)
  - Any blockers or open questions
- Update `dev/MILESTONES.md` checkboxes if roadmap-level items were completed
- If workflow itself improved, reflect in the appropriate guideline file
- Notify the user that changes are ready to commit (do NOT commit or ask to commit — just inform)

### Commit Rules

- All commit messages in **English**
- Update documents (STATUS.md, MILESTONES.md, etc.) **before** committing — docs are part of the commit
- One meaningful commit per logical unit of work, not per file
- When only doc/meta changes remain after a commit, amend rather than creating a noise commit
- **Never propose commits unprompted** — show document updates to the user, commit only when they ask

## Document Roles

| Document | Purpose | When to Read |
|----------|---------|--------------|
| `dev/STATUS.md` | Current state, next tasks | Every session start |
| `dev/MILESTONES.md` | Backlog and upcoming work | When planning next work |
| `docs/ROADMAP.md` | Project history | When understanding past decisions |
| `dev/VISION.md` | Architecture philosophy | When making design choices |
| `dev/DECISIONS.md` | Design decision records | When making design choices |

## Project Structure

```text
ouroboros/
├── commands/          # Command definitions (core/, swe/)
│   ├── core/          # Meta-plugin commands (research, generate, evaluate, evolve, ...)
│   └── swe/           # Software engineering commands (understand, constrain, design, ...)
├── agents/            # Agent definitions (core/, swe/)
│   ├── core/          # Meta-capability agents (evaluator, researcher, generator, ...)
│   └── swe/           # Development agents (analyst, implementer, reviewer)
├── skills/            # Skill definitions with SKILL.md + references/ (Claude Code plugin)
│   ├── core/          # Shared methodology (evaluation, validation, brainstorming, ...)
│   └── swe/           # Domain-specific methodology (constraint, methodology)
├── .agents/skills/    # Cross-tool ported skills (Codex CLI compatible)
│                      # Generated via scripts/port-skills.sh — do not edit directly
├── templates/         # Output templates (core/, swe/)
├── hooks/             # Hook definitions
├── scripts/           # Utility scripts
├── dev/               # Development documentation
├── .claude-plugin/    # Plugin metadata (plugin.json)
├── AGENTS.md          # Shared development guidelines (this file)
└── CLAUDE.md          # Claude Code-specific operational rules
```

## Plugin Runtime Data

- `${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/{id}/`
- Claude Code creates this directory automatically for each plugin
- Data stored there survives plugin updates
- Use it for persistent plugin-owned state, not for files that should be committed to the repository
