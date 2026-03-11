#!/usr/bin/env bash
# Port ouroboros methodology skills to .agents/skills/ for cross-tool compatibility.
#
# Usage: port-skills.sh [generate|clean|status]
#   generate  — Create neutralized copies from originals → .agents/skills/
#   clean     — Remove all generated files in .agents/skills/
#   status    — Show diff summary between originals and ported copies
#
# Neutralization transforms:
#   1. name field: strip '-methodology' / 'swe-pipeline-' prefix to match directory name
#   2. See Also section: remove entirely (ouroboros internal paths)
#   3. Slash commands: /evaluate → evaluation, /evolve → evolution workflow, etc.
#   4. Internal paths: docs/decisions/ → project decision log, docs/specs/knowledge/ → knowledge base
#   5. Reference selection: exclude Claude-specific files (hook-criteria, claudemd-criteria, etc.)
#   6. Evaluation types: remove Command/Hook/CLAUDE.md rows (keep Agent/Skill only)
#   7. Agent criteria: neutralize model names and tool names

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$PROJECT_ROOT/.agents/skills"

# ─── Skill definitions: "target_name:source_dir" ───

PORTABLE_SKILLS=(
  "brainstorming:skills/core/brainstorming"
  "swe-constraint:skills/swe/constraint"
  "swe-methodology:skills/swe/methodology"
  "evolution:skills/core/evolution"
  "evaluation:skills/core/evaluation"
)

# References to EXCLUDE from copy (Claude-specific)
EXCLUDE_REFS=(
  "researcher-relay-prompt.md"
  "hook-criteria.md"
  "claudemd-criteria.md"
  "command-criteria.md"
  "evaluator-relay-prompts.md"
  "agent-output-criteria.md"
  "skill-output-criteria.md"
  "command-output-criteria.md"
  "hook-output-criteria.md"
  "regression-format.md"
)

# ─── Common transforms (applied to all SKILL.md) ───

_apply_common_transforms() {
  local target_name="$1"

  sed -E \
    -e "s/^name: .*/name: ${target_name}/" \
    -e 's|`/evaluate`|evaluation|g' \
    -e 's|`/evolve`|the evolution workflow|g' \
    -e 's|`/research`|research|g' \
    -e 's|/evaluate|evaluation|g' \
    -e 's|/evolve |evolution workflow |g' \
    -e 's|/research ([a-z])|research \1|g' \
    -e 's|`docs/decisions/`|project decision log|g' \
    -e 's|`docs/specs/knowledge/`|knowledge base|g' \
    -e 's|in `docs/decisions/`|in the project decision log|g' \
    -e 's|in docs/decisions/|in the project decision log|g' \
    -e 's|using Edit tool|using targeted edits|g' \
    -e 's|Edit tool with specific old/new strings|targeted modifications to specific sections|g'
}

# Remove ## See Also section (from marker to EOF)
_remove_see_also() {
  sed '/^## See Also/,$d'
}

# ─── Skill-specific transforms ───

_transform_brainstorming() {
  _apply_common_transforms "brainstorming" |
    _remove_see_also |
    sed -E \
      -e 's|`/research "caching patterns in CLI tools"`|"research caching patterns in CLI tools"|g' \
      -e 's|specific command invocations with arguments|specific, actionable next steps with concrete details|g' \
      -e 's|a specific command invocation with arguments, not a generic reference\.|a specific, actionable next step, not a generic reference.|' \
      -e 's|a specific command with arguments, not a template placeholder|a specific action with concrete details, not a template placeholder|'
}

_transform_swe_constraint() {
  _apply_common_transforms "swe-constraint" |
    _remove_see_also
}

_transform_swe_methodology() {
  _apply_common_transforms "swe-methodology" |
    _remove_see_also
}

_transform_evolution() {
  _apply_common_transforms "evolution" |
    _remove_see_also |
    sed -E \
      -e 's|Researcher agent performs|Perform|' \
      -e 's|Researcher agent reads|Read|'
}

_transform_evaluation() {
  _apply_common_transforms "evaluation" |
    _remove_see_also |
    sed -E \
      -e '/^\| `commands\//d' \
      -e '/^\| `hooks\//d' \
      -e '/^\| `CLAUDE\.md`/d' \
      -e '/^\| Command \|/d' \
      -e '/^\| Hook \|/d' \
      -e '/^\| CLAUDE\.md \|/d' \
      -e 's|### Dynamic Evaluation \(4 types — CLAUDE\.md excluded\)|### Dynamic Evaluation|' \
      -e 's|Dynamic criteria assess output quality\. CLAUDE\.md is excluded because it has no executable output\.|Dynamic criteria assess output quality.|'
}

# ─── Reference transforms ───

_transform_divergent_techniques() {
  sed -E \
    -e 's|SCAMPER on `/evaluate` command'\''s Phase 1 \(Parse Input\):|SCAMPER on an evaluation workflow'\''s input parsing phase:|' \
    -e 's|on-demand `/evaluate`|on-demand evaluation|g' \
    -e 's|while keeping `/evaluate` for deep analysis \(manual\)|while keeping manual evaluation for deep analysis|'
}

_transform_bias_patterns() {
  sed -E \
    -e 's|Edit tool with specific old/new strings|targeted modifications to specific sections|g' \
    -e 's|Prefer targeted edits \(Edit tool with specific old/new strings\)|Prefer targeted edits (specific modifications)|'
}

_transform_evolution_stages_detail() {
  sed -E \
    -e 's|run `/evaluate`|run evaluation|g' \
    -e 's|Researcher agent reads the target component and evaluation report|Read the target component and evaluation report|' \
    -e 's|Search knowledge base \(`docs/specs/knowledge/`\)|Search knowledge base|' \
    -e 's|Create decision entry in `docs/decisions/`|Create decision entry in project decision log|' \
    -e 's|in `docs/decisions/` using the evolve template|in the project decision log|'
}

_transform_agent_criteria() {
  sed -E \
    -e 's|Complex reasoning \(architecture, evaluation, deep analysis\) → opus, balanced execution\+analysis → sonnet, fast assistance → haiku|Complex reasoning (architecture, evaluation, deep analysis) → high-capability model, balanced execution+analysis → standard model, fast assistance → lightweight model|' \
    -e 's|Opus for simple tasks, haiku for complex reasoning|High-capability model for simple tasks, lightweight model for complex reasoning|' \
    -e 's|\[Read, Grep, Glob\]|read-only analysis tools|' \
    -e 's|Write/Edit on an analysis agent|write tools on an analysis agent|'
}

# ─── Check if a reference should be excluded ───

_is_excluded_ref() {
  local filename="$1"
  for excluded in "${EXCLUDE_REFS[@]}"; do
    if [[ "$filename" == "$excluded" ]]; then
      return 0
    fi
  done
  return 1
}

# ─── Actions ───

action_generate() {
  echo "Generating ported skills → $TARGET/"

  for entry in "${PORTABLE_SKILLS[@]}"; do
    local target_name="${entry%%:*}"
    local source_dir="$PROJECT_ROOT/${entry#*:}"
    local target_dir="$TARGET/$target_name"

    echo "  [$target_name] from $source_dir"

    # Create target directory
    mkdir -p "$target_dir/references"

    # Transform SKILL.md
    local transform_fn="_transform_${target_name//-/_}"
    if declare -f "$transform_fn" >/dev/null 2>&1; then
      "$transform_fn" <"$source_dir/SKILL.md" >"$target_dir/SKILL.md"
    else
      echo "    WARN: no transform function $transform_fn, using common transforms"
      _apply_common_transforms "$target_name" <"$source_dir/SKILL.md" |
        _remove_see_also >"$target_dir/SKILL.md"
    fi

    # Copy references (with exclusion and optional transforms)
    if [[ -d "$source_dir/references" ]]; then
      local ref_count=0
      local skip_count=0
      for ref_file in "$source_dir/references/"*.md; do
        [[ -f "$ref_file" ]] || continue
        local basename
        basename="$(basename "$ref_file")"

        if _is_excluded_ref "$basename"; then
          skip_count=$((skip_count + 1))
          continue
        fi

        # Apply per-file transforms if available
        local ref_transform="_transform_${basename%.md}"
        ref_transform="${ref_transform//-/_}"
        if declare -f "$ref_transform" >/dev/null 2>&1; then
          "$ref_transform" <"$ref_file" >"$target_dir/references/$basename"
        else
          cp "$ref_file" "$target_dir/references/$basename"
        fi
        ref_count=$((ref_count + 1))
      done
      echo "    refs: ${ref_count} copied, ${skip_count} excluded"
    fi
  done

  echo "Done. $(find "$TARGET" -name '*.md' | wc -l | tr -d ' ') files generated."
}

action_clean() {
  if [[ -d "$TARGET" ]]; then
    echo "Cleaning $TARGET/"
    # Use safe-rm if available, otherwise rm -rf
    if [[ -f "$SCRIPT_DIR/safe-rm.sh" ]]; then
      bash "$SCRIPT_DIR/safe-rm.sh" -rf "$TARGET"
    else
      rm -rf "$TARGET"
    fi
    echo "Done."
  else
    echo "Nothing to clean — $TARGET/ does not exist."
  fi
}

action_status() {
  if [[ ! -d "$TARGET" ]]; then
    echo "No ported skills found. Run 'generate' first."
    exit 1
  fi

  echo "=== Ported Skills Status ==="
  echo ""

  for entry in "${PORTABLE_SKILLS[@]}"; do
    local target_name="${entry%%:*}"
    local source_dir="$PROJECT_ROOT/${entry#*:}"
    local target_dir="$TARGET/$target_name"

    if [[ ! -d "$target_dir" ]]; then
      echo "[$target_name] MISSING — not generated"
      continue
    fi

    # Check SKILL.md diff (compare transformed source vs current target)
    local transform_fn="_transform_${target_name//-/_}"
    local tmp_transformed
    tmp_transformed="$(mktemp)"

    if declare -f "$transform_fn" >/dev/null 2>&1; then
      "$transform_fn" <"$source_dir/SKILL.md" >"$tmp_transformed"
    else
      _apply_common_transforms "$target_name" <"$source_dir/SKILL.md" |
        _remove_see_also >"$tmp_transformed"
    fi

    if diff -q "$tmp_transformed" "$target_dir/SKILL.md" >/dev/null 2>&1; then
      echo "[$target_name] SKILL.md: up to date"
    else
      echo "[$target_name] SKILL.md: STALE — differs from transformed source"
      diff --unified=0 "$tmp_transformed" "$target_dir/SKILL.md" | head -20
    fi
    rm -f "$tmp_transformed"

    # Check reference files
    if [[ -d "$source_dir/references" ]]; then
      local stale_refs=0
      for ref_file in "$source_dir/references/"*.md; do
        [[ -f "$ref_file" ]] || continue
        local basename
        basename="$(basename "$ref_file")"
        _is_excluded_ref "$basename" && continue

        local target_ref="$target_dir/references/$basename"
        if [[ ! -f "$target_ref" ]]; then
          echo "  ref $basename: MISSING"
          stale_refs=$((stale_refs + 1))
        else
          # Check if file needs transform
          local ref_transform="_transform_${basename%.md}"
          ref_transform="${ref_transform//-/_}"
          local tmp_ref
          tmp_ref="$(mktemp)"
          if declare -f "$ref_transform" >/dev/null 2>&1; then
            "$ref_transform" <"$ref_file" >"$tmp_ref"
          else
            cp "$ref_file" "$tmp_ref"
          fi

          if ! diff -q "$tmp_ref" "$target_ref" >/dev/null 2>&1; then
            echo "  ref $basename: STALE"
            stale_refs=$((stale_refs + 1))
          fi
          rm -f "$tmp_ref"
        fi
      done
      if [[ $stale_refs -eq 0 ]]; then
        echo "  refs: all up to date"
      fi
    fi
  done
}

# ─── Main ───

case "${1:-}" in
  generate) action_generate ;;
  clean) action_clean ;;
  status) action_status ;;
  *)
    echo "Usage: port-skills.sh [generate|clean|status]"
    echo "  generate  — Create neutralized copies from originals → .agents/skills/"
    echo "  clean     — Remove all generated files in .agents/skills/"
    echo "  status    — Show diff summary between originals and ported copies"
    exit 1
    ;;
esac
