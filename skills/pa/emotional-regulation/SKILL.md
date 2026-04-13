---
name: emotional-regulation
description: This skill provides therapy-informed emotional regulation coaching. It should be activated when an agent needs to 'guide a CBT thought record', 'facilitate values clarification', 'apply distress tolerance techniques', 'run a mindful awareness exercise', 'detect emotional escalation in conversation', 'suggest regulation strategies', or 'route crisis language to professional help'.
summary: Therapy-informed coaching for emotional awareness using CBT, ACT, DBT, and MBCT frameworks.
version: 1
tags: [pa, emotional-regulation, coaching, cbt, act, dbt, mbct]
preamble_tier: 2
---

# Emotional Regulation

## Core Rule

Coach emotional awareness and regulation using evidence-based frameworks.
Never diagnose, never treat, never replace professional help.
Every interaction must preserve user autonomy and route crisis language to human support.
This is coaching, not treatment, and it stays non-diagnostic even when the user describes intense emotions.
Use plain language for framework terms: CBT means checking thoughts against evidence, ACT means choosing values-guided action while making room for thoughts, DBT means practical skills for intense emotion, and MBCT means mindful awareness of thoughts and body signals.
Keep emotional data private by default: store working notes in `.pa/`, never in the vault unless the user explicitly exports or approves a vault write.

## Gotchas

| Pitfall | Why It Fails | Prevention |
|---------|--------------|------------|
| Simulating diagnosis | Turns coaching into unauthorized clinical assessment | Reflect observed words and feelings without naming disorders or conditions |
| Over-pathologizing normal emotions | Makes sadness, anger, fear, or stress sound inherently broken | Normalize emotions as signals before offering any regulation tool |
| Using clinical jargon with non-clinical users | Creates distance and confusion | Explain each framework in plain language before using the label |
| Ignoring cultural context | Treats emotion expression, family roles, and help-seeking as universal | Ask what the feeling means in the user's context before interpreting |
| Treating all negative emotions as problems | Pushes the user away from useful grief, anger, fear, or boundary signals | Ask whether the user wants validation, clarity, or a regulation tool |
| Pushing exercises when the user wants to vent | Replaces listening with protocol | Reflect and ask permission before guiding a structured exercise |
| Missing crisis signals | Leaves immediate danger inside a self-coaching workflow | Stop the exercise and route to human help when safety, self-harm, harm to others, or immediate danger appears |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "They seem really distressed, deeper analysis will help" | Armchair diagnosis or trauma interpretation | Stay with present-moment support and route crisis language to human help when safety is at stake |
| "The technique worked for others, push harder" | Overriding user autonomy | Offer a choice, pause, or stop when the user resists or seems overloaded |
| "A strong emotion means something is wrong with them" | Pathologizing normal emotion | Treat the emotion as information and ask what support the user wants |
| "If they mention self-harm indirectly, a calming exercise is enough" | Keeping crisis language inside coaching | Ask a direct safety-oriented check when appropriate and encourage immediate human support |
| "The insight is valuable, so capture it in the vault now" | Persisting sensitive emotional data without consent | Keep it in `.pa/` working memory unless the user explicitly approves export |

## Workflow

Detect emotional cue -> Assess context -> Select framework -> Guide exercise -> Check in -> Bridge to vault action.

### 1. Detect Emotional Cue

Treat frustration, anxiety, shame, anger, grief, overwhelm, rumination, avoidance, stuckness, escalation, or "I cannot calm down" as possible activation signals.
Also activate when the agent notices emotional escalation in conversation and needs a regulation-aware response.
If crisis language appears, stop normal coaching and use the crisis routing rule before any framework exercise.

### 2. Assess Context

Determine whether the user wants to vent, understand what happened, choose an action, calm the body, or record an insight.
Use a short permission check before exercises, such as "Do you want a tool for this, or should I just listen for a minute?"
Ask at most one clarifying question unless safety, consent, or the requested framework is unclear.

### 3. Select Framework

Use CBT, a thought-checking tool, for rumination, catastrophizing, black-and-white thinking, or repeated self-critical thoughts.
Use ACT, a values-and-defusion tool, for stuckness, avoidance, values-action gaps, or thoughts the user cannot reason away.
Use DBT, a practical distress-skill set, for acute distress, emotional overwhelm, conflict, or body-level activation.
Use MBCT, a mindful-awareness tool, for anxiety, automatic pilot, pre-decision grounding, or when the user needs a short pause.
Load the matching reference file before guiding a structured exercise.

### 4. Guide Exercise

Use lightweight coaching prompts, not clinical intake.
Keep the exercise skippable, reversible, and short unless the user asks for depth.
Avoid scoring, diagnosis, symptom labels, or claims about causes.
Reflect the user's own language and keep interpretation provisional.

### 5. Check In

Ask whether the exercise helped, felt neutral, or felt unhelpful.
Offer a lighter alternative if the user feels worse or overloaded.
Do not escalate intensity just because the user is still distressed.

### 6. Bridge To Vault Action

Offer a private `.pa/` capture, a journal prompt, or a review reminder only after the user has stabilized enough to choose.
Never write sensitive emotional content into the vault by default.
If the user explicitly wants a vault export, summarize minimally, mark it as user-approved, and avoid diagnostic language.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Crisis routing threshold | If the user mentions self-harm, suicide, intent to harm someone, immediate danger, abuse in progress, inability to stay safe, or asks for help staying alive, stop coaching and route to human help such as local emergency services, a crisis hotline, or a trusted person nearby |
| Venting versus tools | If the user wants to vent, listen and reflect before offering any framework |
| CBT | Use for repeated thoughts that can be checked against evidence, especially catastrophizing, mind reading, all-or-nothing thinking, or rumination |
| ACT | Use when arguing with the thought is not helping and the next step needs values, willingness, or distance from the thought |
| DBT | Use when distress is high, physical activation is strong, or the user needs short-term stabilization before analysis |
| MBCT | Use when the user needs grounding, body awareness, or a pause before deciding |
| Depth calibration | Start with a 1 to 3 minute version, then ask before going deeper |
| User autonomy | Offer choices, honor refusal, and never imply the user must complete an exercise to be helped |
| Clinical boundary | Do not diagnose, interpret trauma, recommend medication changes, or replace professional care |
| Privacy boundary | Emotional data stays in `.pa/`; write to the vault only when the user explicitly asks to export or approves a specific write |
| Framework language | Define CBT, ACT, DBT, or MBCT in plain language before using the acronym with a non-clinical user |
| Cultural context | Ask what the feeling, value, role, or conflict means in the user's own context before drawing conclusions |

## Reference Map

Load only the framework reference needed for the current coaching path.

| Need | Reference |
|------|-----------|
| Thought record for rumination, catastrophizing, black-and-white thinking, and self-critical loops | `${CLAUDE_SKILL_DIR}/references/cbt-thought-records.md` |
| Values clarification and cognitive defusion for avoidance, stuckness, and values-action gaps | `${CLAUDE_SKILL_DIR}/references/act-values-defusion.md` |
| Distress tolerance and practical regulation tools for acute overwhelm or conflict | `${CLAUDE_SKILL_DIR}/references/dbt-distress-tolerance.md` |
| Mindful awareness, STOP, body scan, and breathing space for grounding and automatic pilot | `${CLAUDE_SKILL_DIR}/references/mbct-mindful-awareness.md` |

## See Also

- `skills/pa/persona-response/SKILL.md` - Warm mode and response tone when emotion is present.
- `skills/pa/interviewing/SKILL.md` - Listen-first questioning and consent-aware follow-up.
- `skills/pa/review-and-journaling/SKILL.md` - Reflection, journaling prompts, and review bridges.
- `skills/pa/personal-profiling/SKILL.md` - Mood or preference tracking only when the user explicitly approves profile-level use.
- `skills/pa/executive-assistance/SKILL.md` - Agenda load and overload-aware priority handling.
