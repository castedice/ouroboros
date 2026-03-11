#!/usr/bin/env bash
# PreCompact hook: output compact change summary + extract conversation context
# Fires before auto-compact or manual /compact.
# Output is included in the context that gets summarized, helping preserve
# recent change awareness through compaction.
# Also generates .compact-context.md for session-start injection after compaction.
# NOTE: STATUS.md injection is handled by SessionStart (no duplication).
set -euo pipefail

# Read stdin (hook provides JSON with transcript_path)
STDIN_DATA=""
if ! [ -t 0 ]; then
  STDIN_DATA=$(cat)
fi

echo "=== Pre-Compaction: Recent Changes ==="

# Compact git summary: commit messages + file count
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  LOG=$(git log --oneline -3 2>/dev/null || true)
  if [[ -n "$LOG" ]]; then
    echo "$LOG"
    # One-line summary: "15 files changed, 410 insertions(+), 38 deletions(-)"
    SUMMARY=$(git diff --stat HEAD~3 2>/dev/null | tail -1 || true)
    [[ -n "$SUMMARY" ]] && echo "$SUMMARY"
  fi
fi

# Session name suggestion based on recent commits
if [[ -n "${LOG:-}" ]]; then
  FIRST_COMMIT=$(echo "$LOG" | head -1 | sed 's/^[a-f0-9]* //')
  echo "Session name suggestion: $FIRST_COMMIT"
fi

echo "=== End ==="

# --- Conversation context extraction ---
# Parse transcript JSONL to preserve discussion context through compaction.
# Output: .compact-context.md (consumed once by session-start.sh)

TRANSCRIPT_PATH=""
if [[ -n "$STDIN_DATA" ]] && command -v jq &>/dev/null; then
  TRANSCRIPT_PATH=$(echo "$STDIN_DATA" | jq -r '.transcript_path // empty' 2>/dev/null || true)
fi

# Skip if no transcript available
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

PROJECT_ROOT="$(pwd)"
CONTEXT_FILE="$PROJECT_ROOT/.compact-context.md"

{
  echo "## Conversation Context (pre-compaction)"
  echo ""

  # 1. Recent conversation (last ~5 user+assistant pairs, 150 char truncate)
  echo "### Recent Discussion"
  echo ""
  tail -500 "$TRANSCRIPT_PATH" | jq -r '
    if .type == "user" and .userType == "external" then
      (.message.content |
        if type == "string" then .
        elif type == "array" then
          ([.[] | select(type == "object" and .type == "text") | .text] | join(" "))
        else ""
        end
      | gsub("\n"; " ") | gsub("  +"; " ")) as $text |
      if ($text | length) > 0 then
        "- **User**: " + (if ($text | length) > 150 then ($text[0:150] + "...") else $text end)
      else empty
      end
    elif .type == "assistant" then
      ([.message.content[]? | select(.type == "text") | .text] | join(" ")
      | gsub("\n"; " ") | gsub("  +"; " ")) as $text |
      if ($text | length) > 0 then
        "- **Assistant**: " + (if ($text | length) > 150 then ($text[0:150] + "...") else $text end)
      else empty
      end
    else empty
    end
  ' 2>/dev/null | tail -10 || true

  echo ""

  # 2. Modified files (from Edit/Write tool_use, deduplicated)
  echo "### Modified Files"
  echo ""
  MODIFIED=$(tail -500 "$TRANSCRIPT_PATH" | jq -r '
    select(.type == "assistant") | .message.content[]? |
    select(.type == "tool_use" and (.name == "Edit" or .name == "Write")) |
    .input.file_path // empty
  ' 2>/dev/null | sort -u || true)

  if [[ -n "$MODIFIED" ]]; then
    echo "$MODIFIED" | while IFS= read -r fpath; do
      # Convert to relative path
      echo "- ${fpath#$PROJECT_ROOT/}"
    done
  else
    echo "(none detected)"
  fi

  echo ""

  # 3. Uncommitted changes
  echo "### Uncommitted Changes"
  echo ""
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    STATUS=$(git status --short 2>/dev/null || true)
    if [[ -n "$STATUS" ]]; then
      echo "$STATUS"
    else
      echo "(working tree clean)"
    fi
  else
    echo "(not a git repo)"
  fi

} >"$CONTEXT_FILE" 2>/dev/null || true

exit 0
