# Dual-Model Collaboration Protocol

This reference defines the normative protocol for controller-executor collaboration on non-trivial tasks.
It governs delegation, autonomy, review bounds, and escalation after routing has already decided whether an executor model is involved.

## Scope

Use this protocol when a task benefits from separating direction from execution.
Use a single model instead when the task is trivial, low-risk, or too small to justify handoff overhead.
Treat this protocol as complementary to routing rather than a replacement for routing.
Routing selects whether and how to involve another model, and collaboration governs behavior after that choice.

## Role Model

The controller sets goals, constraints, boundaries, acceptance criteria, and review bar.
The executor owns the delegated slice after handoff and chooses implementation details within the contract.
The user is the final arbiter only for genuine ambiguity, unresolved bounded disagreement, or priority trade-offs that cannot be inferred from context.
The controller must not use the user as a convenience tiebreaker for issues it can review directly.
The executor must not redirect already-specified requirements back to the user.
Both models must preserve user-stated invariants verbatim.

## Default Ownership And Role Reversal

Default ownership is executor implements and controller reviews.
Role reversal is allowed when the controller has stronger implementation context or the change is small and bounded.
In role reversal, the controller implements and the executor reviews.
The same review discipline applies regardless of which side implemented the change.

## Core Invariants

Direction-only delegation is the default handoff mode.
Direction-only means the controller passes goals, constraints, boundaries, and required invariants without prescribing a preferred implementation.
Required invariants include API names, schemas, file paths, wire formats, interface contracts, explicit user preferences, and any other non-negotiable constraints.
Pass required invariants verbatim rather than paraphrasing them.
Ownership transfers with the delegation contract.
After ownership transfers, the executor owns the delegated slice until completion, blocker escalation, or contract invalidation.
Review is bounded rather than open-ended.
Audit output is compressed rather than transcript-shaped.

## Delegation Levels

`off` means single-model execution with no executor handoff.
Use `off` when the task is small, the controller already has the needed capability, or the cost of coordination exceeds the benefit.
`balanced` means the controller plans independently and delegates execution against a merged contract.
Use `balanced` when the controller should retain architectural direction but the executor is stronger at implementation or mechanical throughput.
`heavy` means the executor may contribute detailed planning in addition to execution.
Use `heavy` when the executor has materially better domain knowledge, tool reach, or implementation context for the delegated slice.
`auto` means detect capabilities, constraints, and availability first, then choose `off`, `balanced`, or `heavy`.
`auto` is the default unless the user or command surface explicitly fixes another level.

## Workflow

Use this five-step workflow whenever delegation is chosen.

### Step 1: Detect Capabilities And Choose A Level

Compare controller and executor strengths before delegating.
Consider reasoning quality, code synthesis quality, tool access, speed, context window pressure, failure cost, and review confidence.
Delegate only when the executor can materially improve quality, latency, or parallelism on a bounded slice.
Prefer `balanced` when the controller understands the shape of the work but should not micromanage implementation.
Prefer `heavy` when the executor is better placed to determine the detailed implementation plan.
Fall back to `off` when ownership boundaries would be blurry or the executor is unavailable.

#### Session Strategy: Resume vs Fresh

Use session resume for planning agreement and review discussion when context continuity matters.
Prefer fresh sessions with the correct write scope for implementation delegation so the executor has autonomy inside the right boundary.
Exact session invocation mechanics belong in the invocation reference rather than in this protocol.

### Step 2: Plan Independently Then Merge

Independent planning exists to reduce anchoring.
The controller should form its own view of the task before seeing the executor's implementation ideas when `balanced` or `heavy` is in play.
The executor may also form an independent plan when the chosen level permits it.
If an executor planning thread already exists for the same planning context, the controller must get executor agreement before presenting a merged plan to the user.
If no executor planning thread exists yet, start one rather than forcing resume into a nonexistent planning context.
Merge only the minimum shared contract needed for execution.
The merged plan should define scope, interfaces, invariants, constraints, acceptance, and escalation conditions.
The merged plan should avoid solution sketches unless the user explicitly required them.
Present the merged plan to the user only after both models agree or explicitly disagree with documented reasoning.
The user should only see genuinely ambiguous decisions.

### Step 3: Delegate With A Contract

Every delegated slice needs a contract even when the handoff is compact.
The contract must define the goal in outcome terms rather than implementation terms.
The contract must define scope boundaries so the executor knows what it owns and what it does not own.
The contract must include verbatim invariants that cannot drift during execution.
The contract must include acceptance criteria that allow the controller to review against objective requirements.
The contract must include escalation conditions for blockers, ambiguity, or invalid assumptions.

### Compact Delegation Contract

```text
Goal:
Scope:
Out of Scope:
Verbatim Invariants:
Constraints:
Acceptance Criteria:
Inputs And Interfaces:
Expected Deliverable:
Escalate If:
```

### Step 4: Execute Autonomously

Once delegated, the executor owns the slice end-to-end within the contract.
The executor may refine local sequencing, implementation details, and intermediate checks without asking for approval on each step.
The executor should ask for guidance only when blocked by missing information, invalid assumptions, or a conflict with verbatim invariants.
The controller must not re-implement the delegated slice in parallel.
The controller must not inject mid-flight design nudges that change local implementation direction without restarting the contract.
If assumptions change materially, stop the slice, restate the contract, and redelegate rather than steering incrementally.

### Step 5: Review With Bounded Disagreement, Then Resolve Or Escalate

Review is a check against the contract, not a second implementation pass.
The controller must inspect every changed file in the delegated slice rather than spot-checking a sample.
Review must cover content accuracy, semantic loss, structural consistency, and cross-reference integrity.
Mechanical-only verification such as line counts or section counts is insufficient on its own.
The reviewer owns issue identification and acceptance judgment rather than patch authorship.
The reviewer must not fix the delegated slice directly and should always return issues to the implementer with reasoning.
The controller should identify issues with evidence, reasoning, and a concrete requirement violation.
The executor may agree and revise, or push back with reasoning grounded in the contract or repository evidence.
A review round is one issue set plus one executor response.
Limit review to two rounds for any unresolved disagreement.
Use the bounded deliberation shape from `skills/core/routing/references/consensus-protocol.md` as the pattern for issue-response exchange, but apply it to implementation findings rather than rubric scores.

Resolve locally when one side clearly demonstrates conformance to the contract.
Resolve locally when disagreement was caused by missing evidence, overlooked invariants, or a straightforward factual correction.
Escalate when the dispute survives two rounds with coherent reasoning on both sides.
Escalate when the contract itself is ambiguous or incomplete.
Escalate when user priorities conflict and the repository does not provide a defensible tiebreaker.
Escalation should present the smallest possible decision surface to the user.

## Protocol Violations

Over-specifying is a violation because it anchors the executor to the controller's preferred implementation.
Shadow ownership is a violation because the controller silently retakes a delegated slice instead of reviewing it.
Mid-flight steering is a violation because it creates oscillation without clean ownership.
Endless review loops are a violation because they convert review into unbounded co-implementation.
Transcript dumping is a violation because it shifts the processing burden to the user.
Premature user escalation is a violation when the models could have resolved the issue from the contract or repository context.
Spot-checking is a violation because partial inspection lets defects pass unreviewed.
Mechanical-only verification is a violation because it checks form without checking content.
Reviewer fixing directly is a violation because it bypasses implementer ownership and the review loop.

## Fallback When The Executor Is Unavailable

If the executor is unavailable, the controller may continue in single-model mode.
Single-model fallback must simulate separation by adding an explicit self-critique pass after implementation.
Use adversarial self-review by asking what a skeptical executor would contest, what invariants may have drifted, and what evidence is missing.
Lower the escalation threshold because no independent executor review occurred.
Be more willing to surface residual uncertainty to the user when confidence depends on missing external validation.
Do not pretend that fallback delivered the same assurance level as dual-model execution.

## Audit Compression

Report the chosen delegation level.
Report the delegated slice in one compact summary.
Report only the resolved review themes rather than every review exchange.
Report unresolved items only if they materially affect correctness, risk, or user choice.
Do not paste full model-to-model transcripts into the user-facing output.
Preserve full internal reasoning only when a command or artifact explicitly requires it for later machine use.

## Escalation Format

Escalations must be short and decision-shaped.
State the exact ambiguity or disagreement in one sentence.
State each side's best reasoning in one sentence.
State the concrete decision the user must make.
State the default if the user does not choose.
Avoid forwarding raw back-and-forth unless the user explicitly asks for the transcript.

## Reference Boundaries

Use `skills/core/routing/SKILL.md` for model selection, relay mechanics, and cost-aware routing defaults.
Use `skills/core/routing/references/consensus-protocol.md` for the generic bounded disagreement pattern that review should mirror.
Use this reference for controller-executor ownership, delegation contracts, autonomy rules, and escalation boundaries.
Do not duplicate routing tables, CLI invocation details, or consensus scoring formats here.
Exact CLI session syntax, including resume flags and sandbox overrides, belongs in the invocation reference rather than here.
