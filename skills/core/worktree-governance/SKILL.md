---
name: worktree-governance
description: This skill governs the shared git worktree lifecycle for isolated draft edits, and it should be activated when a command or agent needs to detect or resume an existing worktree, create a new absolute-path worktree, write only inside that scope, hold a user review checkpoint before merge, or clean up a failed draft safely.
summary: Governs isolated git worktree drafts from status checks through scoped writes, review checkpoints, merge, discard, and cleanup.
version: 1
tags: [core, worktree-governance, git-worktree, draft-isolation, merge-governance]
preamble_tier: 2
---

# Worktree Governance

## Core Rule

Use a governed worktree whenever the task needs isolated draft edits before the user decides whether they should land on `main`.
The standard lifecycle is Status -> Decide -> Create or Resume -> Write -> Commit -> Review -> Merge or Discard -> Cleanup on error.
Treat `$WORKTREE` as the only write root for the draft and treat `main` as read-only until merge completes.
Use `scripts/worktree.sh` for lifecycle actions rather than ad hoc git commands.
Keep governance policy here and script mechanics in the mapped references.

## Gotchas

Skipping the status check can fork the same task into multiple draft branches.
Ignoring an existing draft breaks the resume, discard, or merge decision that the user must make explicitly.
Reconstructing the worktree path manually is wrong because `create` returns the authoritative absolute path and may append a timestamp.
Writing outside `$WORKTREE` leaks draft state onto `main` and defeats the isolation contract.
Reviewing before the draft is committed makes the diff unstable and weakens the checkpoint.
Merging without the review checkpoint bypasses the shared command contract used by all current worktree commands.
Treating `merge` failure as harmless is incorrect because the script enforces clean-main and untracked-file safety checks.
Using custom cleanup sequences instead of the shared script risks leaving a branch, lock, or detached worktree behind.
Forgetting that `discard` delegates to `cleanup` causes duplicate error-handling logic.
Running post-merge follow-up work before merge succeeds can operate on files that still exist only in the draft.

### Rationalization Red Flags

| Rationalization | Forbidden Move | Corrective Action |
|-----------------|----------------|-------------------|
| "This is a fresh task, so no matching draft exists" | Creating a worktree before checking governed status | Run `worktree.sh status`, resolve matching drafts, and only then create or resume |
| "I can infer the branch from the slug" | Constructing worktree paths or branch names manually | Use the absolute path returned by `worktree.sh create` as the authoritative write root |
| "Validation passed, so merge is automatic" | Merging without the user review checkpoint | Commit the draft, present the diff and warnings, and wait for explicit Merge or Discard |

## Workflow

Follow this six-step workflow for draft-producing commands.

### 1. Check Status And Resolve Existing Drafts

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh status` before creating a new worktree.
Filter the JSON by the current operation name.
If matching entries exist, show the path, branch, commits ahead, and dirty file count to the user.
Offer `Resume`, `Discard`, and `Merge` as the lifecycle choices for that existing draft.
Wait for user choice before proceeding.
Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh prune` around setup to clear stale worktrees silently.

### 2. Create Or Resume The Worktree

If the user chose `Resume`, bind the selected path to `$WORKTREE` and skip creation.
If the user chose `Discard`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "{path}"` and then continue with fresh creation if the task still needs a draft.
If the user chose `Merge`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "{path}" "{message}"` and then continue with fresh creation if the task still needs a draft.
For a fresh draft, derive a stable slug from the task identity and create the worktree with `WORKTREE=$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create {operation} {slug})`.
Treat the returned stdout value as an absolute path contract.
Do not infer branch names or `.worktrees/...` paths by string concatenation.

### 3. Write Only Inside The Worktree Scope

Create any needed parent directories inside `$WORKTREE` before writing files.
When multiple file paths are known in advance, prefer `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh scaffold "$WORKTREE" {path}...`.
Read from `main` if needed for context, but write only to `$WORKTREE/{relative-path}`.
Store draft-only artifacts, decision entries, and generated outputs inside the same worktree.
Keep pre-edit snapshots in memory or in task-local state if later validation may need rollback.
Commit the coherent draft with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh commit "$WORKTREE" "{message}"` before presenting it for review.

### 4. Hold The Review Checkpoint

Prepare a user-facing draft summary with the draft branch, affected files or artifacts, important warnings, and the diff.
Treat this as the primary approval gate for the draft.
Ask the user whether to `Merge` or `Discard`.
Do not auto-merge just because validation passed or the draft looks correct.
If validation or quality gates raised warnings, surface them in this checkpoint instead of hiding them behind the merge choice.

### 5. Merge Or Discard Explicitly

On `Merge`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh merge "$WORKTREE" "{message}"`.
Rely on the script to squash-merge onto `main` and then remove the worktree and branch.
On `Discard`, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh discard "$WORKTREE"`.
After merge or discard, report the outcome in user language and stop writing to the old `$WORKTREE`.
Run any post-merge follow-up tasks only after merge succeeds.

### 6. Cleanup On Error

If any worktree lifecycle step fails after `$WORKTREE` is known, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh cleanup "$WORKTREE"` before aborting.
Treat cleanup as idempotent and safe after partial failure.
After cleanup, report the original failure in a way the caller or user can act on.
Do not continue the draft after a cleanup path has run.
The shared command pattern is fail-closed at the draft level, so cleanup means the current draft is abandoned.

## Decision Rules

Use `Resume` when the existing draft still matches the current task and the user wants continuity.
Use `Discard` when the draft is obsolete, invalid, or explicitly unwanted.
Use `Merge` on an existing draft only when the user is explicitly approving that draft for `main`.
Create fresh only after every matching existing draft has been resolved.
Derive slugs from stable task identities rather than timestamps unless the script adds the timestamp because a branch already exists.
Treat the path returned by `create` as authoritative even if the slug was mutated for collision handling.
Skip worktree creation entirely for read-only or `--check` style flows that do not write files.
Commit before review because the review diff should reflect the exact candidate for merge.
Use `cleanup` for unexpected errors and `discard` for intentional user rejection.
Keep command-specific validation, retry, and post-merge tasks outside this skill, because this skill governs lifecycle rather than task semantics.
If multiple matching drafts exist for one operation, present them explicitly and make the user pick one before any destructive action.
If a merge attempt fails because `main` is dirty or has conflicting untracked files, surface the script error and follow the command's fail-closed cleanup policy.
- **Isolation delegation**: When a command writes a small number of draft files with no cross-session resume requirement, delegate to the `draft-writer` agent instead of manual `worktree.sh` lifecycle per `${CLAUDE_SKILL_DIR}/references/isolation-delegation.md`.

## Reference Map

| Reference | Purpose |
|-----------|---------|
| `isolation-delegation.md` | When to use built-in isolation vs manual worktree.sh |

Read [`references/lifecycle-pattern.md`](${CLAUDE_SKILL_DIR}/references/lifecycle-pattern.md) for the normalized phase-by-phase lifecycle shared by `evolve`, `generate`, `absorb`, `research`, and `upgrade`.
Read [`references/failure-and-recovery.md`](${CLAUDE_SKILL_DIR}/references/failure-and-recovery.md) for session recovery prompts, stale worktree handling, and fail-closed cleanup rules.
Read [`references/script-interface.md`](${CLAUDE_SKILL_DIR}/references/script-interface.md) for `scripts/worktree.sh` actions, status schema, safety checks, and exit semantics.
Read [`commands/core/evolve.md`](commands/core/evolve.md), [`commands/core/generate.md`](commands/core/generate.md), [`commands/core/absorb.md`](commands/core/absorb.md), [`commands/core/research.md`](commands/core/research.md), and [`commands/core/upgrade.md`](commands/core/upgrade.md) when you need command-specific logic that sits on top of the shared lifecycle.

## See Also

Use this skill when the problem is draft isolation and merge governance rather than content generation, evaluation, or research method.
Current consumers are `commands/core/evolve.md`, `commands/core/generate.md`, `commands/core/absorb.md`, `commands/core/research.md`, and `commands/core/upgrade.md`.
Use `skills/core/validation/SKILL.md` or `skills/core/evaluation/SKILL.md` for quality gates that happen inside the worktree but are not part of the lifecycle itself.
Use `scripts/worktree.sh` as the execution surface, not as a source of policy.
