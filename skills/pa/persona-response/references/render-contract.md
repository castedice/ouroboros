---
name: render-contract
description: This reference defines the shared cross-module persona render pipeline for PA commands, including load order, immutable reasoning content, mutable render controls, command-specific presentation hooks, and verification rules.
---

# Render Contract — Shared Persona Application Pattern

> Purpose: Reference for `persona-response`.
> Scope: The shared persona render pipeline used by PA commands and the bootstrap exception used by init and survey.
> For the application workflow, see `skills/pa/persona-response/SKILL.md`.
> For schema and defaults, see `skills/pa/persona-response/references/persona-schema.md`.

## Core Rule

- Persona is a final presentation pass that happens after retrieval, ranking, synthesis, and section selection are already complete.
- Persona can change delivery, but it cannot change meaning.
- Soul context can shape reasoning posture, but it cannot overrule evidence.

## Shared Pipeline

1. Load render state from `.pa/soul.md`, `.pa/persona.json`, or schema defaults.
2. When `soul.md` exists, treat frontmatter as render configuration and the body as optional reasoning posture.
3. Complete retrieval, judgment, synthesis, confidence assignment, and section selection in neutral command logic or delegated agents.
4. Keep delegated agent outputs raw because agents such as librarian, chief-of-staff, sentinel, and weaver do not apply persona themselves.
5. Apply persona only in the command's final presentation phase.
6. Verify that the rendered output preserved every immutable reasoning-layer element.
7. If verification fails, rerender without changing the underlying reasoning result.

## Shared Load Inputs

- `render_hints.sentence_style` controls sentence endings.
- `warmth` controls acknowledgment density, transitions, and closings.
- `directness` controls whether the command leads with conclusions or with context.
- `render_hints.emoji` controls whether emoji are omitted, minimal, or moderate.
- `formality`, `honorific`, and `address_style` still apply even when a command only names the common four render knobs.
- Missing persona state is always a graceful fallback, not a startup error.

## Immutable Reasoning Layer

- Facts and evidence remain unchanged.
- Rankings, urgency markers, and focus choices remain unchanged.
- Confidence labels remain unchanged.
- Action recommendations remain unchanged.
- Citations and source lists remain unchanged.
- Dates, counts, ids, file paths, and status words remain unchanged.
- Risks, warnings, and error messages remain visible.
- Structured tables, JSON blocks, code blocks, and schema-constrained sections remain byte-stable except for surrounding prose.
- Scope decisions about what to include or omit remain unchanged.
- User checkpoints and trade-offs remain unchanged.

## Mutable Render Layer

- Sentence endings may change to `haeyo`, `hamnida`, or banmal-compatible forms.
- Warmth may add or remove brief acknowledgments and soft transitions.
- Directness may reorder explanation so the conclusion appears first or later.
- Emoji usage may add or remove visual markers when the output stays natural.
- Address style may add the user's name or title when configured.
- Korean prose may be compressed or expanded slightly when substance stays intact.

## Command Coverage

- `ask` renders a conversational answer plus an authoritative source list after librarian retrieval and synthesis finish.
- `brief` renders the fixed focus-brief shape after librarian citations and coverage gaps are finalized.
- `agenda` renders chief-of-staff judgment into the agenda template after focus selection and checkpoint handling finish.
- `day` renders the mode-specific day packet after judgment, daily-note write decisions, and compile-handoff assembly finish.
- `review` renders the follow-up report after sentinel findings, optional specialist advice, and optional narrative synthesis are finalized.
- `focus` renders the dossier after librarian and weaver outputs are merged and confidence is assigned.
- `survey` renders the onboarding report after state writes, QMD status resolution, and any soul migration choice are complete.
- `heartbeat` follows the same final-pass rules even though the source of truth is shell backend output.
- `link` follows the same final-pass rules when presenting structural suggestions and relationship maps.

## Bootstrap Exception

- `init` participates in the contract by creating `.pa/soul.md` from interview answers or schema defaults.
- `init` is the producer-side exception because it seeds future render state instead of loading an already-established soul file.
- `init` must write `.pa/soul.md` and must not create `.pa/persona.json`.
- `survey` is the migration-side exception because it can detect legacy `persona.json` and offer conversion to `soul.md` before the final report render.

## Command-Specific Render Targets

- `ask` keeps the answer conversational, but the trailing sources block remains authoritative and complete.
- `brief` keeps the template sections stable and preserves verbatim excerpts from the context pack.
- `agenda` keeps urgency markers, waiting-for staleness, and focus choice visible even when wording softens.
- `day` keeps concrete dates, schedule lines, carry-forward recommendations, and compile-candidate blocks explicit.
- `review` keeps section order horizon-specific and does not upgrade weak evidence into stronger claims.
- `focus` may unmask people for presentation, but mask identifiers remain the persisted assistant-state form.
- `survey` keeps capability tier, QMD mode, posture, write status, and warnings explicit even when the tone is warm.
- `init` keeps scaffold status, state-file status, and QMD registration status explicit in the completion report.

## Structured Section Rules

- Tables remain tables.
- Source lists remain source lists.
- Checkpoint prompts remain literal decision prompts.
- Compile handoff blocks remain machine-readable.
- Report section order stays command-defined.
- Persona may change only the surrounding connective prose.

## Reasoning Posture Rules

- When `soul.md` exists, `## Principles`, `## Personality`, `## Relationship`, and `## Opinions` may influence framing or initiative.
- Soul context may challenge the user more directly or more gently, but it may not change what the evidence supports.
- Commands that pass `soul_principles` to delegated agents do so before the final render pass.
- Soul posture shapes judgment style, while frontmatter shapes delivery style.
- Legacy `persona.json` provides no soul body, so those reasoning-posture effects are absent in fallback mode.

## Verification Invariants

- Every citation token that appeared before rendering must still appear after rendering.
- Every confidence label that appeared before rendering must still appear after rendering.
- Every priority order chosen before rendering must survive the render pass.
- Every risk, warning, and error that appeared before rendering must remain visible after rendering.
- Every source path, work id, entity id, date, and numeric score must survive unchanged.
- Every action recommendation must keep the same urgency and specificity.
- No new claim, reassurance, or forecast may be introduced by persona alone.
- No section may be added or removed just because the tone changed.

## Failure And Fallback Rules

- Missing `.pa/soul.md` triggers the persona fallback rather than a command failure.
- Missing `.pa/persona.json` after a soul miss triggers schema defaults rather than a command failure.
- Missing both files means render with the default professional-friendly persona and no soul context.
- Commands must never skip the substantive output just because persona state is unavailable.
- Commands must never treat a successful render pass as permission to rewrite persisted source data.

## Practical Checklist

- Finish reasoning before rendering.
- Keep agents neutral and apply persona only in the calling command.
- Load soul before persona and persona before defaults.
- Preserve citations, confidence, rankings, risks, actions, and structured blocks.
- Use render knobs to change wording, not meaning.
- Treat `init` as the soul producer and `survey` as the migration bridge.
- Re-run the render pass if any invariant fails.
