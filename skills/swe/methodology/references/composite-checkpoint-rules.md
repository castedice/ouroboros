# Composite Checkpoint Rules

This reference documents when SWE composites skip intermediate user checkpoints.
It captures the shared pattern used by `spec`, `dev`, `ship`, `tune`, and `spiral`.
Use this file when you need to know whether a pause is an approval gate or only a status report.

## Core Pattern

Composite commands collapse multiple internal stages behind one meaningful review checkpoint.
They do this to avoid asking the user to approve every intermediate artifact in sequence.
The composite owns stage-to-stage flow once the depth plan is accepted.
The user still sees summaries and blockers, but not every primitive review screen.

## Why The Pattern Exists

Stage artifacts depend on each other too tightly for repeated approval loops to add much value.
Repeated stage-level pauses would multiply friction without improving the contract chain.
A composite-level checkpoint lets the user review the whole bundle with downstream context present.
The pattern also prevents the same artifact from being reviewed once by the primitive and again by the composite.

## Primitive Rule Under Spec

`/swe understand` skips its Phase 5 review when invoked by `/swe spec`.
`/swe constrain` skips its Phase 5 review when invoked by `/swe spec`.
`/swe design` skips its Phase 5 review when invoked by `/swe spec`.
`/swe interface` skips its Phase 5 review when invoked by `/swe spec`.
Each primitive still writes its artifact before the composite moves on.
The composite then performs one consolidated review at Spec Phase 7.

## Primitive Rule Under Dev

`/swe test` skips its Phase 5 review when invoked by `/swe dev`.
`/swe implement` skips its Phase 5 review when invoked by `/swe dev`.
`/swe verify` skips its Phase 5 review when invoked by `/swe dev`.
`/swe optimize` skips its Phase 5 review when invoked by `/swe dev`.
Each primitive still logs warnings, failures, and partial states.
The composite then performs one consolidated review at Dev Phase 7.

## Spec Composite Rule

`/swe spec` asks for confirmation at the depth-plan stage before execution starts.
After that point, Understand, Constrain, Design, and Interface run without separate user approvals.
Spec explicitly states that the user checkpoint occurs once at Phase 7.
Spec Phase 7 presents the complete artifact chain instead of stage-local slices.
Spec keeps decision points only for real exceptions such as degraded Constrain failure handling.

## Dev Composite Rule

`/swe dev` asks for confirmation at the depth-plan stage before execution starts.
After that point, Test, Implement, Verify, and Optimize run without separate review pauses.
Dev explicitly states that the user checkpoint occurs once at Phase 7.
Dev still surfaces partial implementation and FAIL verdict warnings during execution.
Dev only interrupts early when a recovery branch genuinely needs a choice, such as continuing after partial implementation.

## Ship Composite Rule

`/swe ship` asks for confirmation at the depth-plan stage before execution starts.
Integration, Security Review, Code Review, and Deploy Readiness then run without stage-local approval pauses.
Ship explicitly states that the user checkpoint occurs at Phase 6.
The review screen bundles test results, security findings, code-review findings, and ship status.
Deploy execution is the separate hard checkpoint that still requires explicit approval.

## Tune Composite Rule

`/swe tune` asks for confirmation at the depth-plan stage before execution starts.
Evaluate, Improve, and Retrospect then run without separate stage-level review pauses.
Tune explicitly states that the user checkpoint occurs at Phase 6.
The review screen bundles evaluation, applied improvements, retrospect findings, and feedback synthesis.
Tune may still skip Improve automatically when the evaluation is clean or depth is Light.

## Spiral Rule

`/swe spiral` is different because it orchestrates composites rather than primitive stages.
It confirms the composite depth plan before state initialization.
After that, the default rule is to auto-proceed across composite transitions.
Spiral transition checkpoints are verification gates, not approval checkpoints.
The transition summary is shown to the user, but the command proceeds automatically unless the user asks to pause.

## Transition Checkpoint Versus Review Checkpoint

A transition checkpoint verifies artifacts and state before the next composite starts.
A review checkpoint asks the user to approve, redirect, or inspect results.
Spiral Phases 4, 6, and 8 are transition checkpoints.
Spec, Dev, Ship, and Tune final review phases are review checkpoints.
Confusing these two checkpoint types leads to duplicate pauses and broken flow expectations.

## Transition Gate Content

The gate updates the relevant state key to `running`.
The gate verifies prerequisite artifacts in `.swe/active/`.
The gate checks one critical condition such as Interface Contracts existence, Green state, or P1 findings.
The gate updates the state key to `completed` when the check passes.
The gate presents a compact transition summary.
The gate then proceeds automatically unless the user asks to pause.

## Team Policy Modification

Under `--policy team`, Spiral Phases 4 and 6 become auto-gates.
No user approval is requested at those gates.
The next composite assignment and the current composite cross-review are launched immediately.
The user still receives the current specialist review content as a relay.
The system only interrupts when cross-review severity or regression decisions demand it.

## Probe Policy Modification

Probe policy inserts a real checkpoint after the Light-depth probe run.
That checkpoint is not an intermediate artifact review in the old sense.
It is a keep-versus-escalate decision based on the probe result.
If the user keeps the Light result, flow resumes without extra internal stage approvals.
If the user escalates, the composite reruns at the target depth from the preserved checkpoint.

## Hard Checkpoints That Remain

Depth-plan confirmation remains a real checkpoint in every composite command.
Degraded-mode choices remain real checkpoints when the command cannot decide safely on its own.
Partial implementation continuation remains a real checkpoint inside Dev.
P1 blockers remain real checkpoints inside Ship and Spiral.
Deploy execution remains a real checkpoint inside Ship.
Regression restore remains a real checkpoint inside Spiral.
Resume-versus-restart remains a real checkpoint when Spiral detects existing state.

## Soft Checkpoints That Are Skipped

Primitive artifact review is skipped when the primitive is running under its parent composite.
Composite-to-composite handoff review is skipped in Spiral unless a blocker appears.
Normal stage completion notices are informational and do not wait for approval.
Successful transition summaries in Spiral are informational and do not wait for approval.
Passing internal reviews in Ship and Tune do not pause before final synthesis.

## Failure And Blocker Exceptions

A missing required artifact breaks the skip pattern because execution cannot continue safely.
A failed build or missing test suite can abort before the final review screen appears.
Critical acceptance-criteria failure in Dev may request user direction before Optimize.
P1 findings in Ship block Deploy Readiness even though earlier review pauses were skipped.
P1 findings in Spiral Phase 8 create an explicit choice instead of silent continuation.

## What The User Still Gets

The user still gets the depth plan before execution.
The user still gets warnings, degraded-mode notices, and blocker summaries during execution.
The user still gets a consolidated artifact review after the composite finishes.
The user still gets next-step commands and restart points in the final report.
Skipping a checkpoint never means hiding artifacts or suppressing failures.

## What The Command Avoids

The command avoids asking for approval after every primitive artifact write.
The command avoids re-reviewing the same artifact once in the primitive and again in the composite.
The command avoids pausing between successful Spiral transitions.
The command avoids letting approvals fragment the contract chain before downstream context exists.

## Design Invariants

There should be one normal review checkpoint per composite execution.
There should not be both a primitive checkpoint and a composite checkpoint for the same artifact flow.
Transition verification may be automatic when the next move is structurally obvious.
Safety-critical actions still need explicit approval even inside a composite.
User choice is reserved for ambiguity, blockers, escalations, and irreversible actions.

## Command Map

Spec keeps its main review at Phase 7.
Dev keeps its main review at Phase 7.
Ship keeps its main review at Phase 6.
Tune keeps its main review at Phase 6.
Spiral keeps transition summaries at Phases 4, 6, and 8 and its full review at Phase 10.

## Practical Reading Rule

If a phase says "user checkpoint occurs once" for the composite, intermediate stages should not stop for review.
If a phase says "proceed automatically unless user requests a pause," treat the screen as a transition summary.
If a phase presents options with named branches, treat it as a real checkpoint.
If the action changes production state, restores checkpoints, or overrides blockers, explicit approval is mandatory.

## Related References

Use `depth-procedure.md` when the skipped checkpoint is the result of already-confirmed depth planning.
Use `artifact-resolution.md` when you need to see how skipped checkpoints still pass artifacts forward safely.
Use `spiral-state-patterns.md` when a checkpoint becomes a regression or restore operation rather than a forward handoff.
