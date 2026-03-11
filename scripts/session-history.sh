#!/usr/bin/env bash
# Session history — git log based recent activity extraction
#
# Subcommands:
#   list [--limit N]              — recent N commits (default 5)
#   summary [--since "1 day ago"] — period-based work summary
#
# Uses git log only (no Claude session directory access — path-change resilient).
#
# Part of ouroboros session intelligence (v0.18.5)

set -euo pipefail

ACTION="${1:-}"

# ─── List ───

action_list() {
  local limit=5

  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit)
        limit="${2:-5}"
        shift 2
        ;;
      *) shift ;;
    esac
  done

  if ! command -v git &>/dev/null || ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Not a git repository."
    exit 1
  fi

  git log --oneline --no-decorate -n "$limit" 2>/dev/null || echo "(no commits)"
}

# ─── Summary ───

action_summary() {
  local since="1 day ago"

  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        since="${2:-1 day ago}"
        shift 2
        ;;
      *) shift ;;
    esac
  done

  if ! command -v git &>/dev/null || ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "Not a git repository."
    exit 1
  fi

  local count
  count=$(git log --oneline --since="$since" 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$count" -eq 0 ]]; then
    echo "No activity since \"$since\"."
    exit 0
  fi

  echo "Activity since \"$since\": $count commits"
  echo ""

  # Commit list
  git log --oneline --no-decorate --since="$since" 2>/dev/null

  echo ""

  # File change summary
  local stat
  stat=$(git diff --stat "$(git log --format=%H --since="$since" | tail -1)^"..HEAD 2>/dev/null | tail -1 || true)
  if [[ -n "$stat" ]]; then
    echo "Files: $stat"
  fi
}

# ─── Dispatch ───

case "$ACTION" in
  list)
    action_list "$@"
    ;;
  summary)
    action_summary "$@"
    ;;
  *)
    echo "Usage: session-history.sh {list|summary} [options]" >&2
    echo "  list [--limit N]              — recent N commits (default 5)" >&2
    echo "  summary [--since \"1 day ago\"] — period-based work summary" >&2
    exit 1
    ;;
esac
