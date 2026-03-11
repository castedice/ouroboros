# Ouroboros — Development Journey

> From initial prototype to v1.0.0: how a meta-plugin built and improved itself.

## Phase 0: Foundation

Established the modular monolith layout: `commands/`, `agents/`, `skills/`, `templates/` separated by module (`core/`, `swe/`). Created the 4-document system (VISION, DECISIONS, STATUS, PLAN) for project governance.

## Phase 1: Core Meta-Plugin MVP

Built 9 core commands (5 primitives + 4 composites) that form the self-improvement cycle:

| Command | Key Design |
|---------|-----------|
| `/evaluate` | LLM-as-judge with tiered binary criteria and before/after comparison |
| `/evolve` | Researcher agent analyzes weaknesses, applies changes in isolated worktree |
| `/research` | 3 modes (local/web/topic), 4-layer security, knowledge base integration |
| `/generate` | Module generation (Mode A) + component generation (Mode B) |
| `/brainstorm` | Divergent + convergent thinking with multi-model consensus |
| `/absorb` | Research → Evaluate → Generate/Evolve pipeline for external sources |
| `/upgrade` | Fetch upstream → reconcile with local customizations → apply |
| `/adopt` | Analyze a codebase → generate AGENTS.md for multi-model development |
| `/onboard` | Discover capabilities, list commands, recommend workflows |

**Milestone**: Self-improvement cycle proven — evaluate → evolve → evaluate on 4 components. Self-bootstrap achieved — `/generate` used to create `/absorb`.

## Phase 2: Multi-Model Routing

Integrated Codex and Gemini alongside Claude for cross-model evaluation consensus. Built routing infrastructure (`invoke-model.sh`, relay prompt templates), worktree management (`worktree.sh` with 9 actions), and parallel fan-out/fan-in execution.

## Phase 3: Evaluation Automation

Created the tiered binary criteria system (Foundation 5 + Craft 7 + Excellence 4 = 16 criteria) with severity gating. Built regression tracking, output evaluation mode, and optimized model selection through [48-invocation experiment](experiments/model-optimization.md).

## Phase 4: Self-Dogfooding

Evaluated and improved all 15 core components to 16/16 Level 4. Discovered and quantified [self-evaluation bias](experiments/self-eval-bias.md) (ΔE=+2.2 concentrated in Excellence tier). Validated that Codex alone is sufficient as external corrective.

## Phase 5: SWE Module

Generated the first domain module — an 8-stage disciplined engineering pipeline (DDD + SDD + TDD):

| Batch | Components | Result |
|-------|-----------|--------|
| Foundation | Methodology skill + constraint skill + 7 references | All Level 4 |
| Spec (Stages 1-4) | 4 primitives + 1 composite + analyst agent | All Level 4 |
| Dev (Stages 5-8) | 4 primitives + 1 composite + implementer agent | All Level 4 |
| Ship + Tune | Reviewer agent + 2 composites + 3 templates | All Level 4 |
| Spiral | Meta-composite orchestrating all stages | Level 4 |

Dogfooded on a Rust project (mdsearch): 3 spiral tasks, 81 tests, real process improvements extracted.

## Phase 5.5: External Validation

Red-teamed with 3-way brainstorm (Claude + Codex + Gemini, 34 ideas). Permission audit, multi-language dogfooding (Python FastAPI + TypeScript React 19), release preparation.

## v0.13.0–v0.14.7: Quality Infrastructure

- Parallel evaluation (3× wall-clock reduction)
- [Unanimous convergence experiment](experiments/unanimous-convergence.md) — fact-based convergence proven effective
- Quality sprints: Core 97.89% Level 4, SWE 18/18 Level 4
- Deep research (`--deep` flag) with autonomous convergence
- Companion skills (research, generation, absorption methodologies)

## v0.15.0–v0.15.5: Spiral Evolution

Transformed the SWE spiral from a fixed linear pipeline to an adaptive system:

- **v0.15.0**: State machine infrastructure — `spiral-state.json` + checkpoint-rewind + cascade invalidation + circuit breaker. See [design analysis](designs/v0.15.0-spiral-analysis.md)
- **v0.15.1**: Probe policy — hypothesis-driven traversal (Light-first → confidence check → escalate)
- **v0.15.5**: Pipeline parallelism — stage-level parallel execution (Security ‖ Code Review) + multi-model review

## v0.16.0–v0.16.5: Team Spiral

Multi-agent pipelined execution: Director + 3 Specialists (Shaper/Builder/Critic). Each specialist runs composites concurrently, with auto-gates and cross-review between them. Added Bridge Agent for external model delegation via MCP, cross-turn learning, and team+probe policy composition.

## v0.17.0: SWE Feature Expansion

- `/swe reverse` — derive specification artifacts from existing code
- Persuasion skill — structured argumentation (Cialdini, Aristotle, Toulmin)
- Teaching skill — decision-focused knowledge transfer (Bloom's Taxonomy, ZPD)

## v0.18.0–v0.18.5: Developer Experience

Permission pattern fixes, LSP integration (4 language templates), plan mode interrogation, command defaults optimization (`--multi` auto-detect, `--deep` default on). Added `/doctor` health check, friction collection, session history.

## v0.19.0–v0.19.5: Living Project Model

Cumulative project-level specification that evolves across spiral turns (domain, constraints, architecture, interfaces). Knowledge INDEX for discoverability. Artifact path migration, monorepo support (pnpm/Cargo/Go/npm workspaces).

## v1.0.0: Public Release

- 44/44 components at Level 4 with Codex multi-model consensus
- Prompt injection defense (structural content isolation in relay prompts)
- 71 design decisions documented
- 11 knowledge base entries from external research

## Timeline

| Date | Phase | Highlights |
|------|-------|-----------|
| Feb 10 | Phase 0 | Document restructure |
| Feb 12-15 | Phase 1 | Core MVP — 9 commands, self-improvement cycle |
| Feb 16-17 | Phase 2 | Multi-model routing |
| Feb 18-21 | Phase 3-4 | Evaluation automation, self-dogfooding, all 16/16 |
| Feb 22-25 | Phase 5 | SWE module — 19 components, Rust dogfooding |
| Feb 26 | Phase 5.5 | Red team, permission audit, release prep |
| Feb 27-28 | v0.10-v0.12 | Hooks, session lifecycle, multi-model ecosystem |
| Mar 1 | v0.13-v0.14.7 | Evaluation infrastructure, quality sprints |
| Mar 2 | v0.15-v0.16.5 | Spiral evolution, team spiral |
| Mar 3 | v0.17-v0.18.5 | Feature expansion, DX improvements |
| Mar 4-11 | v0.19-v1.0 | Living Project Model, monorepo, public release |
