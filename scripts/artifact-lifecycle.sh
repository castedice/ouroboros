#!/usr/bin/env bash
# Artifact lifecycle manager for SWE pipeline (DR-041)
#
# Manages the three-tier artifact directory structure:
#   .swe/active/    — current turn's working artifacts
#   .swe/record/    — completed turn archives
#
# Usage:
#   artifact-lifecycle.sh init                              — create .swe/active/ directory
#   artifact-lifecycle.sh archive <slug> [--package <name>] — move active/ → record/{pkg}/{NNN}-{slug}/
#   artifact-lifecycle.sh status                            — JSON: active files + record summary
#   artifact-lifecycle.sh next-number [--package <name>]    — next turn number for package
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — operation failed

set -uo pipefail

ACTION="${1:?Usage: artifact-lifecycle.sh <action> [args...]}"
shift

# ─── Action: init ───
#   Args: none
#   Creates .swe/active/ directory. No-op if exists.

action_init() {
  mkdir -p .swe/active
  echo "Initialized .swe/active/"
}

# ─── Action: archive ───
#   Args: <slug> [--package <name>]
#   Moves active/ artifacts to record/{package}/{NNN}-{slug}/

action_archive() {
  local slug="${1:?Missing slug. Usage: artifact-lifecycle.sh archive <slug> [--package <name>]}"
  shift

  # Parse --package flag
  local package=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package)
        package="${2:?Missing package name after --package}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  # Check active/ has files
  if [[ ! -d .swe/active ]] || [[ -z "$(ls -A .swe/active 2>/dev/null)" ]]; then
    echo "Error: .swe/active/ is empty or does not exist. Nothing to archive." >&2
    exit 2
  fi

  # Auto-detect package if not provided
  if [[ -z "$package" ]]; then
    package=$(_detect_package)
  fi

  # Determine next turn number
  local number
  number=$(_next_number "$package")

  # Create target directory
  local target=".swe/record/${package}/${number}-${slug}"
  mkdir -p "$target"

  # Move all files from active/ to target/
  local count=0
  for f in .swe/active/*; do
    [[ -e "$f" ]] || continue
    mv "$f" "$target/"
    count=$((count + 1))
  done

  echo "Archived ${count} artifacts to ${target}/"
}

# ─── Action: status ───
#   Args: none
#   JSON output: active files + record summary

action_status() {
  local json="{"

  # Active files
  json="${json}\"active\":["
  local first=1
  if [[ -d .swe/active ]]; then
    for f in .swe/active/*; do
      [[ -e "$f" ]] || continue
      if [[ "$first" -eq 0 ]]; then
        json="${json},"
      fi
      first=0
      json="${json}\"$(basename "$f")\""
    done
  fi
  json="${json}],"

  # Record packages and turn counts
  json="${json}\"record\":{"
  first=1
  if [[ -d .swe/record ]]; then
    for pkg_dir in .swe/record/*/; do
      [[ -d "$pkg_dir" ]] || continue
      local pkg_name
      pkg_name=$(basename "$pkg_dir")
      local turn_count=0
      for turn_dir in "${pkg_dir}"[0-9][0-9][0-9]-*/; do
        [[ -d "$turn_dir" ]] || continue
        turn_count=$((turn_count + 1))
      done
      if [[ "$first" -eq 0 ]]; then
        json="${json},"
      fi
      first=0
      json="${json}\"${pkg_name}\":${turn_count}"
    done
  fi
  json="${json}}"

  json="${json}}"
  echo "$json"
}

# ─── Action: next-number ───
#   Args: [--package <name>]
#   Prints the next turn number for the given package

action_next_number() {
  local package=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --package)
        package="${2:?Missing package name after --package}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "$package" ]]; then
    package=$(_detect_package)
  fi

  _next_number "$package"
}

# ─── Helpers ───

_next_number() {
  local package="$1"
  local pkg_dir=".swe/record/${package}"
  if [[ ! -d "$pkg_dir" ]]; then
    echo "001"
    return
  fi
  local max
  max=$(ls -1d "$pkg_dir"/[0-9][0-9][0-9]-* 2>/dev/null | sort -t/ -k4 | tail -1 | sed 's|.*/\([0-9]*\)-.*|\1|')
  if [[ -z "$max" ]]; then
    echo "001"
    return
  fi
  printf "%03d" $((10#$max + 1))
}

_detect_package() {
  # 1. Cargo.toml → package name
  if [[ -f Cargo.toml ]]; then
    local name
    name=$(sed -n '/^\[package\]/,/^\[/{s/^name *= *"\(.*\)"/\1/p;}' Cargo.toml | head -1)
    if [[ -n "$name" ]]; then
      echo "$name"
      return
    fi
  fi
  # 2. package.json → name
  if [[ -f package.json ]]; then
    local name
    name=$(sed -n 's/^ *"name" *: *"\(.*\)".*/\1/p' package.json | head -1)
    if [[ -n "$name" ]]; then
      echo "$name"
      return
    fi
  fi
  # 3. go.mod → module
  if [[ -f go.mod ]]; then
    local name
    name=$(sed -n 's/^module *\(.*\)/\1/p' go.mod | head -1)
    if [[ -n "$name" ]]; then
      # Use last path component as package name
      echo "${name##*/}"
      return
    fi
  fi
  # 4. Fallback
  echo "default"
}

# ─── Dispatch ───

case "$ACTION" in
  init) action_init ;;
  archive) action_archive "$@" ;;
  status) action_status ;;
  next-number) action_next_number "$@" ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: init|archive|status|next-number" >&2
    exit 1
    ;;
esac
