# Ouroboros — The Plugin That Builds Plugins

> Like the serpent eating its own tail, each cycle makes the next one stronger

Ouroboros is a **meta-plugin** for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). It researches, generates, evaluates, and evolves Claude Code plugins — including itself. It ships with two modules: **Core** (meta-plugin operations) and **SWE** (disciplined software engineering).

## Installation

```bash
git clone https://github.com/castedice/ouroboros.git
claude --plugin-dir ./ouroboros
```

That's it. The plugin includes project-scoped permissions (`.claude/settings.json`) so commands work out of the box.

## Quick Start

```bash
# Discover what's available
/onboard

# Run a full engineering cycle on a task
/swe spiral "Add user authentication to the API"

# Evaluate a plugin component's quality
/evaluate commands/swe/spiral.md

# Improve a component based on evaluation
/evolve commands/swe/spiral.md

# Research an external plugin or methodology
/research https://github.com/some/plugin

# Reverse-engineer specs from existing code
/swe reverse src/auth/

# Check system health
/doctor

# Generate a new module
/generate assistant "Personal assistant for Obsidian vault management"

# Brainstorm ideas with multi-model consensus
/brainstorm "How should we handle offline sync?" --multi
```

## Modules

### Core Module — Meta-Plugin Operations

10 commands (5 primitives + 5 composites) for the plugin lifecycle:

#### Primitives

| Command | Description |
|---------|-------------|
| `/evaluate` | Assess component quality — static scoring, output evaluation, or before/after comparison |
| `/evolve` | Improve a component — analyze weaknesses, plan changes, apply, validate |
| `/research` | Research external sources — analyze plugins, fetch web content, build knowledge base |
| `/generate` | Create a new module or add a component to an existing module |
| `/brainstorm` | Explore ideas through divergent and convergent thinking |

#### Composites

| Command | Description |
|---------|-------------|
| `/absorb` | Absorb external sources — Research + Evaluate + Generate/Evolve pipeline |
| `/upgrade` | Upgrade from upstream — fetch changes, reconcile with local customizations |
| `/adopt` | Adopt ouroboros into a project — analyze codebase, generate AGENTS.md |
| `/onboard` | Discover capabilities — list modules, commands, and recommended workflows |
| `/doctor` | System health check — verify CLI tools, MCP servers, hooks, settings |

### SWE Module — Software Engineering Companion

14 commands implementing an 8-stage disciplined pipeline: **Spec** (DDD) + **Dev** (TDD) + **Ship** (Review) + **Tune** (Feedback).

#### Stage Commands

| Stage | Command | Methodology | Description |
|-------|---------|-------------|-------------|
| 1 | `/swe understand` | DDD | Analyze requirements, model problem domain, survey existing code |
| 2 | `/swe constrain` | SDD | Enumerate constraints and design boundaries |
| 3 | `/swe design` | DDD | Architecture decisions, algorithm selection, bounded by constraints |
| 4 | `/swe interface` | SDD | Define contracts — types, error conditions, invariants |
| 5 | `/swe test` | TDD | Write tests against interface contracts (Red Phase) |
| 6 | `/swe implement` | TDD | Write minimal code to pass all tests (Green Phase) |
| 7 | `/swe verify` | TDD | Verify implementation against acceptance criteria |
| 8 | `/swe optimize` | TDD | Profile, optimize, and refactor based on measured data |

#### Composites

| Command | Stages | Description |
|---------|--------|-------------|
| `/swe spec` | 1-4 | Specification — from problem to interface contracts |
| `/swe dev` | 5-8 | Development — from contracts to working code |
| `/swe ship` | Review | Security review, code review, deploy readiness |
| `/swe tune` | Feedback | Evaluate, improve, retrospect — extract learnings |
| `/swe spiral` | All | Full engineering cycle: spec + dev + ship + tune |
| `/swe reverse` | 1-4 (reverse) | Derive specification artifacts from existing code |

#### Depth System

Every stage has a configurable depth level: **Skip**, **Light**, **Standard**, **Deep**. Depth is per-stage, not per-project — a bug fix might use Light/Understand + Standard/Test while a new service uses Deep/Design + Standard/Implement.

Three **traversal policies** control how stages are traversed:

- **probe** (default) — Light-first exploration with confidence-gated escalation
- **linear** — execute all stages at specified depth
- **team** — multi-agent pipelined execution (Director + Shaper/Builder/Critic)

```bash
# Probe policy (default) — explore light, escalate if needed
/swe spiral "Fix pagination bug"

# Custom depth per composite
/swe spiral "Add user authentication" --depth S:Deep D:Standard H:Light N:Light

# Team policy — multi-agent parallel execution
/swe spiral "New authentication service" --policy team
```

## Architecture

```
ouroboros/
├── .claude-plugin/plugin.json    # Plugin manifest
├── commands/{core,swe}/          # User-invoked slash commands
├── agents/{core,swe}/            # Specialized sub-agents
├── skills/{core,swe}/            # Auto-triggered methodology knowledge
├── templates/{core,swe}/         # Document templates
├── hooks/hooks.json              # Event-driven hooks (PostToolUse format check)
├── scripts/                      # Shell scripts (worktree, formatting, model invocation)
├── docs/specs/                   # Living project model + knowledge base
├── CLAUDE.md                     # Claude Code behavioral guidelines
├── AGENTS.md                     # Multi-model development guidelines
└── README.md                     # This file
```

**Commands** are orchestration (what/when), **Skills** are knowledge (how), **Agents** are execution (do).

### Agents

| Agent | Module | Role |
|-------|--------|------|
| evaluator | core | Quality assessment with tiered binary criteria |
| researcher | core | Pattern extraction, source analysis, project profiling |
| generator | core | Module/component creation from specifications |
| reconciler | core | Version reconciliation and 3-way merge analysis |
| brainstormer | core | Divergent idea generation with convergent evaluation |
| analyst | swe | Requirements analysis, constraint enumeration, architecture design, interface contracts |
| implementer | swe | TDD test writing, code implementation, verification, optimization |
| reviewer | swe | Security review, 4-perspective code review |
| bridge | swe | External model delegation via MCP (Codex) |

### Multi-Model Support

Commands support `--multi` for cross-model evaluation consensus. When enabled, ouroboros invokes Codex alongside Claude, then synthesizes results using majority-rule consensus. This mitigates self-evaluation bias.

```bash
/evaluate commands/swe/spiral.md --multi
/brainstorm "Architecture options for caching layer" --multi
```

Requires [Codex CLI](https://github.com/openai/codex) installed. Auto-detected; gracefully degrades if unavailable.

## Philosophy

**Co-Evolutionary Self-Improvement**: user, AI, and process evolve together through every cycle.

- **Compound Growth** — every task makes the next one easier
- **Right-sized Abstraction** — no excessive layers, no hardcoding
- **Evaluate-first** — measure before improving, prove before expanding
- **Dogfooding** — ouroboros builds and improves itself using its own commands

## Development

The `dev/` directory contains internal development documents (not required for using ouroboros):

- `dev/VISION.md` — Architecture philosophy and module roadmap
- `dev/DECISIONS.md` — Design decision log (DR-001 through DR-071)
- `dev/PLAN.md` — Implementation roadmap with phase tracking
- `dev/STATUS.md` — Session handover document
- `AGENTS.md` — Shared development guidelines for all AI agents

## License

MIT
