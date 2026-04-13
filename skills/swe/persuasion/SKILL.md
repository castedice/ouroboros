---
name: swe-persuasion
description: This skill provides structured argumentation methodology for technical communication. It should be activated when an agent needs to "structure a technical argument", "defend a design decision", "present trade-offs persuasively", "write a convincing code review comment", "justify architectural choices to stakeholders", "handle technical disagreements constructively", or "frame a refactoring proposal".
summary: Structures technical arguments with visible evidence, steel-manning, audience fit, qualifiers, and concrete decisions.
version: 1
tags: [swe, persuasion, arguments, communication, tradeoffs]
preamble_tier: 3
---

# Persuasion — Structured Technical Argumentation

## Core Rule

**"Make the logic visible, not the opinion."**

Technical persuasion is not about winning by confidence or force of personality.
It is about exposing the reasoning so other people can evaluate it independently.
Good persuasion makes correction possible because evidence, warrants, trade-offs, and qualifiers are all on the page.
When the logic is visible, disagreement becomes diagnosable instead of personal.

## Gotchas

| Pitfall | Phase | Prevention |
|---------|-------|------------|
| Starting from the conclusion and backfilling support | Framing | Run the reversal test and make sure the evidence could still change your recommendation |
| Leaning on authority instead of evidence | Evidence | Treat expert names as backing, not as the primary proof |
| Presenting a weak version of the opposing view | Steel-man | State the strongest counter-position until the other side would accept the summary |
| Choosing the delivery structure by habit | Delivery | Match the structure to the audience, claim type, and decision context |
| Using rhetorical force to hide logical weakness | Delivery | Strip away the tone and check whether the naked argument still holds |
| Overloading the audience with objections | Inoculation | Address the 1 to 3 objections most likely to matter and strengthen the core case instead of piling on |
| Omitting qualifiers to sound decisive | Final check | State when the recommendation does not apply and what would change the answer |

### Rationalization Red Flags

Treat these as argument-integrity anti-drift checks before sending technical recommendations.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The conclusion is correct, so stronger wording will help" | Using rhetorical force to cover weak evidence or warrants | Strip the tone, expose the evidence chain, and add the missing qualifier |
| "The opposing view is obviously riskier" | Steel-manning a weak or caricatured counter-position | State the opposing view's real strengths and the context where it would win before rebuttal |
| "Stakeholders want a quick answer, so qualifiers will distract" | Omitting boundary conditions to make the recommendation sound cleaner | Name at least one condition that would change the answer and the action it implies |

## Workflow

### 1. Diagnose The Audience And The Resistance

Identify the receiver's technical depth, cognitive mode, stake in the decision, and likely resistance source.
Use this diagnosis to choose how much context to provide, what type of evidence will matter, and how directly to surface trade-offs.

### 2. Classify The Claim And Frame The Criteria

Decide whether the task is a recommendation, defense, trade-off presentation, or objection response.
Before making the ask, establish shared goals and the axes the audience should use to judge the proposal.

### 3. Anchor Every Claim In Evidence

Prefer SWE artifacts, measured data, codebase evidence, and explicit logic over precedent or anecdote.
A persuasive recommendation should still work if the reader ignores your confidence and reads only the evidence chain.

### 4. Steel-Man The Best Counter-Position

State the strongest opposing case, acknowledge the real concerns it addresses, and identify the context where it would win.
Then explain why your recommendation still wins under the current constraints.

### 5. Choose A Structure And Deliver With Qualifiers

Use Toulmin, SCQA, or the Yes Ladder based on the audience and claim type.
Inoculate the most likely objections, keep qualifiers explicit, and end with a concrete action or decision request.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Structure choice | Use Toulmin for technical review and ADR contexts, SCQA for stakeholder summaries and proposals, and Yes Ladder for gradual alignment or anticipated defensiveness |
| Audience sizing | Favor Toulmin for small technical audiences and SCQA for larger or mixed audiences where the answer must land early |
| Evidence sufficiency | Use at least 2 independent evidence items per important claim, and make sure at least 1 is an SWE artifact or measured datum |
| Steel-man adequacy | Address at least 2 specific strengths of the opposing view before rebutting it |
| Objection scope | Pre-handle 1 to 3 likely objections, and treat a larger list as a sign the argument itself needs work |
| Qualifier rule | Every recommendation must state at least 1 boundary condition where another answer becomes preferable |
| Ethics rule | Use cognitive-bias techniques only to make a valid argument easier to process, never to disguise a weak one |
| Output rule | End with a concrete action, decision, or requested trade-off choice rather than criticism alone |

## Reference Map

| Need | Reference |
|------|-----------|
| Toulmin, SCQA, Yes Ladder, and structure-combination rules | `${CLAUDE_SKILL_DIR}/references/argument-structures.md` |
| Pre-suasion, Cialdini principles, steel-manning, and cognitive-bias tactics | `${CLAUDE_SKILL_DIR}/references/cognitive-persuasion.md` |
| Audience diagnosis and reusable SWE playbooks | `${CLAUDE_SKILL_DIR}/references/audience-playbooks.md` |

## See Also

- `agents/swe/reviewer.md` — Uses persuasion patterns for actionable, defensible review findings.
- `agents/swe/analyst.md` — Uses the same logic when defending design or architectural choices.
- `skills/swe/methodology/SKILL.md` — Supplies the constraint and artifact context that persuasive arguments should cite.
