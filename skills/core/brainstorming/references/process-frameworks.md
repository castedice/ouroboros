# Process Frameworks

Five structured frameworks for organizing a brainstorming session end-to-end. Each framework provides a different lens on the creative process, suited to different problem types. All frameworks map to the current 5-stage brainstorm flow (Frame → Diverge → Cluster → Converge → Select) but emphasize different stages.

## Framework Selection Guide

| Framework | Best For | Core Insight | Stages |
|-----------|----------|-------------|--------|
| Double Diamond | Problem definition unclear | Diverge twice — first on the problem, then on solutions | 4 |
| Design Thinking | User-centered problems | Empathy before ideation; prototype before committing | 5 |
| CPS (Creative Problem Solving) | Structured problem solving | Separate "mess-finding" from "solution-finding" | 4 |
| TRIZ | Technical contradiction resolution | Contradictions are features, not bugs — resolve them inventively | 3 |
| Triple Diamond | Complex system problems | Add research upfront and reflection at the end | 6 |

**Default recommendation**: Use CPS for most ouroboros brainstorming sessions — its Clarify stage maps cleanly to Frame, and its structure matches the existing 5-stage flow. Switch to Double Diamond when you are unsure whether you are solving the right problem. Switch to TRIZ when the problem involves a technical trade-off (e.g., "we need X but X breaks Y").

---

## 1. Double Diamond

**Description**: Developed by the UK Design Council, Double Diamond separates problem-finding from solution-finding. The first diamond diverges and converges on understanding the problem; the second diamond diverges and converges on solving it. The key insight is that most failed projects solve the wrong problem well.

**Stage structure**:

| Phase | Diamond | Mode | Activity |
|-------|---------|------|----------|
| Discover | 1st (Problem) | Diverge | Explore the problem space broadly — gather data, interview stakeholders, map context |
| Define | 1st (Problem) | Converge | Synthesize findings into a clear problem statement |
| Develop | 2nd (Solution) | Diverge | Generate solutions to the defined problem |
| Deliver | 2nd (Solution) | Converge | Evaluate, select, and plan implementation |

**Mapping to 5-stage brainstorm flow**:

| Brainstorm Stage | Double Diamond Phase | Notes |
|-----------------|---------------------|-------|
| Frame | Discover + Define | Frame becomes two steps: explore the problem broadly, then sharpen it |
| Diverge | Develop | Standard divergent generation |
| Cluster | Deliver (first half) | Group solutions before evaluating |
| Converge | Deliver (second half) | Apply Feasibility × Impact criteria |
| Select | Deliver (final) | Top 3 recommendation |

**Recommended technique combinations**:

- Discover: 5 Whys, Stakeholder Mapping, Jobs-to-be-Done (from `references/framing-techniques.md`)
- Define: HMW (How Might We) to reframe discovered problems as opportunities
- Develop: SCAMPER, Analogy, What-if (from `references/divergent-techniques.md`)
- Deliver: Feasibility × Impact, Risk Assessment (from `references/convergent-criteria.md`)

**Best used when**: You suspect the stated problem is a symptom, not the root cause. The first diamond forces you to validate the problem before investing in solutions.

**Ouroboros context example**: A user says "the evaluate command is too slow." Before brainstorming speed optimizations (second diamond), first diamond explores: Is it actually slow, or does it feel slow because output is unstructured? Is the bottleneck in evaluation or in file I/O? Is speed the real concern, or is it that users run evaluate too often because they don't trust prior results? The first diamond might redefine the problem as "evaluation results lack persistence" rather than "evaluation is slow."

---

## 2. Design Thinking

**Description**: Popularized by IDEO and Stanford d.school, Design Thinking centers on user empathy. It adds two stages that other frameworks skip: Empathize (understand the user before defining the problem) and Prototype (test ideas cheaply before committing). The key insight is that understanding the user's actual experience reveals problems they cannot articulate.

**Stage structure**:

| Phase | Mode | Activity |
|-------|------|----------|
| Empathize | Research | Observe and engage with users to understand their experience |
| Define | Converge | Frame the problem from the user's perspective |
| Ideate | Diverge | Generate a wide range of solutions |
| Prototype | Build | Create quick, cheap representations of top ideas |
| Test | Evaluate | Put prototypes in front of users and learn |

**Mapping to 5-stage brainstorm flow**:

| Brainstorm Stage | Design Thinking Phase | Notes |
|-----------------|----------------------|-------|
| Frame | Empathize + Define | Frame starts with user empathy, not just problem scoping |
| Diverge | Ideate | Standard divergent generation |
| Cluster | (between Ideate and Prototype) | Implicit grouping before selecting what to prototype |
| Converge | Prototype + Test | Evaluate by building and testing, not just scoring |
| Select | (after Test) | Selection informed by prototype results |

**Recommended technique combinations**:

- Empathize: Jobs-to-be-Done, Stakeholder Mapping (from `references/framing-techniques.md`)
- Define: HMW, Problem Reframing (from `references/framing-techniques.md`)
- Ideate: Brainwriting 6-3-5, Lateral Thinking, SCAMPER (from `references/divergent-techniques.md`)
- Prototype: Rapid implementation in a worktree (using `scripts/worktree.sh`)
- Test: `/evaluate` on prototype output, manual inspection

**Best used when**: The problem is user-facing and you need to validate assumptions about what users actually want before committing to a direction.

**Ouroboros context example**: Before redesigning the `/brainstorm` command output format, Design Thinking would start by examining how users actually interact with brainstorm results. Do they read the full output? Do they copy-paste specific ideas? Do they feed results into `/evolve` or `/generate`? The Empathize phase might reveal that users skip the ranked list and jump to the next-action suggestions — meaning the output redesign should prioritize actionable next steps over detailed ranking tables.

---

## 3. CPS (Creative Problem Solving)

**Description**: Developed by Osborn and Parnes, CPS is the most research-backed creative process framework. It separates problem-finding ("Clarify"), solution-finding ("Ideate"), and solution-refining ("Develop") into distinct phases, each with its own diverge-converge cycle. The key insight is that every stage benefits from both divergent and convergent thinking.

**Stage structure**:

| Phase | Sub-steps | Activity |
|-------|-----------|----------|
| Clarify | Explore the Vision, Gather Data, Formulate Challenge | Understand the mess, identify the real challenge |
| Ideate | Generate Ideas | Produce many solutions to the formulated challenge |
| Develop | Develop Solutions | Strengthen promising ideas, assess acceptability |
| Implement | Formulate a Plan | Create action steps, identify supporters and resistors |

**Mapping to 5-stage brainstorm flow**:

| Brainstorm Stage | CPS Phase | Notes |
|-----------------|-----------|-------|
| Frame | Clarify | Direct mapping — both scope the problem with context |
| Diverge | Ideate | Direct mapping — both generate ideas without judgment |
| Cluster | Develop (first half) | Group ideas to identify solution themes |
| Converge | Develop (second half) | Strengthen and evaluate grouped ideas |
| Select | Implement | Top recommendations with concrete action plans |

**Recommended technique combinations**:

- Clarify: 5 Whys, Problem Reframing (from `references/framing-techniques.md`)
- Ideate: First Principles, Constraint Removal, Analogy (from `references/divergent-techniques.md`)
- Develop: Feasibility × Impact, Risk Assessment, Weighted Decision Matrix (from `references/convergent-criteria.md`)
- Implement: Specific command invocations with arguments (matching Select stage format)

**Best used when**: The problem is well-understood enough to frame clearly, and you want a balanced, structured process. CPS is the safest default — it rarely leads you astray.

**Ouroboros context example**: Improving the `/evolve` command's improvement cycle. Clarify: what exactly is suboptimal about the current cycle? (Score plateaus, same improvements suggested repeatedly, evolve sometimes degrades quality.) Ideate: generate improvement ideas using multiple techniques. Develop: strengthen top ideas by checking against the evaluation criteria framework. Implement: recommend specific changes to `commands/core/evolve.md` with before/after evaluation plans.

---

## 4. TRIZ

**Description**: Developed by Genrich Altshuller from analysis of 200,000+ patents, TRIZ (Theory of Inventive Problem Solving) is based on a counter-intuitive insight: inventive solutions resolve contradictions rather than compromising between them. When improving Parameter A makes Parameter B worse, TRIZ provides 40 Inventive Principles for resolving the contradiction without trade-off.

**Stage structure**:

| Phase | Activity |
|-------|----------|
| Identify Contradiction | Define the improving parameter and the worsening parameter |
| Apply Inventive Principles | Use the contradiction matrix to find applicable principles |
| Generate Solutions | Apply selected principles to generate concrete solutions |

**Mapping to 5-stage brainstorm flow**:

| Brainstorm Stage | TRIZ Phase | Notes |
|-----------------|------------|-------|
| Frame | Identify Contradiction | Frame the problem as a specific contradiction |
| Diverge | Apply Inventive Principles + Generate Solutions | Use TRIZ principles as structured divergent techniques |
| Cluster | (group by principle applied) | Solutions cluster naturally around the principle that generated them |
| Converge | (standard) | Apply Feasibility × Impact criteria |
| Select | (standard) | Top 3 with contradiction resolution quality as extra criterion |

**Recommended technique combinations**:

- Frame: State the contradiction explicitly ("Improving X worsens Y")
- Diverge: TRIZ 40 Principles top 10 (from `references/divergent-techniques.md`), supplemented by What-if
- Converge: Feasibility × Impact plus TRIZ Contradiction Check (from `references/convergent-criteria.md`)
- Select: Prioritize solutions that fully resolve the contradiction over those that merely shift it

**Best used when**: The problem involves a clear trade-off or tension — you want A but A causes not-B. TRIZ is specifically designed for these "you can't have both" problems.

**Ouroboros context example**: The evaluation system has a contradiction: improving evaluation depth (more thorough criteria, longer analysis) worsens evaluation speed (slower feedback, higher cost). TRIZ reframes this as a solvable contradiction rather than an inherent trade-off. Inventive Principle #1 (Segmentation): split evaluation into fast-pass (check critical criteria only) and deep-pass (full criteria). Inventive Principle #15 (Dynamicity): adjust evaluation depth based on component's recent change magnitude. The contradiction is resolved — not compromised.

---

## 5. Triple Diamond

**Description**: An extension of Double Diamond that adds a Research diamond before problem-finding and a Reflect phase after solution-delivering. The key insight is that complex system problems benefit from foundational research upfront (you don't know what you don't know) and structured reflection afterward (did we actually solve it?).

**Stage structure**:

| Phase | Diamond | Mode | Activity |
|-------|---------|------|----------|
| Research | 0th (Context) | Diverge + Converge | Survey the landscape — what exists? what has been tried? what do we know? |
| Discover | 1st (Problem) | Diverge | Explore the problem space broadly |
| Define | 1st (Problem) | Converge | Synthesize into a clear problem statement |
| Develop | 2nd (Solution) | Diverge | Generate solutions |
| Deliver | 2nd (Solution) | Converge | Evaluate and select |
| Reflect | (Post) | Meta | Did we solve the right problem? What did we learn about our process? |

**Mapping to 5-stage brainstorm flow**:

| Brainstorm Stage | Triple Diamond Phase | Notes |
|-----------------|---------------------|-------|
| (Pre-Frame) | Research | Run `/research` before brainstorming to gather context |
| Frame | Discover + Define | Two-step framing with problem exploration |
| Diverge | Develop | Standard divergent generation |
| Cluster | (between Develop and Deliver) | Implicit grouping |
| Converge | Deliver | Apply criteria with research context |
| Select | Deliver (final) | Top 3 recommendation |
| (Post-Select) | Reflect | Apply meta-reflection techniques from `references/meta-reflection.md` |

**Recommended technique combinations**:

- Research: `/research` command for external sources, codebase exploration
- Discover: Stakeholder Mapping, 5 Whys (from `references/framing-techniques.md`)
- Define: HMW, Problem Reframing (from `references/framing-techniques.md`)
- Develop: Morphological Analysis, Reverse Engineering, Brainwriting 6-3-5 (from `references/divergent-techniques.md`)
- Deliver: Feasibility × Impact, Weighted Decision Matrix, Pareto Priority (from `references/convergent-criteria.md`)
- Reflect: Double Loop Learning, Assumption Mapping (from `references/meta-reflection.md`)

**Best used when**: The problem is complex, systemic, and poorly understood. Triple Diamond is the most thorough framework — use it when the cost of solving the wrong problem is high.

**Ouroboros context example**: Planning the next major ouroboros version. Research phase: survey what other plugin systems do (VS Code extensions, Neovim plugins, Obsidian community plugins), analyze the current system's pain points from STATUS.md backlog, review DECISIONS.md for past architectural choices. This research informs a much richer first diamond (problem-finding) than jumping straight to "what should we build next?" The reflect phase after selecting priorities asks: "Did we consider all stakeholders? Did our research bias us toward solutions we already know?"
