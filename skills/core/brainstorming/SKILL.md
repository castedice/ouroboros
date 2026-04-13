---
name: brainstorming-methodology
description: This skill provides brainstorming methodology knowledge. It should be activated when an agent needs to "brainstorm ideas for a topic", "explore alternatives creatively", "generate divergent options", "evaluate and rank ideas", "apply structured thinking techniques", or "select the best idea from a set of candidates".
summary: Structures ideation from framing through divergence, convergence, selection, and reflection to produce grounded options and decisions.
version: 1
tags: [core, methodology, brainstorming, ideation, decision-making]
preamble_tier: 3
---

# Brainstorming Methodology

## Core Rule

**"Diverge to discover, converge to decide."**

Keep ideation and judgment in separate phases.
The operating cycle is Frame -> Diverge -> Cluster -> Converge -> Select -> Reflect, and the transition into convergence must be explicit.
Use this file for operating rules, and load the mapped references when you need stage techniques, framework choices, or detailed session heuristics.
The method is designed to produce option breadth first and decision quality second.

## Gotchas

Most brainstorming failures happen when the session drifts into premature decision-making or context-free ideation.

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Judging during divergence | Diverge | Ban phrases like "that will not work" until convergence begins |
| Too few ideas | Diverge | Use multiple techniques and switch when a technique stalls |
| Context-free ideation | Diverge | Ground every idea in at least one concrete fact from the codebase or domain |
| Skipping convergence | Select | Never recommend raw, unranked ideas |
| Single-technique dependence | Diverge | Rotate techniques instead of letting one pattern dominate |
| Vague ideas | Diverge | Make every idea specific enough to turn into an action |
| Token weaknesses | Select | State real trade-offs, not placeholder caveats |
| Generic next actions | Select | End with a specific command or concrete follow-up action |

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "The first cluster is obviously best" | Converging before enough divergent techniques have run | Return to divergence with a different technique and capture grounded alternatives before ranking |
| "This is a creative session, so evidence can wait" | Recording ideas with no codebase, domain, or constraint grounding | Attach each idea to a concrete fact before it enters convergence |
| "The user only needs one answer" | Skipping runner-up trade-offs and presenting a single recommendation | Keep a small option set with reasons, risks, and next actions for the top candidates |

## Workflow

Each stage changes the cognitive mode, so signal the transitions instead of blending them together.

1. Frame the topic into a scoped question with clear success criteria and a fitting process framework.
2. Diverge with multiple techniques and capture enough grounded ideas before any evaluation starts.
3. Cluster the raw ideas into themes so the structure of the option space becomes visible.
4. Converge with explicit evidence for feasibility, impact, risk, and alignment.
5. Select the top recommendations, including why the runner-ups still matter and what each one would require next.
6. Reflect when the topic is high-stakes, inherited, or showing signs of tunnel vision.

If the session cannot support convergence with evidence, go back and strengthen framing or divergence first.

## Decision Rules

These rules keep the session productive without collapsing it into free association or premature ranking.

| Decision Point | Rule |
|----------------|------|
| Framing width | Aim for one to three key constraints and a scope that still allows roughly 8 to 15 ideas |
| Technique mix | Use three to four techniques, switch if one yields fewer than two ideas, and rotate if one technique starts dominating |
| Grounding | Every idea must point back to a concrete fact from the codebase, knowledge base, or domain |
| Cluster diagnosis | One giant cluster means the framing is too narrow, while all singletons usually means the framing is too broad |
| Evidence standard | Feasibility, impact, and risk ratings are invalid without a cited reason |
| Reflection trigger | Reflect when the top ideas all come from one cluster, the framing was inherited, more stakeholders are affected, or the decision is hard to reverse |
| Selection output | Keep the final recommendation set small enough that the user can actually choose from it |

## Reference Map

Use the stage reference that matches the stage you are actively running.

| Need | Reference |
|------|-----------|
| Framing techniques such as 5 Whys, HMW, and Jobs-to-be-Done | `${CLAUDE_SKILL_DIR}/references/framing-techniques.md` |
| Process framework selection such as Double Diamond, Design Thinking, CPS, TRIZ, and Triple Diamond | `${CLAUDE_SKILL_DIR}/references/process-frameworks.md` |
| Divergent idea-generation techniques | `${CLAUDE_SKILL_DIR}/references/divergent-techniques.md` |
| Convergent criteria and ranking logic | `${CLAUDE_SKILL_DIR}/references/convergent-criteria.md` |
| Reflection techniques for blind spots and assumption checks | `${CLAUDE_SKILL_DIR}/references/meta-reflection.md` |
| Session heuristics, thresholds, and bias controls | `${CLAUDE_SKILL_DIR}/references/session-rules.md` |

## See Also

These components usually consume the brainstorm output or orchestrate the session.

- **brainstormer agent** (`agents/core/brainstormer.md`) - Primary consumer of this staged brainstorming flow
- **brainstorm command** (`commands/core/brainstorm.md`) - Orchestrates the brainstorm session and any multi-model coordination
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) - Useful when a brainstorm output must later be assessed against quality criteria
- **evolution-methodology** (`skills/core/evolution/SKILL.md`) - Useful when selected ideas turn into concrete improvement work
