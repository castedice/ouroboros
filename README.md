# Ouroboros - Claude Code Plugin System

[![Release](https://img.shields.io/github/v/release/castedice/ouroboros)](https://github.com/castedice/ouroboros/releases/latest)
[![License](https://img.shields.io/github/license/castedice/ouroboros)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-plugin-blue)](https://docs.anthropic.com/en/docs/claude-code)

> A Claude Code plugin for meta-plugin development, disciplined software engineering, personal knowledge work, and bounded research.

## What is Ouroboros

Ouroboros is a Claude Code meta-plugin that researches, generates, evaluates, absorbs, and evolves plugin components.
It also works as a software engineering companion, a Personal Assistant for Obsidian vaults, and a bounded autonomous Research Agent.
The current public surface includes 4 modules, top-level `/rnd` and `/session-wiki` entrypoints, 20 agents, 31 skills, 75 shell scripts plus one JS proxy, and 51 Markdown templates plus JSON/LSP templates.

## Installation

```bash
git clone https://github.com/castedice/ouroboros.git
claude --plugin-dir ./ouroboros
```

That is enough to load the plugin and its project-scoped permissions from `.claude/settings.json`.

## Quick Start

```bash
# Discover available modules and recommended workflows
/onboard

# Run a full SWE cycle from spec through review and tuning
/swe spiral "Add session export filtering to the API"

# Onboard an existing Obsidian vault for PA
/pa survey ~/vaults/personal

# Ask a cited question against your vault
/pa ask "What did I decide about weekly review cadence?"

# Run a bounded research study
/rnd --budget 90 "What patterns make agent memory reliable in plugin workflows?"

# Propose a reviewed wiki page from archived session transcripts
/session-wiki propose --component session-archive --since 7d
```

## Modules

### Core

Core contains 10 meta-plugin commands for the plugin lifecycle.

| Command | Type | Purpose |
|---------|------|---------|
| `/evaluate` | Primitive | Score a component, compare versions, or evaluate output quality |
| `/evolve` | Primitive | Improve a component from evaluation findings |
| `/research` | Primitive | Study external sources, plugins, topics, or codebases |
| `/generate` | Primitive | Create a module or add a component to an existing module |
| `/brainstorm` | Primitive | Generate, compare, and narrow ideas |
| `/absorb` | Composite | Turn external sources into new or updated plugin components |
| `/upgrade` | Composite | Reconcile upstream ouroboros changes with local customizations |
| `/adopt` | Composite | Adopt ouroboros into a project and scaffold agent guidance |
| `/onboard` | Composite | Discover installed capabilities and choose a command |
| `/doctor` | Composite | Check CLI, MCP, hooks, settings, and plugin health |

### SWE

SWE contains 14 commands for an 8-stage engineering pipeline: understand -> constrain -> design -> interface -> test -> implement -> verify -> optimize.
Each stage supports Skip, Light, Standard, or Deep depth, with `linear`, `probe`, and `team` traversal policies.

| Command | Stage | Purpose |
|---------|-------|---------|
| `/swe understand` | 1 | Clarify requirements, domain concepts, and existing code |
| `/swe constrain` | 2 | Identify constraints, risks, and design boundaries |
| `/swe design` | 3 | Choose architecture, algorithms, and data shapes |
| `/swe interface` | 4 | Define contracts, invariants, and error handling |
| `/swe test` | 5 | Write tests from interface contracts |
| `/swe implement` | 6 | Write the minimal code that passes the tests |
| `/swe verify` | 7 | Check implementation against tests, spec, and acceptance criteria |
| `/swe optimize` | 8 | Improve performance or simplify based on measured evidence |
| `/swe spec` | 1-4 | Produce specification artifacts before coding |
| `/swe dev` | 5-8 | Drive an approved spec to working, verified code |
| `/swe ship` | Review | Run production-readiness, security, and code review |
| `/swe tune` | Feedback | Evaluate, improve, and capture lessons |
| `/swe spiral` | All | Run spec -> dev -> ship -> tune as one loop |
| `/swe reverse` | 1-4 reverse | Recover requirements, constraints, design, and interfaces from existing code |

### PA

PA is a personal assistant for Obsidian vaults with QMD-based retrieval, an entity graph, and a soul/persona layer for vault-native writing.
It adapts to an existing vault instead of imposing a new knowledge system.

| Command | Group | Purpose |
|---------|-------|---------|
| `/pa <request>` | Router | Route natural language to the right PA command |
| `/pa init` | Vault management | Bootstrap a fresh Obsidian vault for PA |
| `/pa survey` | Vault management | Onboard an existing vault and infer conventions |
| `/pa heartbeat` | Vault management | Check indexing, memory, cadence, and privacy state |
| `/pa steward` | Vault management | Run bounded routine vault maintenance |
| `/pa ask` | Knowledge | Answer a vault question with citations |
| `/pa brief` | Knowledge | Build a concise briefing on a topic, project, or person |
| `/pa focus` | Knowledge | Assemble goal-centered working context |
| `/pa link` | Knowledge | Discover or repair meaningful note and entity relationships |
| `/pa specialist` | Knowledge | Create, inspect, or manage domain specialists |
| `/pa capture` | Capture | Turn scraps, thoughts, or transcripts into structured vault material |
| `/pa ingest` | Capture | Bring external content into the vault |
| `/pa draft` | Capture | Create or revise a note in vault-native voice |
| `/pa compile` | Capture | Roll recent inputs into a durable period summary |
| `/pa day` | Planning | Produce a morning brief, evening closeout, or today status |
| `/pa agenda` | Planning | Surface current priorities, deadlines, and waiting-fors |
| `/pa review` | Planning | Inspect vault health, stale commitments, and forgotten context |
| `/pa reset` | Planning | Turn review findings into refreshed priorities and links |

### RnD

RnD contains one public command for bounded autonomous research studies.
Orchestration runs 13 baseline phases plus a conditional branch-grouping overlay and Phase 14 meta-research.
The persisted research stages are scope -> prior-work -> perspectives -> hypotheses -> experiment-design -> probes -> analyze-prune -> report -> review -> meta-learn.
The system also includes branch search, cumulative prior-work memory, multi-model adversarial peer review, and meta-research.

| Command | Purpose |
|---------|---------|
| `/rnd` | Run, resume, review, and archive a bounded research study |

## Architecture

```text
ouroboros/
├── .claude-plugin/plugin.json
├── commands/
│   ├── core/
│   ├── swe/
│   ├── pa/
│   ├── rnd.md
│   └── session-wiki.md
├── agents/
│   ├── core/
│   ├── swe/
│   ├── pa/
│   └── rnd/
├── skills/
│   ├── core/
│   ├── swe/
│   ├── pa/
│   └── rnd/
├── .agents/skills/
├── templates/
│   ├── core/
│   ├── swe/
│   ├── pa/
│   └── rnd/
├── hooks/
├── scripts/
├── docs/
├── dev/
├── CLAUDE.md
├── AGENTS.md
└── README.md
```

Commands orchestrate workflows and decide what runs when.
Agents execute bounded specialist tasks.
Skills provide reusable methodology and reference contracts.
Scripts and templates provide the runtime helpers and artifact scaffolds that commands and agents reuse.

| Agent | Module | Role |
|-------|--------|------|
| `brainstormer` | Core | Divergent idea generation and convergent ranking |
| `draft-writer` | Core | Isolated worktree draft writing |
| `evaluator` | Core | Component and output quality scoring |
| `generator` | Core | Module, component, and project guidance generation |
| `reconciler` | Core | Upstream/local version reconciliation |
| `researcher` | Core | Source analysis, project profiling, and improvement diagnosis |
| `session-synthesizer` | Core | Session wiki page synthesis from archive segments |
| `analyst` | SWE | Requirements, constraints, design, interface, and reverse-spec analysis |
| `implementer` | SWE | Test, implementation, verification, and optimization execution |
| `reviewer` | SWE | Security and four-perspective code review |
| `cartographer` | PA | Vault structure inference and profile drafting |
| `chief-of-staff` | PA | Priority judgment, agenda planning, and reset synthesis |
| `curator` | PA | Capture triage and durable-note routing |
| `librarian` | PA | QMD retrieval, context packs, and citation assembly |
| `scribe` | PA | Vault-native note drafting and revision |
| `sentinel` | PA | Review loops, stale commitments, and vault health checks |
| `weaver` | PA | Entity graph, relations, and link discovery |
| `collector` | RnD | Prior-work collection and evidence packet preparation |
| `critic` | RnD | Stage-gate review, falsifiability checks, and release verdicts |
| `investigator` | RnD | Briefing, hypotheses, probe contracts, reports, and meta-learning |

## Key Features

| Feature | Description |
|---------|-------------|
| Session archive | `scripts/session-archive.sh` indexes Claude transcripts into SQLite FTS5 for local search and retrieval |
| Session wiki | `/session-wiki` promotes archive knowledge through proposal-only flow: propose -> show -> apply or reject -> lint |
| Multi-model evaluation | Claude and Codex can be combined for consensus evaluation, adversarial review, and bias reduction |
| Learning pipeline | Evaluation, friction, tool-failure, and evolution outcomes are ingested, distilled, and loaded as prior learnings |
| Self-improvement loop | Core commands research, generate, evaluate, evolve, and absorb improvements back into the plugin |

## Configuration

`CLAUDE.md` contains Claude Code-specific operating guidance.
`AGENTS.md` contains shared guidance for Codex and other agents working in this repository.
`.claude/settings.json` defines project-scoped permissions, hooks, and plugin runtime settings.

## Development

The `dev/` directory contains development-only project documents.
Use `dev/VISION.md` for architecture philosophy, `dev/DECISIONS.md` for design decisions, `dev/MILESTONES.md` for roadmap tracking, and `dev/STATUS.md` for current session handoff.
These files are useful for contributing to ouroboros but are not required for installing or using the plugin.

## License

MIT
