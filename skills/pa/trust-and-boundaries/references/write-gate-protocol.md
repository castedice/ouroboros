---
name: write-gate-protocol
description: This reference defines the shared write gate used by PA note-writing commands to choose between direct mutation, proposal-only handling, and no-note outcomes.
---

# Write Gate Protocol — Shared Vault Write Decision Pattern

> Purpose: Reference for `trust-and-boundaries` and PA writer commands.
> Scope: Extract the common write-vs-propose decision flow used by `draft`, `capture`, `compile`, and `ingest`.

## Core Rule

The write gate decides safety before any mutating tool call happens.
The gate exists to make posture, confidence, provenance, and reversibility visible before PA touches user markdown.
When the gate is uncertain, the safe outcome is an exact proposal rather than a guess-backed write.

## Source Commands

`draft` uses the most explicit version of the protocol through its Unified Decision Table, Shared Fallback Policy, permission envelope, and Phase 7 apply step.
`capture` uses the same logic through routing normalization, duplicate handling, permission envelope, Application Policy, and declassification gate.
`compile` uses the same low-risk single-note creation path after source collection and synthesis.
`ingest` uses the same low-risk single-note creation path after source-packet normalization and deduplication.

## Shared Inputs

The gate starts only after `.pa/settings.json` and `.pa/vault-profile.json` are loaded successfully.
The configured automation posture from `.pa/settings.json` is authoritative.
The target path basis must be resolved before the command can classify scope or reversibility.
Visible markdown is always treated as `source-markdown`, even when PA created it previously.
`.pa/` overlays may help the decision, but they never lower the safety bar for user-visible notes.

## Gate Sequence

1. Parse the command-specific target and identify whether the command is creating one note, revising one note, or producing a proposal body only.
2. Resolve the candidate path from vault naming and placement rules before asking whether the write is allowed.
3. Classify the surface as `source-markdown`, `derived-markdown`, or `.pa-state`, and apply the strictest rule when one action spans more than one surface.
4. Classify the action as `low-risk write`, `high-risk write`, or `destructive` from scope, semantic impact, and placement effects.
5. Attach provenance and confidence to the rendered output or extracted units before any write decision is finalized.
6. Compare the classified action against the active posture using `posture-matrix.md`.
7. Downgrade to proposal-only when posture, evidence, confidence, or scope is weaker than the requested mutation.
8. Render the exact note body or exact bounded patch even when the likely result is proposal-only.
9. Run the declassification gate on the rendered markdown immediately before the mutating tool call.
10. Choose exactly one outcome from `apply`, `proposal-only`, or `no-note`, and then keep the rest of the command aligned with that outcome.

## Surface And Scope Rules

Single-note creation can be low-risk only when the path stays inside already approved placement rules.
Single-note revision can be low-risk only when it stays bounded, non-destructive, and in place.
Creating a new folder, changing placement rules, or spilling into multiple notes upgrades the action beyond the low-risk path.
Rename, move, delete, folder migration, and structural reorganization never stay on the low-risk path.
Replacing more than 30 percent of an existing note is treated as a higher-risk or confirmation-requiring change.
Commands should resolve these scope facts before they ask whether posture allows the write.

## Confidence Rules

The parent skill treats `high` confidence as at least three confirming signals with no contradictions.
The parent skill treats `medium` confidence as two supporting signals or one strong direct source.
The parent skill treats `low` confidence as proposal-only.
Writer commands inherit that contract even when the confidence value comes from a command-local agent such as the curator or scribe.
`draft` routes low scribe confidence through the Shared Fallback Policy.
`capture` treats malformed curator output as low confidence and falls back to `timestamp-note`.
`capture` also forces proposal-only when scribe confidence is low even if posture would otherwise permit a write.
`compile` and `ingest` both synthesize from collected evidence, so confidence must still be explicit before the note is written.
Weak provenance, contradictory evidence, or unresolved duplicate risk should be treated like low confidence for the purpose of the gate.

## Posture Rules

`observe` never authorizes user-markdown writes.
`propose` never authorizes user-markdown writes.
`apply-low-risk` authorizes only bounded, reversible low-risk markdown changes.
`operate` authorizes broader bounded maintenance, but it still does not authorize destructive freedom.
Posture is a ceiling rather than a command to write.
A command may still choose proposal-only at a posture that would technically allow the write when confidence or reversibility is weak.
PA never self-promotes posture because a write looks harmless.
When posture is unreadable, contradictory, or missing, the gate fails closed to `observe`.

## Reversibility Rules

A write is safer when it can be undone with one concrete instruction.
New-note creation should carry a reversal hint equivalent to deleting the newly created path.
Single-note revision should carry enough reversal data to reconstruct the previous state through content hashes or the exact bounded patch.
Commands should record `content_hash_before` for revisions when the prior note state exists.
Commands should record `content_hash_after` when a note was actually written.
Reversibility must be assessed before the write happens, not added as an afterthought in the ledger.
If the command cannot explain how to undo the change cleanly, the gate should downgrade toward proposal-only.

## Declassification Gate

The declassification gate is the final safety check immediately before `Write` or `Edit`.
`scripts/pa-write-safe.sh inspect` checks the rendered markdown for irreversible privacy residuals and unknown masks.
Known reversible masks may be declassified through `scripts/pa-write-safe.sh declassify`.
Irreversible residuals or unknown masks force `proposal-only`.
The gate inspects rendered prose rather than upstream structured state because privacy failures matter at the final markdown surface.
Writer commands should carry the declassification verdict into the ledger metadata after the outcome is chosen.

## Outcome Selection

Choose `apply` only when posture allows the classified action, the output has acceptable confidence, the change is reversible, the path is valid, and declassification passes.
Choose `proposal-only` when the command can produce an exact note body or bounded patch but at least one safety gate blocks direct application.
Choose `no-note` when the command cannot justify any note creation at all, such as empty extraction or an explicit no-output route.
The command should never oscillate between outcomes once the final gate result is known.
If a command produces both a note proposal and a secondary entity proposal, each proposal needs its own acceptance path.

## Command Notes

`draft` is the clearest single-note writer because it separates creation and revision and makes the fallback path explicit.
`draft` treats revision scope drift, placement changes, and low grounding confidence as write blockers even when the user asked for a note change.
`capture` adds an earlier routing stage, but it still resolves to the same `apply`, `proposal-only`, or `no-note` decision before Phase 7.
`capture` also uses duplicate handling and path-collision checks as part of the write gate rather than as a later cosmetic warning.
`compile` reaches the gate later because it first needs enough eligible sources and a confident synthesis, but the final note write is still just one bounded authored note.
`compile` therefore follows the low-risk creation path only when posture is `apply-low-risk` or higher and declassification passes.
`ingest` adds source normalization and deduplication before the gate, but its final mutation is still one digest note with explicit provenance.
`ingest` therefore treats duplicate detection, fetch degradation, and posture as preconditions to the same single-note writer decision.

## Shared Blocking Reasons

The candidate write would create a new folder outside approved placement rules.
The candidate revision would rename, move, delete, or restructure notes.
The rendered content carries low confidence or contradictory evidence.
The duplicate risk is still likely or unresolved enough that creating a new note would be misleading.
The command would need to replace too much existing prose to stay reversible.
The declassification gate found irreversible residuals or unknown masks.
The active posture does not authorize the classified action.

## Proposal-Only Expectations

Proposal-only still requires exactness.
The user should see the actual note body, the actual bounded patch, or the actual blocking reason that prevented the write.
Proposal-only does not permit hidden broadening of scope.
Proposal-only should preserve citations, provenance, and the intended target path so the user can evaluate the real mutation.
Proposal-only outcomes still belong in the assistant ledger because blocked judgment is part of the trust record.

## What This Protocol Forbids

It forbids planning the edit before classifying the action and posture.
It forbids treating `.pa/` authority as permission to mutate visible notes.
It forbids converting low confidence into a confident write just because the note would be helpful.
It forbids splitting a high-risk change into hidden micro-edits to stay under the threshold.
It forbids skipping the declassification gate on rendered markdown that may contain privacy residuals.

## Validation Checklist

- [ ] The command resolved the exact target path before evaluating write safety.
- [ ] The surface and action class were made explicit.
- [ ] The active posture was read from settings rather than inferred from conversation.
- [ ] Confidence and provenance were attached before the final outcome decision.
- [ ] Reversibility was explained concretely enough to produce rollback metadata.
- [ ] The declassification gate ran immediately before any mutating tool call.
- [ ] The final outcome is exactly one of `apply`, `proposal-only`, or `no-note`.
- [ ] Proposal-only handling preserved the exact mutation instead of paraphrasing it.

## See Also

- `skills/pa/trust-and-boundaries/SKILL.md` — Parent trust workflow and confidence rules.
- `references/posture-matrix.md` — Permission ceilings, bounded maintenance thresholds, and escalation triggers.
- `references/ledger-append.md` — Shared assistant-ledger append procedure after the gate chooses an outcome.
- `scripts/pa-write-safe.sh` — Final declassification and residual-inspection gate.
