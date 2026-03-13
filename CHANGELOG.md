# Changelog

All notable changes to ouroboros are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). This project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] — 2026-03-13

Codex MCP → exec migration, spiral quality improvements, and public release documentation.

### Added

- Codex `exec resume` multi-turn pattern in invocation protocol (thread_id-based session continuity)
- Codex skills symlink setup: 12 ouroboros skills shared with Codex via `~/.codex/skills/` symlinks (format-compatible SKILL.md + references/)
- Public-facing documentation: `docs/ROADMAP.md` (development journey), refined `docs/designs/v0.15.0-spiral-analysis.md`, 3 experiment reports (`docs/experiments/` — self-eval bias, model optimization, unanimous convergence)
- Coding Style section in AGENTS.md with writing conventions for contributors

### Changed

- Bridge Agent: MCP-based delegation → `codex exec` + `exec resume` for multi-turn stage execution
- Team execution pattern: MCP availability check → Codex CLI availability check (`which codex`)
- Spiral command: extracted 3 shared team patterns (Team Composite Delegation, Team Auto-Gate, Cross-Review Resolution), `--policy` default `probe` → `linear`, 608→554 lines (E1/E2 improvement)
- `methodology/SKILL.md`: added Bias column to Pitfalls table (7 cognitive biases)
- Invocation protocol: CLI version baseline updated (v0.104.0 → v0.114.0)
- `prepare-release.sh`: curated `docs/` content inclusion (ROADMAP, designs, experiments), knowledge directory excluded from release
- CLAUDE.md and AGENTS.md: translated Korean content to English for public release
- README.md: fixed default policy description (probe → linear)
- `plugin.json` version: 1.0.0 → 1.0.1

### Removed

- `.mcp.json` (Codex MCP server configuration) — replaced by direct exec invocation
- `docs/specs/knowledge/` from release package (project-specific, not plugin content)

## [1.0.0] — 2026-03-11

Public release.

### Added

- Prompt injection defense: structural `<<<UNTRUSTED_CONTENT>>>` boundary markers in all relay prompt templates handling external web content, isolating untrusted data from model instructions
- Content safety reinforcement in researcher agent and absorb/research commands with marker recognition rules

### Changed

- README.md: updated for v1.0.0 — new commands (`/doctor`, `/swe reverse`), traversal policies, bridge agent, Living Project Model, architecture tree
- `plugin.json` version: 0.18.5 → 1.0.0
- `prepare-release.sh`: added AGENTS.md to copy list and required files
- `dev/PLAN.md`: v1.0.0 items completed, Future Versions expanded with new ideas (heartbeat, mobile, messenger)

## [0.19.5] — 2026-03-11

Artifact storage migration, monorepo support, and full quality sprint.

### Changed

- Artifact storage migration: `.swe/project/` → `docs/specs/project/`, `.swe/record/` → `docs/specs/record/`, `docs/knowledge/` → `docs/specs/knowledge/` (DR-068)
- Monorepo support: `--package` flag on `artifact-lifecycle.sh` and `knowledge-catalog.sh`, workspace auto-detection (pnpm, Cargo, Go, npm/yarn)
- `artifact-lifecycle.sh`: `_resolve_specs_path()`, `_resolve_active_path()`, `_is_workspace()` for monorepo-aware path resolution
- `knowledge-catalog.sh`: per-subproject knowledge directory support with `--package` flag
- `artifact-contracts.md`: rewritten Path Conventions with Monorepo Layout section and Knowledge Base paths
- 30+ files updated: all commands, agents, skills, templates, and references migrated to new paths
- Evaluation JSON: `multi_model.models` from string array to structured objects with `model_id` and `effort` (DR-069)
- Evaluation JSON: dual hash system — `content_hash` (file only) + `eval_hash` (file + model + effort) for precise regression tracking (DR-069)
- `regression.sh`: add `eval-hash` action for combined content+model+effort hashing
- Codex model: `gpt-5.3-codex` → `gpt-5.4` across all commands and routing table

## [0.19.0] — 2026-03-04

Living Project Model: cumulative project-level specification and knowledge base discoverability.

### Added

- Living Project Model: 4 cumulative specification files in `docs/specs/project/` (domain, constraints, architecture, interfaces) that evolve across spiral turns (DR-067)
- 4 project model templates: `templates/swe/project-{domain,constraints,architecture,interfaces}.md`
- `artifact-lifecycle.sh init-project`: create `docs/specs/project/` with template-initialized living documents
- `knowledge-catalog.sh index`: generate `docs/specs/knowledge/INDEX.md` with entry table and tag index
- `spiral.md` Phase 10.6: post-archive project model update with additive merge strategy
- `reverse.md` Phase 5.5: bootstrap project model from reverse-engineered artifacts
- DR-067 (Living Project Model — Cumulative Specification)

### Changed

- `spec.md` Phases 3-6: inject project model Summary as analyst context for each stage
- `understand.md`, `constrain.md`, `design.md`, `interface.md`: project model context injection
- `analyst.md` Procedures 1-4: project context handling guidance
- `tune.md` Phase 6.5: standalone project model update after archive
- `research.md` Phase 7: auto-regenerate INDEX.md after knowledge entry merge
- `artifact-contracts.md`: added Project Model path convention section

## [0.18.5] — 2026-03-03

Session intelligence and diagnostics: friction detection, parallel resilience, and health checks.

### Added

- `/core:doctor` command: 8-phase system health check (CLI tools, MCP servers, settings, hooks, LSP, plugin version) — report-only MVP
- `scripts/parallel.sh`: 3-tier resilient parallel result collection (manifest-based → raw file re-parse → JSONL transcript recovery)
- `scripts/friction-report.sh`: LLM batch analysis reader for accumulated user friction signals
- `scripts/user-message-log.sh`: UserPromptSubmit async hook for raw message accumulation
- `scripts/choice-log.sh`: PermissionRequest hook logging user approval/denial choices to `.claude/choice-log.jsonl`
- `scripts/session-history.sh`: git-based session history (list/summary) + session-start.sh Recent Activity integration
- DR-066 (Session Intelligence Architecture — Git-Based, Transcript-Based)

### Changed

- `hooks/hooks.json`: added UserPromptSubmit and PermissionRequest hook entries
- `scripts/session-start.sh`: Recent Activity section from session-history.sh
- `evaluate.md`, `evolve.md`: parallel.sh init/collect integration
- `parallel-execution-pattern.md`: 3-tier resilience documentation

## [0.18.0] — 2026-03-03

Developer experience quick wins, Gemini removal, and command defaults optimization.

### Added

- LSP integration: 4 language-specific `.lsp.json` templates (`templates/core/lsp-configs/` — TypeScript, Python, Rust, Go) + `/adopt` auto-generation in Phase 6
- Plan mode interrogation: CLAUDE.md directive requiring pre-plan questions, trade-off presentation, and assumption restatement
- Session auto-naming: CLAUDE.md directive for meaningful session name suggestions + PreCompact summary-based naming
- DR-064 (DX Quick Wins + Default Optimization)
- DR-065 (Gemini Integration Removal — OAuth Account Safety)
- Multi-model re-evaluation baselines: core-012 (8 components, 8/8 L4, 91.4% agreement), swe-007 (4 components, 4/4 L4, 85.9% agreement)
- Branch Summary tables added to research.md, evolve.md, upgrade.md (Q6 improvement)

### Changed

- Permission pattern fix: `bash */ouroboros/scripts/*` → `bash scripts/*` relative path matching + utility auto-allow (`ls`, `wc`, `jq`, `cat`, `git -C`)
- Built-in tool guidance in CLAUDE.md: LSP-first, Explore agent routing, WebFetch model delegation
- `agents-md.md` template: added Tool Guidance section for adopted projects
- Command defaults optimization across 10 commands: `--multi` auto-detect (codex installed → on, `--single` opt-out), `/research --deep` default on (`--shallow` opt-out), `/evaluate --save` default on (`--no-save` opt-out), `--compare` baseline auto-discovery
- Routing skill files: 3-way → 2-way consensus (Claude + Codex only)
- `invoke-model.sh`: removed Gemini provider case

### Removed

- `GEMINI.md` bridge file — OAuth account safety risk (DR-065)
- Gemini provider from `invoke-model.sh`, routing table, consensus protocol
- `--gemini` flags from research.md and other commands
- `cross-model-cli-integration-patterns.md` knowledge entry (Gemini-specific content)

## [0.17.0] — 2026-03-03

SWE feature expansion: new reverse-engineering command and two instructional skills.

### Added

- `/swe reverse` command: derive Stages 1-4 specification artifacts from existing code. Analyst Procedure 5 with Explicit/Inferred/Assumed confidence markers (DR-063)
- Persuasion skill (`skills/swe/persuasion/`): Cialdini, Aristotle, Toulmin, SCQA, Steel-manning frameworks. SKILL.md + argument-structures.md + cognitive-persuasion.md
- Teaching skill (`skills/core/teaching/`): Bloom's Taxonomy, ZPD, Cognitive Load Theory. SKILL.md + cognitive-learning.md + explanation-depth.md

### Changed

- `methodology/SKILL.md`: added Procedure 5 (Reverse) and reverse composite path
- `pipeline-stages.md`: added reverse card per stage
- Agent/command cross-references updated for reverse flow

## [0.16.5] — 2026-03-02

Team spiral advanced: stage-level pipelining, cross-turn learning, and external model integration.

### Added

- Stage-level pipelining: specialists call primitive commands individually with message checkpoints between stages
- `--policy team+probe` composition: Light-first specialist probe → Director confidence check → user escalation
- Cross-turn learning: Tune generates learning delta (depth calibration, team effectiveness) → next turn Phase 2 auto-recommends
- Generator-Critic loops: optional 2-pass verification for Design/Interface (Standard+ depth, max 2 iterations)
- Bridge Agent (`agents/swe/bridge.md`): MCP-based external model delegation. Codex via subscription-based MCP (DR-062)
- `--route` flag on `/swe spiral`: per-stage external model routing

### Changed

- `spiral.md`: stage-level team execution, team+probe branches, cross-turn learning integration
- `team-execution-pattern.md`: stage-level protocol, Bridge Agent integration, selective routing
- `spiral-state.sh`/`spiral-state.md`: stage-level state transitions, learning delta schema

## [0.16.0] — 2026-03-02

Team spiral: multi-agent pipelined composite execution.

### Added

- `team-execution-pattern.md` (336 lines): Team Topology (Director + Shaper/Builder/Critic), Pipelined Phase Flow, Auto-Gate Protocol, Cross-Review Protocol, Backtracking Decision Tree, Shutdown Protocol
- `--policy team` on `/swe spiral`: Director orchestrates specialist agents via TeamCreate/SendMessage
- State machine v2: team section in `spiral-state.json`, `team-update`/`cross-review` actions (DR-061)

### Changed

- `spiral.md`: Phase 2.7 Team Setup, auto-gates, cross-review resolution, Phase 11 Team Shutdown (+107 lines)
- `spiral-state.sh`/`spiral-state.md`: team transitions, cross-review tracking

## [0.15.5] — 2026-03-02

SWE pipeline parallelism: composite-internal stage parallelism and multi-model review.

### Added

- Stage parallelism: Ship (Security Review ‖ Code Review), Tune (Improve ‖ Retrospect) — default behavior via parallel Tasks (DR-060)
- `--multi` on Ship/Tune: Codex background relay + Claude foreground for review consensus
- `swe-relay-prompts.md`: Security Review, Code Review, SWE Quality Evaluate relay templates
- `relay-response-schemas.md`: Schema SR, CR, SQ for SWE relay responses

### Changed

- `spiral.md`: `--multi` relay to Ship/Tune, `--policy parallel` removed (replaced by composite-internal parallelism)
- `methodology/SKILL.md`: parallel row removed from Traversal Policies, stage parallelism note added

## [0.15.1] — 2026-03-02

Probe policy: hypothesis-driven traversal with confidence-gated escalation.

### Added

- Probe Execution Pattern: Light-first exploration → user confidence check → keep or escalate (DR-059)
- `--policy probe` as default traversal policy on `/swe spiral`
- `--deep` flag on `/swe spiral` (alias for `--depth Deep`)

### Changed

- `spiral.md`: probe branches in Phase 3/5/7/9, Decision Matrix probe paths, Phase 10.5 archive
- `spiral-state.md`: Probe Policy Transition Table, `escalate` transition type
- `spiral-state.sh`: `probe` in VALID_POLICIES, `--type` flag, `escalation_count`
- `tune.md`: archive skip condition when `spiral-state.json` exists

## [0.15.0] — 2026-03-02

Spiral state machine: adaptive traversal with checkpoint-rewind and cascade invalidation.

### Added

- `spiral-state.json` schema + `spiral-state.sh` script (init, update, read, status, checkpoint, restore, cascade) + `spiral-state.md` reference (DR-058)
- `--policy` flag on `/swe spiral`: linear policy with state tracking
- Checkpoint-rewind protocol: regression detection, `.versions/` artifact versioning, cascade invalidation from Selective Load Matrix
- Circuit breaker: max 3 regressions per spiral run

### Changed

- `spiral.md`: Phase 2.5 state init, state updates in composite/transition patterns, Decision Matrix regression paths
- `methodology/SKILL.md`: "Fixed stages, variable traversal" principle, Traversal Policies subsection

## [0.14.7] — 2026-03-01

SWE quality sweep: all 18 SWE components promoted to Level 4.

### Added

- 3 reference files: `agent-instructions.md`, `artifact-wrappers.md`, `calibration-examples.md`

### Changed

- 17 SWE components: inline implementation details → reference delegation (E1/E2/E3 improvements)
- SWE baseline: swe-004 (1/18 L4) → swe-005 (18/18 L4)

## [0.14.6] — 2026-03-01

Deep research: autonomous convergence-based iterative research.

### Added

- `--deep` flag on `/research`: iterative collection with autonomous convergence (DR-057)
- `deep-research-procedure.md`: Goal Extraction, Gap Reports, Convergence Logic, Gap-to-Query mapping
- Relay infrastructure: Schema R `coverage_assessment`, Research Analyst deep variant template

### Changed

- `research.md`: Phase 1 Scope Definition, Phase 2 auto-detect, Phase 3 coverage assessment + iteration loop (+77 lines)

## [0.14.5] — 2026-03-01

Quality sprint: remaining Level 3 commands promoted to Level 4. Core 97.89%.

### Changed

- `absorb.md`: inline relay prompts → 2 reference files, --multi/single unification (687→586 lines)
- `evolve.md`: state verification added, relay prompt → reference, Phase 6 unified (298→311 lines)
- `onboard.md`: methodology references, implementation hints removed, template simplified (210→201 lines)
- Core baseline: core-010 = 371/379 (97.89%), L4=23/24

## [0.14.0] — 2026-03-01

Feature expansion: brainstorm methodology overhaul, generate unification, companion skills.

### Added

- Brainstorm 3-Layer methodology: Process Frameworks, Stage Techniques, Meta-Reflection. 5 reference files new/expanded
- `--output [path]` and `--framework <name>` flags on `/brainstorm`
- Companion skills: research methodology, generation methodology, absorption methodology (10 new files)

### Changed

- `generate.md`: Mode A/B unification, inter-component consistency check Phase 5.5 (511→473 lines)
- `brainstorm.md`: 5→6 stages, Phase 7 structured output

## [0.13.5] — 2026-03-01

Quality sprint: E4 integration sections, criteria threshold adjustment, Core E1/E2 evolve.

### Changed

- 6 components: added See Also + consumer sections for E4 integration (adopt, evaluate, research, upgrade, evaluation/SKILL, validation/SKILL)
- `skill-criteria.md`: F2 word limit 2,500, F4 "logical categories" criterion (DR-056)
- 4 components: inline → reference delegation for E1/E2 (adopt, evaluate, research, upgrade)

## [0.13.0] — 2026-03-01

Evaluation infrastructure: multi-model baselines, parallel evaluation, and bias analysis.

### Added

- Parallel evaluation in Mode B: batch size 3, `--sequential` opt-out, circuit breaker at batch boundary (DR-054)
- SWE --multi baseline: 18 components cross-model evaluated (swe-004)
- Core --multi baseline: 21 components cross-model evaluated (core-007)
- Test set infrastructure: `dev/test-sets/evaluator-regression.json` (6 GT + 5 PS)
- `--unanimous` convergence mode with convergence prompts (DR-055)

### Changed

- Gemini 3.1 re-experiment: E1 100%, E2 50%, viable as spot-checker (DR-035 update)
- Self-evaluation bias analysis: E-tier concentrated (ΔE=+2.2), Codex sufficient as external validator

## [0.12.0] — 2026-02-28

Multi-model ecosystem: ouroboros development accessible to Claude Code, Gemini CLI, and Codex CLI.

### Added

- `.agents/skills/` cross-tool ported skills: 5 methodology skills (brainstorming, swe-constraint, swe-methodology, evolution, evaluation) neutralized for Gemini/Codex CLI compatibility
- `scripts/port-skills.sh`: generate/clean/status management for ported skills — regenerates neutralized copies from originals with sed transforms
- `AGENTS.md` at project root: shared multi-model development guidelines extracted from CLAUDE.md (DR-004-update)
- `GEMINI.md` bridge file: `@AGENTS.md` import for Gemini CLI auto-loading
- DR-053 (Skills Cross-tool Compatibility): frontmatter and structure fully compatible, content adaptation needed for cross-tool symlink
- DR-004-update: CLAUDE.md/AGENTS.md split extended for multi-model ecosystem
- Multi-model setup guide in `/adopt` Phase 7 report
- `GEMINI.md` auto-generation in `/adopt` Phase 6d
- Multi-model compatibility section in `agents-md.md` template

### Changed

- `CLAUDE.md` refactored: shared content moved to AGENTS.md, Claude-specific rules only (hooks, plan mode, model routing, memory policy, compaction recovery)
- `project-detection-patterns.md`: added Gemini CLI, Codex CLI, and cross-model skills detection patterns
- `adopt.md`: GEMINI.md creation in Phase 6, multi-model setup guide in Phase 7, updated Branch Summary and file tables

## [0.11.0] — 2026-02-27

Hook infrastructure and session lifecycle automation.

### Added

- PreCompact hook: `scripts/pre-compact.sh` outputs structured context snapshot (git changes + task state) before compaction (DR-051)
- PreCompact transcript parsing: extract conversation context from JSONL transcript → `.compact-context.md` file-based handoff to session-start
- SubagentStop output capture: `scripts/capture-output.sh` with opt-in `OUROBOROS_CAPTURE=1`, saves ouroboros agent outputs to `.captures/` (DR-052)
- Compaction Recovery section in CLAUDE.md: post-compaction context restoration guidelines
- Validation SKILL event list expanded from 4 to 17 events across 5 categories

### Changed

- `hooks/hooks.json`: added PreCompact and SubagentStop hook entries, updated description
- `CLAUDE.md`: added Compaction Recovery section, enhanced Plan Mode Integration with hook limitations (DR-050)
- `scripts/session-start.sh`: refactored exit structure for compact context injection after STATUS.md
- `validation/SKILL.md`: hook event field now references full event list instead of hardcoded 4 events
- `validation/references/frontmatter-and-fields.md`: Valid Event Types expanded to 17 events in 5 categories

## [0.10.0] — 2026-02-27

Component quality: full evaluation baseline across 37 components, selective polish, and structural validation.

### Added

- Full evaluation baseline for Batch 1 core components: research.md, evolve.md, generate.md, generator.md, brainstormer.md (all Level 4)
- Full evaluation baseline for Batch 2 core components: brainstorm.md (Level 4), brainstorming/SKILL (Level 4), evolution/SKILL (Level 4), routing/SKILL (**Level 3**), validation/SKILL (Level 4)
- Re-evaluation baseline for Batch 3 core components: absorb.md (Level 4), evaluate.md (Level 4, E1=0), reconciler.md (Level 4), upgrade.md (Level 4)
- Evaluation baseline for Batch 4 SWE primitives: understand.md (15/16), constrain.md (15/16), design.md, interface.md, test.md, implement.md, verify.md, optimize.md (all 16/16, all Level 4)
- Evaluation baseline for Batch 5 SWE composites+agents+skills: spec.md, dev.md, ship.md, tune.md, spiral.md, analyst.md, implementer.md, reviewer.md, methodology/SKILL, constraint/SKILL (all 16/16, all Level 4)
- Spot-check baseline for Batch 6 core components: evaluator.md (Level 4), researcher.md (Level 4), adopt.md (**Level 3**, 13/16), onboard.md (**Level 2**, 13/16, F2=0 agent delegation cap), evaluation/SKILL (Level 4)
- Regression baseline snapshots for core and swe modules
- Re-evaluation after polish: all 7 polished components confirmed 16/16 Level 4 (understand, constrain, evolve, evaluate, routing/SKILL, adopt, onboard)
- Structural validation integration: `evaluate.md` Phase 2.5 (informational gate) + `generate.md` Phase 5.5 (auto-fix gate) — references validation-methodology SKILL

### Changed

- `understand.md`: added `--fast` flag to Phase 1 parameter table and Phase 2 depth decision table
- `constrain.md`: added `--fast` to Phase 1, restructured Phase 2 with consolidated Branch Summary and Depth Resolution tables
- `evolve.md`: extracted Phase 3 researcher relay prompt template to `skills/core/evolution/references/researcher-relay-prompt.md`
- `evaluate.md`: extracted Phase 3 evaluator relay prompt templates (4 modes) to `skills/core/evaluation/references/evaluator-relay-prompts.md`
- `routing/SKILL.md`: added inline routing table key defaults (E3), added Consumers section listing 4 consuming commands (E4)
- `adopt.md`: added Recovery sections for researcher/generator agent failures (Q7), extracted detection patterns to `templates/core/project-detection-patterns.md` (E1), simplified Phase 1 validation to reference Branch Summary (E2)
- `onboard.md`: added researcher agent delegation for workflow recommendations (F2), restructured Recovery as table with retry/escalation (Q7)
- `dev/PLAN.md` v0.10.0 items: replaced ad-hoc items with systematic full-sweep evaluation + selective polish plan

## [0.9.0] — 2026-02-27

Efficiency and lightweight optimization. Reduced ceremony for simple tasks, context window conservation, and cost-effective model routing.

### Added

- `--fast` flag on all SWE commands (5 composites + 8 primitives): syntactic sugar for `--depth Light` with relaxed skip conditions (DR-048)
- Relaxed skip conditions for fast mode: Constrain (single-file), Design (existing patterns), Interface (single module), Verify (tests pass + < 50 lines), Optimize (default skip)
- SessionStart hook: auto-inject STATUS.md on startup, resume, compact, and clear events (DR-047)
- Universal STATUS.md pattern: any project can create a STATUS.md for automatic session context injection
- Artifact Summary convention: all SWE stage artifacts now start with `## Summary` (3-5 sentences) for selective loading
- Selective Load Matrix in `artifact-contracts.md`: downstream stages load optional upstream artifacts as summary-only at Light depth
- `/research --gemini` flag: opt-in Gemini search for Mode C topic research via gemini-3-flash-preview (DR-049)
- Model routing experiment framework: `dev/experiments/model-routing/` with evaluator/researcher sonnet hypothesis

### Changed

- `/research` 2-tier architecture: sonnet collector (Phase 2) + opus analyzer (Phase 3) for cost-effective collection (DR-049)
- SWE primitive commands: depth-aware artifact loading in Phase 3 (Context Gathering) — full read at Standard+, summary at Light
- `depth-system.md`: added Fast Mode section with relaxed skip condition table
- `routing-table.md`: gemini-3-flash-preview usage updated with research collection role

## [0.8.0] — 2026-02-26

Robustness and stability improvements from red team findings.

### Added

- Worktree auto-prune on create: stale worktrees cleaned before new creation
- Stale lock file detection: `_unlock_stale_worktrees()` removes locks for missing worktree directories
- `format.sh` opt-out via `OUROBOROS_NO_FORMAT=1` environment variable
- `invoke-model.sh` timeout support (6th argument, default 300s)
- `invoke-model.sh` retry with exponential backoff (max 2 retries, 1s/2s delay)
- Gemini error JSON filtering (`select(.error == null)`) in parse pipeline
- Explicit parse failure warnings to stderr (replacing silent `|| true`)
- Circuit breaker responsibility documented in invocation-protocol.md

### Changed

- `worktree.sh discard` now delegates to `cleanup` (single implementation)
- `action_prune()` runs `git worktree prune` after removing stale worktrees
- `format.sh` explicit `*)` case for unsupported file types (no-op)
- `invoke-model.sh` CLI invocation wrapped in `_invoke_cli()` function with retry logic

### Removed

- `dev/archive/` directory (31 pre-pivot skeleton files, DR-046) — preserved in `.trash/` and git history
- Empty `commands/dev/`, `agents/dev/`, `skills/dev/`, `templates/dev/` directories

## [0.7.0] — 2026-02-26

External validation and public release preparation.

### Added

- Red team 3-way brainstorm (Claude+Codex+Gemini, 34 ideas → 19 after dedup)
- Permission audit (DR-044): `safe-rm.sh`, settings.json self-contained, namespace collision-free
- `prepare-release.sh`: plugin deliverable extraction + 6-check security audit
- Multi-language dogfooding validation (Python FastAPI + TypeScript React 19)
- Versioning system: semver policy, CHANGELOG.md, retroactive Phase→version mapping (DR-045)

### Changed

- Document restructuring: STATUS/PLAN/ROADMAP 3-way split
- CLAUDE.md: Document Roles, Session Start/End, versioning workflow added

## [0.6.0] — 2026-02-23

First domain module: 8-stage disciplined software engineering pipeline (DDD+SDD+TDD).

### Added

- SWE module: 19 evaluable components, 4 artifact templates — all at 16/16 Level 4
  - Stages: understand, constrain, design, interface, test, implement, verify, optimize
  - Composites: spec, dev, ship, tune, spiral
  - Agents: analyst, implementer, reviewer
- Artifact lifecycle system (DR-041): `.swe/active/` + `.swe/record/` dual-path, `artifact-lifecycle.sh`
- Core module lifecycle (DR-043): evaluation persistence, knowledge entry management, `knowledge-catalog.sh`
- Smoke test in verify stage (DR-042), depth calibration feedback loop

### Changed

- 13 command paths migrated to artifact lifecycle system

## [0.5.0] — 2026-02-21

Self-dogfooding cycle: all 15 core components evaluated and evolved to 16/16 Level 4.

### Changed

- evaluate.md 13→16, evaluator 15→16, researcher 15→16
- research 14→16, generate 14→16, generator 13→16 (DR-037)
- adopt 15→16, onboard 13→16, reconciler 15→16
- Severity gate review: F=100%, Q=95.2%, E=81.7%

### Added

- `/brainstorm` command promoted from experimental (DR-038)
- `--multi` 3-way brainstorming (Claude+Codex+Gemini)

## [0.4.0] — 2026-02-18

Automated evaluation pipeline with score inflation mitigation.

### Added

- Tiered Binary Criteria (DR-034): F5+Q7+E4 with severity gate
- Regression suite: `regression.sh` (enumerate/hash/save/latest/list/history)
- Output evaluation: Mode D flow (`--output`), dual-axis reporting
- Model optimization (DR-035): 48 invocations benchmarked

### Changed

- Evaluation scoring: from subjective 1-5 scale to binary tiered criteria

## [0.3.0] — 2026-02-16

Multi-model orchestration: Claude, Codex, Gemini working together.

### Added

- Routing skill + 3 references, `--multi` opt-in (DR-030)
- `/evaluate --multi`: external scoring + consensus
- `invoke-model.sh` + `parsing-strategy.md` (SoC extraction)
- `worktree.sh` (9 actions): isolation for concurrent operations (DR-031)
- `format.sh`: PostToolUse hook for automated linting
- Parallel fan-out/fan-in execution pattern

### Changed

- Agent model experiments (DR-036): Codex gpt-5.3-codex optimal for external evaluation

## [0.2.0] — 2026-02-15

Core meta-plugin MVP: 5 primitives + 4 composites = 9 commands.

### Added

- `/evaluate`: LLM-as-judge, before/after comparison (DR-022)
- `/evolve`: researcher agent, worktree isolation, 2-Phase execution (DR-023, DR-024)
- `/research`: 3 modes (plugin/web/topic), 4-layer security
- `/generate`: Mode A (module) + Mode B (component) (DR-025)
- `/brainstorm`: divergent+convergent thinking (experimental)
- `/absorb`: Research → Evaluate → Generate/Evolve pipeline (self-bootstrapped)
- `/upgrade`: reconciler agent, CONFLICT-A/B classification
- `/adopt`: codebase analysis → AGENTS.md generation
- `/onboard`: plugin discovery and workflow recommendation
- Evaluator, researcher, generator, reconciler agents

### Changed

- Directory layout: modular monolith (DR-012)

## [0.1.0] — 2026-02-10

Initial project structure.

### Added

- Modular monolith directory layout: `commands/`, `agents/`, `skills/`, `templates/`, `hooks/`, `scripts/`
- VISION/DECISIONS/STATUS/PLAN 4-document system
- CLAUDE.md development guidelines
