---
name: feedback-learning-protocol
description: This reference defines the end-to-end PA feedback loop from proposal-producing commands through ledger analysis, survey approval, and downstream behavior changes.
---

# Feedback Learning Protocol — Cross-Command Behavioral Adaptation Loop

> Purpose: Reference for `personal-profiling` that complements `feedback-learning.md`.
> Scope: Explain how `draft`, `capture`, `day`, and `link` turn user reactions into approved learned preferences and context profiles.

## What This Reference Adds

`feedback-learning.md` already defines thresholds, preference kinds, and lifecycle statuses.
This reference adds the operational loop that connects producer commands, the assistant ledger, the analysis script, `survey`, and downstream command behavior.
This reference also makes the boundary clear between behavioral learning and personal-profile enrichment.

## Core Rule

PA learns from explicit reactions to concrete proposals, not from silence, convenience, or speculative inference.
The loop stays proposal-first at every stage because behavior changes affect future autonomy.

## Producer Commands

`draft` records feedback only when Phase 7 ended as `proposed`.
`capture` records feedback when the note outcome or the decision-entity proposal stayed proposal-only.
`day` records feedback when morning or evening produced a daily-note write proposal.
`link` records feedback when it presented a suggestion set rather than a read-only relationship map.
These commands are the canonical behavioral feedback producers in the current PA flow.

## Step 1 — Produce A Concrete Proposal

The loop starts only after a command presents an exact note body, exact bounded patch, exact daily-note append, or exact link suggestion set.
The proposal must already have a `run_id`-scoped ledger entry that records the parent action.
Feedback is meaningful only when the user is reacting to a concrete candidate action.
This is why read-only answers without a mutation proposal do not enter the feedback branch.

## Step 2 — Record Explicit User Reaction

The feedback entry reuses the original `run_id` from the proposal-producing invocation.
The follow-up entry uses `action: "feedback"`.
The normalized `user_feedback` value is `accepted`, `rejected`, or `modified`.
Optional `feedback_tags` make the reaction more useful for later analysis.
The allowed tag examples in the ledger contract are `too-many`, `not-now`, `wrong-target`, `too-broad`, and `helpful`.
If the conversation ends without a response, nothing is appended because absence is neutral.
Unattended runs skip this step entirely.

## Step 3 — Preserve Command Context

The proposal-side ledger entry keeps the command name, posture, status, target paths, and rationale tied to the same `run_id`.
This lets later analysis ask not only whether the user reacted positively, but also what kind of thing PA proposed.
`draft`, `capture`, and `day` can also contribute context telemetry through `state_files_loaded`, `state_files_used`, and `estimated_context_chars`.
That telemetry becomes the raw material for context-profile learning rather than preference learning.

## Step 4 — Group Events By `run_id`

`scripts/pa-feedback-analysis.sh` groups ledger events by `run_id`.
The script keeps the non-feedback events for the run as the parent action context.
The script pairs them with the latest valid `feedback` entry for that same run.
Runs with no valid feedback stay analyzable for proposal counts, but they do not become behavioral evidence.
This grouping step prevents cross-run contamination when several PA commands happen in one session.

## Step 5 — Generate Behavioral Candidates

The `preferences` action in `scripts/pa-feedback-analysis.sh` reads grouped feedback runs and looks for stable acceptance or rejection patterns.
The script does nothing until the ledger contains at least 30 usable feedback runs.
Per-command patterns still need enough local evidence rather than piggybacking on global volume alone.
The generated output lives in `.pa/preferences-learned.json`.
Newly generated rules always start as `status: "proposed"`.
They are candidates for behavior change, not active settings.

## Step 6 — Generate Context-Budget Candidates

The `context --generate` action in `scripts/pa-feedback-analysis.sh` reads context telemetry from the ledger.
This branch starts when there are at least 20 command runs with context telemetry.
The output lives in `.pa/context-profiles.json`.
These generated profiles propose which optional files each command should usually load or skip.
Context-profile generation is part of feedback learning because it uses observed command behavior to tune future context budgets conservatively.

## Step 7 — Surface One Proposal In `survey`

`survey` is the approval checkpoint for learned preferences and generated context profiles.
Phase 5.6 handles preference proposals from `.pa/preferences-learned.json`.
Phase 5.7 handles context-profile proposals from `.pa/context-profiles.json`.
`survey` presents only one preference proposal per run to match the same low-interruption rhythm used by profile enrichment.
This keeps behavioral adaptation legible instead of turning `survey` into a batch approval screen.

## Step 8 — Approve Or Reject

If the user accepts a learned preference, `survey` updates it to `status: "approved"` and adds `approved_at`.
If the user rejects it, `survey` updates it to `status: "reverted"` and adds `reverted_at`.
Context-profile proposals follow the same approval pattern.
`survey` also logs the proposal outcome to `.pa/proposals.jsonl` with `kind: "learned-preference"` for preferences.
Only approved outputs affect later command behavior.

## Step 9 — Apply In Producer Commands

`draft` reads approved rules from `.pa/preferences-learned.json` during Phase 2 and applies them during scribe shaping or final write decisions.
`link` reads approved `frequency` preferences during Phase 2 and caps suggestion volume accordingly.
`day` reads approved `day` preferences during Phase 2 and uses them for brevity or aggressiveness adjustments.
`agenda` also consumes approved preferences even though it is not one of the main feedback producers in this extraction batch.
Commands that support context budgets consult approved context profiles before loading optional enrichment files.
No command should read `status: "proposed"` rules as active behavior.

## Command-Specific Feedback Semantics

`draft` feedback evaluates one intentional note proposal or one bounded patch proposal.
`capture` feedback evaluates either a note proposal or a decision-entity proposal, so the command must keep those proposal types distinct.
`day` feedback evaluates a daily-note mutation proposal rather than the whole conversational briefing.
`link` feedback evaluates the suggestion set as a whole, and partial acceptance should map to `modified`.
This means the same `accepted` or `rejected` label has slightly different semantics across commands, which is why the command name must stay attached in the ledger.

## Boundary With Personal-Profile Enrichment

Feedback learning does not write `.pa/personal-profile.json` directly.
Personal-profile enrichment follows `enrichment-rules.md`, memory signals, specialist patterns, and `survey` catch-up interviews.
Behavioral learning instead enriches `.pa/preferences-learned.json` and `.pa/context-profiles.json`.
Both branches live under `personal-profiling`, but they tune different parts of the PA system.
One branch updates what PA believes about the user.
The other branch updates how PA should usually behave while serving the user.

## Boundary With Memory Signals

Memory observations can nominate future enrichment questions, but they do not replace explicit feedback on proposals.
A `preference` memory signal may support a later behavioral proposal, but it is weaker than direct proposal acceptance or rejection.
A `direction-shift` memory signal belongs in the personal-profile catch-up branch, not the ledger-feedback branch.
This separation keeps action feedback from being mistaken for identity evidence.

## Neutral And Negative Cases

No response produces no feedback entry.
One noisy rejection does not generate a learned rule by itself.
Rejected learned preferences do not update live behavior.
Declined profile enrichments do not count as ledger feedback because they are stored in `.pa/proposals.jsonl`, not as `feedback` ledger entries.
Commands should not infer dissatisfaction from the absence of follow-through.

## Why The Loop Uses `survey`

`survey` already owns the user-facing checkpoint for profile refresh and assistant-state calibration.
Placing learned-preference approval there keeps behavior changes inside an explicit maintenance moment.
This prevents commands like `draft` or `link` from auto-tuning themselves in the middle of ordinary work.
It also keeps learned behavior inspectable in stable `.pa/` files rather than as hidden in-session state.

## Validation Checklist

- [ ] The producer command wrote a proposal-side ledger entry before waiting for user feedback.
- [ ] The feedback entry reused the same `run_id` as the parent proposal.
- [ ] `user_feedback` was normalized to `accepted`, `rejected`, or `modified`.
- [ ] Missing responses were treated as neutral rather than negative evidence.
- [ ] Preference generation waited for at least 30 usable feedback runs.
- [ ] Context-profile generation waited for at least 20 runs with context telemetry.
- [ ] `survey` surfaced proposed rules before they became active.
- [ ] Only `status: "approved"` preferences or context profiles changed future command behavior.
- [ ] Personal-profile enrichment stayed separate from ledger-based behavior tuning.

## See Also

- `references/feedback-learning.md` — Thresholds, preference kinds, lifecycle statuses, and anti-patterns.
- `skills/pa/trust-and-boundaries/references/ledger-schema.md` — Feedback entry schema and allowed tags.
- `commands/pa/survey.md` — Approval checkpoint for learned preferences and context profiles.
- `references/enrichment-rules.md` — Separate proposal-only path for `personal-profile.json` updates.
