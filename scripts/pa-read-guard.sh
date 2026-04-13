#!/usr/bin/env bash
# PreToolUse Read guard — deny vault note reads per .pa/deny-paths.json
#
# Receives hook JSON on stdin (same protocol as validate-url.sh).
# If the path matches a denied pattern, exit 2 (block) with guidance.
# If deny-paths.json is absent, exit 0 (pass) — PA-unaware users unaffected.
#
# Allowed paths: .pa/ directory, shadow_root directory.
# Denied paths: authored vault content listed in deny-paths.json.

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Parse file_path from tool_input
FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

# No file_path means not a Read call we care about
[[ -n "$FILE_PATH" ]] || exit 0

# Resolve symlinks for consistent matching
if [[ -e "$FILE_PATH" ]]; then
  RESOLVED_PATH=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd -P)/$(basename "$FILE_PATH")
else
  RESOLVED_PATH="$FILE_PATH"
fi

# Find deny-paths.json by scanning known vault locations
# Strategy: check if the file path is under a known vault root
find_deny_paths() {
  local path="$1"

  # Check PA_VAULT_PATH env
  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    local expanded="${PA_VAULT_PATH/#\~/$HOME}"
    if [[ -f "$expanded/.pa/deny-paths.json" ]]; then
      printf '%s/.pa/deny-paths.json\n' "$expanded"
      return 0
    fi
  fi

  # Walk up from file_path to find .pa/deny-paths.json
  local dir
  dir=$(dirname "$path")
  local max_depth=10
  local i=0
  while [[ "$dir" != "/" && $i -lt $max_depth ]]; do
    if [[ -f "$dir/.pa/deny-paths.json" ]]; then
      printf '%s/.pa/deny-paths.json\n' "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
    i=$((i + 1))
  done

  return 1
}

DENY_FILE=""
DENY_FILE=$(find_deny_paths "$RESOLVED_PATH") || true

# No deny-paths.json → pass through (PA not configured)
[[ -n "$DENY_FILE" ]] || exit 0

# Parse deny-paths.json
VAULT_ROOT=$(jq -r '.vault_root // empty' "$DENY_FILE" 2>/dev/null || true)
SHADOW_ROOT=$(jq -r '.shadow_root // empty' "$DENY_FILE" 2>/dev/null || true)

# Expand ~ in paths
VAULT_ROOT="${VAULT_ROOT/#\~/$HOME}"
SHADOW_ROOT="${SHADOW_ROOT/#\~/$HOME}"

[[ -n "$VAULT_ROOT" ]] || exit 0

# Check if file is under the vault root at all
if [[ "$RESOLVED_PATH" != "$VAULT_ROOT"/* ]]; then
  # Not a vault path — pass through
  exit 0
fi

# Always allow .pa/ paths
if [[ "$RESOLVED_PATH" == "$VAULT_ROOT/.pa/"* || "$RESOLVED_PATH" == "$VAULT_ROOT/.pa" ]]; then
  exit 0
fi

# Always allow shadow_root paths
if [[ -n "$SHADOW_ROOT" ]]; then
  SHADOW_ROOT="${SHADOW_ROOT/#\~/$HOME}"
  if [[ "$RESOLVED_PATH" == "$SHADOW_ROOT"/* || "$RESOLVED_PATH" == "$SHADOW_ROOT" ]]; then
    exit 0
  fi
fi

# Check allowed_prefixes
ALLOWED_COUNT=$(jq -r '.allowed_prefixes | length' "$DENY_FILE" 2>/dev/null || echo "0")
REL_PATH="${RESOLVED_PATH#"$VAULT_ROOT"/}"
i=0
while [[ $i -lt $ALLOWED_COUNT ]]; do
  PREFIX=$(jq -r ".allowed_prefixes[$i]" "$DENY_FILE" 2>/dev/null || true)
  if [[ -n "$PREFIX" && "$REL_PATH" == "$PREFIX"* ]]; then
    exit 0
  fi
  i=$((i + 1))
done

# Check denied_paths patterns
DENIED_COUNT=$(jq -r '.denied_paths | length' "$DENY_FILE" 2>/dev/null || echo "0")
i=0
while [[ $i -lt $DENIED_COUNT ]]; do
  PATTERN=$(jq -r ".denied_paths[$i]" "$DENY_FILE" 2>/dev/null || true)
  [[ -n "$PATTERN" ]] || {
    i=$((i + 1))
    continue
  }

  # Convert glob pattern to a prefix match
  # "notes/**" → check if REL_PATH starts with "notes/"
  # "journal/**" → check if REL_PATH starts with "journal/"
  DIR_PREFIX="${PATTERN%%/\*\*}"
  if [[ "$DIR_PREFIX" != "$PATTERN" ]]; then
    # Pattern was dir/** — match prefix
    if [[ "$REL_PATH" == "$DIR_PREFIX/"* || "$REL_PATH" == "$DIR_PREFIX" ]]; then
      # Denied — check shadow exists
      if [[ -n "$SHADOW_ROOT" && -f "$SHADOW_ROOT/$REL_PATH" ]]; then
        echo "Read denied: authored vault content. Use shadow path instead: $SHADOW_ROOT/$REL_PATH" >&2
      else
        echo "Read denied: authored vault content is protected. Shadow copy not found for: $REL_PATH" >&2
      fi
      exit 2
    fi
  else
    # Exact pattern match
    if [[ "$REL_PATH" == "$PATTERN" ]]; then
      if [[ -n "$SHADOW_ROOT" && -f "$SHADOW_ROOT/$REL_PATH" ]]; then
        echo "Read denied: authored vault content. Use shadow path instead: $SHADOW_ROOT/$REL_PATH" >&2
      else
        echo "Read denied: authored vault content is protected. Shadow copy not found for: $REL_PATH" >&2
      fi
      exit 2
    fi
  fi
  i=$((i + 1))
done

# No denied pattern matched — pass through
exit 0
