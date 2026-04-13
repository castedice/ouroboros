---
name: state-load-contract
description: This reference defines the shared `.pa/` startup load contract used by PA commands, including required core files, optional overlays, enrichment fallback, and command-specific load deltas.
---

# State Load Contract — Shared `.pa/` Startup Pattern

> Purpose: Reference for `trust-and-boundaries` and PA command authorship.
> Scope: How steady-state PA commands load `.pa/` state before delegation, judgment, or presentation.

## Core Startup Sequence

1. Parse command arguments first so the loader knows the selected horizon, mode, or target shape before it touches optional state.
2. Read `.pa/settings.json` before other assistant-state files because it supplies the vault path, capability tier, automation posture, QMD settings, and shadow metadata.
3. Read `.pa/vault-profile.json` next when the command needs retrieval defaults, linking rules, journaling conventions, placement rules, or assistant preferences.
4. Load command-owned overlays only after the core pair is available.
5. Apply `context-profiles.json` or `loading-strategy.md` before loading enrichment files when the command supports tiered context budgets.
6. Load soul or persona render state after the substantive state pack is known.
7. Delegate to agents or continue with command-local synthesis only after the load contract has resolved required inputs and known degradations.

## Hard Prerequisites

- Most steady-state PA commands abort when `.pa/settings.json` is missing and direct the user to `/pa survey` or `/pa init`.
- Commands that need vault conventions also abort when `.pa/vault-profile.json` is missing and use the same recovery message.
- `heartbeat` is the main exception because it can start from `.pa/` plus `.pa/settings.json` and treat the rest of the files as health overlays.
- `reset` can continue without `.pa/entities.json` or `.pa/derivation-state.json` because those files only enrich goal alignment and compile preflight.
- `review` can continue without work, timeline, entities, or review checkpoint files, but it must lower confidence and name the missing evidence.

## Universal Core Files

- `settings.json` is the execution-environment contract.
- `settings.json` resolves vault location, posture, capability tier, QMD mode, collection name, and sometimes `shadow_root`.
- `vault-profile.json` is the vault-convention contract.
- `vault-profile.json` resolves retrieval defaults, linking style, journaling rules, placement rules, and assistant preferences.
- Commands extract only the fields they need from the core pair instead of treating the files as opaque blobs.
- No command in this batch is allowed to infer the vault root from the current working directory during steady-state startup.

## Overlay Families

- `work.jsonl` and `timeline.jsonl` are the operational overlays for agenda, day, and review.
- `entities.json`, `relations.json`, and `derivation-state.json` are the ontology overlays for goal-aware review, reset, focus-aware synthesis, and health checks.
- `review-state.json` is the checkpoint overlay for review and heartbeat.
- `calendar-events.jsonl` is optional schedule context for agenda and day.
- `retrieval-profiles.json` is the optional per-command retrieval override layer for ask, brief, and day.
- `context-profiles.json` is the optional budget-control layer that decides whether enrichment files should load at all.
- `preferences-learned.json`, `specialists.json`, `memory/observations.jsonl`, and `intelligence/energy-patterns.json` are enrichment overlays that sharpen judgment but do not define the base state.
- `assistant-ledger.jsonl` and `specialist-insights.jsonl` are append targets rather than startup prerequisites.

## Persona And Enrichment Fallback

- Commands that produce user-facing prose load `.pa/soul.md` first for render settings and optional reasoning posture.
- If `.pa/soul.md` is missing, those commands read `.pa/persona.json` as a render-only fallback.
- If both persona files are missing, those commands use defaults from `skills/pa/persona-response/references/persona-schema.md`.
- Missing persona state never aborts the command.
- Missing optional enrichment files are skipped rather than repaired during startup.

## Optional Load Governance

- `ask`, `agenda`, `day`, and `review` explicitly consult `.pa/context-profiles.json` when it exists.
- When no approved context profile exists, those commands fall back to `skills/pa/context-assembly/references/loading-strategy.md`.
- Commands use the context profile to justify skipping optional enrichment files instead of silently omitting them.
- Commands that do not declare context-profile support use direct file-by-file optionality instead.
- Empty optional files are treated as absent context, not as startup errors.

## Command Deltas

- `ask` loads the minimal retrieval baseline of settings, vault profile, retrieval overrides, optional context profile, soul fallback, and optional memory observations.
- `brief` matches the retrieval baseline but stops at retrieval overrides and soul fallback in the current command text.
- `agenda` loads settings and vault profile, then reads work and timeline in full, filters them to the selected horizon, and only then pulls optional calendar, preference, context, soul, specialist, memory, and energy overlays.
- `day` mirrors the agenda baseline, adds retrieval overrides, resolves today's daily note path, and conditionally loads pending memory flush and relationship-date intelligence by mode.
- `review` loads the widest steady-state pack, including work, timeline, entities, relations, derivation state, the follow-up report template, optional context profile, personal profile, review checkpoint, soul fallback, specialists, and observations.
- `reset` loads only the composite baseline of settings, vault profile, optional entities, optional derivation state, and the final weekly review template before delegating the heavy work to subcommands.
- `heartbeat` loads the `.pa/` directory, settings, health overlays, and soul fallback before the shell backend evaluates subsystem status.

## Per-File Startup Semantics

- `settings.json` is always the first source of truth for execution environment.
- `vault-profile.json` is always the first source of truth for vault conventions.
- `work.jsonl` and `timeline.jsonl` are read in full and filtered in memory rather than queried piecemeal.
- `entities.json` is optional in commands that can stay useful without goal or graph context.
- `relations.json` is only loaded when relation evidence matters to judgment or health.
- `derivation-state.json` is optional state for freshness, compile cursor, and dirty-path context.
- `review-state.json` is soft state for checkpoint continuity rather than a hard startup gate.
- `personal-profile.json` is enrichment for year-plus review and not a universal prerequisite.
- `calendar-events.jsonl` is optional schedule context and never blocks agenda or day.
- Templates such as `follow-up-report.md` and `weekly-review.md` are startup inputs when the command promises template-faithful rendering.

## Read Shape Rules

- Commands read JSONL overlays in full and summarize or filter them after load instead of performing partial overlay reads at startup.
- Commands treat templates as startup dependencies when the final report must preserve a fixed section order.
- Commands read `shadow_root` from `settings.json` only when they may need a privacy-safe authored note path.
- Commands do not mutate `.pa/` state during the load phase.
- Commands do not regenerate missing overlays during startup load.

## Failure Semantics

- Missing hard prerequisites abort before delegation.
- Missing optional overlays produce graceful degradation, partial evidence, or skipped sections.
- Malformed review checkpoint state in `review` becomes first-run context on writeback rather than a startup failure.
- Missing `derivation-state.json` in `reset` means compile preflight starts without a prior cursor.
- Missing `derivation-state.json` or `review-state.json` in `heartbeat` should surface as backend health findings rather than silent repairs.
- Missing `work.jsonl` or `timeline.jsonl` in `agenda` is a command-specific hard failure.
- Missing `work.jsonl` or `timeline.jsonl` in `review` is a soft failure that lowers confidence.

## Non-Goals

- Startup load is not permission to read every file under `.pa/`.
- Startup load is not the place to repair malformed state.
- Startup load is not the place to invent missing context from model knowledge.
- Startup load is not the place to apply persona rendering.
- Startup load is not the place to write ledger entries beyond later telemetry append phases.

## Cross-Command Invariants

- `settings.json` remains the first authoritative source for execution environment and posture.
- `vault-profile.json` remains the authoritative source for vault conventions and retrieval defaults.
- Enrichment files can refine judgment, but they never replace the operational overlays or source markdown as the basis for facts.
- Persona state is always a graceful fallback chain, not a prerequisite gate.
- Commands surface missing state explicitly instead of silently fabricating equivalent context.
- Commands load only what the command contract says they will use.

## Practical Checklist

- Load `settings.json` before any other `.pa/` file that depends on vault path, posture, or QMD configuration.
- Load `vault-profile.json` before using retrieval defaults, journaling rules, linking style, or placement rules.
- Treat `work.jsonl`, `timeline.jsonl`, `entities.json`, `relations.json`, and `derivation-state.json` as command-specific overlays rather than universal startup baggage.
- Use `context-profiles.json` and `loading-strategy.md` to justify optional enrichment loads.
- Apply the soul → persona → defaults fallback before any final user-facing render.
- Abort only on missing hard prerequisites, and degrade gracefully everywhere else.
