---
name: interviewing
description: This skill provides structured interview methodology for PA. It should be activated when an agent needs to "interview the user", "run a personal interview", "bootstrap profile", "deep interview", "catch-up interview", "direction check interview", or "convert free-text answers into structured profile updates".
summary: Guides skippable personal interviews that listen first, synthesize structured signals, and require confirmation before profile updates.
version: 1
tags: [pa, interviewing, profile-signals, consent, questions]
preamble_tier: 2
---

# Interviewing

## Core Rule

**"Listen before advising. The user is the expert on their own life."**

An interview exists to discover how the user's life actually works, not to pull them into a preset framework.
The interviewer asks only enough to clarify direction, current reality, and durable patterns.
Advice comes later, if at all.
During the interview, the job is to notice, reflect, and confirm.

## Gotchas

| Risk | Mode or phase | Prevention |
|------|---------------|------------|
| Asking too much too early | `bootstrap` | Keep the opening pass broad and stop once a seed profile is possible |
| Re-asking fields that are already stable | `catch-up` | Ask only about missing, stale, or contradictory fields |
| Turning a direction review into task triage | `direction` | Keep the focus on trajectory, meaning, and what changed |
| Treating one emotional answer as a durable trait | `deep` | Look for repeated or confirmed patterns before raising confidence |
| Updating the profile without explicit confirmation | All | Reflect the field change back before mutation |
| Confusing silence or politeness with consent | All | Respect skips, pauses, and overload as valid boundaries |
| Projecting your own ideal life or productivity model | Question selection | Let the user define categories in their own words first |
| Prescribing instead of observing | Follow-up | Separate "what I heard" from any later advice |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "Several questions at once will finish the profile faster" | Turning the interview into a bulk questionnaire | Ask one skippable primary question at a time |
| "This emotional answer reveals a durable trait" | Persisting a profile trait from one unconfirmed answer | Treat it as a hypothesis and confirm it before any patch proposal |
| "The user did not object, so the update is approved" | Treating silence or politeness as consent to mutate profile state | Reflect the proposed change and ask for explicit confirmation |

## Workflow

### 1. Open With One Clear Question

Choose the interview mode first, then ask one skippable question that matches it.
Use the opt-out line when needed: "대답하고 싶지 않으면 건너뛰어도 괜찮아요".

### 2. Listen For Meaning, Not Keywords

Treat the answer as raw evidence.
Separate direct statements from tone, implication, and possible inference without optimizing or correcting while the user is still describing their experience.

### 3. Follow Up From The Answer

Pick the next question because of what the user just said, not because a script still has unchecked items.
Keep follow-ups light in `bootstrap` and `catch-up`, and use deeper probes only in `direction` and `deep`.

### 4. Synthesize Into Structured Signals

Convert the strongest signals into candidate profile updates.
Map direct statements first to the profile schema, and keep weak interpretation as notes, open questions, or future interview leads.

### 5. Confirm Before Treating It As True

Reflect the synthesized understanding back in plain language.
Unconfirmed synthesis stays provisional, and approved synthesis becomes a patch proposal rather than a silent profile mutation.

## Decision Rules

### Mode Selection

| Mode | Trigger | Question budget | Target confidence |
|------|---------|-----------------|-------------------|
| `bootstrap` | Missing or nearly empty profile | 5 broad questions | `0.4` |
| `catch-up` | Refresh, staleness, or contradictions | 2 to 3 gap questions plus at most 1 insight question | `0.6` |
| `direction` | Year-plus review or explicit direction check | 3 to 5 questions | `0.7` |
| `deep` | Explicit consent for deepening | 15 to 30+ questions across multiple turns | `0.8+` |

Choose `bootstrap` for empty profiles, `catch-up` for freshness problems, `direction` for trajectory checks, and `deep` only with explicit consent and enough conversational bandwidth.
Use `AskUserQuestion` as turn-by-turn transport, never as a bulk questionnaire dump.
Ask one primary question at a time and stop when the mode hits its budget, the target confidence is reached, or the user's fatigue boundary appears.

### Answer Synthesis

| Signal type | Weight | Handling |
|-------------|--------|----------|
| Direct statement | 3 | Map and confirm before update |
| Narrative pattern | 2 | Propose as a pattern, not as certainty |
| Indirect inference | 1 | Keep as hypothesis until confirmed |

Direct statements outrank narrative patterns, and patterns outrank inference.
Map rich stories into the core profile first, then leave residual nuance as open questions, unresolved tensions, or future deep-interview leads.
Advice, if given at all, must stay clearly separate from observation.

### Deep-Mode Boundaries

Deep mode explores motivations, transitions, relationship patterns, energy, stress, decision style, and lessons learned.
Stop when the user asks to pause, overload appears, the marginal value drops below the conversational cost, or the current target fields are confirmed strongly enough.

Validation checks: keep every question skippable, reuse the user's own wording when it improves precision, preserve contradictions instead of flattening them, and confirm changed fields before profile mutation.

## Reference Map

- `${CLAUDE_SKILL_DIR}/references/question-patterns.md` — Mode-specific question banks, usage rules, and interview prompt patterns.

## See Also

- `commands/pa/init.md` — Uses interviewing for profile bootstrap.
- `commands/pa/survey.md` — Uses interviewing for catch-up refreshes.
- `commands/pa/review.md` — Uses interviewing for direction and review-style conversations.
- `skills/pa/personal-profiling/SKILL.md` — Consumes interview output as profile patches and confidence updates.
- `skills/pa/review-and-journaling/SKILL.md` — Adjacent reflective workflow that can feed later interview questions.
