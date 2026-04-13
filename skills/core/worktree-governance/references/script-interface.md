# Script Interface

## Script Surface

The shared execution surface is `scripts/worktree.sh`.
The governance skill defines when to call it.
This reference defines what each action guarantees.

## Naming Conventions

Branches use `ouroboros/{operation}/{slug}`.
Worktree directories use `.worktrees/{operation}-{slug}`.
`create` prints the authoritative absolute worktree path to stdout.
If a branch name already exists, `create` appends a timestamp to the slug before creating the branch and worktree.

## Actions

`create <operation> <slug>` creates a new worktree from `HEAD` and auto-prunes stale worktrees first.
`commit <worktree-path> <message>` stages all changes in the worktree and creates a commit there.
`merge <worktree-path> <message>` squash-merges the worktree branch into `main`, commits on `main`, and removes the worktree and branch.
`discard <worktree-path>` removes the worktree and branch by delegating to `cleanup`.
`cleanup <worktree-path>` force-removes the worktree and deletes the derived branch if present.
`scaffold <worktree-path> <path>...` creates parent directories inside the worktree for one or more relative file paths.
`list` prints all ouroboros worktrees as path and branch pairs.
`status` prints a JSON array describing all ouroboros worktrees.
`prune` removes stale ouroboros worktrees and runs `git worktree prune`.

## Status Schema

Each status object includes `path`.
Each status object includes `branch`.
Each status object includes `operation`.
Each status object includes `slug`.
Each status object includes `dirty_files`.
Each status object includes `commits_ahead`.
Each status object includes `last_commit`.

## Merge Safety Checks

`merge` refuses to run when `main` has uncommitted tracked changes.
`merge` refuses to run when untracked files on `main` would conflict with incoming draft files.
These failures exit before the squash merge and leave the caller to apply the command's error policy.

## Exit Semantics

Exit code `0` means success.
Exit code `1` means invalid arguments or unknown action.
Exit code `2` means a git operation failed.
Lifecycle callers should treat non-zero exit as a failed worktree operation.

## Practical Notes

Use the returned `WORKTREE` variable directly instead of rebuilding paths.
Use `status` for user-facing recovery decisions and `list` for quick human inspection.
Use `scaffold` when path creation is mechanical and known ahead of writing.
Use `cleanup` when the draft must be abandoned after a lifecycle failure.
