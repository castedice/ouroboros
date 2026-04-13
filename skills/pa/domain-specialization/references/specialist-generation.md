---
name: specialist-generation
description: This reference defines the interview-driven specialist generation contract for PA. It should be consulted when an agent needs to "generate a new specialist", "run a specialist persona interview", "write a specialist agent definition", "use specialist exemplars structurally", or "confirm a generated specialist with the user".
---

# Specialist Generation — Interview To Agent Contract

> Purpose: Reference for `domain-specialization` — use it when a new area specialist must be created or regenerated.
> This reference is standalone and can be used without the parent skill.
> Runtime consultation rules live in `references/consultation-pattern.md`.

## When To Use

Use this reference when `/pa init`, `/pa specialist create`, survey follow-up, or a suggested specialist flow needs a real agent definition.
Do not use it for ordinary runtime consultation of an already-active specialist.

## Generation Workflow

### 1. Select The Area

Identify the `core_area` that needs coverage.
This may come from init, a direct specialist command, or a coverage signal that the user agreed to pursue.

### 2. Run The Persona Interview

Ask 2 to 3 focused questions that clarify the user's desired perspective for this area.
Capture how the specialist should evaluate progress, what it should care about most, and what tone of judgment is useful.
Use `skills/pa/interviewing/references/question-patterns.md` for the concrete question forms.

### 3. Generate The Agent Definition

Write the result to `agents/pa/specialists/{area_id}.md`.
Use exemplars from `skills/pa/domain-specialization/examples/` only as structural references.
Generate the actual principles, methodology, and calibration from the interview answers.

### 4. Register The Specialist

Add or update the entry in `.pa/specialists.json`.
Set `status`, `source`, `registered`, `area_refs`, and `surfaces` explicitly so runtime consultation can reason about the specialist deterministically.

### 5. Confirm With The User

Summarize the generated perspective in plain language.
Ask for approval before treating the specialist as active.

## Agent Contract

The generated specialist definition should include the following sections.

| Section | Requirement |
|---------|-------------|
| Frontmatter | `name`, trigger-focused `description`, `model: sonnet`, `tools: [Read, Grep, Glob]`, and consistent display metadata |
| System prompt | Identify the specialist by area and explain that it produces single-area advice only |
| Core Principles | 4 principles derived from the user's stated perspective for this area |
| Domain Methodology | 2 to 3 domain-specific assessment patterns grounded in the interview answers |
| Operating Boundary | The standard single-area boundary table |
| Input Contract | Area, goals, work items, timeline anchors, horizon, personal context, and registry config |
| Output Contract | Compact advice with status, confidence, observations, suggestions, and risks |
| Calibration | One bad or good output pair that reflects the specialist's stance in this area |
| See Also | Standard links back to registry, consultation, and consuming commands |

## Interview Focus

The interview should capture perspective, not just subject matter.

| Area | Perspective Contrast |
|------|----------------------|
| finance | stability and risk control vs aggressive upside and opportunity cost |
| health | performance and measurable progress vs sustainability and consistency |
| learning | depth and mastery vs breadth and exploration |
| career | advancement and leverage vs balance and meaning |

Two users can share the same area and still need very different specialists.

## Exemplar Use

The exemplar files are read-only templates for structure and quality level.
They are never activated directly as live specialists.
Do not copy an exemplar's core principles or methodology into a generated specialist without rewriting them from the interview answers.

## Registration Defaults

| Field | Default Guidance |
|-------|------------------|
| `id` | Lowercase kebab-case version of the chosen area |
| `agent` | `agents/pa/specialists/{area_id}.md` |
| `status` | `active` only after user approval, otherwise `suggested` or `inactive` |
| `source` | `generated` for interview-built agents |
| `surfaces` | Usually `day` and `agenda`, with `review` added only when reflective domain input is useful |
| `priority_hint` | `normal` unless the user explicitly requests otherwise |

## Failure Handling

| Problem | Response |
|---------|----------|
| Area is too broad | Split the area or narrow the interview before generation |
| Interview answers are vague | Ask one more disambiguating question instead of generating a generic specialist |
| User likes the area but not the perspective summary | Revise the generated principles and methodology, not just the wording |
| Registry exists but the agent file is missing | Regenerate the agent from the stored area and ask for confirmation again |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/pa/domain-specialization/SKILL.md` | Parent skill |
| `skills/pa/domain-specialization/references/specialist-registry.md` | Registry schema and lifecycle fields |
| `skills/pa/domain-specialization/references/consultation-pattern.md` | Runtime consultation contract after generation |
| `skills/pa/interviewing/references/question-patterns.md` | Question bank for specialist persona interviews |
