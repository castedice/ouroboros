---
name: persona-response
description: This skill provides persona-aware response rendering for PA. It should be activated when an agent needs to "apply persona to output", "render with persona", "load persona settings", "apply response contract", "separate reasoning from presentation", or "calibrate tone for user output".
summary: Applies persona rendering after reasoning while preserving evidence, confidence, actions, citations, and structured output.
version: 1
tags: [pa, persona, rendering, tone, invariants]
preamble_tier: 1
---

# Persona Response

## Core Rule

**"Persona changes how PA speaks, never what PA says."**

PA output has two layers.
The reasoning layer holds facts, rankings, evidence, risks, confidence, and actions.
The render layer holds sentence endings, warmth, directness, emoji use, and address style.
`soul.md` can shape reasoning posture, but it never overrides evidence or permits fabricated reassurance.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Applying persona before the substance is complete | Reasoning | Finish retrieval, ranking, and judgment before any render pass |
| Letting warmth hide a warning or low confidence result | Rendering | Treat risks, errors, confidence, and actions as immutable reasoning-layer content |
| Treating scribe voice and persona voice as the same thing | Integration | Use persona only for user-facing command output, not vault note authorship |
| Reformatting tables, JSON, code blocks, or source lists | Rendering | Leave structured sections byte-identical |
| Falling back to failure when persona files are missing | Load | Use `.pa/soul.md`, then `.pa/persona.json`, then defaults |
| Using soul personality to override evidence | Reasoning | Soul guides posture and framing, but evidence still wins every conflict |
| Overusing name or emoji settings mechanically | Rendering | Apply address style and emoji only when the configured level permits and the output stays natural |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The persona should make this feel warmer" | Softening warnings, risks, or low-confidence labels during rendering | Keep confidence, risks, errors, and actions immutable |
| "Structured output sounds too stiff in this voice" | Reformatting tables, JSON, code blocks, citations, or source lists | Leave structured sections byte-identical |
| "The soul file says the user likes certainty" | Using soul context to override evidence or fabricate reassurance | Use soul only as posture and let evidence win every conflict |

## Workflow

### 1. Load Persona State

Read `.pa/soul.md` first.
Use frontmatter as render settings and the markdown body as soul context.
If `soul.md` is missing, read `.pa/persona.json` as a render-only fallback.
If both are missing, use the default persona from `${CLAUDE_SKILL_DIR}/references/persona-schema.md`.

### 2. Inject Soul Context Before Reasoning

Use Principles, Personality, Relationship, and Opinions as reasoning posture when those sections exist.
This context may influence judgment style, initiative, and framing, but it does not authorize factual changes.

### 3. Complete The Reasoning Layer

Finish retrieval, synthesis, prioritization, confidence assignment, and action selection before any tone change happens.
At this point the user-facing substance should already be final.

### 4. Apply The Render Layer

Render sentence style, honorific level, warmth, directness, emoji, and address style on top of the completed reasoning output.
Keep Korean prose flexible, but do not alter citations, numbers, ranking order, source paths, or structured blocks.

### 5. Verify The Invariant

Check that confidence labels, risks, warnings, actions, citations, and structured sections are unchanged after rendering.
If any of those changed, the render pass failed and must be redone.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| File precedence | `.pa/soul.md` beats `.pa/persona.json`, and defaults apply only when both are absent |
| Soul influence | Principles, Personality, Relationship, and Opinions may shape reasoning posture but may not override evidence |
| Render authority | Persona may change sentence endings, warmth, directness, emoji, address style, and explanation ordering only |
| Immutable content | Facts, citations, rankings, confidence labels, actions, risks, errors, and structured data never change under persona |
| Scribe boundary | Vault note writing follows vault precedent and `skills/pa/writing/SKILL.md`, not persona-response |
| Agent boundary | Structured-data agents do not apply persona, and calling commands render their outputs later |
| Missing state | Missing persona files are a graceful fallback case, not a command failure |

## Reference Map

| Need | Reference |
|------|-----------|
| Layer boundary, invariants, and worked examples | `${CLAUDE_SKILL_DIR}/references/render-contract.md` |
| Soul file and `.pa/persona.json` schema details and defaults | `${CLAUDE_SKILL_DIR}/references/persona-schema.md` |
| Persona file load order, migration path, and graceful fallback semantics | `${CLAUDE_SKILL_DIR}/references/soul-fallback.md` |

## See Also

- `commands/pa/ask.md`, `commands/pa/brief.md`, `commands/pa/agenda.md`, `commands/pa/day.md`, `commands/pa/review.md`, `commands/pa/focus.md`, `commands/pa/survey.md`, and `commands/pa/init.md` — User-facing command consumers.
- `agents/pa/scribe.md` — Uses vault writing rules instead of persona rendering.
- `skills/pa/writing/SKILL.md` — Handles authored markdown voice rather than conversational output.
