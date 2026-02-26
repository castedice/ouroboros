#!/usr/bin/env bash
# Recoverable deletion — project-local .trash/ directory
#
# Actions:
#   delete [-f] <files...>   — move files to .trash/ (recoverable)
#   list [pattern]            — show .trash/ contents, optionally filtered
#   restore <filename> [dest] — restore file from .trash/ (dest defaults to .)
#   purge [--days N]          — permanently delete old files (default: 7 days)
#
# Usage:
#   bash scripts/safe-rm.sh delete file1 file2
#   bash scripts/safe-rm.sh -f file1 file2           # implicit delete
#   bash scripts/safe-rm.sh list
#   bash scripts/safe-rm.sh list relay
#   bash scripts/safe-rm.sh restore 1740000000_relay.txt .tmp/
#   bash scripts/safe-rm.sh purge --days 3
#
# Files are stored as {unix-timestamp}_{original-name} in .trash/ for uniqueness.
# The .trash/ directory should be in .gitignore.

set -euo pipefail

TRASH_DIR=".trash"

# ─── Action: delete ───

action_delete() {
  local args=()
  for arg in "$@"; do
    [[ "$arg" == "-f" ]] && continue
    args+=("$arg")
  done

  [[ ${#args[@]} -eq 0 ]] && exit 0

  mkdir -p "$TRASH_DIR"
  local ts
  ts=$(date +%s)

  for file in "${args[@]}"; do
    if [[ -e "$file" ]]; then
      local basename
      basename=$(basename "$file")
      mv "$file" "$TRASH_DIR/${ts}_${basename}"
    fi
  done
}

# ─── Action: list ───

action_list() {
  local pattern="${1:-}"

  if [[ ! -d "$TRASH_DIR" ]] || [[ -z "$(ls -A "$TRASH_DIR" 2>/dev/null)" ]]; then
    echo "(trash is empty)"
    exit 0
  fi

  echo "Trashed files (newest first):"
  echo ""

  if [[ -n "$pattern" ]]; then
    ls -t "$TRASH_DIR" | grep -i "$pattern" | while read -r entry; do
      _print_entry "$entry"
    done
  else
    ls -t "$TRASH_DIR" | head -20 | while read -r entry; do
      _print_entry "$entry"
    done
  fi
}

_print_entry() {
  local entry="$1"
  local ts="${entry%%_*}"
  local name="${entry#*_}"
  local date_str
  if [[ "$(uname)" == "Darwin" ]]; then
    date_str=$(date -r "$ts" "+%m-%d %H:%M" 2>/dev/null || echo "unknown")
  else
    date_str=$(date -d "@$ts" "+%m-%d %H:%M" 2>/dev/null || echo "unknown")
  fi
  printf "  %s  %s  (%s)\n" "$date_str" "$name" "$entry"
}

# ─── Action: restore ───

action_restore() {
  local query="${1:-}"
  local dest="${2:-.}"

  if [[ -z "$query" ]]; then
    echo "Error: filename required. Usage: safe-rm.sh restore <filename> [dest]" >&2
    exit 1
  fi

  if [[ ! -d "$TRASH_DIR" ]]; then
    echo "Trash is empty." >&2
    exit 1
  fi

  # Exact match first (full entry name with timestamp)
  if [[ -e "$TRASH_DIR/$query" ]]; then
    local name="${query#*_}"
    mv "$TRASH_DIR/$query" "$dest/$name"
    echo "Restored: $name → $dest/"
    return
  fi

  # Fuzzy match: find most recent entry containing query
  local match
  match=$(ls -t "$TRASH_DIR" | grep -i "$query" | head -1)

  if [[ -n "$match" ]]; then
    local name="${match#*_}"
    mv "$TRASH_DIR/$match" "$dest/$name"
    echo "Restored: $name → $dest/"
  else
    echo "No match for '$query' in trash." >&2
    echo "Use 'safe-rm.sh list' to see available files." >&2
    exit 1
  fi
}

# ─── Action: purge ───

action_purge() {
  local days=7
  if [[ "${1:-}" == "--days" ]] && [[ -n "${2:-}" ]]; then
    days="$2"
  fi

  if [[ ! -d "$TRASH_DIR" ]]; then
    echo "Trash is empty."
    exit 0
  fi

  local cutoff
  cutoff=$(($(date +%s) - days * 86400))
  local count=0

  for entry in "$TRASH_DIR"/*; do
    [[ -e "$entry" ]] || continue
    local basename
    basename=$(basename "$entry")
    local ts="${basename%%_*}"
    if [[ "$ts" =~ ^[0-9]+$ ]] && ((ts < cutoff)); then
      rm -rf "$entry"
      count=$((count + 1))
    fi
  done

  echo "Purged $count files older than $days days."
}

# ─── Dispatch ───

ACTION="${1:-}"

case "$ACTION" in
  delete)
    shift
    action_delete "$@"
    ;;
  list)
    shift
    action_list "${1:-}"
    ;;
  restore)
    shift
    action_restore "${1:-}" "${2:-}"
    ;;
  purge)
    shift
    action_purge "$@"
    ;;
  -f | "")
    # Implicit delete: safe-rm.sh -f file...
    action_delete "$@"
    ;;
  *)
    # No recognized action — treat all args as files to delete
    action_delete "$@"
    ;;
esac
