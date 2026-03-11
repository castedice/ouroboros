---
name: core-teaching
description: This skill provides decision-focused teaching methodology. It should be activated when an agent needs to "explain a concept for a decision", "teach only what's needed for the next choice", "assess knowledge gaps before explaining", "bridge explanation to action", "calibrate explanation depth to the audience", "reduce cognitive load in explanations", or "scaffold understanding incrementally".
---

# Teaching — Decision-Focused Knowledge Transfer

## Core Principle

**"Teach only what the next decision requires."**

The fastest path from confusion to action is not comprehensive understanding — it's targeted understanding of the decision at hand. Every explanation should end with a clearer set of choices, not a broader set of knowledge. Knowledge that doesn't connect to a decision is noise in the moment, however valuable it may be in the abstract.

This principle is not anti-knowledge. It is anti-premature-knowledge. When someone needs to choose between PostgreSQL and Redis for a cache layer, they don't need a history of database evolution — they need to understand the three dimensions where these options differ for their specific constraints. The history becomes relevant later, if ever.

Why this matters for compound velocity: every minute spent explaining irrelevant context is a minute the decision-maker cannot act. Decisions compound — each one unlocks the next. Faster targeted decisions produce exponential throughput improvement compared to slower comprehensive understanding.

## Learner Assessment

Before any explanation, assess the learner on four dimensions. This determines what to teach and how deep to go.

### Dimension 1: Cognitive Level (Bloom's Taxonomy)

Bloom's six levels describe what the learner can do with information:

| Level | Capability | Decision Relevance |
|-------|-----------|-------------------|
| **Remember** | Recall facts and terms | Can recognize options but not evaluate them |
| **Understand** | Explain concepts in own words | Can follow an explanation but not apply it independently |
| **Apply** | Use knowledge in new situations | Can implement a chosen approach |
| **Analyze** | Break down and compare | Can evaluate trade-offs between options |
| **Evaluate** | Judge based on criteria | Can make and defend decisions |
| **Create** | Synthesize new approaches | Can design novel solutions |

Most decisions require **Apply** or **Analyze** level — not Evaluate or Create. Teach to the level the decision needs, not to the highest level possible.

Assessment signals:

| Level Indicator | Evidence |
|----------------|----------|
| Below Apply | "What is a circuit breaker?" / "I've heard of it but never used one" |
| At Apply | "I've used circuit breakers before, but not in this specific context" |
| At Analyze | "I understand circuit breakers but I'm not sure if it's the right pattern here vs retry with backoff" |
| At Evaluate+ | "I'm choosing between three resilience patterns based on our failure mode characteristics" |

### Dimension 2: Domain Familiarity

| Level | Teaching Strategy |
|-------|-----------------|
| **Expert** (built similar systems) | Skip fundamentals entirely. Focus on delta — what's different about this specific context |
| **Intermediate** (knows the domain, not this specific problem) | Brief refresher, then focus on the novel aspects |
| **Novice** (new to the domain) | Start with analogy to something they know, build up to the minimum needed for the decision |

### Dimension 3: Existing Schema

What does the learner already know that connects to the new concept? Schema theory shows that new information integrates best when anchored to existing knowledge structures.

Diagnostic questions:

- "What does this remind you of?"
- "Have you solved a similar problem before?"
- "What's the closest thing you've worked with?"

The answer reveals the anchor point. Teach from there, not from first principles.

### Dimension 4: Cognitive Load State

| State | Strategy |
|-------|---------|
| **Low load** (start of project, exploration phase) | Can absorb more background. Include principles |
| **Medium load** (mid-implementation, juggling components) | Stick to immediately actionable information |
| **High load** (debugging, deadline pressure, context-switching) | Absolute minimum: "Do X because Y. Details later if needed." |

## Cognitive Load Management

John Sweller's Cognitive Load Theory identifies three types of mental burden. Effective teaching manages all three.

### Intrinsic Load (Inherent Complexity)

The complexity that belongs to the concept itself. Cannot be reduced, but can be decomposed.

Strategy: **Chunking** — break complex decisions into sequential smaller decisions.

Instead of: "Choose a database that satisfies performance, durability, scaling, operational, and cost constraints."
Try: "First question: does the data need ACID transactions? That eliminates half the options. Then we'll narrow further."

### Extraneous Load (Unnecessary Complexity)

Complexity from the explanation itself, not the concept. Must be eliminated.

Common sources in technical explanations:

| Source | Fix |
|--------|-----|
| Irrelevant history | "PostgreSQL was created in 1986 at Berkeley..." → Skip unless relevant to decision |
| Unnecessary alternatives | Mentioning 5 options when only 2 are viable → Pre-filter to viable options only |
| Jargon without definition | "Use a WAL for durability" → "Use a write-ahead log (WAL) — it records changes before applying them, so you can recover from crashes" |
| Tangential depth | "The B-tree index works by..." → Only explain if the decision hinges on index behavior |
| Premature abstraction | General theory before concrete instance → Start concrete, abstract only if needed |

### Germane Load (Learning-Productive Complexity)

Mental effort that builds lasting understanding. Should be maximized, but only for decision-relevant concepts.

Techniques to increase germane load:

| Technique | Application |
|-----------|------------|
| **Elaborative interrogation** | "Why does this matter for your specific case?" forces the learner to connect concept to context |
| **Self-explanation** | "Can you explain back how this would work in your system?" reveals gaps |
| **Comparison** | "How does this differ from [thing you already know]?" builds schema connections |
| **Desirable difficulty** | Present trade-offs and let the learner reason through them rather than giving the answer directly |

## Workflow

### Step 1: Decision Point Identification

Identify the specific decision the learner needs to make. Not the topic — the decision.

| Vague (topic) | Specific (decision) |
|---------------|-------------------|
| "Database selection" | "Should we use PostgreSQL or Redis for the session store, given our 50ms latency constraint?" |
| "Error handling" | "Should we use error codes or exceptions for the API boundary, given we're serving both Go and TypeScript clients?" |
| "Architecture" | "Should we extract the pricing logic into a separate service or keep it in the monolith for Q3?" |

### Step 2: Bloom Level Targeting

Determine the minimum cognitive level needed for this decision:

| Decision Type | Minimum Level Needed |
|--------------|---------------------|
| "Which of these two options?" | **Analyze** — needs to compare |
| "How do I implement X?" | **Apply** — needs to use in context |
| "Is this approach correct?" | **Evaluate** — needs to judge against criteria |
| "What approach should we take?" | **Analyze** or **Evaluate** depending on novelty |

Teach to this level, not higher. If the decision needs Analyze, teaching to Create wastes time.

### Step 3: Knowledge Gap Assessment (ZPD)

Vygotsky's Zone of Proximal Development (ZPD) defines the sweet spot between "can do alone" and "can't do even with help." Teach within the ZPD.

```
[Can do alone] ←→ [ZPD: Can do with teaching] ←→ [Can't do yet]
```

Assess what the learner already knows that relates to the decision:

- What concepts do they have that connect? (Schema anchoring candidates)
- What's the smallest knowledge gap between their current understanding and the decision?
- What can they figure out themselves vs. what needs explicit teaching?

### Step 4: Schema Anchoring

Find the learner's closest existing knowledge and build from there.

| Learner Knows | Target Concept | Anchor |
|--------------|----------------|--------|
| REST APIs | GraphQL | "Like REST but the client specifies exactly which fields it wants" |
| SQL databases | NoSQL | "Same goal (store and query data) but trades rigid schema for flexible documents" |
| Function calls | Message queues | "Like a function call where the caller doesn't wait for the return value" |

Anchoring process:

1. Identify the nearest known concept (from Dimension 3 assessment)
2. State the similarity: "X is like Y in that..."
3. State the critical difference: "...but X differs in..."
4. Connect to the decision: "This difference matters for your choice because..."

### Step 5: Depth Selection

Choose the minimum depth that enables the decision. Four levels, from shallowest to deepest:

| Depth | Technique | When |
|-------|-----------|------|
| **a. Analogy** | Compare to something known | Learner needs orientation ("What is this thing?") |
| **b. Principle** | State 1-2 core rules | Learner needs understanding ("Why does this work?") |
| **c. Detail** | Explain mechanism with code/diagrams | Learner needs specifics ("How exactly?") |
| **d. Example** | Show concrete comparison | Learner needs to evaluate ("Which is better for my case?") |

For detailed depth selection criteria and examples, see `references/explanation-depth.md`.

### Step 6: Decision Bridge

Every explanation must end by connecting back to the decision. The bridge pattern:

1. **Summarize the key insight**: "So the main difference is X"
2. **Present the options**: "Given this, you have two viable choices: A or B"
3. **State trade-offs**: "A gives you [benefit] at the cost of [cost]. B gives you [benefit] at the cost of [cost]"
4. **Recommend if appropriate**: "Given your constraint C-03, A is the better fit because [specific reason]"

Never end an explanation without connecting it to an action or choice.

For detailed bridging patterns, see `references/explanation-depth.md`.

### Step 7: Verification Loop (Elaborative Interrogation)

After the decision bridge, verify understanding through questions rather than repetition:

- "Does this match what you expected?" — checks for surprises (possible misunderstanding)
- "Why do you think this approach fits your case?" — forces articulation (reveals gaps)
- "What would change your decision?" — tests understanding of the qualifier/boundary conditions

If the learner's answer reveals a gap, cycle back to the appropriate step (usually Step 4 or 5 with additional depth).

### Decision Thresholds

Quantitative rules governing key methodology decisions:

| Decision Point | Threshold | Workflow Step |
|----------------|-----------|-------------|
| Depth escalation | Learner asks ≥2 clarifying questions at current depth → escalate one level | Step 5 |
| Explanation length | High load: ≤3 sentences. Medium load: ≤2 paragraphs. Low load: ≤5 paragraphs before Decision Bridge | Steps 5-6 |
| Verification retry | Maximum 2 re-explanation cycles (Step 4→7→4). After 2 cycles, decompose into sub-decisions | Step 7 |
| Option pre-filtering | Present ≤3 viable options; pre-filter non-viable before presenting | Step 6 |
| Chunking trigger | >3 simultaneous trade-off dimensions → decompose into sequential sub-decisions | Step 1 |

## Progressive Disclosure

The default path is the minimum path. Only deepen when the learner signals a need.

### Level 1 (Default): Analogy + Decision Bridge

Provide the analogy, state the trade-offs, present the choice. If the learner says "makes sense" and decides, stop. Teaching more would be counterproductive.

### Level 2 (On "Why?"): Add Principle

When the learner asks "why does this work?" or "what's the underlying reason?", provide the core principle. One or two sentences, no more.

### Level 3 (On "How exactly?"): Add Detail + Example

When the learner asks for specifics, provide mechanism explanation with code or diagrams (Dual Coding Theory — combining verbal and visual channels strengthens retention). Show concrete examples, ideally comparing the two options in their specific context.

### Anti-Pattern: Unprompted Deepening

Never deepen the explanation because the topic is interesting. Deepen only in response to:

- Explicit request: "Can you explain more?"
- Revealed gap: learner's response shows misunderstanding
- Decision requires it: the analogy level is genuinely insufficient for the choice

## Bias Mitigation

| Bias | Signal | Correction |
|------|--------|-----------|
| **Curse of knowledge** | Explaining at your level, not theirs | Use Dimension 2 assessment. If in doubt, start one level simpler than you think necessary |
| **Jargon leakage** | Using terms without defining them | Define on first use, or better: use the everyday equivalent |
| **False clarity** | Learner nods but can't explain back | Always run the verification loop (Step 7). Nodding is not understanding |
| **Confirmation bias** | Only explaining the option you prefer | Present both options fairly. Use the persuasion skill's steel-manning if you have a recommendation |
| **Completionism** | Teaching everything about the topic | Core Principle check: "Does the next decision require this information?" If no, omit |

## Validation Checklist

Before delivering any explanation:

- [ ] Specific decision point identified (not just a topic)
- [ ] Bloom level appropriate (not overshooting)
- [ ] Extraneous load removed (no irrelevant history, tangential depth, or premature theory)
- [ ] Anchored to existing knowledge (not starting from first principles)
- [ ] Ends with concrete choices (Decision Bridge present)
- [ ] Progressive: started at minimum depth, only deepened on request

## Integration Contracts

### Input

This skill is activated by agents during explanation tasks. Required context: the decision the learner needs to make, learner's current understanding level, and available domain artifacts for anchoring.

### Output

A depth-calibrated explanation ending with a Decision Bridge: concrete options with trade-offs and a recommendation tied to specific constraints.

### Consumers

| Consumer | Usage | Expected Output from Skill |
|----------|-------|---------------------------|
| `agents/swe/analyst.md` | Presenting architectural alternatives | Depth-calibrated explanation bridging to architecture decision with constraint references |
| `commands/core/onboard.md` | Explaining ouroboros capabilities | Progressive disclosure from analogy to detail based on user's familiarity |
| `commands/core/brainstorm.md` | Explaining divergent options | Comparison-focused explanation bridging to option selection |

### References

Each reference file is self-contained with its own Purpose, Scope, and parent-skill context header, enabling standalone reading:

- `references/cognitive-learning.md` — Bloom's Taxonomy, ZPD scaffolding, Cognitive Load Theory
- `references/explanation-depth.md` — 4-level depth matrix, Decision Bridge patterns, Transfer of Learning
