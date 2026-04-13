# Ouroboros User Guide
This guide is for developers who installed ouroboros and want practical usage patterns.
Read `README.md` for the module inventory and repository layout.
This file focuses on command flow, realistic examples, and expected output.

## 1. Getting Started
Claude Code is required.
Codex CLI is optional and enables multi-model evaluation, review, and selected research checks.
QMD is optional for Core, SWE, and RnD, but PA setup and semantic retrieval require it.
Obsidian CLI and `ob` sync are optional PA enhancements.
Start Claude Code with `claude --plugin-dir ./ouroboros`.
Run `/onboard` first.
Expected: module discovery, command suggestions, and recommended workflows such as `/swe spiral`, `/pa survey`, `/rnd`, and `/session-wiki`.
Run `/doctor` next.
Expected: `## Doctor Report`, a `Check | Status | Detail` table, and a summary such as `6 OK, 1 warnings, 0 failures`.
Treat `OK` as ready, `WARN` as degraded but usable, and `FAIL` as a blocker for that feature family.
If Codex is missing, commands fall back to single-model mode.
If QMD is missing, PA setup or retrieval will stop with an install guide.
If hooks or settings fail, fix them before relying on archive, learning, or scheduled workflows.

## 2. Core Module Workflows
### Evaluate -> Evolve Loop
Use this when a command, agent, skill, or template needs quality improvement.
Run `/evaluate commands/core/evaluate.md --multi --compare`.
Expected: `Score Summary`, zero-score criteria, agreement notes, and saved JSON under `dev/evaluations/`.
Run `/evolve commands/core/evaluate.md --eval dev/evaluations/core-latest.json --focus Q5`.
Expected: before/after level, changed files, and any remaining regressions.
Finish with `/evaluate --before /tmp/evaluate-before.md --after commands/core/evaluate.md --multi` when the change matters.

### Research -> Absorb Pipeline
Use `/research` when you want knowledge captured without changing plugin structure.
Run `/research "session archive retrieval design patterns"`.
Expected: source findings, patterns, trade-offs, and a proposed knowledge entry.
Use `/absorb` when the source should become module or component changes.
Run `/absorb https://github.com/example/plugin-repo --into core --reference core`.
Expected: research findings, gap analysis, generated components, and a quality gate.
If overlap is high, expect a checkpoint before generation.

### Generate A Module
Use `/generate` when you already know the module or component shape.
Run `/generate observability "Plugin telemetry, health summaries, and runtime diagnostics" --reference core`.
Expected: a manifest, generated files, and Level >= 2 quality-gate results.
Add one component with `/generate core/triage "Command that ranks plugin maintenance tasks from STATUS and evaluations" --type command`.
Expected: final path, structural validation, and a generated-file report.
Use `--reference core` when you want the new module to match Core conventions.

### Brainstorm -> Decide
Use `/brainstorm` before design choices where several options could work.
Run `/brainstorm "How should session wiki pages expire or refresh?" --framework double-diamond --output`.
Expected: idea clusters, ranked options, trade-offs, and a saved file under `docs/brainstorms/`.
Use the selected option as input to `/swe spec`, `/generate`, or a decision record.
Example next command: `/swe spec "Implement the selected session wiki refresh policy"`.

### Adopt Into A Project
Use `/adopt` when another project should receive ouroboros guidance and settings.
Run `/adopt ~/workspace/my-api --dry-run`.
Expected: project profile, settings merge preview, and AGENTS.md plan.
Apply after review with `/adopt ~/workspace/my-api`.
Expected: created or updated `AGENTS.md`, `.claude/settings.json`, and docs scaffolding.
The command asks before overwriting an existing `AGENTS.md`.

### Upgrade From Upstream
Use `/upgrade` when local ouroboros customizations need upstream reconciliation.
Run `/upgrade --check`.
Expected: added, modified, deleted, and conflict classifications without writes.
Use `/upgrade --source ~/tmp/ouroboros-upstream --check` for a local release candidate.
Run `/upgrade` without `--check` when ready to apply.
Expected: merge decisions, preserved customizations, validation results, and a final review.

## 3. SWE Module Workflows
### Spec -> Dev -> Ship -> Tune
Use this when you want explicit control over each composite.
Run `/swe spec "Add API filtering for session archive export" --depth U:Std C:Std D:Std I:Deep`.
Expected: a depth plan plus `.swe/active/01-understand.md` through `.swe/active/04-interface.md`.
Run `/swe dev "Add API filtering for session archive export"`.
Expected: test, implement, verify, and optimize artifacts.
Run `/swe ship "Add API filtering for session archive export" --multi`.
Run `/swe tune "Add API filtering for session archive export" --multi`.
Expected: production-readiness findings, safe improvements, and retrospect lessons.

### Spiral For End-To-End Work
Use `/swe spiral` when one command should run spec, dev, ship, and tune.
Run `/swe spiral "Add source filters to session archive search" --policy probe`.
Expected: depth selection, Light probe output, and a keep-or-escalate checkpoint.
Use `/swe spiral "Fix typo in session archive status output" --fast` for small, familiar work.
Use `/swe spiral "Rework RnD branch pruning semantics" --deep --policy linear` for high-risk or unfamiliar work.
Expected: `.swe/active/spiral-state.json`, composite artifacts, and a final tune report.

### Reverse For Existing Code
Use `/swe reverse` when code exists but spec artifacts are missing.
Run `/swe reverse scripts/session-archive.sh --scope "search, get, and wiki promotion flows"`.
Expected: recovered Context, Constraint, Architecture, and Interface artifacts.
Use `/swe reverse ~/workspace/my-api --scope "billing webhook handler" --fast` for a quick existing-code pass.
Expected: scale detection, a depth plan, and partial artifacts if the codebase is too large.

### Depth System Explained
Depth controls ceremony, not coding style.
The fixed order is `understand -> constrain -> design -> interface -> test -> implement -> verify -> optimize`.
Use `Light` for small, familiar, reversible tasks.
Use `Standard` for most production tasks.
Use `Deep` for high risk, unfamiliar domains, cross-team interfaces, compliance, or expensive rollback.
Use `Skip` only when a stage is categorically inapplicable.
Run `/swe spec "Design a new PA ingestion mode" --depth U:Deep C:Std D:Deep I:Std`.
Expected: per-stage depth and rationale.
If `--fast` and `--depth` are both present, `--depth` wins.

### Team Policy
Use team policy for complex work where shaping, building, and critique should be separate.
Run `/swe spiral "Add resumable RnD paper export" --policy team`.
Expected: specialist setup, cross-review findings, and fallback behavior if team setup fails.
Use `/swe spiral "Redesign PA reset horizon handling" --policy team+probe --route design=codex,review=codex`.
Expected: Light probes, team checkpoints, and routed Codex input when available.
Routing is advisory and disabled when Codex or the selected policy cannot support it.

## 4. PA Module Workflows
### Init Or Survey For Vault Setup
Use `/pa init` for a new vault and `/pa survey` for an existing vault.
Run `/pa survey ~/vaults/personal`.
Expected: vault profile preview, QMD registration state, and `.pa/` state files.
Run `/pa init ~/vaults/new-life-os` for a fresh vault.
Expected: starter folders, `.pa/vault-profile.json`, `.pa/settings.json`, and a getting-started note.
If QMD is missing, setup stops with a QMD install and enablement guide.

### Day And Agenda For Daily Flow
Use `/pa day` for a morning brief, evening closeout, or read-only status.
Run `/pa day --mode morning`.
Expected: priorities, risks, waiting-fors, and confidence notes.
Run `/pa agenda --horizon week`.
Expected: current commitments, deadlines, waiting-fors, and focus suggestions.
Run `/pa day --mode status` when you want a conversation-only snapshot.
Status mode never writes to the vault.

### Ask And Brief For Retrieval
Use `/pa ask` for a direct cited answer and `/pa brief` for a compact dossier.
Run `/pa ask "What did I decide about weekly review cadence?"`.
Expected: cited notes, confidence, and coverage gaps.
Run `/pa brief "Agent memory reliability"`.
Expected: topic summary, important sources, and uncertainty notes.
If QMD is unavailable, expect a degraded or aborted retrieval path depending on setup state.

### Capture And Ingest For Input
Use `/pa capture` for thoughts, scraps, transcripts, and quick notes.
Run `/pa capture "Idea: review session archive stale wiki pages every Monday and propose refreshes"`.
Expected: target note path, duplicate status, lookup mode, and reversal hint.
Use `/pa ingest "https://example.com/agent-memory-post"` for URLs or external content.
Expected: digest, destination proposal, and provenance.
The command may present an exact proposal instead of writing.

### Draft For Writing
Use `/pa draft` to create or revise one note in the vault's existing voice.
Run `/pa draft "Session archive retrieval patterns"`.
Expected: write plan, target path, style sources, citations when used, and confidence.
Run `/pa draft --revise Projects/Ouroboros/session-archive.md` for revision.
Expected: exact bounded patch or proposal.
Posture controls whether the draft is applied or shown as a proposal.

### Review And Reset For Maintenance
Use `/pa review` for health, stale commitments, orphan notes, and resurfacing.
Run `/pa review --horizon month`.
Expected: follow-up findings, stale items, resurfaced notes, and confidence notes.
Use `/pa reset --horizon week` to compose review, compile, agenda, and link.
Expected: priority reset, skipped phases if any, and final review.
Use `/pa review --horizon year --narrative` for long-horizon reflection.

### Link For Graph Work
Use `/pa link` for relationship discovery around a note, entity, or topic.
Run `/pa link Projects/Ouroboros/session-archive.md`.
Expected: link suggestions, unresolved-link fixes, and a relationship map when density is high.
Run `/pa link "research agent memory"` for topic-based graph work.
Expected: related notes, entity relations, and no-connection output when evidence is thin.
If you ask to apply changes, PA checks posture and may show an apply preview first.

### Specialist For Domains
Use `/pa specialist` to create or manage domain-specific advisors.
Run `/pa specialist list`.
Expected: registered specialists and status.
Run `/pa specialist create "fitness"`.
Expected: interview questions, generated specialist definition, and registry update.
Run `/pa specialist remove fitness-001` to deactivate an existing specialist.

## 5. RnD Module Workflows
### Running A Study
Use `/rnd` for bounded literature-only studies with persisted state.
Run `/rnd --budget 90 "What patterns make agent memory reliable in plugin workflows?"`.
Expected: session id, archive path, `brief.md`, and a scope approval checkpoint.
If the run pauses, resume with `/rnd --resume rnd-20260412-101500 "approve scope"`.
Expected: the study continues from persisted `state.json`, not chat memory.

### Budget Management
The default study budget is 90 minutes when omitted.
Budget state lives in `.rnd/sessions/{id}/budget.json`.
Run `/rnd --status rnd-20260412-101500`.
Expected: current stage, run status, archive path, and budget usage.
If a hard cap is reached, RnD stops with a partial report instead of spending speculative work.

### Branch Search
Branch search compares multiple live hypothesis clusters.
Auto mode enables branch search when at least three viable hypotheses survive.
Run `/rnd --budget 120 --branch auto "Which retrieval strategies reduce hallucinated prior-work recall?"`.
Force branch mode with `/rnd --budget 120 --branch on "Compare lexical, semantic, and session-wiki prior-work retrieval for RnD studies"`.
Expected: `queue.json`, `branch-ledger.jsonl`, wave scheduling, branch scores, and prune or merge decisions.

### Prior-Work Memory
RnD checks completed study memory and optional session-wiki context before external search.
Run `/rnd --list`.
Run `/rnd --status`.
Expected: sessions, completion state, and archive locations.
Completed studies are indexed into `.rnd/archive-index.json`.
Session archive and session-wiki hints are context-only and not core evidence.

### Meta-Research
Use meta-research to inspect how the RnD harness performs across completed studies.
Run `/rnd --meta extract rnd-20260412-101500`.
Expected: per-study metrics in `.rnd/sessions/{id}/study-metrics.json`.
Run `/rnd --meta analyze`.
Expected: `.rnd/meta-aggregate.json` and `.rnd/meta-report.md`.
Suggestions are advisory only and never auto-edit commands, skills, or scripts.

### Paper Output
Use `--paper` when the final report should use the academic report template.
Run `/rnd --paper --budget 120 "What evidence supports branch pruning in autonomous research agents?"`.
Expected: `report.md`, `review.md`, `references.bib`, `README.md`, and `meta-learning.md` under `docs/research/{year}/{slug}/`.
The report still needs a release or archive-only decision before completion.
Use `--single` when you do not want routed-model review.

## 6. Session Archive
The session archive indexes visible Claude transcript evidence into SQLite FTS5.
Thinking blocks are dropped.
The SessionEnd hook only enqueues transcript paths.
The `sync` action parses and indexes queued transcripts.
Run `bash scripts/session-archive.sh init`.
Run `bash scripts/session-archive.sh sync`.
Run `bash scripts/session-archive.sh status`.
Expected: schema version, pending queue depth, indexed source count, and segment count.
Search with `bash scripts/session-archive.sh search "preimage hash mismatch" --project current --component session-wiki --top 5`.
Expected: segment ids, speakers, segment kinds, timestamps, component hints, and snippets.
Retrieve context with `bash scripts/session-archive.sh get main:abc123:42:0 --before 2 --after 2`.
Use `/session-wiki` to promote raw archive evidence into reviewed wiki pages.
Run `/session-wiki propose --component session-archive --since 7d`.
Run `/session-wiki list --status pending`.
Run `/session-wiki show PROMO-20260412-103000-session-archive`.
Run `/session-wiki apply PROMO-20260412-103000-session-archive`.
Run `/session-wiki lint`.
Expected: proposal id, target pages, confidence, applied paths, final hashes, and lint findings.
Reject weak proposals with `/session-wiki reject PROMO-20260412-103000-session-archive --reason "Not enough independent support"`.
QMD registration for session wiki is manual.
Run `qmd collection add session-wiki "$CLAUDE_PLUGIN_DATA/session-archive/wiki" --pattern '**/*.md'`.
Run `qmd update && qmd embed`.
After registration, query with `/session-wiki query "What did we learn about session archive preimage drift?"`.

## 7. Multi-Model Evaluation
Codex CLI enables Claude plus Codex checks.
Verify Codex with `codex --version`, then rerun `/doctor`.
Most commands auto-detect Codex unless `--single` is present.
Use `--multi` when the command exposes it and you want to force the multi-model path.
Run `/evaluate commands/rnd.md --multi --compare`.
Expected: per-criterion consensus, agreement rate, divergence analysis, bias alerts, and saved evaluation JSON.
Use `--unanimous` when split criteria need a deliberative round.
Run `/evaluate skills/core/session-archive/SKILL.md --multi --unanimous`.
Routine consensus compares independent criterion scores and uses majority or criterion-local evidence rules.
Unanimous consensus uses blinded Advocate, Devil's Advocate, and Judge roles for split criteria.
Self-enhancement bias is flagged when Claude scores its own output higher than Codex.
Use `/evaluate commands/pa/day.md --single` when Codex is unavailable, too slow, or unnecessary.

## 8. Configuration
Use `CLAUDE.md` for Claude Code-specific operating rules.
Use `AGENTS.md` for shared guidance used by Codex and other agents.
Use `.claude/settings.json` for project permissions, hooks, MCP settings, and runtime behavior.
Use `hooks/hooks.json` and scripts under `hooks/` for lifecycle automation.
After changing configuration, run `/doctor`.
Expected: settings and hooks are `OK`, or exact failures are named.
For another project, prefer `/adopt ~/workspace/my-api --dry-run` over copying files manually.
For repository development, keep command and skill docs in English and follow `AGENTS.md`.
For user-specific behavior, customize the target project's `AGENTS.md` after adoption.
Do not edit generated `.agents/skills/` files directly.

## 9. Troubleshooting
Run `/doctor` first for environment issues.
Interpretation: `OK` means the feature family is ready.
Interpretation: `WARN` means the feature family is usable with degraded behavior.
Interpretation: `FAIL` means you should fix it before relying on that feature family.
If `/onboard` cannot find commands, check that Claude Code started with the correct plugin directory.
If Codex does not run, verify `codex --version`, remove `--single`, and rerun `/doctor`.
If evaluation did not save, check whether `--no-save` was used and inspect `dev/evaluations/`.
If `/pa survey` fails immediately, install or expose QMD and rerun the command.
If PA answers have weak citations, run `/pa survey <vault-path>` again to refresh the profile and QMD state.
If `/rnd` pauses with `run_status: needs_user`, resume with the printed `/rnd --resume <session-id>` command plus your checkpoint answer.
If `/rnd` stops with `blocked_escalation`, the question needs code, data, or another mode outside the literature-only boundary.
If archive search returns no hits, run `bash scripts/session-archive.sh status` and then `bash scripts/session-archive.sh sync`.
If session-wiki query says QMD is unregistered, run the manual `qmd collection add session-wiki ...` command from the status output.
If `/swe dev` cannot start, run `/swe spec` first or pass `--artifact .swe/active/04-interface.md`.
If `/swe ship` cannot find implementation artifacts, run `/swe dev` first or pass an explicit `--artifact`.
If depth feels too heavy, use `--fast` or pass explicit per-stage depth.
If depth feels too shallow, rerun the relevant composite with `--depth Deep` or a per-stage override.
