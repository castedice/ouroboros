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
| TRIZ 40 Principles | Resolving technical contradictions | A trade-off or tension between two parameters |
| Lateral Thinking | Intentional non-linear leaps | A problem where logical approaches have stalled |
| Morphological Analysis | Systematic combination coverage | A problem decomposable into independent parameters |
| Brainwriting 6-3-5 | Building on others' ideas | Multi-model or multi-perspective setup |
| Random Entry | Breaking fixation completely | A topic where all ideas feel repetitive |

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

- Constraints: (a) Codex CLI latency, (b) API cost, (c) Parse reliability, (d) Provider availability
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

---

## 7. TRIZ 40 Principles (Top 10)

**Definition**: A systematic innovation technique derived from Genrich Altshuller's analysis of 200,000+ patents. TRIZ identifies 40 Inventive Principles for resolving contradictions — situations where improving one parameter worsens another. The top 10 most frequently applicable principles are presented here for brainstorming use.

**When to use**: When the problem involves a clear trade-off or tension ("we want A but A causes not-B"). TRIZ is more systematic than First Principles because it provides a curated set of proven resolution strategies rather than requiring ground-up reconstruction. Use TRIZ when First Principles feels too unconstrained.

**Procedure**:

1. State the contradiction: "Improving [Parameter A] worsens [Parameter B]"
2. Walk through the top 10 principles, generating at least one idea per applicable principle:
   - **#1 Segmentation**: Divide the object or system into independent parts
   - **#2 Taking Out**: Separate an interfering part or property
   - **#5 Merging**: Combine identical or similar objects/operations
   - **#10 Prior Action**: Perform required changes in advance (partially or fully)
   - **#13 Inversion**: Invert the action, make the fixed part movable or the movable fixed
   - **#15 Dynamicity**: Allow characteristics to change to be optimal at each stage
   - **#18 Mechanical Vibration**: Use oscillation instead of continuous action
   - **#25 Self-service**: Make an object serve itself by performing auxiliary functions
   - **#28 Replace Mechanical System**: Replace mechanical means with sensory (optical, acoustic, etc.)
   - **#35 Parameter Change**: Change an object's physical state, concentration, flexibility, temperature
3. Record all ideas — even principles that seem irrelevant can spark unexpected connections
4. Check: does the idea resolve the contradiction (both parameters improve) or merely shift it?

**Example**: TRIZ on the contradiction "evaluation depth vs. evaluation speed":

- *#1 Segmentation*: Split evaluation into fast-pass (critical criteria only) and deep-pass (all criteria); run fast-pass always, deep-pass on demand
- *#10 Prior Action*: Pre-compute evaluation baselines on commit; only evaluate changed dimensions at runtime
- *#15 Dynamicity*: Adjust evaluation depth based on the magnitude of changes since last evaluation — small changes get shallow evaluation, large changes get deep evaluation
- *#25 Self-service*: Make components self-evaluating — embed quality checks within component templates that run on save

**Pitfalls**:

- Forcing all 10 principles on every problem — typically 3-5 principles are relevant; skip the rest
- Using TRIZ without first stating the contradiction explicitly — the contradiction statement is what makes TRIZ work
- Producing ideas that shift the contradiction rather than resolve it — check that both parameters genuinely improve

---

## 8. Lateral Thinking

**Definition**: Coined by Edward de Bono, Lateral Thinking deliberately breaks logical chains of reasoning to produce unexpected connections. Unlike What-if (which follows logical consequences of changed assumptions), Lateral Thinking intentionally introduces non-logical jumps: random associations, provocation, and reversal.

**When to use**: When logical approaches have been exhausted and all ideas feel like variations on a theme. Lateral Thinking is the most disruptive technique — it intentionally breaks coherence to find ideas that linear thinking cannot reach. Use it as a rescue technique when other methods produce only obvious answers.

**Procedure**:

1. **Provocation**: State something deliberately absurd about the problem. Format: "Po: [absurd statement]" (Po = Provocative Operation, de Bono's marker for statements not meant to be true)
   - Example: "Po: The evaluation system should give random scores"
2. **Movement**: Instead of judging the provocation, extract a useful principle from it
   - From the example: Random scores → what if evaluation added controlled randomness to stress-test criteria robustness?
3. **Random Entry**: Pick a random word/concept unrelated to the problem, then force a connection
   - Random word: "kitchen" → kitchens have recipes → what if components had "quality recipes" (step-by-step improvement paths)?
4. **Reversal**: State the exact opposite of the desired outcome, then find ideas in the reversed state
   - "We want to make evaluation worse" → ideas for making evaluation worse reveal assumptions about what makes it good
5. Capture all ideas from steps 2-4, then evaluate which ones contain a genuinely new direction

**Example**: Lateral Thinking on "how to improve the brainstormer agent":

- *Provocation*: "Po: The brainstormer should never produce ideas" → Movement: What if the brainstormer produced anti-ideas (things to definitely not do)? Anti-ideas often reveal hidden assumptions more clearly than positive ideas
- *Random Entry*: Word "archaeology" → archaeology layers discoveries by time period → what if brainstorming layered ideas by time horizon? Short-term ideas in one cluster, long-term in another, with explicit connections between layers
- *Reversal*: "Make the brainstormer agent produce the worst possible ideas" → It would ignore context, use only one technique, never ground ideas → These are exactly the current pitfalls, which means prevention of these specific failures should be structural, not advisory

**Pitfalls**:

- Treating provocations as proposals — they are thinking tools, not ideas; the ideas come from the Movement step
- Abandoning ideas that feel uncomfortable — lateral ideas should feel strange initially; that is the point
- Using Lateral Thinking first — it works best after logical techniques have been exhausted, providing contrast

---

## 9. Morphological Analysis

**Definition**: A systematic technique that decomposes a problem into independent parameters (dimensions), lists possible values for each parameter, and then explores combinations across the resulting matrix. Developed by Fritz Zwicky, it guarantees coverage of the combinatorial space that intuitive brainstorming misses.

**When to use**: When the problem can be decomposed into 3-5 independent dimensions, each with 3-5 possible values. Morphological Analysis is more thorough than SCAMPER because it systematically covers all combinations rather than walking through a checklist. Use it for architectural or design decisions where the solution space is structured but large.

**Procedure**:

1. Identify 3-5 independent parameters of the solution (dimensions that can vary independently)
2. For each parameter, list 3-5 possible values (options for that dimension)
3. Construct the morphological matrix (parameters × values)
4. Generate ideas by selecting one value from each parameter — each unique combination is a potential solution
5. Focus on non-obvious combinations — skip combinations that match existing solutions or obvious pairings
6. Evaluate the most promising 5-8 combinations for coherence (do the selected values actually work together?)

**Example**: Morphological Analysis on "evaluation output format":

| Parameter | Value 1 | Value 2 | Value 3 | Value 4 |
|-----------|---------|---------|---------|---------|
| **Output target** | Terminal | File | Editor integration | Web dashboard |
| **Detail level** | Score only | Score + summary | Full report | Interactive drill-down |
| **Comparison mode** | Single snapshot | Before/after diff | Trend over time | Cross-component ranking |
| **Trigger** | On-demand | On-commit | On-save | Continuous |

- *Obvious combination*: Terminal + Full report + Single snapshot + On-demand (current implementation)
- *Non-obvious combination 1*: Editor integration + Score only + Before/after diff + On-save → Inline quality annotations that update as you edit, showing whether changes improve or degrade score
- *Non-obvious combination 2*: File + Score + summary + Trend over time + On-commit → Persistent quality ledger in `dev/evaluations/` tracking component scores across commits
- *Non-obvious combination 3*: Terminal + Interactive drill-down + Cross-component ranking + On-demand → TUI dashboard showing all components ranked by quality with drill-down into individual criteria

**Pitfalls**:

- Choosing parameters that are not truly independent — dependent parameters produce incoherent combinations
- Listing too many parameters (6+) — the combinatorial explosion becomes unmanageable; stick to 3-5
- Evaluating combinations only for feasibility — the point is to find novel combinations, then assess feasibility

---

## 10. Brainwriting 6-3-5

**Definition**: A structured idea-building technique where participants write 3 ideas, pass them to the next person, who adds 3 ideas building on the previous ones, repeated for 5 rounds. Originally designed for groups of 6 people, it adapts naturally to multi-model brainstorming: each model extends the previous model's ideas, producing compound innovation through iterative building.

**When to use**: When multiple perspectives are available (multi-model evaluation, or sequential rounds within a single session). Brainwriting excels at building on ideas — each round extends and combines previous ideas rather than generating independently. Use it when you want depth (developed ideas) rather than breadth (many unrelated ideas).

**Procedure**:

1. **Round 1**: Generate 3 seed ideas (any technique — even intuition is fine for seeds)
2. **Round 2**: For each seed idea, generate 1 extension, combination, or variation. Do not evaluate — only build
3. **Round 3**: For each Round 2 idea, add another extension layer. Ideas can now combine across branches
4. **Round 4**: Review all ideas so far, identify the 2-3 most promising threads, and develop them further
5. **Round 5**: Final synthesis — combine the best elements across all threads into 2-3 fully developed ideas
6. The output is 2-3 developed ideas (not 8-15 raw ideas) — Brainwriting trades quantity for depth

**Example**: Brainwriting on "improving worktree.sh isolation":

- *Round 1 seeds*: (A) Per-worktree .env files, (B) Snapshot-based rollback, (C) Worktree health checks
- *Round 2 builds*: (A→A2) .env files auto-generated from component context, (B→B2) Snapshot as pre-merge validation checkpoint, (C→C2) Health checks run evaluation on worktree changes before merge
- *Round 3 builds*: (A2→A3) Context-aware worktree initialization that pre-loads relevant knowledge base entries, (B2+C2→BC3) Pre-merge validation pipeline: snapshot → health check → evaluate → merge-or-rollback
- *Round 4 focus*: BC3 is the most promising — a structured validation pipeline for worktree merges
- *Round 5 synthesis*: "Worktree Validation Pipeline" — on merge request: (1) snapshot current state, (2) run evaluation on changed components, (3) compare before/after scores, (4) auto-merge if scores improve or hold, rollback if scores degrade

**Pitfalls**:

- Evaluating during building rounds — the first 3 rounds are purely generative; save judgment for Round 4
- Not building on previous ideas — each round must extend, not replace; the technique's value is in compounding
- In multi-model context: giving each model independent prompts rather than passing previous model's ideas as input

---

## 11. Random Entry

**Definition**: A fixation-breaking technique that introduces a completely random stimulus (word, image, concept) and forces a connection to the problem. The randomness bypasses existing mental models entirely, producing connections that no amount of logical thinking would reach. Edward de Bono's "random word" technique is the simplest form.

**When to use**: When all ideas feel repetitive, when the same themes keep appearing regardless of which technique is applied. Random Entry is the nuclear option for breaking fixation — it is completely unanchored from the problem context, which is both its strength (novel connections) and its weakness (many connections are useless). Use it as a last resort when anchoring is severe.

**Procedure**:

1. Generate a random stimulus: pick a word from a dictionary page, use a random noun generator, or choose an object you can see
2. List 5-8 attributes, associations, or properties of the random stimulus
3. For each attribute, force a connection to the brainstorming topic: "How does [attribute] relate to [problem]?"
4. Most connections will be weak or absurd — that is expected. Capture all of them anyway
5. Review all forced connections: typically 1-2 out of 5-8 produce genuinely novel directions
6. Develop the promising connections into concrete ideas grounded in the actual problem context

**Example**: Random Entry for "how to improve documentation generation":

- *Random word*: "Coral"
- *Attributes of coral*: grows incrementally, forms reefs (composites), symbiotic with algae, adapts to currents, bleaches under stress, provides shelter for other organisms
- *Forced connections*:
  - "Grows incrementally" → Documentation that grows with the codebase, adding sections as components are created rather than being generated all at once
  - "Symbiotic with algae" → Documentation that lives symbiotically with code — embedded in the same file, extracted automatically for rendering (like literate programming)
  - "Bleaches under stress" → Documentation that signals staleness — sections automatically marked as "possibly outdated" when the code they reference changes significantly
  - "Provides shelter" → Documentation as onboarding shelter — structured specifically as newcomer pathways, not reference material
- *Promising directions*: "Bleaches under stress" → staleness detection via content hashing is immediately actionable and novel

**Pitfalls**:

- Rejecting connections too quickly — the technique requires suspending judgment about plausibility during the connection phase
- Using non-random stimuli (picking a word related to the problem) — the entire value comes from the randomness
- Expecting every random word to work — some words produce nothing useful; try a second word if the first yields fewer than 2 promising connections
