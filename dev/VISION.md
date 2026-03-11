# Ouroboros — Vision

> Like the serpent eating its own tail, each cycle makes the next one stronger

## Philosophy: Co-Evolutionary Self-Improvement

Three entities grow simultaneously with every cycle:

1. **The User** — gains deeper understanding of principles, patterns, and tradeoffs
2. **The AI** — accumulates project-specific knowledge, sharpens criteria
3. **The Process** — templates refine, conventions solidify, automation improves

This is not just knowledge accumulation — it is evolution. Each cycle's output feeds back into the system, making the next cycle qualitatively different.

- **Compound Growth** is the mechanism — how improvement happens
- **Co-Evolution** is the scope — who improves (all three entities)
- **Self-Improvement** is the depth — the system evolves itself, not just its outputs

Ouroboros is a modular monolith — development, research, and assistant capabilities coexist within a single plugin. Regardless of which module the user engages, the co-evolution of all three entities operates identically, and learnings are naturally shared across modules.

## Meta-Plugin Architecture

Ouroboros is **a plugin that builds plugins** — and **a plugin that evolves itself**.

### Core Capabilities

Eight capabilities organized into three lifecycles plus one cross-cutting concern (DR-015):

#### Acquisition — learn, create, integrate

**1. Research**
Analyze plugins, development methodologies, and best practices:

- Study plugin repositories (structure, conventions, prompt engineering)
- Research established methodologies and community best practices
- Build a knowledge base of plugin development insights
- Compare approaches across different plugin ecosystems

**2. Generate**
Extend the modular monolith with new modules:

- Scaffold module structure (commands, agents, skills, hooks, templates)
- Generate appropriate agents and commands for the target domain
- Apply best practices from accumulated knowledge
- Produce module-level CLAUDE.md / AGENTS.md guidelines

**3. Absorb**
Absorb third-party plugins into the monolith as modules:

- Analyze external plugin structure and convert to ouroboros module format
- Evaluate quality before absorption (orchestrates Evaluate)
- Track origin and version for safe future upgrades
- The plugin is not just added but transformed into part of the system

#### Maintenance — improve, update safely

**4. Evolve**
Improve existing sub-modules based on usage and feedback:

- Observe how modules are actually used vs how they were designed
- Identify friction points, underused features, missing capabilities
- Suggest and apply improvements (prompt tuning, agent restructuring, workflow optimization)
- Feed improvements back into generation templates

**5. Upgrade**
Safe version updates across all content types:

- Distinguish built-in, absorbed, and user-customized content
- Merge upstream changes without losing customizations
- Detect and resolve conflicts between content layers
- Track what changed for rollback if needed

#### Deployment — fit project, guide user

**6. Adopt**
Analyze existing project, configure, and initialize (subsumes Setup):

- Understand the project's codebase, conventions, and structure
- Auto-adjust plugin settings to match the project context
- Generate project-specific AGENTS.md and configuration
- Ensure alignment with existing documentation and patterns

**7. Onboard**
Guide users through the plugin's features and usage:

- Present available capabilities and their roles
- Recommend context-appropriate workflows with examples
- Increasingly important as the plugin grows — prevent users from getting lost

#### Cross-cutting

**8. Evaluate**
Assess plugin/module quality through quantitative and qualitative measures:

- Determine whether generation/evolution actually improved the result
- LLM-as-a-judge combined with human evaluation
- Used across all phases: pre-Absorb quality check, post-Evolve validation, post-Generate sanity check
- The evaluation criteria themselves are a subject of evolution

### Module Architecture (Modular Monolith)

Capabilities are organized as domain modules within a single plugin:

```text
ouroboros/
├── commands/
│   ├── core/         # research, generate, absorb, evolve, upgrade, adopt, onboard, evaluate, brainstorm
│   ├── dev/          # plan, work, review, compound, spiral...
│   ├── pa/           # (personal assistant — TBD)
│   └── rnd/          # (research & development — TBD)
├── agents/
│   ├── core/         # meta-capability agents (evaluator, researcher, generator, reconciler, brainstormer)
│   ├── dev/          # software development agents
│   └── ...
├── skills/
│   ├── core/         # shared methodology (evaluation, validation, brainstorming, routing)
│   └── dev/          # domain-specific methodology
└── templates/
    ├── core/         # plugin generation templates
    └── dev/          # SDD document templates
```

**Why modular monolith:**

- Cross-module synergy: development methodology feeds R&D, R&D findings feed PA knowledge base, PA knowledge feeds development
- Co-Evolution philosophy operates naturally within a single system
- Shared capabilities (core /research, brainstorm, evaluate, evolve) without duplication
- Single repo, single version, single install

**Risk mitigation:**

- Per-module namespaces prevent command collisions
- Clear internal module boundaries keep future splitting cost low
- Context size measurement tests at key milestones

## Domain Modules — Roadmap

Core module is the meta-plugin foundation — it builds, evaluates, and evolves the plugin itself. Domain modules are what users actually use. Each module serves a distinct professional role with its own workflows, but they share core capabilities (research, evaluate, evolve, brainstorm) and cross-feed knowledge.

| Order | Module | Serves | One-Line Description |
|-------|--------|--------|---------------------|
| 1st | **SWE** | Software Engineers | Software engineering companion — disciplined Spec (requirements → contracts) + Dev (implementation → verification) + Ship (CI/CD, deployment) + Tune (evaluate → improve) |
| 2nd | **PA** | Everyone (personal) | Obsidian-based second brain — knowledge management, scheduling, personal assistant with full vault awareness |
| 3rd | **R&D** | Data Scientists / Researchers | Autonomous research agent — receives research questions, independently experiments, produces findings |

### Cross-Cutting: Research

Research was originally planned as a standalone module but was reconsidered. External deep research tools (Claude/ChatGPT/Gemini deep research) already excel at multi-hop information gathering. Building a competitive alternative within ouroboros is not cost-effective (opus tokens for web search, quality gap vs dedicated services).

Instead, research capability is structured as:
- **Core `/research`** — existing command for single-source analysis and knowledge entry generation. Planned 2-tier optimization (collector: sonnet/haiku for I/O, analyzer: opus for synthesis) to reduce cost
- **External injection** — user runs deep research via web tools, converts results to markdown, injects into the system
- **PA knowledge management** — the injected research is organized, linked, and made queryable within the Obsidian vault

### SWE Module — Software Engineering Companion

> DR-039: SWE Module Naming and Structure, DR-040: Initial Scope (Build + Ship)

**Problem**: AI-assisted software development currently only replaces code implementation — but real software engineering involves much more: translating requirements into technical solutions, maintaining system consistency, architecture under constraints, technology trade-off analysis, team skill considerations, and long-term maintainability. Conversational AI development provides no real productivity gain beyond typing speed. Worse, AI-written code is often over-engineered (excessive abstraction) or under-engineered (barely meets requirements), making it unsuitable for long-term use.

**Solution**: A disciplined engineering methodology grounded in DDD + SDD + TDD that AI follows rigorously, covering Spec → Dev → Ship → Tune. The methodology produces human-readable artifacts at every stage, enforces constraint-aware design decisions, writes tests before implementation, and defines interface contracts before coding begins.

**Module name**: `swe` (Software Engineering). Commands live in `commands/swe/`, agents in `agents/swe/`, etc.

**Scope — Spec + Dev + Ship + Tune**:

```text
┌──────────────────────────────────────────────────────────────────┐
│                         SWE Module                               │
│                                                                  │
│  ┌── Spec (SDD+DDD) ┐  ┌── Dev (TDD) ──┐  ┌─ Ship ─┐  ┌Tune─┐ │
│  │ Understand  (DDD) │  │ Test      (R) │  │ I-Test │  │Eval │ │
│  │ Constrain   (SDD) │  │ Implement (G) │  │ SecRev │  │Impr.│ │
│  │ Design      (DDD) │  │ Verify        │  │ Review │  │Retro│ │
│  │ Interface   (SDD) │  │ Optimize  (R) │  │ Deploy │  │     │ │
│  └────────────────────┘  └───────────────┘  └────────┘  └─────┘ │
│                                                                  │
│  Spiral = Spec → Dev → Ship → Tune (one upward turn)            │
│                                                                  │
│  spec → dev → ship → tune                                       │
│    ↑                    ↓                                        │
│    └────────────────────┘  (spiral: each turn elevates)          │
│                                                                  │
│  (R)=Red, (G)=Green, (R)=Refactor — TDD cycle                   │
│  External tools ←→ MCP adapters (hexagonal, future)              │
└──────────────────────────────────────────────────────────────────┘
```

**Pipeline Architecture** — Invariant 8 stages, variable depth:

| # | Stage | Methodology | Purpose | Artifact |
|---|-------|-------------|---------|----------|
| 1 | Understand | DDD | Analyze requirements, domain modeling, existing code | Context Document |
| 2 | Constrain | SDD | Enumerate constraints and boundaries | Constraint Profile |
| 3 | Design | DDD | Architecture, algorithm/data structure selection | Architecture Spec |
| 4 | Interface | SDD | Define contracts between components | Interface Contracts |
| 5 | Test | TDD | Write tests against interfaces (Red) | Test Suite |
| 6 | Implement | TDD | Write code to pass tests (Green) | Source Code |
| 7 | Verify | TDD | Broader validation — integration, acceptance | Verification Report |
| 8 | Optimize | TDD | Profiling-driven tuning, refactoring (Refactor) | Optimization Report |

**Command Structure** — Primitives + Composites + Meta-composite (mirrors DR-016):

| Type | Commands |
|------|----------|
| **Primitive** (8) | understand, constrain, design, interface, test, implement, verify, optimize |
| **Composite** (4) | spec (1-4), dev (5-8), ship, tune |
| **Meta-composite** (1) | spiral |

**Three Foundational Methodologies** (DDD + SDD + TDD):

1. **DDD** (Domain-Driven Design) → Understand, Design: Domain modeling, ubiquitous language, bounded contexts. Ensures we solve the right problem with the right abstractions.
2. **SDD** (Specification-Driven Development) → Constrain, Interface: Constraint-first design, artifacts as contracts. Every design decision traces to a constraint — the mechanism that prevents over/under-engineering.
3. **TDD** (Test-Driven Development) → Test, Implement, Verify, Optimize: Red-Green-Refactor cycle. Good interfaces are testable interfaces — Interface stage feeds directly into Test stage.

**Depth System**: Each stage runs at Skip / Light / Standard / Deep. Depth is determined by task scope, risk, familiarity, team impact, and reversibility. Small bug fix = Light everywhere. New service = Standard/Deep. User can override with `--depth`. Depth escalation: any stage can be re-run at a higher depth — the previous artifact becomes input context for the deeper run. Primitives are independently executable, so `/swe spiral --depth light` followed by `/swe understand --depth deep` is a natural workflow.

**Key principles** (carried forward):
- **Top-down decomposition**: Requirements → architecture → components → interfaces → implementation
- **Human-readable artifacts at every stage**: The mechanism that keeps human and AI aligned
- **Both greenfield and brownfield**: Brownfield analyzes existing code before designing changes
- **Hexagonal architecture for external tools**: Domain logic independent of tool choice (future MCP adapters)

**Open design questions** (resolved during DR-039 design session):
- ~~Command/skill/hook/agent composition~~ → Resolved: 8 primitives + 4 composites + 1 meta-composite (DR-039)
- ~~Quality gates between pipeline stages~~ → Resolved: depth-dependent gates, implicit at Light, explicit at Standard/Deep
- Specific document types — what artifacts maximize AI+human productivity (still open, to be resolved during implementation)
- Brownfield analysis depth — how much existing code understanding is needed (partially resolved: depth system handles this)
- Agent composition — which agents the SWE module needs (open, to be designed during /generate)
- Run (SRE/ops) scope — deferred per DR-040

**Legacy assets**: 32 pre-pivot skeleton files archived to `dev/archive/`. Will be consulted during final verification for cherry-picking only.

### PA Module — Obsidian Second Brain

**Concept**: Ouroboros plugin installed in Claude, running in the user's Obsidian vault directory. Claude has direct filesystem access to the entire vault (markdown files, folder structure, links). The vault becomes the user's externalized mental model — everything they know, plan, and track lives there. Claude acts as a second brain and personal assistant on top of this foundation.

**Capabilities**:
- **Knowledge graph / ontology**: Automatically identify relationships between documents, create links, build and maintain an ontology that mirrors the user's mental model
- **Daily log co-writing**: User and Claude collaboratively write detailed daily logs
- **Schedule awareness**: Read calendar/schedule data from the vault, proactively remind the user of upcoming commitments and forgotten tasks
- **Knowledge search (RAG)**: Keyword, semantic, and ontology-based retrieval for finding relevant information across a large vault
- **Research integration**: External deep research results (markdown) are injected, organized, linked to existing knowledge, and made queryable

**Technical notes**:
- Obsidian vault = folder of markdown files → Claude Code Read/Write/Edit/Glob/Grep works natively, no special integration needed
- Key technical challenge: **RAG for large vaults** — context window cannot hold the entire vault, so an index/ontology must be maintained and used for targeted retrieval
- Notification mechanism (PWA push, Obsidian plugin) is deferred — design when the core PA functionality works

### R&D Module — Autonomous Research Agent

**Concept**: An AI research agent that operates like a data scientist or ML researcher. Given a research question or requirement, it independently analyzes data, explores approaches, builds models, runs experiments, evaluates results, and iterates until it produces findings.

**Example workflow**:
```
"Detect specific equipment faults from current signals" (requirement)
     ↓
Data analysis (exploration, preprocessing, feature identification)
     ↓
Approach exploration (literature survey, technique selection)
     ↓
Model training + experimentation (multiple models, hyperparameters)
     ↓
Result evaluation + iteration
     ↓
Deliverables (model + analysis report)
```

**Key difference from Dev**: Dev follows a prescribed methodology — the value is in the discipline. R&D autonomously explores — the value is in the independent experimentation and discovery. Dev produces production-grade code; R&D produces research findings and experimental models.

**Overlap with Dev**: When R&D findings need to be implemented at production level, Dev module methodology applies. The two modules can compose: R&D discovers, Dev productionizes.

**Not limited to ML**: R&D applies to any domain requiring autonomous experimentation — software architecture exploration, performance optimization research, algorithm comparison studies, etc.

### Future Possibilities

- On-demand domain module generation
- Community-contributed module templates
- Module composition (combining capabilities across modules into custom workflows)

## Inspirations

- [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) — compound growth through documentation
- [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) — multi-agent orchestration patterns
