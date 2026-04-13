---
name: cbt-thought-records
description: This reference defines a coaching-safe CBT thought record flow for the emotional-regulation skill.
---

# CBT Thought Records

> Purpose: Reference for `emotional-regulation` when the user needs to examine a distressing thought without diagnosis.
> Relationship: This file provides the CBT-style thought record details that the parent skill loads only when the user wants a thought-checking exercise.
> Boundary: CBT is explained here as checking thoughts against evidence, not as treatment or proof that a thought is wrong.

## Core Principle

Help the user separate the event, the thought, the feeling, and the next action.
Do not argue the user out of the emotion.
Do not label the user, diagnose a condition, or score symptoms.
Use the thought record as a clarity tool, not a courtroom.

## When To Use

Use this reference for rumination, catastrophizing, black-and-white thinking, repeated self-criticism, mind reading, or "I keep replaying this" loops.
Use it when the user wants perspective on a specific thought or prediction.
Avoid it when the user only wants validation, is in acute crisis, or is too activated to analyze.
If crisis language appears, stop the thought record and route to human help.

## Coaching Adaptation

Use simplified column names and conversational prompts.
Do not use clinical scoring, distortion labels, diagnostic categories, or symptom severity numbers.
Keep the form short enough to complete in one turn when the user is distressed.
Use the user's exact words for the thought when possible.
Ask permission before turning a vent into a worksheet.

## Thought Record Flow

| Step | Plain-Language Prompt |
|------|-----------------------|
| Situation | What happened, in one or two factual sentences? |
| Thought | What did your mind say this meant? |
| Emotion | What feeling showed up, and where did you notice it? |
| Evidence For | What facts make the thought feel believable? |
| Evidence Against | What facts do not fit, or what else might be true? |
| Balanced Thought | What is a more complete thought that does not fake positivity? |
| Action | What is one next step that respects the feeling and the facts? |

## Step 1: Situation

Ask for observable facts only.
Keep interpretations out of this step.
Useful prompt: "What would a camera or transcript show?"
If the user gives a long story, summarize one neutral sentence and ask whether it fits.

## Step 2: Thought

Ask for the thought in the user's own words.
Look for predictions, meanings, rules, or self-judgments.
Do not name cognitive distortions unless the user already uses that vocabulary.
Useful prompt: "What sentence is looping in your head?"

## Step 3: Emotion

Ask for emotion words and body cues, not a clinical scale.
Allow mixed emotions.
Useful prompt: "What feeling is strongest right now, and where do you feel it in your body?"
If the user cannot name a feeling, offer simple choices like anger, fear, sadness, shame, guilt, or numbness.

## Step 4: Evidence For

Validate why the thought feels plausible.
Do not skip this step to rush toward reassurance.
Useful prompt: "What real facts support this thought?"
Separate facts from assumptions gently.

## Step 5: Evidence Against

Ask for missing facts, alternative explanations, and context.
Do not force positivity.
Useful prompt: "What facts make the thought less certain or less complete?"
If the user cannot find any, ask what a trusted friend might notice.

## Step 6: Balanced Thought

Create a thought that includes both pain and possibility.
Avoid fake-positive reframes.
Useful pattern: "It makes sense that I feel X because Y, and it is also possible that Z."
Keep the balanced thought believable to the user.

## Step 7: Action

Choose one small action.
The action can be practical, relational, reflective, or regulatory.
Useful prompt: "Given the fuller picture, what is the next respectful step?"
If no action is appropriate, choose a pause or a private `.pa/` note.

## Privacy Rule

Store working notes in `.pa/` only.
Do not write the thought record into the vault unless the user explicitly asks to export it.
When exporting, remove diagnostic labels, keep the summary minimal, and mark it as user-approved.

## Common Pitfalls

| Pitfall | Correction |
|---------|------------|
| Debating the user | Ask for evidence and alternatives without trying to win |
| Skipping evidence for | Validate why the thought feels believable before broadening it |
| Forcing optimism | Use believable balanced thoughts, not reassurance |
| Overfilling the worksheet | Keep only the current thought and current action |
| Treating crisis as a worksheet | Route to human help immediately |

## Output Pattern

Use this compact structure when the user wants the result shown:

```text
Situation:
Thought:
Emotion:
Evidence for:
Evidence against:
Balanced thought:
Next action:
```

## See Also

- `skills/pa/emotional-regulation/SKILL.md` - Parent skill and crisis routing rules.
- `skills/pa/emotional-regulation/references/act-values-defusion.md` - Use when arguing with the thought is not helping.
- `skills/pa/emotional-regulation/references/dbt-distress-tolerance.md` - Use before analysis when distress is high.
