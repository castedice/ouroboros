# Framing Techniques

Five structured techniques for the Frame stage of brainstorming. Each technique helps scope, reframe, or deepen understanding of the problem before divergent generation begins. Poor framing is the most common cause of unproductive brainstorming — these techniques ensure the right problem is being solved.

## Technique Selection Guide

| Technique | Best For | Starting Point |
|-----------|----------|----------------|
| 5 Whys | Root cause tracing | A symptom or surface-level problem |
| How Might We (HMW) | Reframing problem as opportunity | A defined problem statement |
| Problem Reframing | Perspective shift | A problem that feels stuck or intractable |
| Stakeholder Mapping | Multi-perspective scoping | A problem with multiple affected parties |
| Jobs-to-be-Done | True user purpose discovery | A feature request or user complaint |

**Recommended combination**: Start with 5 Whys to find the root cause, then use HMW to reframe the root cause as an opportunity for brainstorming. Use Stakeholder Mapping when the problem affects multiple user types. Use Problem Reframing when 5 Whys leads to a dead end. Use Jobs-to-be-Done when the user's stated need may not reflect their actual goal.

---

## 1. 5 Whys

**Definition**: A root cause analysis technique that repeatedly asks "Why?" to peel back layers of symptoms and reach the fundamental cause. Developed at Toyota as part of the Toyota Production System, it works because most stated problems are symptoms of deeper issues.

**When to use**: When the stated problem feels like a symptom rather than a cause. If the brainstorming topic is "X doesn't work well," 5 Whys reveals what "well" means and why it falls short. Particularly effective for recurring problems that keep resurfacing despite previous fixes.

**Procedure**:

1. State the problem concretely: "What specifically is wrong?" (not "things could be better")
2. Ask "Why does this happen?" — write the answer
3. Ask "Why?" of that answer — write the next answer
4. Repeat until you reach a cause that is actionable and fundamental (typically 3-5 levels)
5. Verify: does addressing this root cause prevent the original symptom? If not, branch and try a different "Why?" at step 2 or 3

**Example**: 5 Whys on "brainstorm sessions produce generic ideas":

1. *Why do brainstorm sessions produce generic ideas?* → Because ideas are not grounded in codebase context
2. *Why are ideas not grounded in context?* → Because the brainstormer agent does not read relevant files before ideating
3. *Why doesn't it read relevant files?* → Because the Frame stage does not identify which files are relevant to the topic
4. *Why doesn't Frame identify relevant files?* → Because Frame only scopes the question, it does not explore the codebase
5. *Root cause*: The Frame stage lacks a codebase exploration step. Actionable fix: add a "gather context" sub-step to Frame that uses Glob/Grep to find relevant components before divergence begins.

**Pitfalls**:

- Stopping at the first plausible-sounding answer — push past the comfortable explanation
- Following only one branch — the first "Why?" answer may not be the only cause; consider branching at step 2-3
- Asking "Who?" instead of "Why?" — 5 Whys seeks systemic causes, not blame

---

## 2. How Might We (HMW)

**Definition**: A reframing technique that converts a problem statement into an opportunity question. The format is always "How might we [desired outcome]?" The phrase "might" is deliberate — it signals possibility rather than obligation, keeping the question open and inviting.

**When to use**: After defining a problem (often after 5 Whys), to transition from problem-finding to solution-finding. HMW questions become the input to the Diverge stage. They should be broad enough to invite multiple solutions but narrow enough to be actionable.

**Procedure**:

1. Start with a problem statement: "Users struggle with X" or "The system fails at Y"
2. Rewrite as "How might we [verb] [object] [context]?"
3. Check scope using the Goldilocks test:
   - Too broad: "How might we make the plugin better?" (invites infinite answers)
   - Too narrow: "How might we add a --verbose flag to evaluate?" (invites only one answer)
   - Just right: "How might we give users more visibility into evaluation progress?" (invites 8-15 answers)
4. Generate 3-5 HMW variants of the same problem to find the most generative framing
5. Select the HMW question that produces the most diverse idea directions as the brainstorming input

**Example**: HMW on "evaluation results are hard to compare across versions":

- HMW v1: "How might we make evaluation results comparable across versions?" (focuses on output format)
- HMW v2: "How might we track component quality over time?" (broader — invites tracking, visualization, alerting)
- HMW v3: "How might we help users understand whether their changes improved quality?" (user-centered — invites UX ideas)
- *Selected*: HMW v3 — broadest solution space while still being specific enough to brainstorm concretely

**Pitfalls**:

- Writing HMW questions that are disguised solutions: "How might we add a dashboard?" is a solution, not a question
- Making the question too broad — if you cannot imagine what a bad answer looks like, the question is too broad
- Skipping the variants step — the first HMW phrasing is rarely the best one

---

## 3. Problem Reframing

**Definition**: A perspective-shifting technique that challenges the problem definition itself by viewing it through different lenses. Instead of asking "How do we solve X?", reframing asks "What if X is not actually the problem?" or "Who else sees this differently?"

**When to use**: When the problem feels stuck or intractable — when every proposed solution seems inadequate. Reframing is the most powerful framing technique because it can completely change the solution space, but it requires intellectual courage to question the problem itself.

**Procedure**:

1. State the current problem definition explicitly
2. Apply 3-4 reframing lenses:
   - **Flip**: What if the opposite were the goal? (e.g., "too slow" → "what if we embraced slowness as thoroughness?")
   - **Broaden**: What larger problem is this a part of? (zoom out)
   - **Narrow**: What specific sub-problem is most painful? (zoom in)
   - **Audience shift**: Who else has this problem and how do they frame it?
3. For each reframing, describe what the new solution space looks like
4. Select the reframing that opens the most productive direction for brainstorming

**Example**: Problem Reframing on "the generate command produces low-quality components":

- *Flip*: What if generate is not supposed to produce high-quality components? What if its job is to produce a valid starting point, and `/evolve` handles quality? → This reframes "low quality" as "expected first draft" and shifts the problem to "evolve pipeline efficiency"
- *Broaden*: What larger problem does this represent? → The generate-evaluate-evolve loop is too many steps. The problem is pipeline friction, not generation quality
- *Narrow*: Which specific quality dimension fails most? → F2 (Progressive Disclosure) consistently scores 0. The problem is not "low quality" but "missing a specific structural pattern"
- *Audience shift*: How do other code generators handle quality? → Copilot generates inline and relies on immediate human review. The problem might be "generate creates whole files when it should create fragments for human assembly"

**Pitfalls**:

- Reframing as procrastination — reframing should take 5-10 minutes, not become an endless exploration
- Abandoning a valid problem definition for a more intellectually interesting one that is less actionable
- Reframing without testing — check "does this new framing lead to ideas we could not see before?"

---

## 4. Stakeholder Mapping

**Definition**: A scoping technique that identifies all parties affected by the problem and brainstorm outcomes, then captures their distinct perspectives. Different stakeholders experience the same problem differently, and solutions that satisfy one may create problems for another.

**When to use**: When the problem affects multiple user types, roles, or system components. Stakeholder Mapping prevents solutions that optimize for one perspective while degrading another. Essential for architectural or cross-cutting changes.

**Procedure**:

1. List all stakeholders (people, systems, or roles affected by the problem):
   - **Direct users**: Who interacts with the affected component?
   - **Indirect users**: Who is affected by the component's output?
   - **Maintainers**: Who updates or evolves the component?
   - **Dependencies**: What other components depend on this one?
2. For each stakeholder, capture:
   - Their primary concern regarding the problem
   - What a good solution looks like from their perspective
   - What would make the problem worse for them
3. Identify conflicts between stakeholder needs
4. Use conflicts as creative constraints for the brainstorming Frame

**Example**: Stakeholder Mapping for "redesigning the evaluation criteria system":

| Stakeholder | Primary Concern | Good Outcome | Worse Outcome |
|-------------|----------------|--------------|---------------|
| Component author | Fair, actionable scoring | Criteria that guide improvement | Criteria that penalize valid design choices |
| Evaluator agent | Clear, unambiguous criteria | Consistent scoring across runs | Criteria requiring subjective judgment calls |
| Evolve command | Identifying improvement targets | Specific, addressable weaknesses | Vague "needs improvement" feedback |
| Multi-model relay | Cross-model consistency | Criteria that models interpret similarly | Criteria sensitive to model-specific reasoning |

- *Conflict*: Component author wants flexible criteria (room for design choice), but evaluator agent wants rigid criteria (consistent scoring). This tension becomes a creative constraint: "How might we design criteria that are specific enough for consistent scoring but flexible enough for valid design variation?"

**Pitfalls**:

- Listing only obvious stakeholders — look for indirect and downstream effects
- Treating all stakeholders as equally important — prioritize by impact and decision authority
- Mapping stakeholders without using the conflicts — the value is in the tensions, not the map itself

---

## 5. Jobs-to-be-Done

**Definition**: A technique that discovers the true purpose behind a user's stated need by asking "What job is the user hiring this product/feature to do?" Developed by Clayton Christensen, JTBD separates the functional job (what gets done), the emotional job (how the user wants to feel), and the social job (how the user wants to be perceived).

**When to use**: When a user requests a specific feature or complains about a specific behavior. JTBD reveals whether the stated request matches the actual need. Particularly effective when a feature request feels oddly specific — specificity often masks a larger unmet need.

**Procedure**:

1. Capture the user's stated need: "I want X" or "X doesn't work"
2. Ask the functional question: "When you use X, what are you ultimately trying to accomplish?"
3. Ask the context question: "In what situation do you reach for X? What triggers it?"
4. Ask the alternative question: "If X did not exist, what would you do instead?"
5. Synthesize the Job Statement: "When [situation], I want to [motivation], so I can [expected outcome]"
6. Use the Job Statement as the brainstorming input — it is more generative than the original request

**Example**: Jobs-to-be-Done for "add a --watch mode to the evaluate command":

- *Stated need*: "I want evaluate to re-run automatically when files change"
- *Functional*: "I want to see evaluation results update as I edit components" → The job is rapid feedback during editing, not file watching per se
- *Context*: "I run evaluate, make a change, run evaluate again, make another change..." → The job is iteration efficiency
- *Alternative*: "I'd open two terminals — one for editing, one for repeatedly running evaluate" → The job is reducing context switching
- *Job Statement*: "When iterating on a component's quality, I want instant feedback on how my changes affect evaluation scores, so I can make targeted improvements without interrupting my editing flow"
- *Reframed brainstorming topic*: "How might we give instant quality feedback during component editing?" — This opens solutions beyond --watch: editor integration, diff-based partial evaluation, preview mode, inline score annotations

**Pitfalls**:

- Accepting the first answer to "what are you trying to accomplish?" — push deeper; the first answer is often a restatement of the feature request
- Ignoring the context question — the situation reveals constraints that the feature request hides
- Over-abstracting the job — "I want to be productive" is too abstract; keep it specific enough to generate ideas
