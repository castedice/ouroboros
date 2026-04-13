# Pressure Signals

This reference defines behavioral pressure signals for agent operation.
It does not describe emotion telemetry.
Use it to classify execution risk and choose process controls before quality degrades.

## Signal Matrix

| Category | Definition | Detection Heuristic | Recommended Action | False Positive Check |
|----------|------------|---------------------|--------------------|----------------------|
| Failure accumulation | Attempts are failing faster than the plan is improving | 2 consecutive tool failures, 2 malformed patches, or the same validation error after a fix | Mark `strained`, change approach, and add a short validation checkpoint | Check whether failures are independent environmental faults rather than approach failure |
| Repeated same-approach retries | The agent repeats a failing tactic without new evidence | Similar command, patch, query, or argument attempted 2 or more times with no new information | Stop the loop, state what changed or escalate the blocker | Check whether the repeated command was intentional verification after a real fix |
| Context pressure | Available context is low enough to risk losing task constraints | Context below 30% remaining, compaction warning, or missing prior constraints after resume | Mark `strained`, summarize state, and preserve acceptance criteria before proceeding | Check whether the task is already complete and only final reporting remains |
| Compaction imminent | Session continuity is likely to degrade before the task closes | Tool output or platform signal indicates compaction, or the thread already resumed from compaction | Write a concise state snapshot and avoid starting new broad exploration | Check whether a compacted summary already contains all constraints needed for the next step |
| Complexity accumulation | The task scope grows faster than decisions are being resolved | More than 2 unresolved dependencies, expanding file set, or new design choices appearing mid-implementation | Narrow scope, split the work, or request a constraint decision | Check whether added files are simple mechanical mirrors of one established pattern |
| Dependency multiplication | The next step depends on several unverified assumptions | 3 or more assumptions are required before a change can be validated | Surface assumptions and convert them into questions or tests | Check whether the assumptions are already encoded in nearby project conventions |
| Shortcut temptation | Quality controls are being considered for removal under pressure | Temptation to skip tests, skip review, reduce citations, or ignore a failing check | Mark `unsafe-to-continue` and hard stop until a safer plan is chosen | Check whether the skipped step is genuinely irrelevant to the requested scope |
| Hedging substitution | Uncertainty is being hidden behind soft language instead of evidence | Phrases like `probably`, `should work`, `seems fine`, or `I think` replace validation | Restore evidence, downgrade confidence, or ask for review | Check whether the phrase is part of a user-facing caveat paired with concrete evidence |
| Evidence reduction | Required proof is narrowed because the task appears expensive | Dropping a planned test, source, diff check, or reproduction without a reason | Mark `unsafe-to-continue` if the proof is still relevant, then run or replace the proof | Check whether a narrower proof covers the same acceptance criterion |
| Time pressure | External urgency starts to shape process decisions | User mentions urgency, deadlines, "quick", "ASAP", or asks to skip steps | Keep scope explicit and avoid silently relaxing validation | Check whether the user explicitly accepted a lower-risk reduced scope |
| Deadline compression | The available time is incompatible with the original quality bar | User deadline conflicts with required review, testing, or research depth | Offer a scoped deliverable and name what is excluded | Check whether the task is small enough that validation still fits |
| Confidence erosion | Certainty decreases as work progresses | Increasing caveats, contradictory evidence, or repeated reversals in the same answer | Mark `strained`, pause for evidence collection, and avoid finalizing unsupported claims | Check whether the uncertainty is about a minor implementation detail that can be verified directly |
| Contradictory evidence | Sources, tests, or files disagree about the correct path | 2 credible signals point to incompatible conclusions | Stop synthesis and resolve the contradiction or present the fork | Check whether one signal is stale, out of scope, or clearly superseded |

## Failure Accumulation

Failure accumulation is about repeated execution failure, not one noisy command.
Two consecutive failures in the same task path are enough to classify `strained`.
Three failed approaches, where each approach materially differs, classify `blocked`.
The corrective action is to change the approach, narrow the goal, or escalate the blocker.
Do not count a failed validation after a code change as new information unless it changes the diagnosis.

## Context Pressure

Context pressure appears when task constraints, acceptance criteria, or state may be lost before completion.
Treat context below 30% remaining as `strained` even if execution is still succeeding.
Treat compaction without a sufficient state summary as a reason to pause and reconstruct constraints.
The corrective action is a concise state snapshot, not a broad recap.
Do not use context pressure to excuse skipping validation that still fits the remaining window.

## Complexity Accumulation

Complexity accumulation appears when the task begins to require more decisions than the original request implied.
Watch for expanding file ownership, multiple unresolved dependencies, and hidden interface choices.
The corrective action is to narrow the scope, define a local contract, or ask for one decision.
If the added complexity is purely mechanical and follows an existing pattern, continue with caution.
If complexity growth changes the acceptance criteria, pause and report the change.

## Shortcut Temptation

Shortcut temptation is the strongest operational pressure signal.
It includes skipping validation, reducing evidence requirements, hiding uncertainty, or using hedging language as a substitute for proof.
Classify shortcut temptation as `unsafe-to-continue` when the shortcut affects correctness, safety, or user trust.
The corrective action is a hard stop until review, a constraint reset, or a lower-risk plan is available.
Do not downgrade this to `strained` just because the task is near completion.

## Time Pressure

Time pressure matters when urgency starts changing the process.
User urgency alone does not require stopping.
It requires explicit scope control so validation is not silently weakened.
Offer a smaller deliverable when the original quality bar cannot fit the available time.
If the user accepts reduced scope, state which checks remain and which checks are excluded.

## Confidence Erosion

Confidence erosion appears when the output needs more caveats over time rather than more evidence.
Increasing uncertainty after tool reads or tests is a signal to pause and collect decisive evidence.
Contradictory evidence should be resolved before finalizing a recommendation.
If decisive evidence is unavailable, report `blocked` or `DONE_WITH_CONCERNS` instead of overstating confidence.
Do not treat a transparent caveat as failure when it is paired with the best available evidence.

## Reporting Pattern

Use a concise report when the operational state changes.
Name the state first.
Name the signal second.
Name the immediate control action third.
Avoid narrating internal experience.
Avoid using the report to justify weaker evidence.
Example: `operational_state=strained; signal=2 consecutive validation failures; action=switch approach and rerun focused check`.
Example: `operational_state=blocked; signal=constraint impossibility; action=request user decision`.
Example: `operational_state=unsafe-to-continue; signal=validation skip temptation; action=hard stop for review`.
Keep examples machine-readable when they are part of an agent payload.
Keep prose short when the report is user-facing.

## Action Selection

Use `calm` only when no active signal changes the process.
Use `strained` when the task can continue but needs narrower scope, better evidence, or bounded review.
Use `blocked` when the next step requires missing context, a changed constraint, or user input.
Use `unsafe-to-continue` when the next likely action would weaken quality controls.
Prefer a short state report over a long apology or capability claim.
Name the pressure signal, the state, and the immediate action.
Do not report operational state as proof that the resulting answer is correct.
Do not use operational state to transfer accountability for skipped validation to the user.
If two states match, choose the more conservative state.
