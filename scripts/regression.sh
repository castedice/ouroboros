#!/usr/bin/env bash
# Regression evaluation helper for ouroboros (Phase 3 Step 2)
#
# Mechanical operations for evaluation result persistence:
#   regression.sh enumerate <module>    — list components as JSON array
#   regression.sh hash <file>           — SHA-256 content hash
#   regression.sh save <module>         — save stdin JSON to dev/evaluations/, update symlink
#   regression.sh latest <module>       — print path to latest result file
#   regression.sh list <module>         — list all evaluation runs for a module
#   regression.sh history <module> [--limit N] — show evaluation history with trends
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — I/O error

set -uo pipefail

ACTION="${1:?Usage: regression.sh <enumerate|hash|save|latest|list|history> ...}"
shift

# ─── Action: enumerate ───
#   Args: <module>
#   Output: JSON array of { path, type } objects

action_enumerate() {
  local module="${1:?Missing module name}"
  local first=true

  echo "["

  # Scan evaluatable component directories (templates excluded — no criteria)
  for dir_type in "agents:agent" "commands:command" "skills:skill"; do
    local dir="${dir_type%%:*}"
    local type="${dir_type##*:}"
    local search_path="${dir}/${module}"

    if [[ ! -d "$search_path" ]]; then
      continue
    fi

    # Skills have SKILL.md at module level + references/*.md
    if [[ "$type" == "skill" ]]; then
      # Find all SKILL.md files (can be nested in subdirectories)
      while IFS= read -r -d '' file; do
        if [[ "$first" == true ]]; then
          first=false
        else
          printf ",\n"
        fi
        printf '  {"path": "%s", "type": "skill"}' "$file"
      done < <(find "$search_path" -name "SKILL.md" -print0 2>/dev/null | sort -z)
      continue
    fi

    # Other types: all .md files directly in the directory
    while IFS= read -r -d '' file; do
      if [[ "$first" == true ]]; then
        first=false
      else
        printf ",\n"
      fi
      printf '  {"path": "%s", "type": "%s"}' "$file" "$type"
    done < <(find "$search_path" -maxdepth 1 -name "*.md" -print0 2>/dev/null | sort -z)
  done

  # Check for hooks
  if [[ -f "hooks/hooks.json" ]]; then
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ",\n"
    fi
    printf '  {"path": "hooks/hooks.json", "type": "hook"}'
  fi

  # Check for CLAUDE.md
  if [[ -f "CLAUDE.md" ]]; then
    if [[ "$first" == true ]]; then
      first=false
    else
      printf ",\n"
    fi
    printf '  {"path": "CLAUDE.md", "type": "claudemd"}'
  fi

  echo ""
  echo "]"
}

# ─── Action: hash ───
#   Args: <file>
#   Output: sha256:{hex} to stdout

action_hash() {
  local file="${1:?Missing file path}"

  if [[ ! -f "$file" ]]; then
    echo "Error: file not found: $file" >&2
    exit 2
  fi

  local hash
  hash=$(shasum -a 256 "$file" | cut -d' ' -f1)
  echo "sha256:${hash}"
}

# ─── Action: save ───
#   Args: <module>
#   Stdin: JSON content
#   Output: saved file path to stdout

action_save() {
  local module="${1:?Missing module name}"
  local eval_dir="dev/evaluations"

  mkdir -p "$eval_dir"

  # Get current date and git sha
  local date_str
  date_str=$(date +%Y-%m-%d)
  local git_sha
  git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

  # Get unique run number (monotonic counter)
  local run_number
  run_number=$(_next_run_number "$module" "$eval_dir")

  local filename="${module}-${run_number}-${date_str}-${git_sha}.json"
  local filepath="${eval_dir}/${filename}"

  # Read stdin and save
  if ! cat >"$filepath"; then
    echo "Error: failed to write $filepath" >&2
    exit 2
  fi

  # Update symlink
  local symlink="${eval_dir}/${module}-latest.json"
  local script_dir
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  bash "$script_dir/safe-rm.sh" -f "$symlink"
  ln -s "$filename" "$symlink"

  echo "$filepath"
}

# ─── Action: latest ───
#   Args: <module>
#   Output: resolved path to latest result file

action_latest() {
  local module="${1:?Missing module name}"
  local symlink="dev/evaluations/${module}-latest.json"

  if [[ ! -L "$symlink" ]]; then
    echo "Error: no latest result for module '$module'" >&2
    exit 2
  fi

  # Resolve symlink to actual file path
  local target
  target=$(readlink "$symlink")
  local resolved="dev/evaluations/${target}"

  if [[ ! -f "$resolved" ]]; then
    echo "Error: symlink target not found: $resolved" >&2
    exit 2
  fi

  echo "$resolved"
}

# ─── Action: list ───
#   Args: <module>
#   Output: table of all evaluation runs for the module

action_list() {
  local module="${1:?Missing module name}"
  local eval_dir="dev/evaluations"

  if [[ ! -d "$eval_dir" ]]; then
    echo "No evaluations directory found." >&2
    exit 2
  fi

  # Find non-symlink JSON files for this module, sorted
  local files=()
  while IFS= read -r f; do
    [[ -L "$f" ]] && continue
    files+=("$f")
  done < <(ls -1 "$eval_dir/${module}"-*.json 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No evaluation runs found for module '$module'."
    return
  fi

  # Header
  printf "%-4s  %-50s  %-25s  %-10s  %s\n" "#" "File" "Timestamp" "SHA" "Components"
  printf "%-4s  %-50s  %-25s  %-10s  %s\n" "---" "--------------------------------------------------" "-------------------------" "----------" "----------"

  local idx=1
  for f in "${files[@]}"; do
    local basename
    basename=$(basename "$f")
    local timestamp
    timestamp=$(sed -n 's/.*"timestamp" *: *"\([^"]*\)".*/\1/p' "$f" | head -1)
    local sha
    sha=$(sed -n 's/.*"git_sha" *: *"\([^"]*\)".*/\1/p' "$f" | head -1)
    local total
    total=$(sed -n 's/.*"total" *: *\([0-9]*\).*/\1/p' "$f" | head -1)

    printf "%-4s  %-50s  %-25s  %-10s  %s\n" "$idx" "$basename" "${timestamp:--}" "${sha:--}" "${total:--}"
    idx=$((idx + 1))
  done
}

# ─── Action: history ───
#   Args: <module> [--limit N]
#   Output: reverse-chronological evaluation history with level distribution and trends

action_history() {
  local module="${1:?Missing module name}"
  shift
  local limit=10

  # Parse --limit flag
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit)
        limit="${2:?Missing limit value after --limit}"
        shift 2
        ;;
      *)
        echo "Error: unknown flag '$1'" >&2
        exit 1
        ;;
    esac
  done

  local eval_dir="dev/evaluations"

  if [[ ! -d "$eval_dir" ]]; then
    echo "No evaluations directory found." >&2
    exit 2
  fi

  # Find non-symlink JSON files for this module, sorted (newest last)
  local files=()
  while IFS= read -r f; do
    [[ -L "$f" ]] && continue
    files+=("$f")
  done < <(ls -1 "$eval_dir/${module}"-*.json 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No evaluation runs found for module '$module'."
    return
  fi

  # Reverse for newest-first display, apply limit
  local reversed=()
  for ((i = ${#files[@]} - 1; i >= 0; i--)); do
    reversed+=("${files[$i]}")
    if [[ ${#reversed[@]} -ge $limit ]]; then
      break
    fi
  done

  # Header
  printf "%-4s  %-25s  %-10s  %-6s  %-20s  %s\n" "#" "Timestamp" "SHA" "Total" "Levels (1/2/3/4)" "Trend"
  printf "%-4s  %-25s  %-10s  %-6s  %-20s  %s\n" "---" "-------------------------" "----------" "------" "--------------------" "-----"

  local prev_l1="" prev_l2="" prev_l3="" prev_l4=""
  local idx=1
  for f in "${reversed[@]}"; do
    local timestamp
    timestamp=$(sed -n 's/.*"timestamp" *: *"\([^"]*\)".*/\1/p' "$f" | head -1)
    local sha
    sha=$(sed -n 's/.*"git_sha" *: *"\([^"]*\)".*/\1/p' "$f" | head -1)
    local total
    total=$(sed -n 's/.*"total" *: *\([0-9]*\).*/\1/p' "$f" | head -1)

    # Extract level distribution
    local l1 l2 l3 l4
    l1=$(sed -n 's/.*"1" *: *\([0-9]*\).*/\1/p' "$f" | head -1)
    l2=$(sed -n 's/.*"2" *: *\([0-9]*\).*/\1/p' "$f" | head -1)
    l3=$(sed -n 's/.*"3" *: *\([0-9]*\).*/\1/p' "$f" | head -1)
    l4=$(sed -n 's/.*"4" *: *\([0-9]*\).*/\1/p' "$f" | head -1)
    l1="${l1:-0}"
    l2="${l2:-0}"
    l3="${l3:-0}"
    l4="${l4:-0}"

    local levels="${l1}/${l2}/${l3}/${l4}"

    # Calculate trend vs previous (next in chronological order)
    local trend=""
    if [[ -n "$prev_l4" ]]; then
      if [[ "$l4" -gt "$prev_l4" ]]; then
        trend="↑ L4+$((l4 - prev_l4))"
      elif [[ "$l4" -lt "$prev_l4" ]]; then
        trend="↓ L4-$((prev_l4 - l4))"
      else
        trend="="
      fi
    fi

    printf "%-4s  %-25s  %-10s  %-6s  %-20s  %s\n" "$idx" "${timestamp:--}" "${sha:--}" "${total:--}" "$levels" "$trend"

    prev_l1="$l1"
    prev_l2="$l2"
    prev_l3="$l3"
    prev_l4="$l4"
    idx=$((idx + 1))
  done
}

# ─── Helpers ───

# Compute next monotonic run number for a module.
# Scans both new format ({module}-{NNN}-...) and legacy format ({module}-{date}-{sha}.json).
_next_run_number() {
  local module="$1"
  local eval_dir="$2"
  local max=0

  if [[ ! -d "$eval_dir" ]]; then
    printf "%03d" 1
    return
  fi

  # Scan all non-symlink JSON files for this module
  local legacy_count=0
  while IFS= read -r f; do
    [[ -L "$f" ]] && continue
    local basename
    basename=$(basename "$f")
    # New format: {module}-{NNN}-{date}-{sha}.json
    if [[ "$basename" =~ ^${module}-([0-9]{3})- ]]; then
      local num="${BASH_REMATCH[1]}"
      if [[ $((10#$num)) -gt $max ]]; then
        max=$((10#$num))
      fi
    else
      # Legacy format: {module}-{date}-{sha}.json — count as existing runs
      legacy_count=$((legacy_count + 1))
    fi
  done < <(ls -1 "$eval_dir/${module}"-*.json 2>/dev/null)

  # Combine: max of new-format counter and legacy file count
  if [[ $legacy_count -gt $max ]]; then
    max=$legacy_count
  fi

  printf "%03d" $((max + 1))
}

# ─── Dispatch ───

case "$ACTION" in
  enumerate) action_enumerate "$@" ;;
  hash) action_hash "$@" ;;
  save) action_save "$@" ;;
  latest) action_latest "$@" ;;
  list) action_list "$@" ;;
  history) action_history "$@" ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: enumerate|hash|save|latest|list|history" >&2
    exit 1
    ;;
esac
