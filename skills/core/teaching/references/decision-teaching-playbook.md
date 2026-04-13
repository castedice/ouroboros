# Decision-Focused Teaching Playbook

## Learner Assessment

Assess the learner before explaining.
The assessment tells you what to teach, how deep to go, and what to omit.

### Dimension 1: Cognitive Level

Most decisions need Apply or Analyze, not the highest Bloom level available.

| Signal | Likely Level | Teaching Implication |
|--------|--------------|----------------------|
| "What is X?" | Below Apply | Start with orientation and anchoring |
| "I know X but not when to use it here" | Apply | Explain how the concept maps into the current context |
| "I am weighing X against Y" | Analyze | Focus on the comparison dimensions |
| "I am judging whether this is correct" | Evaluate | Provide criteria and evidence |

### Dimension 2: Domain Familiarity

| Learner State | Teaching Strategy |
|---------------|-------------------|
| Expert | Skip fundamentals and teach the contextual delta |
| Intermediate | Give a brief refresher, then focus on the novel part |
| Novice | Start with analogy and build only the minimum needed for the decision |

### Dimension 3: Existing Schema

Use the learner's nearest known concept as the anchor.
Useful diagnostic questions include "What does this remind you of", "What is the closest thing you have used", and "Have you solved a similar problem before".

### Dimension 4: Cognitive Load

| Load State | Teaching Strategy |
|------------|-------------------|
| Low | Include a small amount of principle-level context |
| Medium | Stay tightly actionable and avoid long setup |
| High | Give the shortest path to a decision and defer detail |

## Load Management

### Intrinsic Load

Intrinsic load is the real complexity of the decision.
You cannot remove it, but you can decompose it into smaller sequential choices.

### Extraneous Load

Extraneous load comes from the explanation rather than the problem.
This is where most teaching waste happens.

| Source | Fix |
|--------|-----|
| Irrelevant history | Remove it unless it changes the decision |
| Too many alternatives | Pre-filter to the viable set |
| Undefined jargon | Define on first use or replace it with plain language |
| Tangential depth | Cut it unless the trade-off depends on it |
| Premature abstraction | Start concrete and abstract later only if needed |

### Germane Load

Germane load is productive effort that helps the learner build useful mental structure.
Keep only the effort that helps the current decision.

| Technique | Application |
|-----------|------------|
| Elaborative interrogation | Ask why a constraint matters in the learner's case |
| Self-explanation | Ask the learner to explain back how the option would work |
| Comparison | Contrast the current options side by side |
| Desirable difficulty | Let the learner reason about the trade-off before giving the answer |

## Workflow Details

### Step 1: Decision Point Identification

Find the decision, not the topic.

| Vague Topic | Decision-Focused Version |
|-------------|--------------------------|
| Database selection | Should we use PostgreSQL or Redis for this workload given the latency constraint |
| Error handling | Should this API boundary use exceptions or error codes |
| Architecture | Should we extract this subsystem now or keep it in the monolith |

### Step 2: Knowledge Gap Assessment

Use the learner assessment to locate the shortest gap between what the learner already knows and what the decision requires.
This is the practical ZPD target.

### Step 3: Schema Anchoring

Anchor from something familiar before introducing the new concept.

| Learner Knows | Target Concept | Anchor |
|---------------|----------------|--------|
| REST APIs | GraphQL | Like REST, but the client chooses the fields explicitly |
| SQL databases | NoSQL documents | Same storage goal, different schema trade-offs |
| Function calls | Message queues | Like a call where the sender does not wait for the return value |

Use a four-part anchor.
State the known concept.
State the similarity.
State the critical difference.
State why that difference matters for the current decision.

### Step 4: Depth Selection

Choose the shallowest depth that unlocks the decision.
Use `references/explanation-depth.md` for the full four-level matrix.

| Depth | Use When |
|-------|----------|
| Analogy | The learner needs orientation |
| Principle | The learner asks why it works |
| Detail | The learner asks how it works |
| Example | The learner needs a concrete comparison to decide |

### Step 5: Decision Bridge

Every explanation should end by reconnecting to action.

1. Summarize the key difference.
2. Present the viable options.
3. State the trade-offs in the learner's context.
4. Recommend a path when the context supports one.

### Step 6: Verification Loop

Use questions instead of repetition to check understanding.

- Ask whether the explanation matched the learner's expectation.
- Ask why the learner thinks the option fits.
- Ask what would change the choice.

If the answer reveals a gap, loop back to the right step with one level more depth.

### Thresholds

| Decision Point | Threshold |
|----------------|-----------|
| Depth escalation | Two clarifying questions at the same depth |
| Explanation length under high load | Three sentences before the decision bridge |
| Explanation length under medium load | Two paragraphs before the decision bridge |
| Explanation length under low load | Five paragraphs before the decision bridge |
| Option count | Three viable options maximum |
| Retry limit | Two explanation loops before decomposing the decision |

## Progressive Disclosure

Start with the minimum path.
Only deepen when the learner asks, the learner response exposes a gap, or the decision genuinely requires more depth.

### Level 1

Give the analogy and the decision bridge.
Stop if the learner can now decide.

### Level 2

Add the core principle when the learner asks why.
Keep it short and decision-relevant.

### Level 3

Add detail and example when the learner asks how or when the decision depends on mechanism-level understanding.

### Anti-Pattern

Do not deepen because the topic is interesting.
Deepen only when it serves the next decision.

## Validation and Integration

### Delivery Checklist

- [ ] The explanation started from a concrete decision.
- [ ] The learner assessment shaped the explanation depth.
- [ ] Extraneous load was removed.
- [ ] The explanation anchored to existing knowledge.
- [ ] The explanation ended with a decision bridge.
- [ ] Verification happened before the explanation deepened.

### Integration Contracts

| Contract | Expectation |
|----------|-------------|
| Input | The decision, the learner state, and any domain artifacts needed for anchoring |
| Output | A calibrated explanation that ends with options, trade-offs, and a recommendation when appropriate |
| Typical consumers | `agents/swe/analyst.md`, `commands/core/onboard.md`, and `commands/core/brainstorm.md` |
