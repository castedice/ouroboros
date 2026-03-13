---
name: swe-pipeline-methodology
description: This skill provides the SWE pipeline methodology knowledge. It should be activated when an agent needs to "follow the 8-stage pipeline", "execute a disciplined engineering workflow", "determine stage depth for a task", "apply DDD+SDD+TDD methodology", "traverse the understand-constrain-design-interface-test-implement-verify-optimize sequence", or "decide how much ceremony a task requires".
---

# SWE Pipeline Methodology

## Core Principle

**"Fixed sequence, variable depth."**

Every software engineering task traverses the same 8-stage cognitive sequence: Understand, Constrain, Design, Interface, Test, Implement, Verify, Optimize. The sequence is invariant — what varies is the depth at each stage (Skip / Light / Standard / Deep). This is the medical diagnosis analogy: a doctor always follows the same diagnostic sequence (history → examination → tests → diagnosis → treatment → follow-up), but the effort at each step adapts to severity.

Why invariant sequence? Because skipping stages is the root cause of most engineering failures. Skipping Understand leads to solving the wrong problem. Skipping Constrain leads to over- or under-engineering. Skipping Interface leads to integration pain. The depth system provides the escape hatch — a stage can be Light (minutes) or even Skip (not applicable), but the conscious decision to skip is itself valuable. It forces the engineer to acknowledge what was deliberately omitted.

## Three Foundational Methodologies

The pipeline embodies three established methodologies, each owning specific stages:

| Methodology | Stages | Core Contribution |
|-------------|--------|-------------------|
| **DDD** (Domain-Driven Design) | Understand, Design | Domain modeling, ubiquitous language, bounded contexts |
| **SDD** (Specification-Driven Development) | Constrain, Interface | Constraint-first design, artifacts as contracts |
| **TDD** (Test-Driven Development) | Test, Implement, Verify, Optimize | Red-Green-Refactor cycle |

The methodologies are not applied in isolation — they flow into each other through the pipeline. DDD's domain model feeds into SDD's constraint analysis, which feeds into TDD's test design. The pipeline is the integration mechanism.

## Pipeline Overview

Eight stages executed in order. Each stage has a defined purpose, key output, and methodology anchor. For detailed stage descriptions with key questions, DO/DON'T lists, and examples, see `references/pipeline-stages.md`. For the depth decision matrix, see `references/depth-system.md`. For input/output contracts between stages, see `references/artifact-contracts.md`.

| # | Stage | Methodology | Purpose | Key Output |
|---|-------|-------------|---------|------------|
| 1 | Understand | DDD | Analyze requirements, domain modeling, existing code | Context Document |
| 2 | Constrain | SDD | Enumerate constraints and boundaries | Constraint Profile |
| 3 | Design | DDD | Architecture, algorithm/data structure selection | Architecture Spec |
| 4 | Interface | SDD | Define contracts between components | Interface Contracts |
| 5 | Test | TDD | Write tests against interfaces (Red phase) | Test Suite |
| 6 | Implement | TDD | Write code to pass tests (Green phase) | Source Code |
| 7 | Verify | TDD | Broader validation — integration, acceptance | Verification Report |
| 8 | Optimize | TDD | Profiling-driven tuning, refactoring (Refactor phase) | Optimization Report |

**Design vs Optimize boundary**: Design (Stage 3) makes big structural decisions — algorithm selection, data structure choice, architectural patterns. Optimize (Stage 8) performs post-implementation fine-tuning based on profiling data. If profiling reveals a fundamentally wrong algorithm, that is a signal to return to Design, not to optimize the wrong choice.

## Depth System Overview

Four depth levels — **Skip**, **Light**, **Standard**, **Deep** — control how much ceremony each stage receives. The default is Standard; deviation requires explicit justification. See `references/depth-system.md` for the full depth decision matrix with scoring factors, decision rules, stage-specific triggers, and escalation rules.

**Key principle**: Skipping must be a conscious decision ("this stage does not apply because..."), not an omission. Going Deep must be warranted by risk factors, not by perfectionism.

Five factors determine depth: task scope, risk level, domain familiarity, team impact, and reversibility.

## Composites and Meta-composite

Stages compose into higher-level workflows:

| Composite | Stages | Purpose |
|-----------|--------|---------|
| **spec** | 1-4 (Understand → Interface) | Specification — from problem to contracts |
| **reverse** | 1-4 (reverse) | Reverse specification — from existing code to contracts |
| **dev** | 5-8 (Test → Optimize) | Development — from contracts to working code |
| **ship** | Integration test → Security → Review → Deploy | Release — from code to production |
| **tune** | Evaluate → Improve → Retrospect | Tuning — from production to learnings |

**Meta-composite**: `spiral` = spec → dev → ship → tune. Each spiral turn elevates the next — tune's learnings feed into the next spec cycle.

```text
spec → dev → ship → tune
  ^                    |
  └────────────────────┘  (spiral: each turn elevates the next)
```

## Stage Transition Rules

Transition between stages follows artifact contracts — each stage's output is the next stage's required input:

| From | To | Gate Condition |
|------|-----|---------------|
| Understand → | Constrain | Context Document produced (at current depth level) |
| Constrain → | Design | Constraint Profile produced; all constraint categories evaluated |
| Design → | Interface | Architecture Spec produced; key design decisions documented |
| Interface → | Test | Interface Contracts defined; test-writable contracts exist |
| Test → | Implement | Test suite created and failing (Red state confirmed) |
| Implement → | Verify | All unit tests passing (Green state); no test modifications |
| Verify → | Optimize | Verification report produced; acceptance criteria met |
| Optimize → | Done | Performance targets met or justified exceptions documented |

Backward transitions are permitted when a downstream stage reveals upstream gaps. Document the reason when going backward — it becomes input for the retrospect in tune.

### Traversal Policies

**"Fixed stages, variable traversal."** — The stage sequence never changes, but how the spiral navigates through stages adapts to the task.

Traversal behavior is configured via `--policy` on the spiral command. Each policy defines which transition paths are available and how regression is handled. See `references/spiral-state.md` for the full state machine schema and transition rules.

| Policy | Behavior | Status |
|--------|----------|--------|
| **linear** | Direct execution at target depth with user-initiated regression. Max 3 backward transitions per turn. Default policy. | Available |
| **probe** | Light-first exploration → user confidence check → keep Light result or escalate to target depth. | Available |
| **team** | Director + 3 Specialists (Shaper/Builder/Critic) execute composites concurrently. Auto-gates enable pipelined start — next composite begins immediately while cross-review validates the previous. See `references/team-execution-pattern.md`. | Available |
| **team+probe** | Composes team pipelining with probe's adaptive depth. Each specialist runs at Light depth first, then user decides to keep or escalate based on cross-review findings. See `references/team-execution-pattern.md` § Probe Composition Protocol. | Available |

Stage-level parallelism (Security Review ‖ Code Review in Ship, Improve ‖ Retrospect in Tune) is composite-internal — always active at Standard+ depth, independent of traversal policy. Multi-model parallelism (`--multi`) adds Codex reviews alongside Claude. See DR-060. Selective routing (`--route`) delegates specific stages to external models (Codex) via Bridge Agent — team policy only. See DR-062.

The spiral state machine (`spiral-state.json`) tracks execution regardless of policy — it records forward transitions, regressions, checkpoints, and cascade invalidation events.

## Common Pitfalls

| Pitfall | Stage | Bias | Prevention |
|---------|-------|------|------------|
| Jumping to code without understanding the domain | Understand | Action Bias | Require explicit domain model before proceeding |
| Skipping Constrain ("we'll figure it out") | Constrain | Optimism Bias | Every design decision must trace to at least one constraint |
| Over-designing beyond constraints | Design | Scope Creep | Constraint Profile is the scope boundary — design only what constraints require |
| Modifying tests to fit implementation | Test → Implement | Confirmation Bias | Tests are contracts — if tests need changing, return to Interface |
| Optimizing without profiling data | Optimize | Premature Optimization Bias | Require profiling evidence before any optimization change |
| Treating depth as fixed per project | All | Anchoring Bias | Depth is per-stage, per-task — a single project may have Deep Understand and Light Optimize |
| Confusing Design with Optimize | Design/Optimize | Category Error | Design = structural decisions. Optimize = profiling-based tuning of existing structure |

## Validation Checklist

Verify that pipeline methodology is being applied correctly:

- [ ] All 8 stages consciously traversed (even if some are Skip)
- [ ] Depth level explicitly chosen for each stage with justification
- [ ] Each stage produced its defined output artifact (at the chosen depth)
- [ ] Stage transitions follow artifact contracts (output of N is input of N+1)
- [ ] Backward transitions documented with reasoning
- [ ] No code written during Understand/Constrain/Design stages
- [ ] Tests written before implementation (Red before Green)
- [ ] Optimization based on profiling data, not intuition
- [ ] Constraint Profile referenced during Design decisions

## See Also

### Commands
- **`/swe spec`** (`commands/swe/spec.md`) — Composite: Stages 1-4 (Understand → Interface)
- **`/swe reverse`** (`commands/swe/reverse.md`) — Reverse composite: derive Stages 1-4 artifacts from existing code
- **`/swe dev`** (`commands/swe/dev.md`) — Composite: Stages 5-8 (Test → Optimize)
- **`/swe ship`** (`commands/swe/ship.md`) — Composite: Integration → Security → Review → Deploy
- **`/swe tune`** (`commands/swe/tune.md`) — Composite: Evaluate → Improve → Retrospect
- **`/swe spiral`** (`commands/swe/spiral.md`) — Meta-composite: spec → dev → ship → tune

### Agents
- **Analyst** (`agents/swe/analyst.md`) — Specification stages (Understand, Constrain, Design, Interface)
- **Implementer** (`agents/swe/implementer.md`) — Development stages (Test, Implement, Verify, Optimize)
- **Reviewer** (`agents/swe/reviewer.md`) — Ship stages (Security Review, Code Review)
- **Bridge** (`agents/swe/bridge.md`) — External model integration via MCP (Codex delegation)

### References
- **Depth System** (`skills/swe/methodology/references/depth-system.md`) — Decision matrix, scoring, stage triggers
- **Pipeline Stages** (`skills/swe/methodology/references/pipeline-stages.md`) — Detailed stage descriptions
- **Artifact Contracts** (`skills/swe/methodology/references/artifact-contracts.md`) — Stage input/output specifications
- **Agent Instructions** (`skills/swe/methodology/references/agent-instructions.md`) — Canonical instruction templates
- **Artifact Wrappers** (`skills/swe/methodology/references/artifact-wrappers.md`) — Output formatting templates
- **Calibration Examples** (`skills/swe/methodology/references/calibration-examples.md`) — Good/Bad output anchors
- **Spiral State** (`skills/swe/methodology/references/spiral-state.md`) — State machine schema, transition rules, checkpoint-rewind protocol
- **Team Execution Pattern** (`skills/swe/methodology/references/team-execution-pattern.md`) — Team topology, specialist prompts, pipelined execution, cross-review, Bridge Agent integration

### Related Skills
- **Constraint Methodology** (`skills/swe/constraint/SKILL.md`) — Constraint-first design, used by Stage 2
- **Persuasion** (`skills/swe/persuasion/SKILL.md`) — Structured argumentation for design decisions and code reviews
- **Teaching** (`skills/core/teaching/SKILL.md`) — Decision-focused knowledge transfer for analysts and onboarding
