#!/usr/bin/env bash
# Knowledge entry catalog manager for ouroboros
#
# Reports on knowledge base health, tag distribution, and content overlap:
#   knowledge-catalog.sh report        — full catalog table + tag index + overlap + recommendations
#   knowledge-catalog.sh tags          — tag frequency (descending)
#   knowledge-catalog.sh overlap       — tag overlap matrix (30%+ pairs)
#
# Exit codes:
#   0 — success
#   1 — invalid arguments
#   2 — I/O error

set -uo pipefail

ACTION="${1:?Usage: knowledge-catalog.sh <report|tags|overlap>}"
shift

KNOWLEDGE_DIR="docs/knowledge"

# ─── Helpers ───

# Extract frontmatter field value from a markdown file.
# Usage: _frontmatter_field <file> <field>
_frontmatter_field() {
  local file="$1"
  local field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | sed -n "s/^${field}: *//p" | head -1
}

# Extract tags array from frontmatter as space-separated list.
# Handles: tags: [tag1, tag2, tag3]
_extract_tags() {
  local file="$1"
  _frontmatter_field "$file" "tags" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$'
}

# Count shared tags between two files. Outputs the count.
_shared_tag_count() {
  local file1="$1"
  local file2="$2"
  comm -12 <(_extract_tags "$file1" | sort) <(_extract_tags "$file2" | sort) | wc -l | tr -d ' '
}

# ─── Action: report ───
#   Args: none
#   Output: full catalog report

action_report() {
  if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
    echo "Error: $KNOWLEDGE_DIR not found." >&2
    exit 2
  fi

  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(ls -1 "$KNOWLEDGE_DIR"/*.md 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No knowledge entries found."
    return
  fi

  echo "# Knowledge Catalog Report"
  echo ""
  echo "**Entries**: ${#files[@]}"
  echo "**Directory**: $KNOWLEDGE_DIR"
  echo ""

  # ── Catalog Table ──
  echo "## Entries"
  echo ""
  printf "%-4s  %-55s  %-12s  %-12s  %s\n" "#" "File" "Status" "Created" "Tags"
  printf "%-4s  %-55s  %-12s  %-12s  %s\n" "---" "-------------------------------------------------------" "------------" "------------" "----"

  local idx=1
  local missing_status=()
  local missing_related=()
  for f in "${files[@]}"; do
    local basename
    basename=$(basename "$f")
    local status
    status=$(_frontmatter_field "$f" "status")
    local created
    created=$(_frontmatter_field "$f" "created")
    local tags
    tags=$(_frontmatter_field "$f" "tags")

    if [[ -z "$status" ]]; then
      missing_status+=("$basename")
      status="(missing)"
    fi

    local related
    related=$(_frontmatter_field "$f" "related")
    if [[ -z "$related" ]]; then
      missing_related+=("$basename")
    fi

    printf "%-4s  %-55s  %-12s  %-12s  %s\n" "$idx" "$basename" "$status" "${created:--}" "${tags:--}"
    idx=$((idx + 1))
  done

  echo ""

  # ── Tag Index ──
  echo "## Tag Index"
  echo ""
  _print_tags "${files[@]}"
  echo ""

  # ── Overlap Pairs ──
  echo "## High Overlap Pairs (50%+)"
  echo ""
  _print_overlap 50 "${files[@]}"
  echo ""

  # ── Health Checks ──
  echo "## Health"
  echo ""

  if [[ ${#missing_status[@]} -gt 0 ]]; then
    echo "**Missing \`status\` field** (${#missing_status[@]}):"
    for f in "${missing_status[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if [[ ${#missing_related[@]} -gt 0 ]]; then
    echo "**Missing \`related\` field** (${#missing_related[@]}):"
    for f in "${missing_related[@]}"; do
      echo "  - $f"
    done
    echo ""
  fi

  if [[ ${#missing_status[@]} -eq 0 && ${#missing_related[@]} -eq 0 ]]; then
    echo "All entries have status and related fields."
    echo ""
  fi

  # ── Recommendations ──
  echo "## Recommendations"
  echo ""
  if [[ ${#missing_status[@]} -gt 0 ]]; then
    echo "- Backfill \`status: active\` on ${#missing_status[@]} entries"
  fi
  if [[ ${#missing_related[@]} -gt 0 ]]; then
    echo "- Backfill \`related: []\` on ${#missing_related[@]} entries"
  fi
  echo "- Review high-overlap pairs for potential consolidation or supersession"
}

# ─── Action: tags ───
#   Args: none
#   Output: tag frequency table (descending)

action_tags() {
  if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
    echo "Error: $KNOWLEDGE_DIR not found." >&2
    exit 2
  fi

  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(ls -1 "$KNOWLEDGE_DIR"/*.md 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No knowledge entries found."
    return
  fi

  _print_tags "${files[@]}"
}

# Print tag frequency table
_print_tags() {
  local files=("$@")

  # Collect all tags with frequency
  local -A tag_counts
  for f in "${files[@]}"; do
    while IFS= read -r tag; do
      [[ -z "$tag" ]] && continue
      tag_counts["$tag"]=$((${tag_counts["$tag"]:-0} + 1))
    done < <(_extract_tags "$f")
  done

  # Sort by frequency (descending), then alphabetically
  printf "%-4s  %-45s  %s\n" "#" "Tag" "Count"
  printf "%-4s  %-45s  %s\n" "---" "---------------------------------------------" "-----"

  local idx=1
  for tag in $(for k in "${!tag_counts[@]}"; do echo "${tag_counts[$k]} $k"; done | sort -rn -k1 -k2 | awk '{print $2}'); do
    printf "%-4s  %-45s  %s\n" "$idx" "$tag" "${tag_counts[$tag]}"
    idx=$((idx + 1))
  done
}

# ─── Action: overlap ───
#   Args: none
#   Output: tag overlap matrix (30%+ pairs)

action_overlap() {
  if [[ ! -d "$KNOWLEDGE_DIR" ]]; then
    echo "Error: $KNOWLEDGE_DIR not found." >&2
    exit 2
  fi

  local files=()
  while IFS= read -r f; do
    files+=("$f")
  done < <(ls -1 "$KNOWLEDGE_DIR"/*.md 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "No knowledge entries found."
    return
  fi

  _print_overlap 30 "${files[@]}"
}

# Print overlap pairs above threshold
# Usage: _print_overlap <threshold_percent> <files...>
_print_overlap() {
  local threshold="$1"
  shift
  local files=("$@")

  printf "%-45s  %-45s  %s\n" "Entry A" "Entry B" "Overlap"
  printf "%-45s  %-45s  %s\n" "---------------------------------------------" "---------------------------------------------" "-------"

  local found=0
  for ((i = 0; i < ${#files[@]}; i++)); do
    for ((j = i + 1; j < ${#files[@]}; j++)); do
      local fa="${files[$i]}"
      local fb="${files[$j]}"

      local tags_a tags_b shared
      tags_a=$(_extract_tags "$fa" | wc -l | tr -d ' ')
      tags_b=$(_extract_tags "$fb" | wc -l | tr -d ' ')
      shared=$(_shared_tag_count "$fa" "$fb")

      if [[ "$tags_a" -eq 0 || "$tags_b" -eq 0 ]]; then
        continue
      fi

      # Overlap = shared / min(tags_a, tags_b) * 100
      local min_tags=$tags_a
      if [[ "$tags_b" -lt "$min_tags" ]]; then
        min_tags=$tags_b
      fi

      local pct=$((shared * 100 / min_tags))

      if [[ "$pct" -ge "$threshold" ]]; then
        printf "%-45s  %-45s  %s%%\n" "$(basename "$fa")" "$(basename "$fb")" "$pct"
        found=$((found + 1))
      fi
    done
  done

  if [[ "$found" -eq 0 ]]; then
    echo "(no pairs above ${threshold}% threshold)"
  fi
}

# ─── Dispatch ───

case "$ACTION" in
  report) action_report ;;
  tags) action_tags ;;
  overlap) action_overlap ;;
  *)
    echo "Error: unknown action '$ACTION'. Use: report|tags|overlap" >&2
    exit 1
    ;;
esac
