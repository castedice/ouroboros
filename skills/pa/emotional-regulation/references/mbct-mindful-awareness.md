---
name: mbct-mindful-awareness
description: This reference defines coaching-safe MBCT-informed mindful awareness exercises for the emotional-regulation skill.
---

# MBCT Mindful Awareness

> Purpose: Reference for `emotional-regulation` when the user needs grounding, mindful awareness, or a short pause before action.
> Relationship: This file provides the MBCT-style awareness practices that the parent skill loads for anxiety, automatic pilot, and pre-decision grounding.
> Boundary: MBCT is explained here as noticing thoughts, body sensations, and breath with less automatic reaction, not as treatment.

## Core Principle

Help the user notice what is happening now without forcing the feeling to disappear.
Mindfulness is not a command to relax.
It is a way to create a little room between emotion and action.
Keep exercises short and optional.
If crisis language appears, stop and route to human help.

## When To Use

Use this reference for anxiety, automatic pilot, spiraling before a decision, difficulty naming feelings, body tension, or "I need a minute."
Use it when the user wants grounding rather than analysis.
Use it before CBT, ACT, or message drafting when the user needs a pause.
Avoid it when the user says mindfulness is not helpful, feels unsafe in body focus, or needs immediate human support.

## Body Scan: 3-Minute Micro Version

Explain this as a short body check, not a relaxation test.
The user can keep eyes open.
They can skip any body area that feels unsafe or distracting.
Use neutral words like notice, soften if available, and move on.

## Body Scan Script

1. "Place your attention on your feet or wherever your body touches the chair or floor."
2. "Notice pressure, temperature, or the absence of clear sensation."
3. "Move attention through legs, torso, shoulders, hands, neck, and face."
4. "If you find tension, you can soften it by 5 percent, or just note that it is there."
5. "Let attention return to the room and name one thing you can do next."

Keep the script under three minutes unless the user asks for a longer scan.
If body focus increases distress, switch to external grounding such as naming objects in the room.

## STOP Technique

STOP is a short pause before reacting.
Explain it as a four-step reset:

| Step | Prompt |
|------|--------|
| Stop | Pause the next reaction for a moment |
| Take a breath | Take one natural breath or one slower exhale |
| Observe | Notice body, emotion, thought, urge, and surroundings |
| Proceed | Choose the next small action with more awareness |

Use STOP before sending messages, making decisions, switching tasks, or continuing a heated conversation.
Do not use STOP to silence a valid boundary.

## STOP Micro Prompt

Use this compact version in conversation:

```text
Stop for one breath.
Notice the body signal, the emotion, the thought, and the urge.
Ask: what next step would I choose if I did not have to act from the first impulse?
```

## 3-Step Breathing Space

The 3-step breathing space is a short practice for moving from autopilot to choice.
Explain it as awareness, gathering, and expanding.
Keep it brief and non-mystical.

## Step 1: Awareness

Ask: "What is here right now?"
Name one thought, one emotion, and one body sensation if available.
Do not require the user to find all three.
If naming is hard, allow "unclear" or "numb."

## Step 2: Gathering

Ask the user to bring attention to the breath.
Use one to three breaths.
Suggest noticing the exhale or the movement of the chest, belly, or nose.
If breath focus is uncomfortable, use feet on the floor or sounds in the room.

## Step 3: Expanding

Ask the user to widen attention to the whole body and the room.
Ask what next action is available now.
The next action can be pause, ask for help, take a body break, write a private note, or return to the task.

## Pre-Decision Grounding

Use this when the user is about to decide while emotionally activated.
Ask them to pause for STOP or one breathing space before choosing.
Then ask for the smallest reversible next step.
Do not pressure the user into a decision just because they completed the exercise.

## Privacy Rule

Mindfulness notes stay in `.pa/` by default.
Do not write body sensations, anxiety details, or decision notes into the vault unless the user explicitly approves export.
If exported, keep it practical and non-diagnostic.

## Common Pitfalls

| Pitfall | Correction |
|---------|------------|
| Treating mindfulness as relaxation | Frame it as awareness and choice |
| Forcing eyes closed or body focus | Offer eyes-open and external grounding options |
| Making the exercise too long | Start with one breath to three minutes |
| Ignoring user dislike of mindfulness | Switch frameworks or just listen |
| Keeping crisis in grounding mode | Route crisis language to human help |

## See Also

- `skills/pa/emotional-regulation/SKILL.md` - Parent skill and crisis routing rules.
- `skills/pa/emotional-regulation/references/dbt-distress-tolerance.md` - Use when activation is high and body skills are needed.
- `skills/pa/emotional-regulation/references/act-values-defusion.md` - Use after grounding to choose values-guided action.
