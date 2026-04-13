---
name: dual-model-collaboration
description: This skill codifies controller-executor collaboration for non-trivial tasks, and it should be activated when an agent needs to delegate implementation to another model, choose a delegation level, enforce ownership handoff, run bounded review, or fall back safely when the executor is unavailable.
summary: Defines controller-executor delegation, ownership handoff, autonomous execution, bounded review, and fallback discipline for non-trivial work.
version: 1
tags: [core, collaboration, delegation, multi-model, review]
preamble_tier: 4
---

# Dual-Model Collaboration

## Core Rule

If you are running as a subagent dispatched by a command, skip loading this skill.
Commands already embed the relevant methodology inline.

The controller defines direction, boundaries, invariants, and acceptance criteria.
The executor owns the delegated slice after handoff.
Delegate goals, constraints, boundaries, and verbatim invariants, not preferred implementations.
Verbatim invariants include user-stated API names, schemas, file paths, interfaces, and explicit preferences.
The user is the final arbiter only for genuine ambiguity or unresolved bounded disagreement.
Use this skill after routing has decided whether an executor model is involved.
Use a single model when delegation overhead is higher than the capability gain.
The controller reviews for contract conformance rather than for stylistic similarity to its own plan.
The executor should make local implementation decisions without waiting for approval on routine steps.

## Gotchas

Over-specifying anchors the executor to the controller's implementation bias.
Shadow ownership happens when the controller starts re-implementing after delegation.
Mid-flight steering creates oscillation because ownership changes without a new contract.
Endless review loops turn review into co-implementation and waste both models' strengths.
Spot-checking review lets defects pass in uninspected files.
Mechanical-only review checks form without checking meaning.
Reviewer fixing directly bypasses implementer ownership and weakens the review loop.
Transcript dumping shifts synthesis work to the user instead of compressing the audit.
Paraphrasing invariants can silently change user requirements.
Premature escalation treats the user as a routing shortcut instead of the final arbiter for real ambiguity only.
Running a composite skill as the controller and then handing the same slice to the executor creates shadow ownership because the controller already committed to local implementation choices.

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "I know the clean implementation, so I will include it in the contract" | Encoding controller solution details as executor requirements | Strip the handoff down to goal, boundaries, invariants, constraints, acceptance, and escalation conditions |
| "The executor is slow, so I will patch the same slice locally" | Re-implementing delegated work in parallel | Wait for the executor, cancel and redelegate, or formally take ownership back before editing |
| "This comment is minor, so I can fix it during review" | Editing the executor-owned slice instead of returning a contract issue | Send the issue back with evidence and let the executor revise or justify the choice |
| "The user should decide because the models disagree" | Escalating an unresolved model preference before bounded review | Run up to two contract-grounded issue-and-response rounds, then escalate only the remaining ambiguity |
| "The transcript proves we were thorough" | Dumping raw inter-model discussion into the user response | Compress the audit into resolved themes, remaining risk, and the exact decision surface |

## Workflow

Use this five-step workflow for non-trivial delegated work.

### 1. Detect Capabilities And Choose Delegation Level

Compare controller and executor strengths before delegating.
Consider reasoning quality, implementation quality, tool access, speed, context pressure, and failure cost.
Delegate only when the executor can materially improve quality, speed, or parallelism on a bounded slice.
Choose single-model execution if the work is too small or the ownership boundary is blurry.

Use `off` for single-model execution.
Use `balanced` when the controller should keep architectural direction and the executor should own implementation.
Use `heavy` when the executor should contribute detailed planning as well as execution.
Use `auto` as the default, and let capability detection choose `off`, `balanced`, or `heavy`.

### 2. Plan Independently Then Merge

Keep controller thinking separate from executor implementation ideas until a level is chosen.
Independent planning reduces anchoring and preserves a real review perspective.
If an executor planning thread already exists, get executor agreement before presenting the merged plan to the user.
If no executor planning thread exists yet, start one instead of forcing resume into a nonexistent planning context.
Merge only the shared contract needed for execution.
The merged plan should define scope, interfaces, invariants, constraints, acceptance, and escalation conditions.
Do not merge solution sketches unless the user explicitly required them.
Show the user only genuine ambiguity after both models agree or record a bounded disagreement with reasoning.

### 3. Delegate With A Contract

Every delegated slice needs a compact contract.
The contract must include the goal, scope boundaries, verbatim invariants, constraints, acceptance criteria, and escalation conditions.
Pass invariants verbatim rather than summarizing them.
Keep the handoff outcome-shaped rather than implementation-shaped.
Once the contract is issued, ownership transfers to the executor.

### 4. Execute Autonomously

The executor owns local sequencing and implementation choices inside the contract.
The executor should escalate only for blockers, invalid assumptions, or conflicts with verbatim invariants.
The controller must not re-implement the slice in parallel.
The controller must not steer the executor mid-flight.
If assumptions change materially, stop, restate the contract, and redelegate cleanly.

### 5. Review With Bounded Disagreement, Then Resolve Or Escalate

Review against the contract rather than against an unstated preferred solution.
Inspect every changed file in the delegated slice and check content, semantics, structure, and cross-reference integrity rather than relying on mechanical counts.
Return issues to the implementer with reasoning instead of fixing the slice directly during review.
The controller should raise issues with evidence, reasoning, and a concrete requirement violation.
The executor may revise or push back with contract-grounded reasoning.
Bound disagreement to two rounds of issue-and-response for unresolved items.
Use the bounded deliberation shape from `../routing/references/consensus-protocol.md` rather than inventing a new review loop.

Resolve locally when one side shows clear contract conformance.
Escalate when disagreement survives two coherent rounds.
Escalate when the contract itself is ambiguous or two valid user priorities conflict.
Present the smallest possible decision surface to the user.
Compress the audit to resolved themes, remaining risk, and the exact question that needs arbitration.

## Decision Rules

Choose `off` when the task is trivial, reversible, or already within the controller's strongest capability.
Choose `balanced` when architecture and review should stay with the controller but implementation should move.
Choose `heavy` when the executor has materially better implementation context or tool leverage.
Choose the simplest topology that fits the task: single-model if the work is small, pipeline for sequential stages, fan-out for independent parallel slices, and expert pool for capability-based routing.
Use resumed sessions for planning and review discussion when context continuity matters.
Prefer fresh sessions with the correct write scope for implementation delegation.
Allow role reversal when the controller has stronger implementation context or the change is very small, but keep the same review discipline.
Default to hybrid delegation for portable methodology skills: Claude owns contract and review, and the executor uses shared portable skills during execution.
Fall back to relay-only for controller-specific skills such as routing, external-models, and validation.
Stay direction-only unless the user explicitly mandates a solution detail.
Treat API names, schemas, interfaces, explicit preferences, and repository conventions as verbatim invariants.
If the contract changes materially, cancel and redelegate instead of steering incrementally.
If the controller cannot state clear acceptance criteria, do not delegate yet.
If the executor cannot explain a blocker in contract terms, keep working rather than escalating reflexively.
If the executor is unavailable, implement, then add self-critique plus adversarial self-review before concluding.
Lower the escalation threshold in fallback mode because no independent executor challenged the result.
Never dump full inter-model transcripts to the user unless the user explicitly asks for them.
Never ask the user to choose between two model preferences when repository evidence can settle the issue.

## Reference Map

Read [`references/collaboration-protocol.md`](${CLAUDE_SKILL_DIR}/references/collaboration-protocol.md) for the full protocol, compact delegation contract, fallback rules, and escalation format.
Read [`references/coordination-patterns.md`](${CLAUDE_SKILL_DIR}/references/coordination-patterns.md) for multi-agent topology selection.
Read [`../routing/SKILL.md`](../routing/SKILL.md) when you still need to choose whether another model should be involved.
Read [`../routing/references/consensus-protocol.md`](../routing/references/consensus-protocol.md) for the generic bounded disagreement pattern that review should mirror.
Read [`../evaluation/SKILL.md`](../evaluation/SKILL.md) when the collaboration result itself must be scored or compared under a rubric.
Read [`../routing/references/invocation-protocol.md`](../routing/references/invocation-protocol.md) when the collaboration plan also needs relay assembly details.

## See Also

Common consumers that invoke this skill for delegation and review:

- **evolve command** (`commands/core/evolve.md`) — Uses `--multi` parallel evaluation and researcher fan-out with delegation contracts
- **evaluate command** (`commands/core/evaluate.md`) — Multi-model consensus evaluation requires bounded review discipline
- **swe spiral command** (`commands/swe/spiral.md`) — Team execution routes specialist work through delegation levels
- **routing skill** (`skills/core/routing/SKILL.md`) — Decides whether an executor is involved; this skill governs what happens after that decision
- **evaluation skill** (`skills/core/evaluation/SKILL.md`) — Supplies scoring for collaboration results

This skill governs post-routing collaboration rather than model selection.
Use it for controller-executor handoff discipline on non-trivial delegated work.
Extension points: future `${CLAUDE_SKILL_DIR}/learned.md` can capture delegation patterns observed during sessions.
