# Isolation Delegation Pattern

When a command needs to write draft files in isolation, it can delegate to the `draft-writer` agent instead of manually managing worktree lifecycle via `worktree.sh`.

## When to Use

| Condition | Use |
|-----------|-----|
| Single or few files, no cross-session resume needed | `draft-writer` agent (isolation: worktree) |
| Multi-file with session resume, complex merge logic | `worktree.sh` manual lifecycle |
| Read-only analysis | Neither (no isolation needed) |

## Contract

The caller provides:
- One or more `{path, content}` file pairs
- A commit message

The draft-writer returns a `DRAFT_RESULT` block with:
- `worktree`: absolute path to the isolated worktree
- `branch`: the worktree branch name
- `files`: list of written file paths (relative to worktree root)
- `summary`: one-line description

## Caller Responsibilities

After receiving the draft result, the caller:
1. **Reviews** the written files by reading from the worktree path
2. **Presents** the diff to the user for approval
3. **Merges** on approval: `git merge --squash {branch} && git commit -m "..." && git worktree remove {worktree} && git branch -D {branch}`
4. **Discards** on rejection: `git worktree remove --force {worktree} && git branch -D {branch}`

Pre-merge safety: verify main has no uncommitted tracked changes (`git diff --quiet`) before merging.

## Limitations

- No cross-session draft resume (worktrees are ephemeral)
- The worktree location is managed by Claude Code, not by `worktree.sh`
- Session recovery in commands should still check `worktree.sh status` for legacy worktrees
