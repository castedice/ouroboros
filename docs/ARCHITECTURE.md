# Ouroboros Architecture Guide

This guide is for developers who want to understand how ouroboros works internally or contribute to it.
Read `README.md` first for the module inventory and quick-start surface.
Read `CLAUDE.md` for Claude Code-specific runtime rules.
Read `AGENTS.md` for shared development rules that apply to Codex and other agents in this repository.
Use `dev/VISION.md` and `dev/DECISIONS.md` when you need the deeper rationale behind architecture choices.

## 1. Design Philosophy

Ouroboros is a Claude Code meta-plugin that builds, evaluates, and evolves plugin workflows.
The project intentionally dogfoods its own commands, agents, skills, hooks, and scripts during development.
The core philosophy lives in `dev/VISION.md`.
The shortest version is that each cycle should improve the user, the AI, and the process.

```text
User work
  -> command output
  -> evaluation
  -> evolution
  -> captured learning
  -> better next cycle
```

Co-evolutionary self-improvement means the system does not treat artifacts as one-off outputs.
Each artifact can become evidence for future commands, better criteria, sharper prompts, safer scripts, or improved documentation.
Compound growth is the mechanism that makes small improvements matter.
An improved evaluator in `agents/core/evaluator.md` raises the quality of `/evaluate`.
An improved `/evaluate` in `commands/core/evaluate.md` raises the quality of future `/evolve`, `/generate`, `/absorb`, and `/rnd` validation.
Dogfooding is the discipline that keeps the system honest.
When ouroboros adds a capability, the project tries to use that capability on itself before treating it as stable.
The evaluate-first mindset appears in `AGENTS.md`, `skills/core/evaluation/SKILL.md`, and `commands/core/evaluate.md`.
The rule is to measure before improving and prove before expanding.
This is why evaluation artifacts are saved under `dev/evaluations/` and why many commands include explicit quality gates.
The modular monolith choice is deliberate.
Core, SWE, PA, and RnD coexist in one plugin because learning can cross module boundaries.
For example, the session archive created for local recall is consumed by PA retrieval in `agents/pa/librarian.md` and by RnD prior-work checks in `commands/rnd.md`.
Right-sized abstraction is the local style.
Commands keep orchestration details that make execution reconstructable, while repeatable mechanics move into scripts or references when inline logic becomes a maintenance burden.

## 2. Plugin Structure

The primary layering is commands to agents to skills.
`CLAUDE.md` states the layer model directly as `commands/` orchestration recipes, `agents/` execution engines, and `skills/` methodology plus criteria.
The same structure appears in the `README.md` architecture section.

```text
User request
  |
  v
commands/             Orchestrate workflow, branch logic, state, and user checkpoints
  |
  v
agents/               Execute bounded specialist reasoning or review
  |
  v
skills/               Provide reusable methodology, criteria, gotchas, and references
  |
  v
references/           Hold detailed contracts and procedures loaded only when needed
```

Commands live under `commands/`.
Core commands live under `commands/core/`.
SWE commands live under `commands/swe/`.
PA commands live under `commands/pa/` with the router at `commands/pa.md`.
The RnD public command lives at `commands/rnd.md`.
The session wiki command lives at `commands/session-wiki.md`.
Commands decide what mode is active, what context to load, what artifacts to read or write, what agent to call, and what to show the user.
Commands own file mutation unless a command explicitly delegates a bounded write operation.
This is visible in `commands/rnd.md`, which says the command writes `docs/research/` and `.rnd/` while agents return payloads.
It is also visible in `commands/session-wiki.md`, which writes proposals and wiki pages while `agents/core/session-synthesizer.md` returns a `write_plan`.
Agents live under `agents/`.
Core agents include `agents/core/evaluator.md`, `agents/core/researcher.md`, `agents/core/generator.md`, and `agents/core/session-synthesizer.md`.
SWE agents include `agents/swe/analyst.md`, `agents/swe/implementer.md`, and `agents/swe/reviewer.md`.
PA agents include `agents/pa/librarian.md`, `agents/pa/scribe.md`, and `agents/pa/weaver.md`.
RnD agents include `agents/rnd/collector.md`, `agents/rnd/investigator.md`, and `agents/rnd/critic.md`.
Agents execute specialist slices with explicit boundaries.
`agents/swe/analyst.md` analyzes requirements, constraints, designs, and interfaces but never writes files.
`agents/pa/librarian.md` retrieves and compresses vault context but never answers the user directly.
`agents/rnd/critic.md` judges submitted artifacts but never rewrites them in place.
Skills live under `skills/`.
Core skills include `skills/core/evaluation/SKILL.md`, `skills/core/evolution/SKILL.md`, `skills/core/research/SKILL.md`, and `skills/core/session-archive/SKILL.md`.
SWE skills include `skills/swe/methodology/SKILL.md`, `skills/swe/constraint/SKILL.md`, and `skills/swe/code-review/SKILL.md`.
PA skills include retrieval, writing, ontology, profiling, and trust skills under `skills/pa/`.
RnD methodology lives at `skills/rnd/methodology/SKILL.md`.
Skill bodies are compact operating guides.
Detailed rules are placed in sibling `references/` directories such as `skills/core/evaluation/references/command-criteria.md`.
Templates live under `templates/` and define artifact shapes.
Scripts live under `scripts/` and provide deterministic helpers for lifecycle, evaluation, routing, archive, PA, and RnD operations.
Hooks live under `hooks/` and automate lifecycle behavior around Claude Code tool events.
Development state and design records live under `dev/`.
Public user-facing docs live under `docs/`.
Cross-tool ported skills live under `.agents/skills/`.
`AGENTS.md` says `.agents/skills/` is generated by `scripts/port-skills.sh` and should not be edited directly.

## 3. Command Anatomy

Commands are Markdown files with optional YAML frontmatter plus a phase-structured body.
Current command examples include `commands/core/evaluate.md`, `commands/swe/understand.md`, `commands/swe/spiral.md`, `commands/pa/ask.md`, `commands/rnd.md`, and `commands/session-wiki.md`.
The canonical command frontmatter fields are `name`, `description`, `allowed-tools`, and `argument-hint`.
The command criteria in `skills/core/evaluation/references/command-criteria.md` treat those four fields as the F5 frontmatter contract.
`name` should normally follow `{module}:{command}`, such as `core:evaluate`, `swe:spiral`, and `pa:ask`.
Top-level commands can use a simple name when the command surface is intentionally top-level, as in `commands/rnd.md` and `commands/session-wiki.md`.
`description` should start with `Use when` and define the activation condition.
`allowed-tools` should follow minimum privilege.
`argument-hint` documents the invocation shape a user or router should expect.
Some commands include additional fields when useful.
For example, `commands/pa/ask.md` includes `effort: low`.
`allowed-tools` can be inline, as in `commands/core/evaluate.md`.
`allowed-tools` can also be a YAML list, as in `commands/rnd.md` and `commands/session-wiki.md`.
Fine-grained Bash allow patterns are used when a command should run only specific script surfaces.
For example, `commands/session-wiki.md` allows `Bash(scripts/session-archive.sh *)`, `Bash(sha256sum *)`, and `Bash(shasum *)`.

```text
---
name: core:evaluate
description: "Use when ..."
argument-hint: <file-path|module-name> [...]
allowed-tools: Read, Glob, Grep, Task, Bash
---
```

The body usually starts with an H1 title and a `Target: $ARGUMENTS` line.
The next section is often `Agents & Tools Used` or `Agents Used`.
This table gives contributors a fast map from phases to ownership.
`commands/core/evaluate.md` uses the table to show evaluator agent calls, Bash persistence, and command-local consensus integration.
`commands/rnd.md` uses the table to map 14 phases to investigator, collector, critic, AskUserQuestion, QMD, and script helpers.
`commands/session-wiki.md` uses the table to map each action to the archive script, the synthesizer agent, hash tools, and QMD query.

```text
Command body
  |
  +-- Agents & Tools Used
  +-- Delegation Contracts
  +-- References
  +-- System Boundaries
  +-- Branch Summary or Decision Matrix
  +-- Phase 1 through Phase N
  +-- Recovery, Output Contracts, or Rules
```

Delegation contracts are now a first-class command pattern.
Most mature commands point to `skills/core/collaboration/references/runtime-contract.md`.
The contract says the command must pass paths and inline content explicitly instead of telling an agent to rely on prior chat.
The command owns orchestration, temp files, state mutation, and user-facing output.
The agent owns the delegated reasoning slice and returns named fields.
`commands/pa/ask.md` delegates context assembly to `ouroboros:pa:librarian` and keeps answer synthesis command-local.
`commands/rnd.md` delegates artifact drafting and review but keeps state, budgets, ledgers, and file writes command-owned.
`commands/session-wiki.md` delegates markdown synthesis but keeps proposal files, manifest updates, and apply gates command-owned.
Branch summaries and decision matrices are central to command readability.
`commands/core/evaluate.md` has a `Branch Summary` table that covers modes, flags, external model failures, save behavior, compare behavior, and handoff behavior.
`commands/swe/spiral.md` has a `Branch Summary` table that covers depth flags, policies, team setup, routing, probe escalation, gates, and PA bridge behavior.
`commands/rnd.md` has a `Decision Matrix` with parse routes, branch search, budget stops, critic gates, human checkpoints, adversarial review fallback, and citation failures.
`commands/session-wiki.md` has an action table plus fail-open rules.
Recovery is bounded by design.
The command criteria call this Q7: recovery and convergence detection.
Good commands define max retries, stagnation signals, and escalation behavior.
For example, `commands/pa/ask.md` gives librarian retrieval one full attempt plus one narrowed retry.
For example, `commands/rnd.md` gives critic gates one revise loop and analyze-prune a bounded loop cap.
Fail-open does not mean unsafe continuation.
In this repo, fail-open usually means preserving inspectable state, reporting diagnostics, and keeping unrelated read-only flows usable.
`commands/session-wiki.md` says synthesis failure leaves the proposal pending and never writes to `wiki/`.
`skills/core/session-archive/SKILL.md` says the archive logs and continues on per-source sync failures.
`hooks/session-archive-ingest.sh` exits `0` on hook errors so SessionEnd is not blocked.
Output contracts are part of command anatomy.
`commands/core/evaluate.md` lists static, module, comparison, output, multi-model, regression, and action-handoff report contracts.
`commands/pa/ask.md` lists `vault-answer`, `memory-answer`, `session-context-only`, `no-results`, `pa-self-answer`, `vault-meta-answer`, and `retrieval-error`.
`commands/rnd.md` names artifact contracts for `brief.md`, `prior-work-map.md`, `hypothesis-backlog.md`, ledgers, `report.md`, `review.md`, and `meta-learning.md`.
Reference tables are used to avoid burying architecture in prose.
When a command references a detailed contract, it should include the actual path.
Examples include `skills/swe/methodology/references/depth-system.md`, `skills/rnd/methodology/references/peer-review-protocol.md`, and `skills/core/session-archive/references/wiki-gate.md`.

## 4. Agent Anatomy

Agents are Markdown files with YAML frontmatter and a role prompt body.
Current examples include `agents/core/evaluator.md`, `agents/swe/analyst.md`, `agents/pa/librarian.md`, `agents/rnd/critic.md`, and `agents/core/session-synthesizer.md`.
Agent frontmatter normally includes `name`, `description`, `model`, `tools`, `color`, `effort`, `maxTurns`, and optional `skills`.
The agent criteria in `skills/core/evaluation/references/agent-criteria.md` treat `name`, `description`, `model`, and `color` as foundational.
`description` is a block scalar with `Use this agent when` trigger phrases plus multiple `<example>` blocks.
Examples matter because they teach routers and evaluators when the agent should activate.
`model` should match role complexity.
`agents/core/evaluator.md` uses `model: opus` and `effort: max` because quality scoring is judgment-heavy.
`agents/pa/librarian.md` uses `model: sonnet` and `effort: medium` because retrieval brokerage is balanced but narrower than deep synthesis.
`tools` should follow minimum privilege.
Read-only agents normally use `Read`, `Grep`, and `Glob`.
Agents that need retrieval or script access add only the required tools.
For example, `agents/pa/librarian.md` includes QMD MCP tools and Bash because it owns the session archive read-only boundary.
The body starts with an expert role statement.
It then defines core principles, boundaries, input contracts, workflows, output formats, and integration notes.
`agents/swe/analyst.md` defines procedures for Understand, Constrain, Design, Interface, and Reverse.
`agents/rnd/critic.md` defines stage gates, contract validation, final review, consensus behavior, and calibration examples.
`agents/core/session-synthesizer.md` defines proposal-only output authority and a JSON-like `write_plan` return shape.
Agents should not silently take over command responsibilities.
The analyst does not write `.swe/active/` artifacts.
The librarian does not answer user questions.
The RnD critic does not collect new sources to rescue weak evidence.
The session synthesizer does not write proposal files or apply wiki pages.
This separation lets commands remain accountable for state and side effects.
It also makes agents easier to test with static criteria and output criteria.

## 5. Skill Anatomy

Skills are methodology packages centered on a `SKILL.md` file.
The canonical skill shape is described in `skills/core/evaluation/references/skill-criteria.md`.
The standard order is Core Rule, Gotchas, Workflow, Decision Rules, Reference Map, and See Also.
Most modern skills also include a `Rationalization Red Flags` table when the skill involves judgment.
`skills/core/evaluation/SKILL.md` is the core example for quality scoring.
`skills/core/session-archive/SKILL.md` is the core example for archive methodology.
`skills/rnd/methodology/SKILL.md` is the RnD example for a domain-specific workflow.
`skills/swe/methodology/SKILL.md` is the SWE example for staged engineering methodology.
The frontmatter includes `name`, `description`, and usually `preamble_tier`.
The description is written in third person and names activation contexts.
Tier 4 meta skills include an explicit guard that tells subagents not to reload the skill when the command already embedded the relevant methodology.
For example, `skills/core/evaluation/SKILL.md` says subagents dispatched by a command should skip loading it.
Core Rule is the shortest invariant.
Evaluation says measurement comes before improvement.
Session archive says visible transcript evidence goes into SQLite FTS5 and thinking blocks are dropped.
RnD says budget first, artifacts first, and evidence before narrative.
Gotchas capture failure modes with prevention.
Rationalization red flags name the tempting shortcut, the forbidden move, and the corrective action.
Workflow gives the executable sequence.
Decision Rules define the branch logic and thresholds.
Reference Map tells the caller which sibling reference file to load and when.
See Also names consumers and related components.
References are not incidental.
They are the mechanism for progressive disclosure and token control.
For example, evaluation criteria live in `skills/core/evaluation/references/command-criteria.md`, `skills/core/evaluation/references/agent-criteria.md`, and `skills/core/evaluation/references/skill-criteria.md`.
Session archive contracts live in `skills/core/session-archive/references/archive-schema.md`, `skills/core/session-archive/references/retrieval-contract.md`, `skills/core/session-archive/references/wiki-schema.md`, and `skills/core/session-archive/references/wiki-gate.md`.
RnD contracts live in files such as `skills/rnd/methodology/references/artifact-contracts.md`, `skills/rnd/methodology/references/hypothesis-contract.md`, and `skills/rnd/methodology/references/review-rubric.md`.
When adding a skill, keep `SKILL.md` as a quick operating map and put detailed contracts in `references/`.
When changing a skill, update the reference map if the load guidance changes.

## 6. Hooks System

The hook registry is `hooks/hooks.json`.
Hook scripts live in `hooks/` or `scripts/`.
Hooks are lifecycle automation around Claude Code tool events.
They should be narrowly matched, fast, and fail-open unless their purpose is an explicit safety block.

```text
Claude Code event
  -> hooks/hooks.json matcher
  -> command hook script
  -> exit 0 to allow or exit 2 to block where supported
```

`PreToolUse` currently has two repo-local hooks.
The `WebFetch` matcher runs `scripts/validate-url.sh`.
That hook blocks dangerous URLs such as non-HTTPS protocols, internal addresses, and direct IPs with exit code `2`.
The `Read` matcher runs `scripts/pa-read-guard.sh`.
That hook denies reads of authored vault content when `.pa/deny-paths.json` is configured and redirects the workflow toward the shadow vault model.
RTK is documented as an adopted external pattern rather than a repo-local hook entry.
`dev/references/resource-analysis-2026-04-07.md` maps RTK to a Claude Code `PreToolUse` hook with `updatedInput` rewrite for command-output compression.
`dev/MILESTONES.md` records RTK v0.35.0 evaluation and global PreToolUse hook registration.
So contributors should understand RTK as a global token-reduction layer that may rewrite tool input or output before it reaches the model, not as a script inside `hooks/hooks.json`.
`PostToolUse` runs after `Write|Edit`.
It calls `scripts/format.sh`, which dispatches by file extension to tools such as `ruff`, `prettier`, `rustfmt`, Markdown whitespace cleanup, `shfmt`, and `shellcheck`.
The formatter is intentionally idempotent and skips unsupported file types.
`PostToolUseFailure` calls `scripts/learning-log-tool-failure.sh` asynchronously.
That hook turns privacy-safe tool failures into friction evidence for the learning pipeline.
`SessionStart` calls `scripts/session-start.sh`.
It injects `dev/STATUS.md`, recent git activity, and restored conversation context.
`SessionEnd` has two hooks.
It calls `scripts/learning-session-end.sh` to append lightweight session-end learning patterns.
It calls `hooks/session-archive-ingest.sh` to enqueue the main transcript and subagent transcripts for later archive sync.
The session archive hook is enqueue-only.
It does not parse or index transcripts during SessionEnd.
`PreCompact` calls `scripts/pre-compact.sh` to produce compact change context.
`UserPromptSubmit` calls `scripts/user-message-log.sh` for append-only friction analysis.
`PermissionRequest` calls `scripts/choice-log.sh` for permission pattern analysis.
`SubagentStart` injects project-local calibration memory through `scripts/agent-memory-context.sh`.
`SubagentStop` can capture ouroboros agent output through `scripts/capture-output.sh` when `OUROBOROS_CAPTURE=1`.

## 7. Scripts

Scripts provide deterministic automation that commands can call without embedding shell logic inline.
The script surface is broad, so contributors should group scripts by ownership.
Session archive automation centers on `scripts/session-archive.sh`.
It owns `init`, `sync`, `search`, `select`, `get`, `propose`, `wiki-status`, `wiki-lint`, proposal list/show/apply/reject, `rebuild`, and `prune`.
It stores runtime data under `${CLAUDE_PLUGIN_DATA}/session-archive/`.
It uses `index.sqlite`, `queue.jsonl`, `state.json`, `settings.json`, `proposals/`, `wiki/`, and `wiki-ledger.jsonl`.
It keeps `Read`, `Write`, `Edit`, and `Glob` tool results as metadata-only archive content.
It caps selected tool-result stdout at 2 KB.
Codebase diagnostics live in `scripts/codebase-triage.sh`.
That script uses git history to report high churn, author ownership, bug hotspots, velocity, and crisis signals.
Evaluation automation centers on `scripts/eval-normalize.sh`, `scripts/eval-consensus.sh`, and `scripts/eval-save.sh`.
`scripts/eval-normalize.sh` turns varied evaluator JSON into the canonical internal shape.
`scripts/eval-consensus.sh` merges two normalized evaluator results and supports configurable boundary criteria.
`scripts/eval-save.sh` persists results under `dev/evaluations/`.
Routing automation includes `scripts/codex-relay.sh`, `scripts/codex-parse.sh`, `scripts/invoke-model.sh`, and `scripts/parallel.sh`.
The relay scripts keep external model invocation out of command bodies.
`scripts/parallel.sh` provides manifest-based fan-out and fan-in recovery.
Learning automation includes `scripts/learning-ingest-eval.sh`, `scripts/learning-ingest-friction.sh`, `scripts/learning-ingest-correction.sh`, `scripts/learning-distill.sh`, and `scripts/learning-load-context.sh`.
The ingesters write source JSONL.
The distiller routes evidence into per-skill stores.
The loader returns the highest-signal local learnings for a component or skill scope.
RnD automation centers on `scripts/rnd-session.sh`, `scripts/rnd-budget.sh`, `scripts/rnd-branch.sh`, `scripts/rnd-loop.sh`, `scripts/rnd-archive-index.sh`, `scripts/rnd-cite.sh`, and `scripts/rnd-meta.sh`.
`scripts/rnd-session.sh` manages `.rnd/sessions/{id}/state.json` and stage transitions.
`scripts/rnd-budget.sh` tracks wall-clock and probe budgets.
`scripts/rnd-branch.sh` manages branch queues, waves, scoring, pruning, merging, expansion, and finalization.
`scripts/rnd-loop.sh` drives resumable automation around `needs_user`, `blocked_escalation`, and `completed`.
`scripts/rnd-archive-index.sh` maintains cumulative prior-work memory across completed studies.
`scripts/rnd-cite.sh` extracts citations and writes BibTeX.
`scripts/rnd-meta.sh` extracts and aggregates cross-study metrics.
PA automation includes scripts such as `scripts/pa-extract.sh`, `scripts/pa-mask.sh`, `scripts/pa-read-guard.sh`, `scripts/pa-relationship.sh`, and `scripts/pa-write-safe.sh`.
SWE automation includes `scripts/spiral-state.sh`, `scripts/artifact-lifecycle.sh`, and `scripts/worktree.sh`.
Release and validation helpers include `scripts/check-skills.sh`, `scripts/check-port-skills.sh`, `scripts/port-skills.sh`, `scripts/test-skills.sh`, `scripts/regression.sh`, and `scripts/prepare-release.sh`.
Script changes should preserve POSIX-friendly shell where practical and keep usage text current.
Scripts are allowed to be more implementation-heavy than commands because scripts are the execution boundary.

## 8. Evaluation Framework

Evaluation is a three-tier binary rubric family.
The common shape is Foundation, Craft, and Excellence.
For commands, the bundle is F5+Q7+E4.
For agents and skills, the bundle is also 16 binary criteria split across 5 Foundation, 7 Craft, and 4 Excellence criteria.
The command criteria live at `skills/core/evaluation/references/command-criteria.md`.
The agent criteria live at `skills/core/evaluation/references/agent-criteria.md`.
The skill criteria live at `skills/core/evaluation/references/skill-criteria.md`.
Hook and output criteria live in the same `skills/core/evaluation/references/` directory.
Foundation gates Craft and Excellence.
A component with Foundation below 5 cannot reach Level 4.
The command severity gate maps F, Q, and E scores to L1 through L4.
L1 means Poor.
L2 means Needs Work.
L3 means Good.
L4 means Excellent.
The evaluator agent is `agents/core/evaluator.md`.
The command orchestrator is `commands/core/evaluate.md`.
The skill operating guide is `skills/core/evaluation/SKILL.md`.
Static evaluation scores component definitions.
Dynamic evaluation scores component output.
Before/after comparison evaluates both versions independently and uses a position-swapped comparison to avoid ordering bias.
Saved runs go under `dev/evaluations/`.
Regression comparison uses saved baselines and `skills/core/evaluation/references/regression-format.md`.
Multi-model consensus is defined in `skills/core/routing/references/consensus-protocol.md`.
DR-107 in `dev/DECISIONS.md` changed the default from Claude-wins-ties to stricter-score-wins.
For mechanical and structural criteria, the lower score wins unless the higher scorer cites direct satisfying evidence.
For qualitative criteria, the stricter score remains the default unless the disagreement is factual rather than threshold-based.
The consensus protocol also defines a boundary criteria exception for criteria such as F3, Q5, E1, E2, and E3.
Those boundary criteria use criterion-local evidence to distinguish real regressions from evaluator variance.
`scripts/eval-normalize.sh` canonicalizes model outputs before consensus.
`scripts/eval-consensus.sh` performs the mechanical merge for normalized outputs.
The multi-model report shape is in `templates/core/multi-model-report.md`.
The evaluation framework is itself subject to evaluation and evolution.
This is why criterion changes in `command-criteria.md` require rubric-change governance and baseline awareness.

## 9. Learning Pipeline

The learning pipeline is defined in `skills/core/evolution/references/learning-pipeline.md`.
Its purpose is to turn repeated evidence into local reusable guidance without automatically rewriting Git-managed skills.

```text
sources/*.jsonl
  -> skills/{scope}/events.jsonl
  -> learned.md
  -> gotchas.md
  -> SKILL.md only after human or /evolve review
```

The storage root is `${CLAUDE_PLUGIN_DATA:-$PROJECT_ROOT/.tmp}`.
Source files include `sources/session-patterns.jsonl`, `sources/evaluations.jsonl`, `sources/friction.jsonl`, and `sources/corrections.jsonl`.
Per-skill stores live under `${CLAUDE_PLUGIN_DATA}/skills/{scope}/`.
Each per-skill store can contain `events.jsonl`, `state.json`, `learned.md`, and `gotchas.md`.
`scripts/learning-ingest-eval.sh` normalizes saved evaluation JSON into source events.
`scripts/learning-log-tool-failure.sh` records tool failure signals.
`scripts/learning-session-end.sh` records session-end patterns such as unfinished promises.
`scripts/learning-distill.sh` routes events to scope-specific stores and distills evidence.
`scripts/learning-load-context.sh` loads the highest-signal local learnings for a component or skill scope.
Learned entries use IDs like `LRN-YYYYMMDD-XXX`.
Gotcha entries use IDs like `GOTCHA-YYYYMMDD-XXX`.
Promotion from `learned.md` to `gotchas.md` requires enough occurrences, independent tasks, span days, and confidence.
Promotion from `gotchas.md` to Git-managed `SKILL.md` is not automatic.
That last step requires `/evolve` or human review.
The knowledge base under `docs/specs/knowledge/` is separate from the local learning pipeline.
Knowledge entries are durable, Git-managed research outputs.
The index at `docs/specs/knowledge/INDEX.md` is maintained by `scripts/knowledge-catalog.sh`.
Use the learning pipeline for local repeated operational evidence.
Use the knowledge base for reusable external or synthesized knowledge that should travel with the repository.

## 10. Session Archive

The session archive is the local memory layer for visible Claude transcript evidence.
The method is defined in `skills/core/session-archive/SKILL.md`.
The schema is defined in `skills/core/session-archive/references/archive-schema.md`.
The retrieval API is defined in `skills/core/session-archive/references/retrieval-contract.md`.
Wiki promotion is defined in `skills/core/session-archive/references/wiki-schema.md` and `skills/core/session-archive/references/wiki-gate.md`.
Runtime data lives under `${CLAUDE_PLUGIN_DATA}/session-archive/`.
The canonical SQLite file is `${CLAUDE_PLUGIN_DATA}/session-archive/index.sqlite`.
The queue file is `${CLAUDE_PLUGIN_DATA}/session-archive/queue.jsonl`.
The archive uses SQLite FTS5 for lexical search.
The `sources` table stores transcript file metadata.
The `segments` table stores visible searchable segment records.
The `segments_fts` virtual table indexes content, command hints, component hints, and tool names.
FTS maintenance is explicit because defensive SQLite can reject trigger-based virtual-table writes.
Segment IDs use `main:<session-id>:<line-no>:<item-no>` for main transcripts.
Subagent segment IDs use `subagent:<session-id>:<subagent-file-stem>:<line-no>:<item-no>`.
Segment kinds include `text`, `tool_use`, `tool_result`, and `meta`.
Speakers include `user`, `assistant`, and `tool`.
Thinking blocks are always dropped.
Local command wrappers become `segment_kind='meta'` with `is_meta=1`.
Meta segments are excluded by default and require `--include-meta` for search.
`hooks/session-archive-ingest.sh` only enqueues transcript paths on SessionEnd.
`scripts/session-archive.sh sync` is the only parser and indexer.
This enqueue-only design keeps SessionEnd fast and fail-open.
Search uses `scripts/session-archive.sh search`.
Context retrieval uses `scripts/session-archive.sh get`.
Status uses `scripts/session-archive.sh status`.
Backfill uses `scripts/session-archive.sh rebuild --since 30d` by default.
Retention cleanup uses `scripts/session-archive.sh prune --older-than 365d` by default.
PA integration is fail-open and advisory.
`agents/pa/librarian.md` may search the archive as a fourth retrieval lane using read-only `status` and `search`.
Session hits render separately with `[S1]` citations.
RnD integration is also advisory.
`commands/rnd.md` can use raw session archive hits as `session_prior_work[]`, but conversation-session evidence is context-only and cannot support report claims directly.
Session wiki adds a promotion tier above the raw archive.
The three-layer model is raw archive to proposal to wiki.

```text
Raw transcript segments
  -> SQLite FTS5 raw archive
  -> proposal bundle under proposals/
  -> reviewed wiki page under wiki/
  -> optional QMD `session-wiki` collection
```

`commands/session-wiki.md` is the command surface for this tier.
`agents/core/session-synthesizer.md` drafts wiki page markdown from proposal bundles.
Drafts live under `proposals/PROMO-<ts>-<slug>/`.
Applied pages live under `wiki/<project_slug>/<page_type>/<slug>.md`.
Page type directories include `components`, `topics`, `decisions`, and `patterns`.
Wiki citations use `[SA<n>]`.
The PA librarian citation marker `[S<n>]` remains reserved for raw session hits.
`/session-wiki apply <id>` is the only wiki-write path.
Apply checks preimage hashes before writing.
QMD registration is manual and never done automatically by archive commands.

## 11. Multi-Model Collaboration

Multi-model collaboration has two related but distinct layers.
One layer is the human-facing collaboration posture in `CLAUDE.md` and `AGENTS.md`.
The other layer is command-level external model routing in scripts and routing references.
The default collaboration posture is controller and executor separation.
The controller owns goals, constraints, boundaries, invariants, acceptance criteria, merge, and review.
The executor owns the delegated slice after handoff.
Mid-flight steering is avoided unless the contract itself becomes invalid.
Review is bounded to two rounds.
User escalation is reserved for genuine ambiguity, irreducible trade-offs, or persistent bounded disagreement.
This pattern is recorded in `dev/DECISIONS.md` before DR-107 as the portable collaboration decision.
Runtime contracts live in `skills/core/collaboration/references/runtime-contract.md`.
Command-level `--multi` behavior is separate.
It usually means Claude plus Codex, not a general committee.
`commands/core/evaluate.md` uses Codex relay for independent external evaluation.
`commands/swe/ship.md` and `commands/swe/tune.md` use multi-model review or evaluation where the branch makes sense.
`commands/rnd.md` uses optional routed second opinions for boundary cases and adversarial review.
The Codex relay script is `scripts/codex-relay.sh`.
Parsing support is in `scripts/codex-parse.sh`.
Legacy or generic invocation support appears in `scripts/invoke-model.sh`.
Consensus rules live in `skills/core/routing/references/consensus-protocol.md`.
Parallel fan-out and fan-in guidance lives in `skills/core/routing/references/parallel-execution-pattern.md`.
Completion-status handling lives in `skills/core/routing/references/completion-status-protocol.md`.
External model output should be treated as evidence, not authority.
The command still owns final integration and user-visible reporting.
When external tools are unavailable, commands degrade to single-model mode where that is safe.
When a machine-consumed payload is expected, the command should name the authoritative file or structured fields.

## 12. State Management

Ouroboros keeps durable project state in Git-managed docs and runtime state in local plugin data or module-specific runtime directories.
`dev/STATUS.md` is the current handoff document.
It records state, recent session work, immediate next tasks, blockers, and references.
`AGENTS.md` requires reading it at session start and updating it at session end.
`dev/MILESTONES.md` is the roadmap and backlog tracker.
It groups work by version and records completed milestones.
`dev/DECISIONS.md` is the design decision log.
It records DR entries such as DR-107 for stricter evaluation consensus and DR-114 through DR-116 for the session archive and wiki tiers.
`docs/ROADMAP.md` records project history for public or contributor context.
`dev/VISION.md` records architecture philosophy and module rationale.
`CLAUDE.md` documents `MEMORY.md` policy.
The repository does not currently track a root `MEMORY.md` file.
The policy is that memory is for repeated injection of platform gotchas or personal environment details, not for project state.
Project state belongs in `dev/STATUS.md`.
Design rationale belongs in `dev/DECISIONS.md`.
Milestone tracking belongs in `dev/MILESTONES.md`.
SWE runtime artifacts live under `.swe/active/` while a turn is in progress.
Archived SWE specs live under `docs/specs/record/` according to the SWE artifact contracts.
RnD runtime state lives under `.rnd/sessions/{id}/`.
RnD archived study output lives under `docs/research/{year}/{slug}/`.
PA state lives under `.pa/` and should respect PA trust and boundary rules.
Plugin runtime data lives under `${CLAUDE_PLUGIN_DATA}`.
Session archive runtime data lives under `${CLAUDE_PLUGIN_DATA}/session-archive/`.
Learning runtime data lives under `${CLAUDE_PLUGIN_DATA}/skills/{scope}/` and related source directories.
Contributors should avoid moving state across these layers without a decision record.
The boundary keeps public docs, development records, local runtime memory, and user vault data from blurring into each other.
