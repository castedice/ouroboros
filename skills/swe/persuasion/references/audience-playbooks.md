---
name: audience-playbooks
description: This reference defines audience diagnosis and scenario playbooks for technical persuasion. It should be consulted when an agent needs to "diagnose a technical audience", "identify resistance source", "adapt persuasion depth to stakeholders", "choose a persuasion playbook", or "apply a scenario-specific argument pattern".
---

# Audience Playbooks — Diagnosing Receivers and Reusing Proven Patterns

> Purpose: Reference for `swe-persuasion` — use it to size the audience correctly before choosing a structure or a rhetorical technique.
> This reference is standalone and can be used without the parent skill.
> For delivery structures, see `skills/swe/persuasion/references/argument-structures.md`.
> For cognitive tactics, see `skills/swe/persuasion/references/cognitive-persuasion.md`.

## Audience Axes

Diagnose the receiver on these four axes before drafting the argument.

### 1. Technical Depth

| Audience | What They Need |
|----------|----------------|
| Domain expert | Lead with specifics, data, and direct constraint references |
| Technical generalist | Lead with architecture, interfaces, and familiar analogies |
| Non-technical stakeholder | Lead with outcomes, cost, risk, and timeline impact |

### 2. Cognitive Mode

| Mode | Signal | Persuasion Move |
|------|--------|-----------------|
| `system-1` | Time pressure, pattern recognition, quick triage | Start with labels, analogies, and visible framing |
| `system-2` | Review setting, unfamiliar topic, high stakes | Move quickly into structured evidence and trade-off tables |

Use System 1 to open the door and System 2 to land the decision.

### 3. Stake In The Decision

| Stake Type | Hidden Concern | Response |
|------------|----------------|----------|
| Direct implementer | More work, critique of existing code | Acknowledge effort and show the concrete engineering benefit |
| Indirect stakeholder | Cost, delay, or team burden | Quantify impact and show options clearly |
| Approver or reviewer | Choosing the right path | Show alternatives, evidence, and mitigation of downside |

### 4. Resistance Source

| Source | Signal | Response |
|--------|--------|----------|
| Technical disagreement | Specific alternative is proposed | Steel-man it and compare both paths against the same constraints |
| Ego protection | Dismissal without engagement | Lead with common goals and demonstrated understanding |
| Cost concern | "Too much work" or "too much process" | Show the cost of not acting and consider phased adoption |
| Status quo preference | "Current approach works fine" | Make the hidden maintenance or reliability cost visible |

## Fast Diagnosis Checklist

Ask these questions before writing.

1. Does the audience already understand the domain, or do they need translation first.
2. Are they choosing an implementation, approving a trade-off, or protecting their own workload.
3. What evidence will they trust first: metrics, artifacts, codebase precedent, or business impact.
4. What is the strongest reason they might say no.

## Scenario Playbooks

### P1 Code Review Finding

Best when an implementer may feel defensive but the issue is real and actionable.

1. Start with a concrete shared goal such as reliability or correctness.
2. Acknowledge what the current approach gets right.
3. Cite the exact code path, failure mode, and evidence.
4. Show the smallest safe fix that removes the risk.
5. End with a concrete requested change, not just a warning.

### Architecture Decision Defense

Best when the audience is mixed and the recommendation must survive stakeholder scrutiny.

1. Use SCQA to lead with the recommendation and the problem it solves.
2. Anchor the case in constraints, scale limits, or incident evidence.
3. Name the strongest competing approach and where it would win.
4. State the conditions under which this recommendation should be revisited.

### Technology Choice Recommendation

Best when several plausible tools exist and the discussion risks turning into taste or familiarity.

1. Frame the comparison axes first.
2. Use Toulmin to tie the chosen tool to the constraints that matter most.
3. Keep trade-offs explicit rather than pretending the option is universally superior.
4. Include a rebuttal that says when the alternative would be the better fit.

### Refactoring Proposal

Best when the recommendation has short-term cost and long-term operational value.

1. Reframe prior work as learning, not waste.
2. Quantify the ongoing cost of leaving the current structure untouched.
3. Propose a phased path with a small first commitment.
4. Be explicit about the window in which the refactor is cheapest.

## Selection Guide

| Situation | First Move | Likely Structure |
|-----------|------------|------------------|
| Technical review with concrete code evidence | Evidence-first | Toulmin |
| Proposal to mixed or busy stakeholders | Recommendation-first | SCQA |
| Defensive room where agreement must be built gradually | Shared-value framing | Yes Ladder |
| Existing conflict around cost or effort | Loss-avoidance framing plus phased option | Yes Ladder or SCQA |

## Failure Signals

| Signal | What It Usually Means |
|--------|------------------------|
| Audience keeps changing the comparison criteria | You did not lock the evaluation frame early enough |
| Reader focuses on tone instead of content | The evidence chain is too weak or too hidden |
| Objections keep multiplying | The argument is under-evidenced or solving the wrong concern |
| The other side rejects your summary of their view | Your steel-man is incomplete or unfair |

## See Also

| Component | Relationship |
|-----------|-------------|
| `skills/swe/persuasion/SKILL.md` | Parent skill |
| `skills/swe/persuasion/references/argument-structures.md` | Delivery structures once the audience is known |
| `skills/swe/persuasion/references/cognitive-persuasion.md` | Cognitive tactics that should be applied after diagnosis |
