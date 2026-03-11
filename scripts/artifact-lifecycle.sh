#!/usr/bin/env bash
# Artifact lifecycle manager for SWE pipeline (DR-041, DR-068)
#
# Manages the artifact directory structure:
#   .swe/active/          — current turn's working artifacts (hidden, not committed)
#   docs/specs/record/    — completed turn archives (committed)
#   docs/specs/project/   — living project model (committed)
#
# Monorepo: per-subproject paths under packages/{pkg}/.swe/active/ and
# packages/{pkg}/docs/specs/{record,project}/. Root paths for repo-wide concerns.
#
# Usage:
#   artifact-lifecycle.sh init [--package <name>]                — create .swe/active/
#   artifact-lifecycle.sh init-project [--package <name>]        — create docs/specs/project/ with living model templates
#   artifact-lifecycle.sh archive <slug> [--package <name>]      — move active/ → docs/specs/record/{pkg}/{NNN}-{slug}/
#   artifact-lifecycle.sh status [--package <name>]              — JSON: active files + record summary
#   artifact-lifecycle.sh next-number [--package <name>]         — next turn number for package
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — operation failed

set -uo pipefail

ACTION="${1:?Usage: artifact-lifecycle.sh <action> [args...]}"
shift

# ─── Path Resolution ───

# Resolve the docs/specs base path for a given package scope.
# Single-repo or root scope: docs/specs/
# Monorepo with package: packages/{pkg}/docs/specs/
_resolve_specs_path() {
  local package="${1:-}"
  if [[ -n "$package" && "$package" != "default" ]] && _is_workspace; then
    local pkg_dir
    pkg_dir=$(_workspace_pkg_dir "$package")
    if [[ -n "$pkg_dir" ]]; then
      echo "${pkg_dir}/docs/specs"
      return
    fi
  fi
  echo "docs/specs"
}

# Resolve the .swe/active path for a given package scope.
_resolve_active_path() {
  local package="${1:-}"
  if [[ -n "$package" && "$package" != "default" ]] && _is_workspace; then
    local pkg_dir
    pkg_dir=$(_workspace_pkg_dir "$package")
    if [[ -n "$pkg_dir" ]]; then
      echo "${pkg_dir}/.swe/active"
      return
    fi
  fi
  echo ".swe/active"
}

# ─── Workspace Detection ───

# Check if the current repo is a monorepo workspace.
_is_workspace() {
  [[ -f pnpm-workspace.yaml ]] && return 0
  [[ -f go.work ]] && return 0
  # Cargo workspace
  if [[ -f Cargo.toml ]] && grep -q '^\[workspace\]' Cargo.toml 2>/dev/null; then
    return 0
  fi
  # npm/yarn workspaces
  if [[ -f package.json ]] && grep -q '"workspaces"' package.json 2>/dev/null; then
    return 0
  fi
  return 1
}

# Get the relative directory for a package within the workspace.
# Returns empty string if package directory not found.
_workspace_pkg_dir() {
  local package="$1"
  # Check common monorepo layouts
  for prefix in "packages" "apps" "libs" "crates" "services" "modules"; do
    if [[ -d "${prefix}/${package}" ]]; then
      echo "${prefix}/${package}"
      return
    fi
  done
  # Direct subdirectory check
  if [[ -d "$package" ]]; then
    echo "$package"
    return
  fi
  echo ""
}

# ─── Action: init ───
#   Args: [--package <name>]
#   Creates .swe/active/ directory. No-op if exists.

action_init() {
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

  local active_path
  active_path=$(_resolve_active_path "$package")
  mkdir -p "$active_path"
  echo "Initialized ${active_path}/"
}

# ─── Action: archive ───
#   Args: <slug> [--package <name>]
#   Moves active/ artifacts to docs/specs/record/{package}/{NNN}-{slug}/

action_archive() {
  local slug="${1:?Missing slug. Usage: artifact-lifecycle.sh archive <slug> [--package <name>]}"
  shift

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

  local active_path
  active_path=$(_resolve_active_path "$package")

  if [[ ! -d "$active_path" ]] || [[ -z "$(ls -A "$active_path" 2>/dev/null)" ]]; then
    echo "Error: ${active_path}/ is empty or does not exist. Nothing to archive." >&2
    exit 2
  fi

  if [[ -z "$package" ]]; then
    package=$(_detect_package)
  fi

  local specs_path
  specs_path=$(_resolve_specs_path "$package")
  local number
  number=$(_next_number "$package")

  local target="${specs_path}/record/${package}/${number}-${slug}"
  mkdir -p "$target"

  local count=0
  for f in "$active_path"/*; do
    [[ -e "$f" ]] || continue
    mv "$f" "$target/"
    count=$((count + 1))
  done

  echo "Archived ${count} artifacts to ${target}/"
}

# ─── Action: status ───
#   Args: [--package <name>]
#   JSON output: active files + record summary

action_status() {
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

  local active_path specs_path
  active_path=$(_resolve_active_path "$package")
  specs_path=$(_resolve_specs_path "$package")
  local record_path="${specs_path}/record"

  local json="{"

  # Active files
  json="${json}\"active\":["
  local first=1
  if [[ -d "$active_path" ]]; then
    for f in "$active_path"/*; do
      [[ -e "$f" ]] || continue
      if [[ "$first" -eq 0 ]]; then json="${json},"; fi
      first=0
      json="${json}\"$(basename "$f")\""
    done
  fi
  json="${json}],"

  # Record packages and turn counts
  json="${json}\"record\":{"
  first=1
  if [[ -d "$record_path" ]]; then
    for pkg_dir in "$record_path"/*/; do
      [[ -d "$pkg_dir" ]] || continue
      local pkg_name
      pkg_name=$(basename "$pkg_dir")
      local turn_count=0
      for turn_dir in "${pkg_dir}"[0-9][0-9][0-9]-*/; do
        [[ -d "$turn_dir" ]] || continue
        turn_count=$((turn_count + 1))
      done
      if [[ "$first" -eq 0 ]]; then json="${json},"; fi
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
  local specs_path
  specs_path=$(_resolve_specs_path "")
  local pkg_dir="${specs_path}/record/${package}"
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
      echo "${name##*/}"
      return
    fi
  fi
  # 4. Fallback
  echo "default"
}

# ─── Action: init-project ───
#   Args: [--package <name>]
#   Creates docs/specs/project/ with 4 living model template files. No-op if exists.

action_init_project() {
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

  local specs_path
  specs_path=$(_resolve_specs_path "$package")
  local project_path="${specs_path}/project"

  if [[ -d "$project_path" ]]; then
    echo "${project_path}/ already exists. Skipping."
    return
  fi

  local plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
  local template_dir="$plugin_root/templates/swe"

  mkdir -p "$project_path"

  local today
  today=$(date +%Y-%m-%d)

  local files=("domain" "constraints" "architecture" "interfaces")
  for name in "${files[@]}"; do
    local src="$template_dir/project-${name}.md"
    local dst="${project_path}/${name}.md"
    if [[ -f "$src" ]]; then
      sed "s/{date}/$today/g; s/{NNN}/000/g; s/{slug}/initial/g" "$src" >"$dst"
    else
      echo "Warning: template $src not found, creating minimal $dst" >&2
      echo "# Project ${name^}" >"$dst"
    fi
  done

  echo "Initialized ${project_path}/ (4 living model files)"
}

# ─── Dispatch ───

case "$ACTION" in
  init) action_init "$@" ;;
  init-project) action_init_project "$@" ;;
  archive) action_archive "$@" ;;
  status) action_status "$@" ;;
  next-number) action_next_number "$@" ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: init|init-project|archive|status|next-number" >&2
    exit 1
    ;;
esac
