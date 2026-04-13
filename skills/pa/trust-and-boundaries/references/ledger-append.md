---
name: ledger-append
description: This reference defines the shared assistant-ledger append procedure used by PA commands for mutation outcomes, proposals, feedback, and read-only telemetry.
---

# Ledger Append — Shared `assistant-ledger.jsonl` Append Procedure

> Purpose: Reference for `trust-and-boundaries` and PA command authorship.
> Scope: Extract the common append pattern around `.pa/assistant-ledger.jsonl` from writer commands, feedback producers, telemetry commands, and meta-composites.

## Core Rule

The top-level command appends the ledger entry after it knows the outcome and before it exits.
Agents do not append directly.
The ledger records what PA decided, what it touched, and how reversible that decision was.

## What This Reference Adds

`ledger-schema.md` defines the fields and action vocabulary.
This reference defines when commands append, which entry family they use, and how composite commands avoid double logging.

## Ownership Rule

The command that owns the user-visible outcome owns the ledger append.
This keeps one command invocation responsible for one `run_id`.
Child agents return structured output, but the parent command performs the append after outcome resolution.
This is why `draft`, `capture`, and `day` append after their final write or proposal decision.
This is also why `steward` lets child commands own their own ledger events instead of wrapping them in an extra composite event.

## Append Timing

Append after the outcome is known, not while the agent is still reasoning.
Append proposal or blocked outcomes even when no file mutation happened.
Append successful mutation outcomes after the write or edit completed.
Append failure outcomes when the command cannot complete the planned action.
Append feedback as a follow-up event that reuses the parent `run_id`.
Do not edit prior lines to correct history.

## Entry Families

Mutation entries record completed note creation, revision, append, or other successful vault mutations.
Proposal entries record exact mutations that were rendered but not applied.
Blocked entries record posture or safety downgrades that stopped the write.
No-note entries record commands like `capture` that intentionally end without a note.
Telemetry entries record read-only command runs such as `ask`, `agenda`, or `review`.
Feedback entries record the user's reaction to an earlier proposal.

## Universal Field Bundle

Every entry needs `ts`, `run_id`, `command`, `action`, `status`, `posture`, `risk_class`, `target_paths`, and `reversible`.
Most writer entries should also include `confidence`.
Most writer entries should also include a brief `why` rationale.
Feedback entries should include `user_feedback`.
Whenever the command loaded optional state strategically, it should include `state_files_loaded`, `state_files_used`, and `estimated_context_chars`.
These telemetry fields matter for future context-profile generation.

## Reversibility Bundle

New-note creation should include a `reversal_hint` equivalent to deleting the created path.
Revision-style writes should include `content_hash_before` when the prior note existed.
Successful writes should include `content_hash_after`.
Proposal entries may omit hashes when no mutation happened, but they still need a truthful `reversible` value.
The ledger should describe rollback plainly enough that the user can understand what undo would require.

## Privacy Bundle

Writer commands that run the declassification gate should carry the declassification verdict into the ledger metadata.
`draft`, `capture`, and `day` explicitly say to include `declassification` metadata.
`compile` and `ingest` also reference `declassification` metadata in the ledger entry during their write gates.
This means privacy inspection belongs to the append procedure, not only to the tool call that happened before it.
Unknown masks or irreversible residuals should produce a proposal or blocked entry rather than a completed mutation entry.

## Posture Bundle

The ledger should record the posture that governed the outcome, not the posture the user may have wanted.
`capture` is the clearest example because it distinguishes nominal and effective posture after downgrades.
Proposal or blocked entries are still valid ledger events because posture decisions are part of the trust record.
Posture does not decide whether logging happens.
Posture decides which status and action family the append should represent.

## Mutation Append Sequence

1. Resolve the final target path or target paths before appending.
2. Resolve the final outcome as `completed`, `proposed`, `blocked`, `failed`, or another schema-approved status.
3. Collect confidence, rationale, posture, risk class, and reversibility data from the final decision.
4. Add hashes and reversal hints when a write or edit actually happened.
5. Add declassification and context-telemetry metadata when the command gathered them.
6. Append one JSON object line to `.pa/assistant-ledger.jsonl`.

## Feedback Append Sequence

1. Keep the original `run_id` from the parent proposal-producing command.
2. Wait for an explicit user response.
3. Normalize the response to `accepted`, `rejected`, or `modified`.
4. Add `feedback_tags` only when the command can justify them from the user's actual response.
5. Append a second ledger line with `action: "feedback"`.
6. Skip the append when the user never responded or the run was unattended.

## Telemetry Append Sequence

Read-only commands still append when the command needs auditability or context-budget learning data.
`ask`, `agenda`, and `review` explicitly append a run entry even though they do not write vault notes.
These entries should use an action such as `response_presented` from the schema.
`target_paths` may be empty for those entries.
`reversible` is still meaningful because no user-markdown mutation occurred.

## Writer Command Extraction

`draft` appends for every outcome in Phase 7, including proposal-only and declassification-blocked paths.
`draft` also appends feedback later when the proposal result was `proposed`.
`capture` appends for every note outcome, including proposals, no-note, and declassification-blocked paths.
`capture` also appends separate decision-entity entries in Phase 8.
`day` appends for applied or proposed daily-note mutations and later records feedback when the user reacts to a write proposal.
`compile` reaches a shorter inline description, but its write gate still refers to declassification metadata in the ledger entry, so it belongs to the same writer family.
`ingest` also refers to declassification metadata in the ledger entry and follows the same single-note writer shape after deduplication and posture checks.

## Feedback-Only And Delegated Cases

`link` explicitly records feedback when it presented suggestion sets to the user.
`link` therefore uses the feedback-entry family even when the main analysis stayed read-only.
`steward` does not define a top-level ledger append for the composite itself.
`steward` delegates ownership to `survey`, `review`, `link`, and `agenda`, then updates only `.pa/derivation-state.json` with `last_steward`.
This avoids double counting child outcomes and preserves clean `run_id` ownership.

## Status Selection Rules

Use `completed` when the note write, edit, append, or read-only presentation actually finished.
Use `proposed` when the command rendered an exact mutation but did not apply it.
Use `blocked` when posture or another explicit safety rule stopped the action.
Use `failed` when the command could not produce or apply the expected result because of an operational error.
Use command-specific action names such as `note_created`, `note_revised`, `proposal_generated`, `posture_blocked`, or `feedback` from the schema.

## Reversibility Rules By Action

`note_created` should almost always be reversible through deletion of the new file.
`note_revised` should carry both before and after hashes when practical.
`proposal_generated` can still be reversible because nothing changed in the vault.
`posture_blocked` is usually reversible because the blocked mutation never happened.
Read-only telemetry entries are trivially reversible because they mutate no visible note.

## When Not To Append A Wrapper Entry

Do not append a composite wrapper entry around child commands that already own their own ledger writes.
Do not append inside an agent that is returning structured data to a parent command.
Do not write one entry before the final outcome and then silently replace it later.
Do not emit a feedback entry for a proposal that never reached the user.

## Common Mistakes

Logging only successful writes hides the exact moments when PA correctly refused to act.
Logging from both a child command and a parent composite creates duplicate or conflicting histories.
Omitting `target_paths` on proposal entries makes later review and feedback pairing harder.
Omitting reversal data weakens the trust story even when the mutation was otherwise safe.
Treating context telemetry as optional noise prevents later context-profile learning.

## Validation Checklist

- [ ] Exactly one command owns the append for the user-visible outcome.
- [ ] The append happened after final outcome resolution rather than during agent execution.
- [ ] Proposal, blocked, and no-note outcomes were logged, not only successful writes.
- [ ] Reversal hints or hashes were attached when a mutation actually happened.
- [ ] Declassification metadata was carried into writer entries when the gate ran.
- [ ] Context telemetry was included for commands that gathered it.
- [ ] Feedback entries reused the parent `run_id`.
- [ ] Composite commands avoided double logging child outcomes.

## See Also

- `references/ledger-schema.md` — Field-level schema and action vocabulary.
- `references/write-gate-protocol.md` — Shared write-safety decision process before ledger append.
- `commands/pa/draft.md` — Clearest full mutation append pattern.
- `commands/pa/capture.md` — Full mutation plus secondary decision-entity append pattern.
