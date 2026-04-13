# Worktree Lifecycle Pattern

## Scope

This reference normalizes the worktree lifecycle shared by `commands/core/evolve.md`, `commands/core/generate.md`, `commands/core/absorb.md`, `commands/core/research.md`, and `commands/core/upgrade.md`.
It describes the common pattern only.
Each command still owns its own planning, validation, and reporting semantics.

## Standard Sequence

1. Query existing draft state with `bash scripts/worktree.sh status`.
2. Filter status entries by the current operation name.
3. If a matching draft exists, present `Resume`, `Discard`, and `Merge` to the user and wait.
4. Run `bash scripts/worktree.sh prune` during setup to clear stale worktrees.
5. If needed, create a fresh draft with `WORKTREE=$(bash scripts/worktree.sh create {operation} {slug})`.
6. Treat the returned `WORKTREE` value as an absolute path and write only inside that root.
7. Write command artifacts into the worktree and keep related decision records there as well.
8. Stage and commit inside the worktree before review with `bash scripts/worktree.sh commit "$WORKTREE" "{message}"`.
9. Present the draft to the user with branch context, artifact summary, and diff.
10. On approval, merge with `bash scripts/worktree.sh merge "$WORKTREE" "{message}"`.
11. On rejection, discard with `bash scripts/worktree.sh discard "$WORKTREE"`.
12. On lifecycle failure, clean up with `bash scripts/worktree.sh cleanup "$WORKTREE"` before aborting.

## Shared Invariants

Every current worktree command checks status before creating a new draft.
Every current worktree command treats user review as the primary merge gate.
Every current worktree command writes files only inside the worktree.
Every current worktree command commits inside the worktree before presenting the draft.
Every current worktree command uses `merge` or `discard` as the terminal user decision.
Every current worktree command uses `cleanup` as the error path once worktree operations have started.

## Per-Command Variations

`evolve` preserves a before snapshot for validation and may retry before review.
`generate` uses `scaffold` heavily because file paths are known up front.
`absorb` always writes a knowledge entry and may write generated components in the same draft.
`research` writes a single knowledge entry, merges it after review, and then runs post-merge indexing.
`upgrade` applies classified file changes in safety order and may surface degraded merge results at review time.

## Review Checkpoint Shape

The review checkpoint should show the draft branch in `ouroboros/{operation}/{slug}` form.
The review checkpoint should summarize the artifacts or files produced by the draft.
The review checkpoint should expose warnings or degraded validations instead of burying them.
The review checkpoint should end in a concrete `Merge` or `Discard` choice.

## Commit Timing

The common pattern commits before review rather than after approval.
That keeps the review diff stable and aligned with the candidate that would be merged.
It also lets the merge step remain a pure branch-to-main operation rather than a mixed edit-and-merge step.

## Out Of Scope

This reference does not define quality-gate thresholds.
This reference does not define retry strategy inside `evolve`, `generate`, `absorb`, or `upgrade`.
This reference does not define post-merge tasks such as knowledge indexing or downstream bridge calls.
