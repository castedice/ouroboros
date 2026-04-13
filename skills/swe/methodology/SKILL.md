---
name: swe-pipeline-methodology
description: This skill provides the SWE pipeline methodology knowledge. It should be activated when an agent needs to "follow the 8-stage pipeline", "execute a disciplined engineering workflow", "determine stage depth for a task", "apply DDD+SDD+TDD methodology", "traverse the understand-constrain-design-interface-test-implement-verify-optimize sequence", or "decide how much ceremony a task requires".
summary: Defines the stage-ordered SWE pipeline with variable depth, artifact gates, traversal policies, and explicit regressions.
version: 1
tags: [swe, pipeline, methodology, artifacts, traversal]
preamble_tier: 4
---

# SWE Pipeline Methodology

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

**"Fixed sequence, variable depth."**

Every software task moves through the same cognitive order: Understand, Constrain, Design, Interface, Test, Implement, Verify, and Optimize.
What changes is the ceremony level at each stage, not the stage order itself.
Use DDD to shape understanding and design, SDD to lock boundaries and contracts, and TDD to drive execution and proof.
The value of the pipeline is that every skip is conscious, every transition has an artifact, and every regression is explicit.

## Gotchas

| Pitfall | Stage | Prevention |
|---------|-------|------------|
| Jumping to code before understanding the domain | Understand | Require a concrete problem model before implementation planning |
| Treating depth as one project-wide setting | All | Choose depth per stage, not once for the whole task |
| Skipping Constrain because the team feels aligned | Constrain | Write the constraint profile before design decisions start |
| Designing beyond what constraints require | Design | Keep every major design choice tied to a named constraint |
| Writing code before testable contracts exist | Interface → Test | Lock the contract before test design |
| Editing tests to fit the implementation | Test → Implement | Return to Interface when the contract is wrong instead of mutating the tests to excuse code |
| Letting workspace-write output bypass project formatting rules | Implement | Format the generated files explicitly before concluding because workspace-write does not auto-apply repo lint rules such as ruff line-length |
| Optimizing without profiling evidence | Optimize | Treat profiling as a gate, not a nice-to-have |
| Hiding backward transitions | Any | Document why the pipeline moved backward and what artifact changed |
| Deleting `.swe/active/` before archival completes | Ship → Tune | Archive or preserve active artifacts first because downstream comparison needs the spec and ship outputs |

### Rationalization Red Flags

Treat these as pipeline-integrity anti-drift checks before skipping stages or changing gates.

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "It is a tiny fix, so Understand and Interface can stay implicit" | Jumping to implementation without stage skip reasons or a minimal contract | State the skipped-stage reason and lock the smallest testable contract before editing code |
| "The tests are wrong because the implementation changed" | Mutating tests to excuse a contract-breaking implementation | Regress to Interface, update the contract if needed, then derive tests from the new contract |
| "The optimization is obvious from inspection" | Optimizing before verification or profiling evidence exists | Finish Verify first, collect profiling evidence, and only tune the measured bottleneck |

## Workflow

### 1. Map The Task To Stages And Depth

Select the relevant stages and choose `skip`, `light`, `standard`, or `deep` for each one.
Use the depth system reference when the right ceremony level is unclear or when different stages deserve different effort.

### 2. Run The Stage Chain In Order

Traverse Understand → Constrain → Design → Interface → Test → Implement → Verify → Optimize.
Treat `spec`, `reverse`, `dev`, `ship`, and `tune` as grouped stage bundles, and treat `spiral` as the meta-composite that sequences them.

### 3. Produce The Required Artifact At Each Gate

Each stage hands a specific output to the next stage.
If the next stage cannot start from the current artifact, the current stage is incomplete even when the prose looks polished.

### 4. Apply Traversal Policy Only After The Stage Model Is Clear

Use `linear` for direct execution, `probe` for light-first exploration, `team` for specialist concurrency, and `team+probe` when you need both.
Traversal policy changes how the pipeline moves, not which stages exist.

### 5. Regress Explicitly When Downstream Work Finds An Upstream Gap

Backtracking is valid when a later stage reveals a missing assumption, broken contract, or wrong design choice.
When that happens, record the reason, update the upstream artifact, and continue forward again from the new state.

## Decision Rules

| Decision Point | Rule |
|----------------|------|
| Stage ownership | DDD anchors Understand and Design, SDD anchors Constrain and Interface, and TDD anchors Test through Optimize |
| Skip discipline | `skip` is allowed only when the stage truly does not apply and the reason is stated explicitly |
| Transition gates | Interface must exist before tests, tests must fail before implementation, unit tests must pass before Verify, and profiling evidence must exist before Optimize |
| Design vs Optimize | Design chooses structure and algorithms, while Optimize tunes implemented structure using profiling data |
| Default policy | `linear` is the default traversal policy unless the command or user chooses another |
| Team policy | Use `team` or `team+probe` only when pipelined specialist execution materially helps the task |
| Parallelism | Ship and Tune include composite-internal stage parallelism at Standard depth or above, and `--multi` adds external model review on top |
| Backward transitions | Any downstream discovery that invalidates an upstream artifact requires a documented regression instead of local patching |

## Reference Map

| Need | Reference |
|------|-----------|
| Pipeline stage hub for legacy navigation | `${CLAUDE_SKILL_DIR}/references/pipeline-stages.md` |
| Stages 1-4: Understand, Constrain, Design, and Interface | `${CLAUDE_SKILL_DIR}/references/pipeline-spec-stages.md` |
| Stages 5-8: Test, Implement, Verify, and Optimize | `${CLAUDE_SKILL_DIR}/references/pipeline-dev-stages.md` |
| Reverse analysis for code-first specification recovery | `${CLAUDE_SKILL_DIR}/references/pipeline-reverse-analysis.md` |
| Depth selection, escalation, and fast-mode rules | `${CLAUDE_SKILL_DIR}/references/depth-system.md` |
| Artifact contract hub for legacy navigation | `${CLAUDE_SKILL_DIR}/references/artifact-contracts.md` |
| Artifact chain, storage layout, and summary convention | `${CLAUDE_SKILL_DIR}/references/artifact-storage-layout.md` |
| Per-stage input and output contracts | `${CLAUDE_SKILL_DIR}/references/artifact-stage-contracts.md` |
| Selective loading, gates, regressions, and rejection rules | `${CLAUDE_SKILL_DIR}/references/artifact-transition-rules.md` |
| Canonical delegation prompts by stage | `${CLAUDE_SKILL_DIR}/references/agent-instructions.md` |
| Output wrappers and artifact formatting | `${CLAUDE_SKILL_DIR}/references/artifact-wrappers.md` |
| Good vs bad stage outputs | `${CLAUDE_SKILL_DIR}/references/calibration-examples.md` |
| Spiral state hub for legacy navigation | `${CLAUDE_SKILL_DIR}/references/spiral-state.md` |
| Spiral state schema, statuses, and policy tables | `${CLAUDE_SKILL_DIR}/references/spiral-state-schema.md` |
| Spiral checkpoints, invalidation, lifecycle, and script interface | `${CLAUDE_SKILL_DIR}/references/spiral-state-patterns.md` |
| Team execution hub for legacy navigation | `${CLAUDE_SKILL_DIR}/references/team-execution-pattern.md` |
| Team specialists, prompts, stage execution, and probe | `${CLAUDE_SKILL_DIR}/references/team-specialists.md` |
| Team routing, direct relay, and shared team mechanics | `${CLAUDE_SKILL_DIR}/references/team-routing-and-direct-relay.md` |
| Team flow, auto-gates, cross-review, and recovery | `${CLAUDE_SKILL_DIR}/references/team-flow-and-cross-review.md` |
| External review prompt contracts | `${CLAUDE_SKILL_DIR}/references/swe-relay-prompts.md` |

## See Also

- `commands/swe/spec.md`, `commands/swe/reverse.md`, `commands/swe/dev.md`, `commands/swe/ship.md`, `commands/swe/tune.md`, and `commands/swe/spiral.md` — Primary command consumers of this methodology.
- `agents/swe/analyst.md`, `agents/swe/implementer.md`, and `agents/swe/reviewer.md` — Stage-specific execution agents.
- `skills/swe/constraint/SKILL.md` — Constraint-first discipline used at Stage 2.
- `skills/swe/persuasion/SKILL.md` — Structured argumentation for reviews, ADRs, and design defense.
