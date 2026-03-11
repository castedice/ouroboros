---
name: brainstorming-methodology
description: This skill provides brainstorming methodology knowledge. It should be activated when an agent needs to "brainstorm ideas for a topic", "explore alternatives creatively", "generate divergent options", "evaluate and rank ideas", "apply structured thinking techniques", or "select the best idea from a set of candidates".
---

# Brainstorming Methodology

## Core Principle

**"Diverge to discover, converge to decide."**

Brainstorming is a two-phase process. The divergent phase generates raw possibilities without judgment; the convergent phase applies rigorous criteria to select the best. Mixing the phases undermines both — judgment kills creativity during divergence, and uncritical acceptance produces poor decisions during convergence.

The cycle is: **Frame → Diverge → Cluster → Converge → Select → Reflect (optional)**. Each stage has a distinct cognitive mode. The transition between divergence and convergence is the critical moment — it must be explicit and deliberate. A signal like "Divergence complete. Switching to convergence." makes this transition visible and prevents unconscious drift.

Why two separate phases instead of generate-and-evaluate simultaneously? Because evaluation during generation activates the critic, which suppresses novel ideas. Studies of creative problem-solving consistently show that separated generation and evaluation produce both more ideas and better final selections than simultaneous approaches. The brainstorming methodology encodes this separation structurally, not as a suggestion but as a hard constraint.

## Brainstorming Workflow

Six stages executed in order (the final stage is optional). Each stage has a defined input, process, and output. Skipping or reordering stages produces worse results — the ordering is deliberate.

**Reference files by stage:**

| Stage | Reference | Content |
|-------|-----------|---------|
| Frame | `references/framing-techniques.md` | 5 Whys, HMW, Problem Reframing, Stakeholder Mapping, Jobs-to-be-Done |
| Frame | `references/process-frameworks.md` | Double Diamond, Design Thinking, CPS, TRIZ, Triple Diamond — framework selection guide |
| Diverge | `references/divergent-techniques.md` | SCAMPER, What-if, Analogy, First Principles, Constraint Removal, Reverse Engineering + TRIZ Principles, Lateral Thinking, Morphological Analysis, Brainwriting 6-3-5, Random Entry |
| Converge | `references/convergent-criteria.md` | Feasibility × Impact matrix + Novelty Assessment, TRIZ Contradiction Check, Weighted Decision Matrix, Time-to-Value, Pareto Priority |
| Reflect | `references/meta-reflection.md` | Double Loop Learning, Assumption Mapping, Reflection Trigger |

### 1. Frame (Scope)

**Input**: Raw topic or question from the user.
**Output**: Scoped brainstorming question with identified constraints and selected process framework.

- Clarify what to explore: a question, a problem, or an open-ended topic
- Apply framing techniques from `references/framing-techniques.md` to deepen problem understanding (5 Whys for root cause, HMW for reframing, Jobs-to-be-Done for user purpose)
- Select a process framework from `references/process-frameworks.md` to structure the session (or use the default 6-stage flow if no framework fits better)
- Identify constraints: technical, resource, timeline, architectural
- Gather context: existing decisions, related code, knowledge base entries
- Define success: what makes a good outcome for this brainstorm session

Framing prevents both too-narrow thinking (premature constraints) and too-broad thinking (unbounded scope that produces unusable ideas). A well-framed topic balances specificity with openness.

**Framing quality signals**:

| Signal | Too Narrow | Good | Too Broad |
|--------|-----------|------|-----------|
| Scope | "Should we use Redis or Memcached?" | "How should we approach caching for evaluations?" | "How to make things faster?" |
| Constraint count | 5+ constraints listed before brainstorming | 1-3 key constraints | Zero constraints acknowledged |
| Expected idea count | Only 2-3 ideas seem possible | 8-15 ideas feel achievable | Hundreds of ideas possible |

If the topic is too narrow, broaden by removing one constraint. If too broad, add one concrete constraint from the codebase context.

### 2. Diverge (Generate)

**Input**: Scoped question + selected techniques.
**Output**: 8-15 ideas with technique attribution.

- Apply divergent techniques from `references/divergent-techniques.md`
- Generate 8-15 ideas without filtering or evaluating
- Attribute each idea to the technique that produced it
- Capture raw ideas even if they seem impractical — they may inspire practical variants

The quantity target (8-15) is deliberate. Fewer than 8 suggests insufficient exploration; more than 15 suggests insufficient framing. If you reach 15+ easily, the topic may need further scoping.

**Technique selection**: Choose 3-4 techniques based on topic type. Start with the technique least obvious for the topic to counteract anchoring bias. If the topic is about improving an existing component, start with Analogy or First Principles before SCAMPER. Each technique should produce 2-5 ideas; if a technique yields fewer than 2 after genuine effort, switch to the next.

**Grounding rule**: Every idea must connect to at least one concrete fact from the codebase, knowledge base, or domain. "Add a monitoring dashboard" is ungrounded; "Add evaluation result tracking in dev/evaluations/ with content hashing for change detection" is grounded in the actual codebase structure.

### 3. Cluster (Organize)

**Input**: 8-15 raw ideas.
**Output**: 3-5 named clusters with ideas assigned.

- Group related ideas into themes (typically 3-5 themes)
- Name each cluster with a descriptive label
- Identify standalone ideas that don't fit any cluster — these are often the most novel

Clustering reveals the underlying structure of your thinking. Three diagnostic checks:

| Pattern | Diagnosis | Action |
|---------|-----------|--------|
| All ideas in 1 cluster | Divergence too narrow | Re-run divergence with a different technique set |
| Every idea is a singleton | Framing too broad | Re-frame with a more specific question |
| 3-5 balanced clusters | Good divergence | Proceed to convergence |

Standalone ideas deserve special attention — they represent thinking that breaks out of the dominant patterns. Do not discard them simply because they are alone.

### 4. Converge (Evaluate)

**Input**: Clustered ideas.
**Output**: Ranked ideas with Feasibility × Impact scores.

- Apply convergent criteria from `references/convergent-criteria.md`
- Score each idea on Feasibility × Impact dimensions (High/Medium/Low)
- Assess Risk and Alignment for top 5-7 candidates
- Rank ideas within each cluster, then across clusters

Convergence is structured, not intuitive. Each assessment must cite a specific reason, not a gut feeling. "High impact because it reduces 3 manual steps to 1 automated step" is valid. "High impact because it feels important" is not.

**Evidence requirement**: Every Feasibility/Impact/Risk rating must include a parenthetical citation. Examples: "High feasibility (reuses existing worktree.sh infrastructure)", "Medium impact (affects 3 of 6 commands)", "Low risk (fully reversible via git)". Ratings without citations are invalid and must be revised.

### 5. Select (Recommend)

**Input**: Ranked ideas with evidence-based assessments.
**Output**: Top 3 recommendations with rationale, weaknesses, and next actions.

- Present top 3 ideas with clear rationale for each
- Include the runner-up reasoning: why #2 and #3 are worth considering
- Suggest the natural next action for each idea
- Acknowledge what was explored but not selected, and why

Selection is a recommendation, not a decision. The user makes the final choice. Present enough information for an informed decision without overwhelming with detail.

**Weakness requirement**: Each top-3 idea must include at least one honest weakness or risk. An idea presented as having no downsides is insufficiently analyzed — every approach involves trade-offs. The weakness should be genuine, not a token acknowledgment. "Might take a while" is a token weakness; "Requires modifying all 6 command files, creating a large blast radius if the design is wrong" is genuine.

**Next action format**: Each suggestion must be a specific command invocation with arguments, not a generic reference. `/research "caching patterns in CLI tools"` is specific; `/research topic` is generic.

### 6. Reflect (Optional)

**Input**: Top 3 recommendations from the Select stage.
**Output**: Reflection notes identifying blind spots, challenged assumptions, or process improvements.

- Apply meta-reflection techniques from `references/meta-reflection.md`
- **Double Loop Learning**: Ask "Did we solve the right problem?" — check if the framing was appropriate
- **Assumption Mapping**: Identify hidden assumptions in the top recommendations that were never explicitly challenged
- **Reflection Trigger**: Check "What perspectives or stakeholders did we miss?"

This stage is optional but recommended for high-stakes topics (strategic decisions, architecture changes, roadmap planning). Skip for narrow tactical brainstorms where the framing is clearly correct.

**Trigger conditions** — apply Reflect when any of these are true:

| Condition | Why Reflect |
|-----------|-------------|
| Top 3 ideas are all from the same cluster | Possible tunnel vision — reflection may reveal missed directions |
| The framing was inherited, not actively chosen | The problem definition may not be the right one |
| Stakeholders beyond the immediate user are affected | Perspectives may have been missed |
| The topic involves irreversible decisions | Higher stakes warrant the extra scrutiny |

## Quick Reference

**Techniques**: 11 divergent techniques available — see `references/divergent-techniques.md` for procedure cards. Core 6: SCAMPER, What-if, Analogy, First Principles, Constraint Removal, Reverse Engineering. Extended 5: TRIZ Principles, Lateral Thinking, Morphological Analysis, Brainwriting 6-3-5, Random Entry. If one technique dominates (60%+ of ideas), force rotation.

**Frameworks**: 5 process frameworks available — see `references/process-frameworks.md` for stage mappings. Use the default 6-stage flow for most topics; override with Double Diamond (unclear problem), Design Thinking (user-centered), CPS (structured problem), TRIZ (technical contradiction), or Triple Diamond (complex system). Framework overhead should not exceed framework benefit. If the framework feels constraining midway, switch to default.

**Convergence**: Feasibility × Impact matrix (primary) with Risk and Alignment (secondary) — see `references/convergent-criteria.md`. Tiebreaker: Reversibility → Compound potential → Simplicity → User energy.

## Bias Mitigation

Brainstorming involves both generation and evaluation, creating systematic bias risks. The highest-risk biases and their countermeasures:

| Bias | Phase | Symptom | Countermeasure |
|------|-------|---------|----------------|
| Anchoring | Diverge | First idea dominates; subsequent ideas are variations | Start with the most unfamiliar technique (Analogy or First Principles) before SCAMPER |
| Premature convergence | Diverge | Evaluating ideas during generation ("that won't work") | Enforce strict no-judgment during divergence; capture all ideas regardless of initial reaction |
| Status quo | Converge | Favoring ideas closest to current implementation | Explicitly score novelty as a positive factor in impact assessment |
| Confirmation | Converge | Seeking evidence that supports preferred idea | Require at least one weakness for every top-3 idea |
| Sunk cost | Converge | Favoring ideas that build on existing investment | Evaluate each idea as if starting from scratch; past investment is not a criterion |
| Framework fixation | Frame | Forcing the topic into a chosen framework even when it doesn't fit | If the framework feels constraining midway, switch to the default 6-stage flow |

**Detection checklist** — before finalizing any brainstorm output:

- [ ] Did the first technique dominate? (anchoring risk)
- [ ] Were any ideas filtered during generation? (premature convergence)
- [ ] Are the top 3 all similar to current state? (status quo bias)
- [ ] Does every top-3 idea have a genuine weakness? (confirmation bias)
- [ ] Was existing investment used as justification? (sunk cost)
- [ ] Did the chosen framework constrain thinking rather than enable it? (framework fixation)

## Common Pitfalls

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Judging during divergence | Diverge | Phrases like "that's impractical" or "we tried that" are banned until convergence |
| Too few ideas (<5) | Diverge | Apply at least 3 different techniques; switch technique when stuck |
| Context-free ideation | Diverge | Ground every idea in at least one concrete fact from the codebase or domain |
| Skipping convergence | Select | Never present raw unranked ideas; always apply criteria before recommending |
| Single technique reliance | Diverge | Rotate techniques; if SCAMPER produced most ideas, force a What-if or Analogy round |
| Vague ideas | Diverge | Each idea must be specific enough to act on: "use caching" is vague; "cache evaluation results by content hash to skip unchanged components" is actionable |
| Token weaknesses | Select | Weaknesses must be genuine trade-offs, not platitudes. "Might be complex" is a token; "requires modifying 6 files with large blast radius" is genuine |
| Generic next actions | Select | Each next action must be a specific command with arguments, not a template placeholder |

## Validation Checklist

Use this checklist to verify that brainstorming methodology is being applied correctly:

- [ ] Topic is framed with clear scope and constraints
- [ ] Divergent phase produced 8+ ideas (minimum 5 for narrow topics)
- [ ] No judgment or evaluation occurred during divergence
- [ ] At least 2 different divergent techniques were used
- [ ] No single technique produced more than 60% of ideas
- [ ] Each idea attributes its source technique
- [ ] Ideas are grounded in context (codebase, domain, or knowledge base evidence)
- [ ] Ideas are clustered into 3-5 named themes
- [ ] Convergent criteria (Feasibility × Impact) applied to all candidates with evidence citations
- [ ] Top 3 ideas include rationale and at least one genuine weakness each
- [ ] Runner-up reasoning explains why #2 and #3 are worth considering
- [ ] Next actions are specific command invocations with arguments
- [ ] If a process framework was used, its stages were mapped to the 6-stage flow
- [ ] If Reflect stage was triggered, assumptions and blind spots were explicitly noted

## See Also

- **evolution-methodology** (`skills/core/evolution/SKILL.md`) — When brainstorm results feed into component improvement, evolution methodology governs the improvement cycle
- **evaluation-methodology** (`skills/core/evaluation/SKILL.md`) — Evaluation criteria used to assess ideas' impact on component quality
- **brainstormer agent** (`agents/core/brainstormer.md`) — The primary consumer of this skill; implements the workflow as a single procedure
- **brainstorm command** (`commands/core/brainstorm.md`) — The orchestrator that invokes the brainstormer agent and manages multi-model coordination
