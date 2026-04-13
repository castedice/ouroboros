# Brainstorm Session Rules

## Stage-to-Reference Map

Use the stage-specific references for techniques.
Use this file for the operating heuristics that hold the session together.

| Stage | Primary Reference | Use This File For |
|-------|-------------------|-------------------|
| Frame | `framing-techniques.md` | Scope calibration and framework selection heuristics |
| Diverge | `divergent-techniques.md` | Technique rotation, grounding, and quantity rules |
| Cluster | None | Diagnostic interpretation of cluster shapes |
| Converge | `convergent-criteria.md` | Evidence discipline and ranking hygiene |
| Select | `convergent-criteria.md` | Weakness standards and next-action format |
| Reflect | `meta-reflection.md` | Trigger conditions for when reflection is worth the extra pass |

## Framing Calibration

Use framing to balance openness with usefulness.

| Signal | Too Narrow | Good | Too Broad |
|--------|------------|------|-----------|
| Scope | Only one implementation choice is left | Multiple approaches still fit | The topic could cover almost anything |
| Constraint count | Five or more constraints are locking the answer too early | One to three constraints guide the space | No meaningful constraints are acknowledged |
| Expected idea count | Fewer than five ideas seem plausible | Eight to fifteen ideas seem plausible | The space feels unbounded |

If the frame is too narrow, remove one constraint.
If the frame is too broad, add one concrete constraint from the codebase or user context.

## Divergence Rules

### Technique Selection

- Choose three to four techniques for most sessions.
- Start with the least obvious technique for the topic to counter anchoring.
- Expect each technique to produce two to five ideas.
- If a technique yields fewer than two ideas after real effort, switch.
- If one technique produces more than about sixty percent of the ideas, force rotation.

### Grounding Rule

Every idea must connect to at least one concrete fact from the codebase, knowledge base, or domain.
Grounded ideas are easier to compare, easier to implement, and less likely to collapse under scrutiny.

### Quantity Rule

Eight to fifteen ideas is the normal target.
Fewer than eight usually means weak divergence.
More than fifteen usually means the framing still needs tightening.

## Cluster Diagnostics

| Pattern | Diagnosis | Action |
|---------|-----------|--------|
| One dominant cluster | Divergence stayed too close to one line of thought | Re-run divergence with a different technique mix |
| Every idea is a singleton | The framing is too broad or too abstract | Re-frame with a sharper question |
| Three to five balanced clusters | The option space is structured and usable | Move to convergence |

Standalone ideas deserve extra attention.
They often contain the novelty that clustering would otherwise flatten.

## Convergence Evidence Standard

Convergence is evidence-based, not intuition-based.

- Every feasibility rating needs a concrete reason.
- Every impact rating needs a concrete reason.
- Risk and alignment checks should focus on the top candidates rather than the whole set.
- Ratings without cited reasons should be treated as incomplete and revised.

Examples of valid evidence:

- High feasibility because the idea reuses existing infrastructure.
- Medium impact because it improves only one workflow instead of several.
- Low risk because the change is fully reversible.

## Selection Standards

### Weakness Requirement

Each top recommendation needs at least one honest weakness.
If an option appears to have no downside, the analysis is not finished yet.

### Runner-Up Requirement

Recommendations should explain why the second and third options still matter.
This keeps the user's choice space visible instead of pretending that only one path exists.

### Next-Action Format

End each recommendation with a concrete next action.
Prefer a specific command invocation or a clearly bounded follow-up step over generic placeholders.

## Reflection Triggers

Use the Reflect stage when the extra scrutiny is likely to change the decision.

| Condition | Why Reflect |
|-----------|-------------|
| Top recommendations come from the same cluster | Tunnel vision may be hiding alternative directions |
| The framing was inherited rather than chosen | The session may be solving the wrong problem |
| Stakeholders beyond the current requester are affected | Missing perspectives can distort the recommendation |
| The decision is costly to reverse | Higher stakes justify the extra pass |

## Quick Reference

- Default to the six-stage flow unless a named framework clearly improves the session.
- Use Double Diamond when the problem itself is still unclear.
- Use Design Thinking when user experience is central.
- Use CPS when the session needs a familiar structured creativity loop.
- Use TRIZ when the real blocker is a technical contradiction.
- Use Triple Diamond when research context materially changes the brainstorm.
- Break ties with reversibility, then compound potential, then simplicity, then user energy.

## Bias Controls

| Bias | Phase | Signal | Countermeasure |
|------|-------|--------|----------------|
| Anchoring | Diverge | The first idea shapes everything that follows | Start with a less obvious technique |
| Premature convergence | Diverge | Ideas are being judged during generation | Enforce a no-judgment rule until convergence |
| Status quo bias | Converge | Options closest to the current system always rank highest | Score novelty as part of the impact discussion |
| Confirmation bias | Select | Preferred ideas get better evidence than alternatives | Require an honest weakness for every top option |
| Sunk-cost bias | Converge | Existing investment is treated as the deciding factor | Re-evaluate each option as if starting from scratch |
| Framework fixation | Frame | The chosen framework limits the session instead of helping it | Drop back to the default flow when the framework becomes constraining |

### Final Bias Check

- [ ] Did one technique dominate the whole session.
- [ ] Were any ideas filtered out before convergence.
- [ ] Are the top choices all close to the current state.
- [ ] Does every top recommendation contain a genuine weakness.
- [ ] Did existing investment outweigh actual value in the ranking.
- [ ] Did the framework help the session instead of boxing it in.
