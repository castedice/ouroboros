#!/usr/bin/env bash
# Worktree lifecycle manager for ouroboros commands (DR-031)
#
# Centralizes git worktree operations shared across 5 commands:
# generate, evolve, absorb, research, upgrade
#
# Usage:
#   worktree.sh create <operation> <slug>        — create worktree; prints path to stdout
#   worktree.sh commit <worktree-path> <message>  — stage all + commit in worktree
#   worktree.sh merge <worktree-path> <message>   — squash merge to main + cleanup
#   worktree.sh discard <worktree-path>            — force remove worktree + delete branch
#   worktree.sh cleanup <worktree-path>            — idempotent error cleanup
#   worktree.sh list                               — list ouroboros worktrees
#   worktree.sh status                             — JSON status of all ouroboros worktrees
#   worktree.sh scaffold <worktree-path> <path>...   — create parent dirs for file paths
#   worktree.sh prune                              — remove worktrees inactive for 24+ hours
#
# Conventions:
#   branch:   ouroboros/{operation}/{slug}
#   worktree: .worktrees/{operation}-{slug}
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — git operation failed

set -uo pipefail

ACTION="${1:?Usage: worktree.sh <action> ...}"
shift

# ─── Action: create ───
#   Args: <operation> <slug>
#   Output: worktree path to stdout

action_create() {
  local operation="${1:?Missing operation}"
  local slug="${2:?Missing slug}"
  local branch="ouroboros/${operation}/${slug}"
  local worktree=".worktrees/${operation}-${slug}"

  # Auto-prune stale worktrees before creating new one
  action_prune >/dev/null 2>&1 || true

  # If branch already exists (prior aborted run), append timestamp
  if git rev-parse --verify "$branch" &>/dev/null; then
    local ts
    ts=$(date +%s)
    slug="${slug}-${ts}"
    branch="ouroboros/${operation}/${slug}"
    worktree=".worktrees/${operation}-${slug}"
  fi

  mkdir -p .worktrees
  if ! git worktree add "$worktree" -b "$branch" HEAD &>/dev/null; then
    echo "Error: failed to create worktree at $worktree" >&2
    exit 2
  fi

  echo "$worktree"
}

# ─── Action: commit ───
#   Args: <worktree-path> <message>

action_commit() {
  local worktree="${1:?Missing worktree path}"
  local message="${2:?Missing commit message}"

  if [[ ! -d "$worktree" ]]; then
    echo "Error: worktree not found at $worktree" >&2
    exit 2
  fi

  git -C "$worktree" add -A
  if ! git -C "$worktree" commit -m "$message" &>/dev/null; then
    echo "Error: commit failed in $worktree" >&2
    exit 2
  fi
}

# ─── Action: merge ───
#   Args: <worktree-path> <message>

action_merge() {
  local worktree="${1:?Missing worktree path}"
  local message="${2:?Missing commit message}"
  local branch
  branch=$(_get_branch "$worktree")

  # Safety check 1: dirty working tree on main
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Error: main working tree has uncommitted changes. Commit or stash before merging." >&2
    exit 2
  fi

  # Safety check 2: untracked file conflict detection
  # Get list of files the worktree branch would bring in
  local merge_files
  merge_files=$(git diff --name-only HEAD..."$branch" 2>/dev/null)
  if [[ -n "$merge_files" ]]; then
    local conflicts=""
    while IFS= read -r file; do
      # Check if file exists as untracked on main (not in index, but on disk)
      if [[ -f "$file" ]] && ! git ls-files --error-unmatch "$file" &>/dev/null; then
        conflicts="${conflicts}  ${file}\n"
      fi
    done <<<"$merge_files"
    if [[ -n "$conflicts" ]]; then
      echo "Error: untracked files on main would conflict with merge:" >&2
      echo -e "$conflicts" >&2
      echo "Remove, move, or git-add these files before merging." >&2
      exit 2
    fi
  fi

  if ! git merge --squash "$branch" &>/dev/null; then
    echo "Error: squash merge failed for $branch" >&2
    exit 2
  fi

  if ! git commit -m "$message" &>/dev/null; then
    echo "Error: merge commit failed" >&2
    exit 2
  fi

  # Cleanup after successful merge
  git worktree remove "$worktree" &>/dev/null ||
    git worktree remove "$worktree" --force &>/dev/null ||
    true
  git branch -D "$branch" &>/dev/null || true
}

# ─── Action: discard ───
#   Args: <worktree-path>
#   Delegates to cleanup (identical behavior, single implementation)

action_discard() {
  action_cleanup "$@"
}

# ─── Action: cleanup (idempotent) ───
#   Args: <worktree-path>
#   Tolerates missing worktree or branch — safe to call after any error

action_cleanup() {
  local worktree="${1:?Missing worktree path}"
  local branch
  branch=$(_get_branch "$worktree")

  git worktree remove "$worktree" --force &>/dev/null || true
  git branch -D "$branch" &>/dev/null || true
}

# ─── Action: list ───
#   Args: none
#   Output: one line per ouroboros worktree (path branch)

action_list() {
  local found=0
  while IFS= read -r line; do
    local wt_path wt_branch
    wt_path=$(echo "$line" | awk '{print $1}')
    wt_branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
    if [[ "$wt_branch" == ouroboros/* ]]; then
      echo "$wt_path $wt_branch"
      found=1
    fi
  done < <(git worktree list 2>/dev/null)
  if [[ "$found" -eq 0 ]]; then
    echo "No ouroboros worktrees found."
  fi
}

# ─── Action: status ───
#   Args: none
#   Output: JSON array of worktree status objects

action_status() {
  local json="["
  local first=1
  while IFS= read -r line; do
    local wt_path wt_branch
    wt_path=$(echo "$line" | awk '{print $1}')
    wt_branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
    if [[ "$wt_branch" != ouroboros/* ]]; then
      continue
    fi
    # Extract operation from branch: ouroboros/{operation}/{slug}
    local operation slug
    operation=$(echo "$wt_branch" | cut -d/ -f2)
    slug=$(echo "$wt_branch" | cut -d/ -f3-)
    # Count dirty files
    local dirty_count=0
    if [[ -d "$wt_path" ]]; then
      dirty_count=$(git -C "$wt_path" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    fi
    # Count commits ahead of main
    local ahead=0
    ahead=$(git rev-list --count HEAD.."$wt_branch" 2>/dev/null || echo 0)
    # Get last commit timestamp
    local last_commit=""
    last_commit=$(git -C "$wt_path" log -1 --format=%aI 2>/dev/null || echo "")
    if [[ "$first" -eq 0 ]]; then
      json="${json},"
    fi
    first=0
    json="${json}{\"path\":\"${wt_path}\",\"branch\":\"${wt_branch}\",\"operation\":\"${operation}\",\"slug\":\"${slug}\",\"dirty_files\":${dirty_count},\"commits_ahead\":${ahead},\"last_commit\":\"${last_commit}\"}"
  done < <(git worktree list 2>/dev/null)
  json="${json}]"
  echo "$json"
}

# ─── Action: scaffold ───
#   Args: <worktree-path> <file-path1> [file-path2] ...
#   Creates parent directories for each file path within the worktree

action_scaffold() {
  local worktree="${1:?Missing worktree path}"
  shift

  if [[ ! -d "$worktree" ]]; then
    echo "Error: worktree not found at $worktree" >&2
    exit 2
  fi

  if [[ $# -eq 0 ]]; then
    echo "Error: no file paths provided" >&2
    exit 1
  fi

  for filepath in "$@"; do
    local dir
    dir=$(dirname "${worktree}/${filepath}")
    mkdir -p "$dir"
  done
}

# ─── Action: prune ───
#   Args: none
#   Removes ouroboros worktrees with last commit older than 24 hours
#   Also unlocks stale lock files and runs git worktree prune

action_prune() {
  # Phase 1: Unlock stale lock files before pruning
  _unlock_stale_worktrees

  local now pruned=0
  now=$(date +%s)
  local cutoff=$((now - 86400))

  while IFS= read -r line; do
    local wt_path wt_branch
    wt_path=$(echo "$line" | awk '{print $1}')
    wt_branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
    if [[ "$wt_branch" != ouroboros/* ]]; then
      continue
    fi
    # Get last commit epoch
    local last_epoch=0
    if [[ -d "$wt_path" ]]; then
      last_epoch=$(git -C "$wt_path" log -1 --format=%at 2>/dev/null || echo 0)
    fi
    if [[ "$last_epoch" -lt "$cutoff" ]]; then
      echo "Pruning: $wt_path ($wt_branch) — inactive for 24+ hours"
      git worktree remove "$wt_path" --force &>/dev/null || true
      git branch -D "$wt_branch" &>/dev/null || true
      pruned=$((pruned + 1))
    fi
  done < <(git worktree list 2>/dev/null)

  # Phase 2: Clean up git internal worktree references
  git worktree prune 2>/dev/null || true

  if [[ "$pruned" -eq 0 ]]; then
    echo "No stale worktrees to prune."
  else
    echo "Pruned $pruned worktree(s)."
  fi
}

# ─── Helpers ───

_unlock_stale_worktrees() {
  local git_dir
  git_dir=$(git rev-parse --git-dir 2>/dev/null) || return 0
  local wt_dir="$git_dir/worktrees"
  [[ -d "$wt_dir" ]] || return 0

  for entry in "$wt_dir"/*/; do
    [[ -d "$entry" ]] || continue
    local name gitdir_file
    name=$(basename "$entry")
    gitdir_file="$entry/gitdir"
    [[ -f "$gitdir_file" ]] || continue
    local target
    target=$(cat "$gitdir_file")
    # Only unlock ouroboros worktrees whose target directory is gone
    if [[ "$target" == *".worktrees/"* ]] && [[ -f "$entry/locked" ]] && [[ ! -d "$target" ]]; then
      rm -f "$entry/locked"
      echo "Unlocked stale: $name"
    fi
  done
}

_get_branch() {
  local worktree="$1"
  # Try worktree HEAD first; fall back to path-based derivation
  if [[ -d "$worktree" ]]; then
    local branch
    branch=$(git -C "$worktree" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
      echo "$branch"
      return
    fi
  fi
  _derive_branch "$worktree"
}

_derive_branch() {
  # .worktrees/{operation}-{rest} → ouroboros/{operation}/{rest}
  local base
  base=$(basename "$1")
  local operation="${base%%-*}"
  local slug="${base#*-}"
  echo "ouroboros/${operation}/${slug}"
}

# ─── Dispatch ───

case "$ACTION" in
  create) action_create "$@" ;;
  commit) action_commit "$@" ;;
  merge) action_merge "$@" ;;
  discard) action_discard "$@" ;;
  cleanup) action_cleanup "$@" ;;
  scaffold) action_scaffold "$@" ;;
  list) action_list ;;
  status) action_status ;;
  prune) action_prune ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: create|commit|merge|discard|cleanup|scaffold|list|status|prune" >&2
    exit 1
    ;;
esac
