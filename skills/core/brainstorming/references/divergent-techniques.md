# Divergent Thinking Techniques

Six structured techniques for generating ideas. Each technique card includes: definition, when to use it, procedure, an ouroboros-context example, and common pitfalls.

## Technique Selection Guide

| Technique | Best For | Starting Point |
|-----------|----------|----------------|
| SCAMPER | Improving existing things | An existing component or process |
| What-if | Breaking assumptions | A constraint or "given" to challenge |
| Analogy | Cross-domain inspiration | A similar problem in another domain |
| First Principles | Fundamental rethinking | The core purpose or goal |
| Constraint Removal | Expanding possibility space | A known limitation |
| Reverse Engineering | Working backward from ideal | A desired end-state |

**Recommended rotation**: Start with the technique least familiar to the topic. If the topic is about improving an existing component, start with Analogy or First Principles (not SCAMPER, which will feel natural and produce obvious variations). This counteracts anchoring bias.

---

## 1. SCAMPER

**Definition**: A checklist-based technique that systematically modifies an existing concept through seven lenses: Substitute, Combine, Adapt, Modify/Magnify, Put to other use, Eliminate, Reverse.

**When to use**: When you have an existing artifact (component, process, architecture) and want to explore variations. SCAMPER excels at incremental innovation — finding improvements to things that already work.

**Procedure**:

1. Identify the target artifact clearly (what exactly are we modifying?)
2. Walk through each SCAMPER lens:
   - **Substitute**: What component, material, or process can be replaced?
   - **Combine**: What can be merged with something else?
   - **Adapt**: What can be borrowed from another context and adjusted?
   - **Modify/Magnify**: What can be made larger, smaller, more frequent, less frequent?
   - **Eliminate**: What can be removed without losing core value?
   - **Reverse**: What happens if the order, direction, or roles are flipped?
3. Record every idea generated, even partial ones
4. Skip lenses that produce nothing after 30 seconds — not every lens applies

**Example**: SCAMPER on `/evaluate` command's Phase 1 (Parse Input):

- *Substitute*: Replace file path input with git diff input (evaluate changes, not files)
- *Combine*: Merge Phase 1 and Phase 2 — detect mode and gather context simultaneously
- *Eliminate*: Remove mode detection entirely — always run all modes and let evaluator decide relevance
- *Reverse*: Instead of user specifying target, evaluator scans and suggests what needs evaluation

**Pitfalls**:

- Applying all 7 lenses mechanically when only 3-4 are relevant — skip unproductive lenses
- SCAMPER tends toward incremental ideas — pair with First Principles or What-if for radical alternatives

---

## 2. What-if

**Definition**: Challenge assumptions by hypothetically removing or inverting constraints. The format is always "What if [assumption] were [opposite/removed/changed]?"

**When to use**: When the solution space feels constrained by unquestioned assumptions. What-if is the fastest technique for expanding the possibility space.

**Procedure**:

1. List 5-8 assumptions about the current situation (technical, organizational, resource)
2. For each assumption, form a What-if question by removing or inverting it
3. Follow each What-if to its logical conclusion (don't stop at the question)
4. Identify ideas that survive even when the assumption is reinstated — these are the most robust

**Example**: What-if on ouroboros plugin architecture:

- Assumption: "Commands must be markdown files" → *What if commands were executable scripts?* → Could enable dynamic argument parsing, but lose readability
- Assumption: "Agents are read-only" → *What if agents could write files?* → Simpler pipeline, but harder to audit and test
- Assumption: "One agent per procedure" → *What if multiple agents collaborated on one procedure?* → Pipeline agents (collector → analyzer) could specialize

**Pitfalls**:

- Asking What-if without following through to consequences — always complete the thought
- Challenging only safe assumptions — the most productive What-ifs challenge deeply held beliefs

---

## 3. Analogy

**Definition**: Borrow solutions from other domains by identifying structural similarities between problems. The format is "How does [other domain] solve [similar problem]?"

**When to use**: When internal thinking has stalled or when the problem seems unique. Analogy breaks domain fixation by importing external patterns.

**Procedure**:

1. Abstract the current problem to its structural essence (remove domain-specific details)
2. Identify 2-3 other domains that face structurally similar problems
3. For each domain, describe how they solve it
4. Translate the domain-specific solution back to the original problem context
5. Evaluate which translated elements are applicable

**Example**: Analogy for plugin evaluation methodology:

- Abstract problem: "How to assess quality of a complex artifact against criteria"
- *Code review*: Pull request reviews use checklists, multiple reviewers, and approval gates → multi-evaluator consensus
- *Academic peer review*: Blind review, structured rubrics, revise-and-resubmit cycle → evaluation → feedback → improvement loop
- *Restaurant inspection*: Critical violations vs. minor violations, severity-based pass/fail → tiered criteria with severity gate

**Pitfalls**:

- Forcing analogies that don't structurally match — the abstraction step must be honest
- Taking the analogy too literally — translate principles, not mechanisms

---

## 4. First Principles

**Definition**: Decompose a problem to its fundamental truths and rebuild from scratch, ignoring current implementations and conventions.

**When to use**: When the current approach feels fundamentally wrong, not just needing incremental improvement. First Principles is the most radical technique — use it when SCAMPER and What-if produce unsatisfying results.

**Procedure**:

1. State the core goal: "What are we fundamentally trying to achieve?"
2. Decompose into fundamental truths: "What do we know to be true, independent of current implementation?"
3. Build up from truths: "If we started from scratch with only these truths, what would we build?"
4. Compare with current state: "Where does our current approach deviate from this ground-up design?"
5. Identify bridging ideas: "What elements of the ground-up design can we adopt without full rewrite?"

**Example**: First Principles on plugin quality assurance:

1. *Goal*: Ensure every plugin component does its job well
2. *Truths*: (a) Quality has multiple dimensions, (b) AI evaluation is probabilistic, (c) Improvement requires measurement, (d) Human judgment is the ultimate arbiter
3. *Ground-up*: Continuous quality monitoring with automated measurement + human override — not periodic manual evaluation
4. *Gap*: Current approach is on-demand `/evaluate` — no continuous monitoring
5. *Bridge*: Add evaluation on commit hook (automated) while keeping `/evaluate` for deep analysis (manual)

**Pitfalls**:

- Claiming something is a "first principle" when it's actually an assumption — be rigorous about what's truly fundamental
- Producing impractical ground-up designs with no bridge to current reality

---

## 5. Constraint Removal

**Definition**: Temporarily remove one or more real constraints to explore what becomes possible, then selectively reintroduce constraints to find the practical sweet spot.

**When to use**: When a constraint is so dominant that it shapes all thinking. By temporarily removing it, you discover which ideas are killed by the constraint vs. which are simply unthought-of.

**Procedure**:

1. List all constraints (technical, budget, time, compatibility, convention)
2. Remove the most restrictive constraint
3. Generate ideas without that constraint (3-5 ideas)
4. Gradually reintroduce the constraint — which ideas survive? Which can be adapted?
5. Repeat with a different constraint removed

**Example**: Constraint Removal on multi-model evaluation:

- Constraints: (a) Codex/Gemini CLI latency, (b) API cost, (c) Parse reliability, (d) Provider availability
- *Remove latency*: Could run 5 models in parallel for every evaluation, creating a review panel
- *Remove cost*: Could run each evaluation 10 times per model for statistical reliability
- *Reintroduce gradually*: 3-model panel is feasible at current cost; 10-run reliability is too expensive but 2-run reproducibility check is practical

**Pitfalls**:

- Removing trivial constraints ("what if we had more time") instead of fundamental ones
- Failing to reintroduce constraints — ideas must ultimately be grounded in reality

---

## 6. Reverse Engineering

**Definition**: Start from the ideal outcome and work backward to identify what must be true for that outcome to exist.

**When to use**: When the desired end-state is clear but the path to get there is not. Reverse Engineering is goal-driven — it turns "how do we get there?" into "what must be true?"

**Procedure**:

1. Describe the ideal outcome in concrete terms (not vague aspirations)
2. Identify the immediate preconditions: "For this to be true, what must already exist?"
3. For each precondition, identify its own preconditions (chain backward)
4. Continue until you reach current state or an actionable starting point
5. The backward chain reveals the critical path and potential shortcuts

**Example**: Reverse Engineering for "all core components at 16/16":

1. *Ideal*: Every command, agent, and skill scores 16/16 on tiered criteria
2. *Precondition*: Each component has been evaluated and evolved to address all 0-score criteria
3. *Precondition*: Evaluation pipeline is reliable (evaluator itself is 16/16)
4. *Precondition*: Criteria are well-calibrated (not too lenient, not too strict)
5. *Current state*: Evaluator is 16/16, criteria exist but threshold tuning is deferred
6. *Critical path*: Evaluate remaining components → evolve → validate. Criteria tuning can happen in parallel

**Pitfalls**:

- Describing the ideal too vaguely ("everything works perfectly") — be concrete
- Stopping the backward chain too early — continue until you reach something actionable
