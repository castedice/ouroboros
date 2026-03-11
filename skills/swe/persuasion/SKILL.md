---
name: swe-persuasion
description: This skill provides structured argumentation methodology for technical communication. It should be activated when an agent needs to "structure a technical argument", "defend a design decision", "present trade-offs persuasively", "write a convincing code review comment", "justify architectural choices to stakeholders", "handle technical disagreements constructively", or "frame a refactoring proposal".
---

# Persuasion — Structured Technical Argumentation

## Core Principle

**"Make the logic visible, not the opinion."**

Persuasion in technical contexts is not about winning arguments — it is about making reasoning transparent so others can evaluate the logic independently. The goal is to move from "I think X is better" to "Given constraints A and B, X satisfies both while Y satisfies only A. Here's the evidence." When the logic is visible, agreement follows from shared understanding rather than authority or persistence.

This matters because technical decisions affect entire teams. A poorly argued but correct recommendation gets ignored. A well-argued but wrong recommendation gets adopted and caught early through transparent reasoning. Visible logic enables correction; hidden opinion prevents it.

## Audience Analysis

Before constructing any argument, assess the audience on four dimensions. The same technical truth requires different delivery based on who receives it.

### Dimension 1: Technical Depth

| Audience | Approach |
|----------|----------|
| **Domain expert** | Lead with data and specifics. Skip fundamentals. Use precise terminology. They detect shallow reasoning instantly |
| **Technical generalist** | Lead with architecture-level reasoning. Provide enough context for the specific domain. Use analogies to familiar systems |
| **Non-technical stakeholder** | Lead with outcomes and business impact. Translate technical constraints into timeline/cost/risk language |

### Dimension 2: Cognitive Mode (Kahneman)

| Mode | When Active | Persuasion Strategy |
|------|-------------|-------------------|
| **System 1** (intuitive) | Quick decisions, familiar patterns, time pressure | Use pattern names ("this is a classic N+1 problem"), analogies, visual comparisons |
| **System 2** (analytical) | Important decisions, unfamiliar territory, design reviews | Use structured data, benchmarks, constraint matrices, explicit trade-off tables |

Tip: Start with System 1 (pattern recognition) to establish frame, then shift to System 2 (structured analysis) for the decision.

### Dimension 3: Stake

| Relationship | Key Concern | Address With |
|-------------|-------------|-------------|
| **Direct implementer** | "More work for me" / "My code isn't good enough" | Acknowledge effort, frame as evolution not criticism, show concrete benefit |
| **Indirect stakeholder** | "How does this affect my timeline/budget?" | Quantify impact, provide options with trade-offs, respect their constraints |
| **Reviewer/approver** | "Is this the right decision?" | Provide evidence, present alternatives considered, show risk mitigation |

### Dimension 4: Resistance Source

| Source | Signal | Response |
|--------|--------|----------|
| **Technical disagreement** | "I think approach Y is better because..." | Steel-man their position, compare systematically against constraints |
| **Ego protection** | Defensive tone, dismissal without engagement | Pre-suasion: acknowledge their expertise first, frame as collaborative exploration |
| **Cost/effort concern** | "This is too much work" / "Can we do it simpler?" | Reframe: show cost of NOT doing it (loss aversion), provide phased approach |
| **Status quo preference** | "Current approach works fine" | Make hidden costs of status quo visible — maintenance burden, tech debt, incident data |

## Pre-Suasion

Before making the actual request, set the context. Pre-suasion is about channeling attention toward the evaluation criteria that matter before the proposal arrives.

### Step 1: Establish Common Ground (Unity)

Recall a shared goal or value: "We both want the checkout flow to handle Black Friday traffic reliably." This activates the reciprocity principle — by showing you share their priorities, they become more open to your reasoning.

### Step 2: Frame Evaluation Criteria (Attention Channeling)

Explicitly state how the proposal should be evaluated: "Let's compare options on three axes: reliability under load, implementation timeline, and operational complexity." This prevents post-hoc criterion shifting and ensures the discussion stays structured.

### Step 3: Acknowledge Constraints

Show that you've considered the audience's constraints before proposing: "I know the team is already committed to the Q2 release timeline. This proposal works within that constraint." This builds ethos (credibility through demonstrated understanding).

## Workflow

### Step 1: Claim Classification

Categorize the argument type — this determines the optimal structure:

| Type | Description | Best Structure |
|------|-------------|---------------|
| **Recommendation** | "We should use X" | SCQA or Toulmin |
| **Defense** | "X was the right choice because..." | Toulmin with steel-manning |
| **Trade-off presentation** | "X vs Y — here are the trade-offs" | Anchored comparison with Yes Ladder |
| **Objection response** | "Regarding the concern about X..." | Steel-man + Inoculation |

### Step 2: Evidence Anchoring

Ground every claim in traceable evidence. Never argue from authority alone.

| Evidence Type | Strength | Example |
|--------------|----------|---------|
| **SWE artifacts** | Highest | "The Constraint Profile (C-03) requires <200ms p99 latency" |
| **Measured data** | High | "Current implementation averages 340ms p99 under load test" |
| **Codebase evidence** | High | "The existing `OrderService` already uses this pattern (see line 142)" |
| **Industry precedent** | Medium | "AWS, Google, and Stripe all use circuit breakers for this scenario" |
| **Logical deduction** | Medium | "If A and B, then necessarily C" |
| **Expert opinion** | Low-medium | "Martin Fowler recommends..." (cite specifically, not vaguely) |
| **Personal experience** | Lowest | "In my previous project..." (valid only as supplementary) |

For detailed evidence anchoring patterns, see `references/argument-structures.md`.

### Step 3: Steel-Manning

Before presenting your position, construct the strongest version of the opposing view. This serves three purposes:

1. **Intellectual fairness signal**: The audience sees you engaged with the best counter-argument, not a straw man
2. **Preemptive disarmament**: Opponents have less to add when you've already stated their best case
3. **Self-check**: If the steel-manned counter-argument is stronger than your position, you should change your position

Steel-manning process:

1. State the opposing position in its strongest form: "The strongest argument for keeping the monolith is..."
2. Identify the legitimate concerns it addresses: "This correctly identifies the risk of distributed system complexity..."
3. Acknowledge where it outperforms your proposal: "For teams with less microservice experience, this approach has lower initial risk..."
4. Explain why your proposal still wins on balance: "However, given our specific constraints (C-02: independent deployment, C-05: team scaling)..."

### Step 4: Structured Delivery

Select the delivery structure based on audience and claim type:

| Structure | Best For | Core Pattern |
|-----------|----------|-------------|
| **Toulmin** | Technical audiences, design reviews, ADRs | Claim → Ground → Warrant → Backing → Qualifier → Rebuttal |
| **SCQA (Minto Pyramid)** | Stakeholder presentations, proposals, executive summaries | Situation → Complication → Question → Answer |
| **Yes Ladder** | Team discussions, gradual alignment, controversial proposals | Small agreements → Larger agreements → Full proposal |

For detailed structures with SWE examples, see `references/argument-structures.md`.

### Step 5: Objection Inoculation

Proactively address expected counter-arguments in weakened form. This builds psychological resistance to the full objection when it arrives later.

Pattern: "Some might argue that [weakened objection]. While this has merit in [limited context], it doesn't apply here because [specific reason]."

This technique (from McGuire's Inoculation Theory) works because:

- It shows you've considered objections (builds ethos)
- It provides the audience with counter-arguments before opponents deliver them
- Hearing the weakened form first makes the full objection feel less novel

### Decision Thresholds

Quantitative rules governing key methodology decisions:

| Decision Point | Threshold | Workflow Step |
|----------------|-----------|-------------|
| Structure selection | Audience ≤5 technical reviewers → Toulmin; ≥6 or mixed audience → SCQA; sequential buy-in needed → Yes Ladder | Step 4 |
| Evidence sufficiency | Minimum 2 independent evidence items per claim; ≥1 must be SWE artifact or measured data | Step 2 |
| Steel-man adequacy | Must address ≥2 specific counter-points from the opposing position | Step 3 |
| Inoculation scope | Address 1-3 anticipated objections; >3 suggests the argument needs strengthening, not more inoculation | Step 5 |
| Qualifier requirement | Every recommendation must state ≥1 explicit boundary condition where it does NOT apply | Validation |

## Cognitive Bias Toolkit

Use these techniques ethically — to make valid arguments more accessible, not to make weak arguments seem strong.

### Loss Aversion

People feel losses ~2x more strongly than equivalent gains. Frame proposals in terms of what's at risk by NOT acting.

- Instead of: "Migrating to PostgreSQL gives us better JSON support"
- Try: "Staying on MySQL means we lose the ability to query nested JSON, which blocks the analytics feature for Q3"

### Anchoring

Set the comparison point before presenting options. The first number/option mentioned becomes the anchor.

- Present the expensive/complex option first, then present the recommended option as more reasonable
- In trade-off tables, order columns so the recommended option's strengths appear in the first comparison

### Status Quo Reframe

When the audience defaults to "keep things as they are," make the hidden costs of the status quo visible.

- Calculate the maintenance cost of the current approach (incidents/month, developer hours, workarounds)
- Frame status quo as an active choice with ongoing costs, not a passive default

### Sunk Cost Reframe

When past investment in an approach creates emotional attachment:

- Acknowledge the value of what was learned: "The prototype taught us exactly where the bottlenecks are"
- Frame the change as building on that investment: "We're applying those learnings to a more scalable approach"
- Never say "that work was wasted" — say "that work was the research phase"

## Scenario Playbooks

### A: P1 Code Review Finding (Implementer Resistance)

1. **Pre-suasion**: "I can see the thought behind this approach — it handles the happy path cleanly"
2. **Ethos**: "Looking at the error rates in the monitoring dashboard for similar patterns..."
3. **Steel-man**: "The simpler approach works if we assume the upstream service is always available, which has been true 99% of the time"
4. **Yes Ladder**: Agreement on reliability goal → agreement that upstream can fail → agreement that the code should handle it → specific fix proposal
5. **Evidence**: Link to incident data or constraint profile entry

### B: Architecture Decision Defense (Stakeholder Audience)

1. **SCQA**: Situation (current architecture) → Complication (scaling bottleneck) → Question (how to handle 10x traffic?) → Answer (recommended approach)
2. **Social Proof**: "Netflix/Uber solved this same problem with the same pattern"
3. **Loss Aversion**: "Without this change, Black Friday traffic will exceed our capacity by 3x"
4. **Qualifier**: "This recommendation is valid assuming traffic projections hold. If growth slows, the simpler option remains viable."

### C: Technology Choice Recommendation (Trade-off)

1. **Inoculation**: "Redis is often recommended for this use case. While it excels at speed, it lacks the durability guarantees our constraint C-04 requires"
2. **Toulmin**: Claim (PostgreSQL) → Ground (ACID compliance) → Warrant (C-04 requires durability) → Backing (incident data from Redis cache invalidation bugs) → Qualifier (for datasets under 10GB) → Rebuttal (Redis is better if we relax C-04)
3. **Anchoring**: Present PostgreSQL metrics first as the baseline for comparison

### D: Refactoring Proposal (Short-term Cost, Long-term Gain)

1. **Sunk Cost reframe**: "The current codebase taught us exactly what abstractions we need"
2. **Scarcity**: "Refactoring window closes when the Q3 features land — after that, the cost triples"
3. **Progressive Commitment**: Propose Phase 1 (low-risk extraction) → demonstrate value → Phase 2 (full refactoring)
4. **Loss Aversion**: "Each month of delay adds ~8 hours of developer workaround time. Over Q3: 96 hours lost"

## Bias Mitigation

Phase-linked pitfalls and their prevention:

| Pitfall | Workflow Phase | Signal | Prevention |
|---------|--------------|--------|-----------|
| **Motivated reasoning** | Step 1 (Classification) | Starting with conclusion, building argument backwards | Reversal test: "If evidence pointed the other way, would I change my position?" |
| **Authority bias** | Step 2 (Evidence) | "X is right because [famous person] said so" | Cite specific evidence, not reputation. Authority supports but doesn't replace logic |
| **Cherry-picking** | Step 2 (Evidence) | Only presenting data that supports your position | Include disconfirming evidence. If you can't find any, your search was incomplete |
| **Straw-manning** | Step 3 (Steel-Man) | Weak version of opposing view, easy to dismiss | Present opponent's best case. If they'd disagree with your summary, it's a straw man |
| **Rhetorical overreliance** | Step 4 (Delivery) | Emotionally compelling but logically weak | Strip the rhetoric — does the bare logic still hold? |
| **False urgency** | Step 5 (Inoculation) | "We must decide NOW" when timing is flexible | State actual deadline and delay consequences. Artificial urgency erodes trust |

## Validation Checklist

Before delivering any argument, verify:

- [ ] Every claim traces to specific evidence (not general assertions)
- [ ] The opposing view has been steel-manned (strongest version, not straw man)
- [ ] A concrete action is proposed (not just criticism)
- [ ] Audience analysis informed the delivery structure
- [ ] Cognitive bias techniques are used to clarify valid logic, not to mask weak reasoning
- [ ] Qualifiers are present — when does this recommendation NOT apply?

## Integration Contracts

### Input

This skill is activated by agents during argumentation tasks. Required context: claim or position to argue, audience description, and available evidence artifacts (constraint profiles, architecture specs, measured data).

### Output

Structured argument following the selected delivery structure (Toulmin/SCQA/Yes Ladder), with traceable evidence, steel-manned counter-position, and explicit qualifiers.

### Consumers

| Consumer | Usage | Expected Output from Skill |
|----------|-------|---------------------------|
| `agents/swe/reviewer.md` | Code review findings delivery | Toulmin-structured finding with evidence anchored to code and constraint artifacts |
| `agents/swe/analyst.md` | Design decision defense | SCQA or Toulmin argument with constraint traceability and architecture alternatives |
| `skills/swe/methodology/references/team-execution-pattern.md` | Inter-specialist communication | Structure-appropriate argument adapted to the receiving specialist's role |

### References

Each reference file is self-contained with its own Purpose, Scope, and parent-skill context header, enabling standalone reading:

- `references/argument-structures.md` — Toulmin, SCQA, Yes Ladder detailed structures with SWE examples
- `references/cognitive-persuasion.md` — Cialdini principles, pre-suasion, steel-manning process, cognitive bias details
