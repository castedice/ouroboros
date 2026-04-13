---
name: soul-fallback
description: This reference defines the persona-state load order and fallback chain from `.pa/soul.md` to `.pa/persona.json` to schema defaults, including what each stage contributes to reasoning and rendering.
---

# Soul Fallback — Persona State Load Order

> Purpose: Reference for `persona-response`.
> Scope: How PA loads conversational persona state and what is lost or preserved at each fallback level.

## Primary Rule

- Always load `.pa/soul.md` first.
- Fall back to `.pa/persona.json` only when `soul.md` is missing.
- Fall back to schema defaults only when both files are missing.
- Missing persona state is a graceful fallback case and never a command failure.

## Stage 1 — `.pa/soul.md`

- `.pa/soul.md` is the version 2 persona container.
- Its YAML frontmatter carries the same render fields that legacy `persona.json` used.
- Its markdown body carries soul context that can shape reasoning posture.
- Frontmatter controls sentence style, warmth, directness, emoji use, honorifics, and address style.
- Body sections such as `## Principles`, `## Personality`, `## Relationship`, and `## Opinions` can influence framing, initiative, and challenge style.
- Soul body content may shape how PA thinks, but it may not override evidence.

## Stage 2 — `.pa/persona.json`

- `.pa/persona.json` is the legacy version 1 render-state file.
- It provides render fields only and no soul body.
- Commands can still render correctly from `persona.json`, but they lose soul-specific reasoning posture.
- The legacy file remains valid as a runtime fallback until the user migrates.
- `persona.json` never becomes a reason to fail a command just because `soul.md` is absent.

## Stage 3 — Schema Defaults

- Defaults come from `skills/pa/persona-response/references/persona-schema.md`.
- Defaults provide a professional-friendly Korean assistant with polite speech, medium warmth, medium-high directness, and no emoji.
- Defaults provide render configuration only and no soul body.
- Defaults are the last resort and keep the command usable when the user never configured persona state.

## What Each Stage Contributes

- `soul.md` contributes render settings and reasoning posture.
- `persona.json` contributes render settings only.
- Schema defaults contribute a safe baseline render configuration only.
- None of the three stages are allowed to change facts, rankings, citations, risks, or actions after reasoning is complete.

## Shared Field Continuity

- `locale`, `tone`, `formality`, `warmth`, `directness`, and `render_hints` are continuous across `soul.md` frontmatter and `persona.json`.
- `soul.md` adds `version: 2` and `updated`.
- `persona.json` remains `version: 1` and has no body sections.
- Render consumers can therefore read frontmatter and legacy JSON with the same mental model for delivery settings.

## Migration Contract

- When `persona.json` exists but `soul.md` does not, the migration target is `soul.md`.
- Migration copies legacy render fields into soul frontmatter.
- Migration upgrades the version to `2` and adds `updated`.
- Migration fills the body with default sections from `templates/pa/soul.md`.
- Survey is the command that explicitly offers this migration during report generation.
- Init bypasses migration entirely because it writes `soul.md` directly.

## Producer Versus Consumer Commands

- `init` is the producer command that builds `$SOUL` from interview answers or defaults and writes `.pa/soul.md`.
- `init` must not create `.pa/persona.json` as a parallel state source.
- `survey` is the bridge command that can detect a legacy persona-only vault and offer migration.
- Steady-state commands such as `ask`, `brief`, `agenda`, `day`, `review`, `focus`, and `heartbeat` are consumers of the fallback chain.

## Reasoning Consequences

- When `soul.md` is present, commands may pass soul principles into delegated judgment agents before the final render pass.
- When only `persona.json` is present, those soul-principle effects are unavailable.
- When only defaults are available, commands should keep neutral judgment posture and default delivery.
- No fallback stage authorizes fabricated reassurance or evidence changes.

## Rendering Consequences

- Sentence endings always come from the highest available render state.
- Warmth and directness always come from the highest available render state.
- Emoji usage always comes from the highest available render state.
- Address style and honorific rules always come from the highest available render state.
- Formality wins when frontmatter fields conflict with each other.

## Source Values

- `source: "default"` means the state came from schema defaults or a default soul template.
- `source: "interview"` means the user chose the persona through an interview flow.
- `source: "manual"` means the user edited the file directly.
- The source value explains provenance, but it does not change load precedence.

## Failure Semantics

- Missing `soul.md` is a normal fallback case.
- Missing `persona.json` after a soul miss is a normal fallback case.
- Malformed persona state should degrade to defaults instead of aborting user-facing commands whenever safe parsing is impossible.
- Missing soul body content removes reasoning posture, but it does not remove render capability.

## Practical Checklist

- Try `.pa/soul.md` first.
- Use soul frontmatter for rendering and soul body for optional reasoning posture.
- Use `.pa/persona.json` only as a render-only fallback.
- Use schema defaults only when both files are absent.
- Let `survey` handle migration when the user wants to upgrade legacy persona state.
- Let `init` create `soul.md` directly and keep `persona.json` absent in fresh vaults.
