# Failure And Recovery

## Session Recovery

Session recovery starts with `bash scripts/worktree.sh status`.
The status output is a JSON array of active ouroboros worktrees.
Commands filter by `operation` and ignore unrelated draft branches.
If one matching draft exists, present its path, branch, commits ahead, and dirty file count.
If multiple matching drafts exist, present them explicitly rather than guessing.
The user must choose whether to `Resume`, `Discard`, or `Merge`.

## Choice Semantics

`Resume` reuses the existing draft and skips fresh creation.
`Discard` removes the existing worktree and its branch, then allows a fresh draft if needed.
`Merge` squashes the existing draft onto `main`, cleans it up, and then allows a fresh draft if needed.
Fresh creation should never happen until the existing draft state is resolved.

## Prune And Stale State

`bash scripts/worktree.sh prune` is the background hygiene step.
The script removes ouroboros worktrees whose last commit is older than 24 hours.
The script also unlocks stale git worktree lock files when the target directory is already gone.
Prune is best-effort cleanup, not a substitute for explicit user decisions on active drafts.

## Merge Failure Model

`merge` fails when the main working tree has uncommitted tracked changes.
`merge` also fails when untracked files on `main` would conflict with files coming from the draft branch.
These checks protect `main` from an unsafe squash merge.
The commands using this pattern treat worktree-operation failure as a fail-closed path.

## Cleanup Policy

Use `cleanup` after unexpected worktree-operation failures once `$WORKTREE` is known.
`cleanup` is idempotent and tolerates a missing worktree or branch.
`discard` delegates to `cleanup`, so deliberate rejection and error cleanup share the same removal behavior.
After cleanup runs, the current draft is considered abandoned.
Do not keep editing or retrying inside a cleaned-up draft.

## Failure Reporting

Report the original operation that failed, not just the cleanup result.
If cleanup itself had nothing to remove, that is still a successful cleanup outcome.
If the failure happened before creation returned a path, report the setup error directly because there is no `$WORKTREE` to clean.
If command-specific validation failed but the worktree itself is still healthy, return to the command's own retry or review logic rather than invoking cleanup reflexively.

## Recommended User-Facing Wording

Use concrete wording for recovery prompts so the user can choose quickly.
Say `Resume` when the existing draft should continue from its current state.
Say `Discard` when the existing draft should be removed without affecting `main`.
Say `Merge` when the existing draft is ready to land on `main` before starting a new draft.
