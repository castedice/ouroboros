---
name: core-teaching
description: This skill provides decision-focused teaching methodology. It should be activated when an agent needs to "explain a concept for a decision", "teach only what's needed for the next choice", "assess knowledge gaps before explaining", "bridge explanation to action", "calibrate explanation depth to the audience", "reduce cognitive load in explanations", or "scaffold understanding incrementally".
summary: Guides decision-focused explanations that assess learner context, minimize cognitive load, bridge concepts to action, and verify understanding.
version: 1
tags: [core, methodology, teaching, explanation, cognitive-load]
preamble_tier: 3
---

# Teaching - Decision-Focused Knowledge Transfer

## Core Rule

**"Teach only what the next decision requires."**

Decision-focused teaching is not anti-knowledge.
It is anti-premature-knowledge.
Explain only the concepts that reduce the learner's uncertainty about the next real choice, and always end by bridging back to action.
Good teaching here is measured by better decisions, not by how much content was delivered.
The learner should leave with less confusion and a smaller, clearer choice set.

## Gotchas

Most teaching failures come from explaining too broadly, too deeply, or without checking what the learner already knows.

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Teaching a topic instead of a decision | Framing | Identify the specific choice the learner needs to make before explaining anything |
| Overshooting the needed Bloom level | Assessment | Teach to the minimum level that enables the decision |
| Starting from first principles unnecessarily | Anchoring | Begin from the learner's nearest existing schema |
| Dumping history or theory under pressure | Load management | Remove context that does not change the decision |
| Explaining without a decision bridge | Delivery | End every explanation with options, trade-offs, and a recommendation when appropriate |
| Unprompted deepening | Progressive disclosure | Start shallow and deepen only on request or when a gap is exposed |
| Assuming a nod means understanding | Verification | Ask the learner to explain back the choice or the trade-off |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "They asked about the topic, so teach the whole topic" | Explaining beyond the immediate decision | Reframe the question around the next choice and teach only the concepts needed for it |
| "More background will prevent confusion" | Adding theory that does not change the user's option set | Cut the background and bridge directly to options, trade-offs, or the recommendation |
| "They said yes, so they understand" | Treating confirmation as verification | Ask for an explanation-back of the choice or trade-off before deepening or moving on |

## Workflow

The sequence keeps assessment ahead of explanation and explanation ahead of recommendation.

1. Identify the exact decision point rather than the broad topic area.
2. Assess the learner's cognitive level, domain familiarity, existing schema, and current load.
3. Anchor the concept to something the learner already understands.
4. Choose the shallowest explanation depth that still enables the decision.
5. Bridge the explanation back to concrete options, trade-offs, and a recommendation when appropriate.
6. Verify understanding, and only deepen if the learner's response shows a real gap.

If the learner cannot act after the bridge, the explanation was not yet decision-ready.

## Decision Rules

These rules keep the explanation short enough to be useful and deep enough to unlock the choice.
They also keep the teacher from drifting into a lecture when the user actually needs a recommendation.

| Decision Point | Rule |
|----------------|------|
| Bloom target | Teach to the lowest cognitive level that still supports the decision |
| Load budget | High load gets at most three sentences before the bridge, medium load gets at most two paragraphs, and low load gets at most five paragraphs |
| Option count | Present no more than three viable options after pre-filtering |
| Chunking trigger | Split the decision when more than three trade-off dimensions are active at once |
| Depth escalation | Escalate one level after two clarifying questions at the current depth |
| Re-explanation limit | After two explanation loops, decompose the decision instead of repeating the same explanation again |
| Recommendation fairness | If you recommend an option, still explain the strongest viable alternative fairly |
| Verification style | Prefer explanation-back questions over yes or no confirmation questions |

## Reference Map

Load the playbook first, then pull the theory or depth references only where needed.
This keeps the main interaction responsive while preserving the option to deepen later.

| Need | Reference |
|------|-----------|
| Applied learner assessment, load management, workflow details, and integration contracts | `${CLAUDE_SKILL_DIR}/references/decision-teaching-playbook.md` |
| Bloom, ZPD, cognitive-load, schema, and transfer foundations | `${CLAUDE_SKILL_DIR}/references/cognitive-learning.md` |
| Four depth levels and decision-bridge patterns | `${CLAUDE_SKILL_DIR}/references/explanation-depth.md` |

## See Also

These components commonly need explanation that ends in a concrete decision.

- **analyst agent** (`agents/swe/analyst.md`) - Common consumer when comparing architectural options for the user
- **onboard command** (`commands/core/onboard.md`) - Uses progressive disclosure to explain the system without overwhelming the user
- **brainstorm command** (`commands/core/brainstorm.md`) - Often needs explanation that bridges divergent options back to a choice
- **persuasion skill** (`skills/swe/persuasion/SKILL.md`) - Useful when the explanation must also defend a recommendation against competing alternatives
- **PA teaching skill** (`skills/pa/teaching/SKILL.md`) - PA-domain adapter that uses this methodology for vault, QMD, and workflow explanations
