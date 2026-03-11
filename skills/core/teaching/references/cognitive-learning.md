# Cognitive Learning Theory — Foundations for Decision-Focused Teaching

> **Purpose**: Theoretical foundations (Bloom's Taxonomy, ZPD, Cognitive Load Theory, Schema Theory) for the teaching methodology.
> **Scope**: Learning science principles informing the teaching SKILL's learner assessment and depth calibration.
> **Parent Skill**: `skills/core/teaching/SKILL.md` — core methodology and workflow.
> **Standalone**: Yes — can be read independently for understanding the theoretical basis.

Theoretical foundations underlying the teaching methodology. This reference provides depth for agents that need to understand the "why" behind the SKILL's workflow.

## Bloom's Taxonomy: Cognitive Levels

Benjamin Bloom's revised taxonomy (Anderson & Krathwohl, 2001) defines six hierarchical levels of cognitive processing. Each level includes all capabilities of lower levels.

### The Six Levels

| Level | Verb | What the Learner Can Do | Decision Capability |
|-------|------|------------------------|-------------------|
| 1. **Remember** | Recall, recognize, list | Retrieve information from memory | Can name options but not evaluate them |
| 2. **Understand** | Explain, summarize, interpret | Grasp meaning, translate between representations | Can follow an explanation but not apply independently |
| 3. **Apply** | Execute, implement, use | Use knowledge in new concrete situations | Can implement a chosen approach correctly |
| 4. **Analyze** | Compare, differentiate, organize | Break information into parts, find relationships | Can evaluate trade-offs between options |
| 5. **Evaluate** | Judge, justify, critique | Make judgments based on criteria and standards | Can make and defend decisions with confidence |
| 6. **Create** | Design, construct, generate | Combine elements into novel patterns | Can invent new approaches beyond existing options |

### Decision Type → Required Level Mapping

| Decision Type | Minimum Bloom Level | Rationale |
|--------------|-------------------|-----------|
| "Do X or Y?" (binary choice) | Analyze | Needs comparison capability |
| "How do I implement X?" | Apply | Needs execution capability |
| "Is this correct?" (review) | Evaluate | Needs judgment against criteria |
| "What should we build?" (design) | Analyze → Evaluate | Needs comparison + judgment |
| "Invent a solution" (novel) | Create | Needs synthesis (rare in typical decisions) |

### Teaching to Level, Not Beyond

The key insight: teach to the minimum level the decision requires. If a decision needs Analyze (compare two databases), teaching to Create (design a new database) wastes cognitive resources. The learner needs to compare, not invent.

Overshooting symptoms:

- Explaining theory when the learner needs a concrete comparison
- Discussing historical evolution when the learner needs current trade-offs
- Teaching general principles when the learner needs specific application guidance

Undershooting symptoms:

- Providing facts (Remember) when the learner needs to compare (Analyze)
- Showing one example (Understand) when the learner needs to apply to their context (Apply)
- Listing options without trade-offs (Remember/Understand) when the learner needs to choose (Analyze)

## Zone of Proximal Development (ZPD)

Lev Vygotsky's ZPD defines three zones of learner capability:

```
┌─────────────────────────────────────────────┐
│            Can't do (even with help)         │
│   ┌─────────────────────────────────────┐   │
│   │     ZPD (can do with scaffolding)    │   │
│   │   ┌─────────────────────────────┐   │   │
│   │   │     Can do independently     │   │   │
│   │   └─────────────────────────────┘   │   │
│   └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

Teaching is only effective within the ZPD. Below it: the learner already knows, so teaching is redundant. Above it: the learner lacks prerequisites, so teaching is incomprehensible.

### Scaffolding Strategy (Gradual Release)

Scaffolding is temporary support that enables the learner to operate within their ZPD. It follows a four-phase withdrawal:

| Phase | Teacher Role | Learner Role | Example |
|-------|-------------|-------------|---------|
| 1. **Modeling** | Demonstrates the full process | Observes and asks questions | "Let me walk through how I'd evaluate these two options..." |
| 2. **Coaching** | Guides as learner attempts | Tries with support, asks when stuck | "Start by listing the constraints. What's the first one you'd check?" |
| 3. **Supporting** | Available but not leading | Works independently, consults on uncertainty | "You're on track. For the performance constraint, check the benchmark data in..." |
| 4. **Independence** | Steps back entirely | Handles the decision alone | Learner evaluates and decides without assistance |

In teaching skill context, most interactions are Phase 1 (explaining for a decision) or Phase 2 (guiding through a decision process). Phases 3-4 happen naturally as the learner applies the decision pattern to future similar decisions.

### ZPD Assessment Shortcuts

| Signal | Zone | Action |
|--------|------|--------|
| "I've never heard of X" | Below ZPD for X | Anchor to something they know, then bridge |
| "I know what X is but not when to use it" | In ZPD | Perfect teaching opportunity — connect X to their decision context |
| "I use X regularly" | Above ZPD for X | Skip teaching X, focus on the novel aspect |
| "I've evaluated X vs Y before in a similar context" | Above ZPD for this decision type | Provide only the delta — what's different about this context |

## Cognitive Load Theory

John Sweller's Cognitive Load Theory explains why some explanations succeed and others fail, regardless of accuracy. Working memory has finite capacity (~4 chunks for novel information). Exceed it, and learning stops.

### Three Load Types

| Type | Source | Management |
|------|--------|-----------|
| **Intrinsic** | Complexity inherent in the concept | Cannot be reduced, but can be decomposed into sequential steps (chunking) |
| **Extraneous** | Poor explanation design | Must be eliminated — this is the primary optimization target |
| **Germane** | Productive learning effort (building schemas) | Should be maximized, but only for decision-relevant concepts |

The equation: **Intrinsic + Extraneous + Germane ≤ Working Memory Capacity**

If Extraneous is high, there's no room for Germane (actual learning). The first priority is always: reduce Extraneous to near zero.

### Extraneous Load Elimination Checklist

| Source | Check | Action |
|--------|-------|--------|
| **Irrelevant context** | "Does this information affect the decision?" | If no → remove |
| **Historical tangent** | "Does the history explain why the options differ?" | If no → remove |
| **Excessive alternatives** | "Are more than 2-3 options genuinely viable?" | If no → pre-filter to viable options |
| **Undefined jargon** | "Would the learner know this term?" | If no → define on first use or use plain language |
| **Redundant information** | "Did I already convey this in a different form?" | If yes → remove the weaker version |
| **Premature abstraction** | "Is the theory needed before the concrete example?" | If no → start concrete, abstract later if requested |
| **Split attention** | "Does the learner need to mentally integrate separate pieces?" | If yes → integrate them in the presentation (annotated diagrams, inline code comments) |

### Germane Load Maximization Techniques

| Technique | Theory | Application |
|-----------|--------|------------|
| **Elaborative Interrogation** | Asking "why" questions deepens processing | "Why does this constraint matter for your specific system?" |
| **Self-Explanation** | Explaining back reveals and fills gaps | "Can you walk me through how this would work in your codebase?" |
| **Interleaving** | Mixing related concepts strengthens discrimination | Compare the two options side-by-side rather than explaining each fully in isolation |
| **Worked Examples** | Complete solutions with reasoning visible | "Here's how a team chose between the same options: they checked X, then Y, then decided Z because..." |
| **Desirable Difficulty** | Moderate challenge strengthens retention | Present trade-offs without immediate recommendation — let the learner reason through before providing your analysis |

## Schema Theory

Schemas are organized knowledge structures in long-term memory. New information integrates faster and more durably when it connects to existing schemas.

### Schema-Based Teaching Pattern

1. **Diagnose existing schema**: What related concept does the learner already know?
2. **Select anchor point**: Choose the closest known concept
3. **State similarity**: "X is like Y in that [shared properties]"
4. **State difference**: "But X differs from Y in [critical distinctions]"
5. **Connect to decision**: "This difference is what makes X better/worse for your case because [constraint connection]"

### Schema Mismatch Handling

When the learner has an incorrect schema (misconception):

| Signal | Response |
|--------|----------|
| "Oh, so X is basically the same as Y?" (when it's not) | "They're similar in [aspect], but there's a critical difference in [aspect] that affects your decision: [specific impact]" |
| Confident but wrong assumption | Don't say "that's wrong." Say "That's true for [context], but in your context [different behavior because ...]" |
| Partially correct understanding | Build on the correct parts: "You're right that [correct part]. The piece that's different here is [correction]" |

## Active Learning Integration

Research consistently shows that active engagement produces stronger learning than passive reception. In teaching for decisions, this means the learner should work through the reasoning, not just receive the conclusion.

### Passive → Active Conversion

| Passive | Active |
|---------|--------|
| "Option A is better because..." | "Looking at your constraints, what would you check first to compare these options?" |
| "The trade-off is X vs Y" | "What would you gain with A? What would you lose?" (then fill gaps) |
| "I recommend X" | "Given what we discussed, which option do you lean toward? Why?" |

Active learning takes more time per interaction but produces faster independent decision-making — the compound velocity benefit.

## Transfer of Learning

Transfer is the ability to apply learning from one context to another. Teaching for transfer means the learner can handle similar future decisions independently.

### Near vs Far Transfer

| Type | Definition | Teaching Strategy |
|------|-----------|-----------------|
| **Near transfer** | Same type of decision in similar context | Teach the decision pattern explicitly: "Whenever you face [this type of choice], check [these dimensions]" |
| **Far transfer** | General reasoning applicable to different contexts | Teach the underlying principle, not just the instance: "The general pattern is: constrain first, then evaluate options against constraints" |

For decision-focused teaching, near transfer is the primary goal — enabling the learner to make the same type of decision next time without help. Far transfer is a bonus that emerges from repeated near transfer experiences.
