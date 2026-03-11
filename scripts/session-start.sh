#!/usr/bin/env bash
# SessionStart hook: inject project status into session context
# Fires on: startup, resume, compact, clear
# Priority: STATUS.md (project root) > dev/STATUS.md (ouroboros internal)
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
PROJECT_ROOT="$(pwd)"

# Priority 1: Project-level STATUS.md (universal pattern for any project)
if [[ -f "$PROJECT_ROOT/STATUS.md" ]]; then
  echo "=== Project Status ==="
  cat "$PROJECT_ROOT/STATUS.md"
  echo "======================"
# Priority 2: Ouroboros dev status (only within ouroboros project itself)
elif [[ -f "$PLUGIN_ROOT/dev/STATUS.md" ]] && [[ "$PROJECT_ROOT" == "$PLUGIN_ROOT" ]]; then
  echo "=== Ouroboros Dev Status ==="
  # Extract State + Immediate Next sections (skip Backlog for brevity)
  awk '/^## State:/{found=1} found{print} /^## Backlog/{exit}' "$PLUGIN_ROOT/dev/STATUS.md"
  echo "============================="
fi

# Recent activity (git-based session history)
if [[ -f "$PLUGIN_ROOT/scripts/session-history.sh" ]]; then
  ACTIVITY=$(bash "$PLUGIN_ROOT/scripts/session-history.sh" list --limit 5 2>/dev/null || true)
  if [[ -n "$ACTIVITY" ]]; then
    echo ""
    echo "=== Recent Activity ==="
    echo "$ACTIVITY"
    echo "======================="
  fi
fi

# Inject compact context if available (one-shot: read then delete)
COMPACT_CTX="$PROJECT_ROOT/.compact-context.md"
if [[ -f "$COMPACT_CTX" ]]; then
  echo ""
  echo "=== Conversation Context (restored) ==="
  cat "$COMPACT_CTX"
  echo "========================================"
  rm -f "$COMPACT_CTX"
fi

exit 0
