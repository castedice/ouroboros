# Ouroboros — Claude Code Rules

> Claude Code-specific operational rules for developing ouroboros.
> Shared development guidelines (conventions, versioning, session workflow, commit rules) are in `AGENTS.md`.

## Plugin Structure

`commands/` (orchestration recipes) → delegate to `agents/` (execution engines) → reference `skills/` (methodology + criteria). `hooks/` (lifecycle automation), `scripts/` (shell utilities), `templates/` (output formats). Full directory tree in `AGENTS.md`.

## Operational Rules

### Skill Invocation

Ouroboros skills require fully qualified names: `ouroboros:{module}:{command}`. Short names fail.

- `Skill: ouroboros:core:evaluate` — correct
- `Skill: ouroboros:swe:spec` — correct
- `Skill: evaluate` — fails ("Unknown skill")

### Plan Mode Integration (DR-050, DR-064)

Use Claude Code's built-in plan mode (`EnterPlanMode`) actively for non-trivial implementation tasks on ouroboros itself:

- **Use plan mode**: before editing commands, agents, scripts, or skills (multi-file changes with design decisions). Explore the codebase, understand existing patterns, then present a plan
- **Skip plan mode**: when running ouroboros commands (`/evaluate`, `/evolve`, `/swe spiral`, etc.) — these commands have their own exploration and planning phases built in
- **Principle**: plan mode for "how to change ouroboros code", ouroboros commands for "how to use ouroboros methodology"
- **No hook automation**: `PostToolUse:EnterPlanMode` only fires on programmatic calls, not user-initiated plan mode (`Shift+Tab`). Do not depend on hooks for plan mode detection
- **`allowed-tools` overlap**: command frontmatter `allowed-tools` already provides write protection similar to plan mode's read-only constraint. These are complementary, not redundant — `allowed-tools` scopes the command, plan mode scopes the session

**Plan mode interrogation** — eliminate ambiguity and align with the user's mental model:

- If requirements are ambiguous, use AskUserQuestion to clarify before incorporating into the plan
- If 2+ reasonable approaches exist, state the trade-offs explicitly and ask the user to choose
- Restate key assumptions explicitly so the user can verify them
- Before ExitPlanMode, ask at least 1 question to confirm requirements or get approach selection

### Model Routing — Cost Efficiency

Opus is the default for design, analysis, and synthesis. Route lightweight operations to sonnet to save cost:

| Operation | Model | How |
|-----------|-------|-----|
| Web search / content fetch | sonnet | `Agent(model: "sonnet", subagent_type: "general-purpose")` — search and summarize |
| Codebase exploration | sonnet | `Agent(model: "sonnet", subagent_type: "Explore")` — file/pattern searching |
| Mechanical fixes | sonnet | `Agent(model: "sonnet")` — formatting, simple refactoring, hook warning fixes |
| Design decisions, evaluation, synthesis | opus | Direct in main conversation — requires judgment |

When in doubt, keep opus. Rework from low quality costs more than the opus premium.

### Tool Selection Guidance

Tool selection priority for efficient codebase work:

- **LSP first**: In projects with `.lsp.json`, prefer `lsp_goto_definition` over Grep, use `lsp_hover` for type checking, `lsp_diagnostics` for pre-build error detection
- **Explore agent**: Use `Agent(model: "sonnet", subagent_type: "Explore")` when search scope is broad or 3+ queries are expected. For simple 1-2 searches, use Glob/Grep directly
- **WebFetch/WebSearch**: Always delegate to a sonnet agent. Never call directly from main context (prevents context pollution)

### Safe Deletion (DR-044)

- AI must not use `rm` directly — `Bash(rm *)` is denied in settings.json
- For temp file cleanup: use `bash scripts/session.sh cleanup {SESSION_ID}`
- All scripts use `scripts/safe-rm.sh` internally — deleted files go to project-local `.trash/` (recoverable)
- Recovery: `bash scripts/safe-rm.sh list` to find, `bash scripts/safe-rm.sh restore <name>` to recover
- Periodic cleanup: `bash scripts/safe-rm.sh purge --days 7`

## Claude Code Session Extensions

### Dogfooding — Mandatory Tool-First Approach

Always use ouroboros commands, agents, skills, and scripts before manual work:

- `/generate` over hand-writing, `/evaluate` over manual scoring, scripts over ad-hoc git operations
- Fall back to Claude Code built-ins only when ouroboros has no coverage. Document gaps in `dev/STATUS.md` backlog

### Session Naming

Suggest a descriptive session name when starting a meaningful work unit. Examples: "v0.18.0 DX quick wins", "evaluate spiral fix". Only suggest the name as text — the user invokes `/rename` themselves. PreCompact also suggests a name based on session summary.

### Compaction Recovery

Context compaction summarizes older conversation to free space. CLAUDE.md is reloaded from disk after compaction, so these instructions persist. The PreCompact hook outputs a compact change summary (recent commit messages + diff summary + session name suggestion) that gets included in the compaction summary. STATUS.md state is injected separately by SessionStart after compaction — no duplication between hooks.

After compaction occurs:

1. Re-read `dev/STATUS.md` — the SessionStart hook auto-injects it on `/compact` and `/clear`, but if auto-compacted mid-session, read it manually
2. Run `git diff --stat HEAD~3` to restore awareness of recent file changes
3. Check the task list (`TaskList`) if tasks were created before compaction
4. Do not rely on specific details from pre-compaction conversation — re-read source files as needed

To maximize compaction quality, work in focused units and update `dev/STATUS.md` frequently. When manually compacting, use `/compact "preserve: current task state, modified files, pending decisions"` to guide the summary.

### Hook Response

PostToolUse hook (`format.sh`) runs after every Write/Edit. When it produces output:

- **No output** → clean, continue
- **Lint warnings** → act on them before proceeding:
  - Mechanical fixes (formatting, whitespace, line structure): apply directly via Edit
  - Judgment-needed fixes (code block content, structural issues): delegate to sonnet via Task tool
- Do not ignore hook output — treat warnings as work items until resolved

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
- Session workflow, coding style, commit rules → `AGENTS.md`

**Principle:** If it's worth remembering across sessions, it belongs in a Git-managed document. MEMORY.md supplements — it never duplicates.
