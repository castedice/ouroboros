---
name: domain-specialization
description: This skill provides domain-specialist methodology for PA. It should be activated when an agent needs to "provide area-specific advice", "assess domain progress", "generate specialist insights", "evaluate area health", "check habit consistency", "produce domain-scoped recommendations", "create a new specialist", "interview for specialist persona", or "generate specialist agent definition".
summary: Creates and consults area specialists while keeping advice scoped, confirmed, and ready for chief-of-staff integration.
version: 1
tags: [pa, specialists, domain-advice, registry, consultation]
preamble_tier: 3
---

# Domain Specialization

## Core Rule

**"A specialist knows one area deeply, and the chief of staff knows the whole life broadly."**

Specialists provide domain-scoped observations, risks, and suggestions for one area only.
They do not prioritize across areas, create new obligations, or render the final user-facing agenda.
Their job is to contribute a strong local read that the chief of staff can integrate with the rest of the user's life context.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Treating specialists as hardcoded defaults | Creation | Generate or confirm each specialist from the user's actual area language and interview answers |
| Skipping the persona interview for a new area | Creation | Gather perspective, posture, and methodology choices before generating the agent |
| Activating a specialist with no matching area context | Consultation | Require active status, matching surface, and at least one area-relevant item |
| Letting a specialist rank work across areas | Advice | Keep the specialist single-area and let the chief of staff handle cross-area trade-offs |
| Turning suggestions into new obligations | Advice | Tie every suggestion to an existing goal, work item, or timeline anchor |
| Auto-activating suggestions without consent | Lifecycle | Suggested specialists stay proposed until the user confirms generation |
| Overloading the final agenda with domain noise | Output | Keep specialist advice compact and structured so the chief of staff can integrate it selectively |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The area is obvious, so generate the specialist now" | Creating or activating a specialist without interview-derived posture and user confirmation | Run the persona interview and keep the registry entry suggested until confirmed |
| "The specialist knows this area best, so let it rank the agenda" | Letting a single-area specialist decide cross-area priority | Return compact area-scoped advice for the chief of staff to integrate |
| "This suggestion is helpful, so make it a new obligation" | Turning specialist advice into a work item without an existing goal, anchor, or user consent | Tie suggestions to existing context and leave new commitments for the caller or user |

## Workflow

### 1. Load Registry And Coverage State

Read `.pa/specialists.json` and any activation metadata before deciding which specialists exist, which are active, and which remain suggested.
Use profile areas plus coverage signals to decide whether the current request needs generation, consultation, or only lifecycle maintenance.

### 2. Generate Specialists For New Or Suggested Areas

When an area lacks a usable specialist, run the persona interview, generate the area agent, and register it with explicit provenance.
Use exemplar agents only as structural references.
Generate the methodology, principles, and calibration from the user's answers instead of copying exemplar content.

### 3. Filter Specialists For The Current Surface

Call a specialist only when its `status` is `active`, its `surfaces` include the current command, and at least one work item or timeline event matches its `area_refs`.
If no items match, skip the specialist instead of emitting empty advice.

### 4. Run The Consultation Pattern

Pass area-scoped goals, work items, timeline anchors, and personal direction into the specialist.
Collect compact, evidence-backed advice through the shared consultation contract and pass the resulting `specialist_advice[]` to the calling judgment component.

### 5. Record Insights And Refresh Lifecycle

Append consultation outcomes to `.pa/specialist-insights.jsonl`, update `last_matched_at`, and let survey or steward decide whether activation, deactivation, or follow-up questions are warranted.
Suggestions and deactivations stay user-mediated unless the registry rules explicitly allow auto cleanup for `source: "auto"` specialists.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Creation path | `generated` and `manual` specialists are explicit user choices, `default` specialists are mapped by confirmation, and `auto` specialists begin as suggestions |
| Activation gate | A specialist must be `active`, valid for the current surface, and matched to at least one area-relevant item before consultation |
| Matching rule | `area_refs` matching is exact against the collected aliases and user-language terms, not semantic guesswork |
| Suggestion flow | Coverage signals may create `suggested` entries, but interview plus user confirmation is required before activation |
| Deactivation rule | Hard auto-deactivation applies only to `source: "auto"` entries when coverage disappears, while user-created entries get soft proposals only |
| Advice budget | Return 1 to 3 observations, 0 to 2 suggestions, and 0 to 1 risks so the chief of staff can still integrate the result cleanly |
| Scope rule | Specialist advice stays inside one area and never decides cross-area priority |
| Output boundary | Specialists return structured advice, and the calling command or chief of staff owns user-facing rendering |

## Reference Map

| Need | Reference |
|------|-----------|
| Persona interview, agent contract, and exemplar-driven generation | `${CLAUDE_SKILL_DIR}/references/specialist-generation.md` |
| Registry schema, `status`, `source`, `surfaces`, and alias fields | `${CLAUDE_SKILL_DIR}/references/specialist-registry.md` |
| Coverage signals, suggestion flow, and deactivation rules | `${CLAUDE_SKILL_DIR}/references/activation-signals.md` |
| Shared consultation flow, input contract, and advice output | `${CLAUDE_SKILL_DIR}/references/consultation-pattern.md` |
| Insight recording, pattern detection, and survey feedback loop | `${CLAUDE_SKILL_DIR}/references/insight-accumulation.md` |

## See Also

- `commands/pa/specialist.md` — On-demand specialist creation path.
- `commands/pa/day.md`, `commands/pa/agenda.md`, and `commands/pa/review.md` — Main command consumers for specialist consultation.
- `agents/pa/chief-of-staff.md` — Receives and integrates `specialist_advice[]`.
- `skills/pa/interviewing/references/question-patterns.md` — Supplies the specialist persona interview prompts.
