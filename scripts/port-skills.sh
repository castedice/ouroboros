#!/usr/bin/env bash
# Port ouroboros methodology skills to .agents/skills/ for cross-tool compatibility.
#
# Usage: port-skills.sh [generate|clean|status]
#   generate  — Create neutralized copies from originals → .agents/skills/
#   clean     — Remove all generated files in .agents/skills/
#   status    — Show diff summary between originals and ported copies
#
# Neutralization transforms:
#   1. name field: strip source-specific names to match the target directory name
#   2. Preserve the Phase 4 six-section structure, including See Also
#   3. Slash commands: /evaluate → evaluation, /evolve → evolution workflow, etc.
#   4. Internal paths: docs/decisions/ → project decision log, docs/specs/knowledge/ → knowledge base
#   5. Skill references: ${CLAUDE_SKILL_DIR}/references/ → references/
#   6. Script paths: ${CLAUDE_PLUGIN_ROOT}/scripts/ → scripts/
#   7. Cross-skill references: keep links only when the target skill is ported
#   8. Reference selection: exclude source-only files that should not be copied
#   9. Agent criteria: neutralize model names and tool names

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="$PROJECT_ROOT/.agents/skills"

# ─── Skill definitions: "target_name:source_dir" ───

PORTABLE_SKILLS=(
  "brainstorming:skills/core/brainstorming"
  "collaboration:skills/core/collaboration"
  "swe-constraint:skills/swe/constraint"
  "swe-methodology:skills/swe/methodology"
  "worktree-governance:skills/core/worktree-governance"
  "evolution:skills/core/evolution"
  "evaluation:skills/core/evaluation"
  "code-review:skills/swe/code-review"
)

# References to EXCLUDE from copy because they remain source-only.
EXCLUDE_REFS=(
  "researcher-relay-prompt.md"
  "hook-criteria.md"
  "claudemd-criteria.md"
  "command-criteria.md"
  "evaluator-relay-prompts.md"
  "command-output-criteria.md"
  "hook-output-criteria.md"
  "regression-format.md"
)

# ─── Common transforms (applied to SKILL.md and references) ───

_rewrite_skill_name() {
  local target_name="$1"

  sed -E \
    -e "s/^name: .*/name: ${target_name}/" \
    -e '/^preamble_tier: /d'
}

_apply_generic_text_transforms() {
  sed -E \
    -e 's|\$\{CLAUDE_SKILL_DIR\}/references/|references/|g' \
    -e 's|\$\{CLAUDE_PLUGIN_ROOT\}/scripts/|scripts/|g' \
    -e 's|`/evaluate`|evaluation|g' \
    -e 's|`/evolve`|the evolution workflow|g' \
    -e 's|`/research`|research|g' \
    -e 's#(^|[[:space:](])/evaluate([[:space:].,:;!?)]|$)#\1evaluation\2#g' \
    -e 's|/evolve |evolution workflow |g' \
    -e 's|/research ([a-z])|research \1|g' \
    -e 's|`docs/decisions/`|project decision log|g' \
    -e 's|`docs/specs/knowledge/`|knowledge base|g' \
    -e 's|in `docs/decisions/`|in the project decision log|g' \
    -e 's|in docs/decisions/|in the project decision log|g' \
    -e 's|using Edit tool|using targeted edits|g' \
    -e 's|Edit tool with specific old/new strings|targeted modifications to specific sections|g'
}

_port_map_data() {
  printf '%s\n' "${PORTABLE_SKILLS[@]}"
}

_sanitize_markdown_paths() {
  local target_name="$1"
  local source_file_rel="$2"
  local source_dir_rel

  source_dir_rel="$(dirname "$source_file_rel")"

  PORT_MAP="$(_port_map_data)" \
  EXCLUDE_MAP="$(printf '%s\n' "${EXCLUDE_REFS[@]}")" \
  CURRENT_SOURCE_DIR="$source_dir_rel" \
  CURRENT_TARGET_NAME="$target_name" \
    perl -0pe '
    use strict;
    use warnings;

    our %PORT_MAP;
    our %EXCLUDE_MAP;
    our $CURRENT_SOURCE_DIR;
    our $CURRENT_TARGET_NAME;

    BEGIN {
      %PORT_MAP = ();
      for my $entry (split /\n/, ($ENV{PORT_MAP} // "")) {
        next unless length $entry;
        my ($target, $source) = split /:/, $entry, 2;
        next unless defined $target && defined $source;
        $PORT_MAP{$source} = $target;
      }

      %EXCLUDE_MAP = map { $_ => 1 } grep { length } split /\n/, ($ENV{EXCLUDE_MAP} // "");
      $CURRENT_SOURCE_DIR = $ENV{CURRENT_SOURCE_DIR} // "";
      $CURRENT_TARGET_NAME = $ENV{CURRENT_TARGET_NAME} // "";
    }

    sub _clean_path {
      my ($path) = @_;
      my @parts;

      for my $part (split m{/+}, $path) {
        next if $part eq q{} || $part eq q{.};
        if ($part eq q{..}) {
          pop @parts if @parts;
          next;
        }
        push @parts, $part;
      }

      return join q{/}, @parts;
    }

    sub _normalize_source_path {
      my ($raw_path) = @_;

      return q{} unless defined $raw_path && length $raw_path;
      return $raw_path if $raw_path =~ m{^\.agents/skills/};
      return "references/$1" if $raw_path =~ m{^\$\{CLAUDE_SKILL_DIR\}/references/([^)\s]+\.md)$};
      return "scripts/$1" if $raw_path =~ m{^\$\{CLAUDE_PLUGIN_ROOT\}/scripts/([^)\s]+)$};
      return _clean_path("$CURRENT_SOURCE_DIR/$raw_path") if $raw_path =~ m{^(?:\.\.?/)+};
      return _clean_path($raw_path);
    }

    sub _ported_path_for_source {
      my ($normalized_path) = @_;

      return $normalized_path if $normalized_path =~ m{^\.agents/skills/};
      return undef if $normalized_path =~ m{^references/([^/]+\.md)$} && $EXCLUDE_MAP{$1};
      return $normalized_path if $normalized_path =~ m{^references/[^/]+\.md$};
      return $normalized_path if $normalized_path =~ m{^scripts/};

      if ($normalized_path =~ m{^(skills/[^/]+/[^/]+)/SKILL\.md$}) {
        return exists $PORT_MAP{$1} ? ".agents/skills/$PORT_MAP{$1}/SKILL.md" : undef;
      }

      if ($normalized_path =~ m{^(skills/[^/]+/[^/]+)/references/([^/]+\.md)$}) {
        return undef if $EXCLUDE_MAP{$2};
        return exists $PORT_MAP{$1} ? ".agents/skills/$PORT_MAP{$1}/references/$2" : undef;
      }

      return undef;
    }

    sub _humanize_name {
      my ($name) = @_;

      $name =~ s/[-_]+/ /g;
      $name =~ s/\bclaudemd\b/CLAUDE.md/g;
      $name =~ s/\bswe\b/SWE/g;
      return $name;
    }

    sub _plain_label_for_source {
      my ($normalized_path) = @_;

      if ($normalized_path =~ m{^commands/[^/]+/([^/]+)\.md$}) {
        return "the " . _humanize_name($1) . " command";
      }

      if ($normalized_path =~ m{^agents/[^/]+/([^/]+)\.md$}) {
        return "the " . _humanize_name($1) . " agent";
      }

      if ($normalized_path =~ m{^(skills/[^/]+/([^/]+))/SKILL\.md$}) {
        return undef if exists $PORT_MAP{$1};
        return "the " . _humanize_name($2) . " skill";
      }

      if ($normalized_path =~ m{^(skills/[^/]+/[^/]+)/references/([^/]+)\.md$}) {
        return undef if exists $PORT_MAP{$1};
        return "the " . _humanize_name($2) . " reference";
      }

      if ($normalized_path =~ m{^references/([^/]+)\.md$}) {
        return "the " . _humanize_name($1) . " reference" if $EXCLUDE_MAP{"$1.md"};
      }

      return undef;
    }

    sub _rewrite_link {
      my ($label, $destination) = @_;
      my $normalized_path = _normalize_source_path($destination);
      my $ported_path = _ported_path_for_source($normalized_path);
      my $plain_label = _plain_label_for_source($normalized_path);

      return "[$label]($ported_path)" if defined $ported_path;
      return $label if defined $plain_label;
      return "[$label]($destination)";
    }

    sub _rewrite_inline {
      my ($inner) = @_;
      my $normalized_path = _normalize_source_path($inner);
      my $ported_path = _ported_path_for_source($normalized_path);
      my $plain_label = _plain_label_for_source($normalized_path);

      return "`$ported_path`" if defined $ported_path;
      return $plain_label if defined $plain_label;
      return "`$inner`";
    }

    s{\[([^\]]+)\]\(([^)]+)\)}{_rewrite_link($1, $2)}ge;
    s{`([^`\n]+)`}{_rewrite_inline($1)}ge;
  '
}

_finalize_skill_markdown() {
  local target_name="$1"
  local source_file_rel="$2"

  _rewrite_skill_name "$target_name" |
    _apply_generic_text_transforms |
    _sanitize_markdown_paths "$target_name" "$source_file_rel"
}

_finalize_reference_markdown() {
  local target_name="$1"
  local source_file_rel="$2"

  _apply_generic_text_transforms |
    _sanitize_markdown_paths "$target_name" "$source_file_rel"
}

# ─── Skill-specific transforms ───

_transform_brainstorming() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|`/research "caching patterns in CLI tools"`|"research caching patterns in CLI tools"|g' \
    -e 's|specific command invocations with arguments|specific, actionable next steps with concrete details|g' \
    -e 's|a specific command invocation with arguments, not a generic reference\.|a specific, actionable next step, not a generic reference.|' \
    -e 's|a specific command with arguments, not a template placeholder|a specific action with concrete details, not a template placeholder|' |
    _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_collaboration() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_swe_constraint() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_swe_methodology() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_worktree_governance() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_evolution() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|Researcher agent performs|Perform|' \
    -e 's|Researcher agent reads|Read|' |
    _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_evaluation() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

_transform_code_review() {
  local target_name="$1"
  local source_file_rel="$2"

  _finalize_skill_markdown "$target_name" "$source_file_rel"
}

# ─── Reference transforms ───

_transform_divergent_techniques() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|SCAMPER on `/evaluate` command'\''s Phase 1 \(Parse Input\):|SCAMPER on an evaluation workflow'\''s input parsing phase:|' \
    -e 's|on-demand `/evaluate`|on-demand evaluation|g' \
    -e 's|while keeping `/evaluate` for deep analysis \(manual\)|while keeping manual evaluation for deep analysis|' |
    _finalize_reference_markdown "$target_name" "$source_file_rel"
}

_transform_bias_patterns() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|Edit tool with specific old/new strings|targeted modifications to specific sections|g' \
    -e 's|Prefer targeted edits \(Edit tool with specific old/new strings\)|Prefer targeted edits (specific modifications)|' |
    _finalize_reference_markdown "$target_name" "$source_file_rel"
}

_transform_evolution_stages_detail() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|run `/evaluate`|run evaluation|g' \
    -e 's|Researcher agent reads the target component and evaluation report|Read the target component and evaluation report|' \
    -e 's|Search knowledge base \(`docs/specs/knowledge/`\)|Search knowledge base|' \
    -e 's|Create decision entry in `docs/decisions/`|Create decision entry in project decision log|' \
    -e 's|in `docs/decisions/` using the evolve template|in the project decision log|' |
    _finalize_reference_markdown "$target_name" "$source_file_rel"
}

_transform_agent_criteria() {
  local target_name="$1"
  local source_file_rel="$2"

  sed -E \
    -e 's|Complex reasoning \(architecture, evaluation, deep analysis\) → opus, balanced execution\+analysis → sonnet, fast assistance → haiku|Complex reasoning (architecture, evaluation, deep analysis) → high-capability model, balanced execution+analysis → standard model, fast assistance → lightweight model|' \
    -e 's|Opus for simple tasks, haiku for complex reasoning|High-capability model for simple tasks, lightweight model for complex reasoning|' \
    -e 's|\[Read, Grep, Glob\]|read-only analysis tools|' \
    -e 's|Write/Edit on an analysis agent|write tools on an analysis agent|' |
    _finalize_reference_markdown "$target_name" "$source_file_rel"
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
    local source_rel="${entry#*:}"
    local source_dir="$PROJECT_ROOT/$source_rel"
    local target_dir="$TARGET/$target_name"

    echo "  [$target_name] from $source_dir"

    # Create target directory
    mkdir -p "$target_dir/references"

    # Transform SKILL.md
    local transform_fn="_transform_${target_name//-/_}"
    if declare -f "$transform_fn" >/dev/null 2>&1; then
      "$transform_fn" "$target_name" "$source_rel/SKILL.md" <"$source_dir/SKILL.md" >"$target_dir/SKILL.md"
    else
      echo "    WARN: no transform function $transform_fn, using common transforms"
      _finalize_skill_markdown "$target_name" "$source_rel/SKILL.md" <"$source_dir/SKILL.md" >"$target_dir/SKILL.md"
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
        local source_ref_rel="$source_rel/references/$basename"
        if declare -f "$ref_transform" >/dev/null 2>&1; then
          "$ref_transform" "$target_name" "$source_ref_rel" <"$ref_file" >"$target_dir/references/$basename"
        else
          _finalize_reference_markdown "$target_name" "$source_ref_rel" <"$ref_file" >"$target_dir/references/$basename"
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
    # Prefer safe-rm, but fall back to rm -rf when safe-rm cannot move within the sandbox.
    if [[ -f "$SCRIPT_DIR/safe-rm.sh" ]]; then
      if ! bash "$SCRIPT_DIR/safe-rm.sh" -rf "$TARGET"; then
        rm -rf "$TARGET"
      fi
      if [[ -d "$TARGET" ]]; then
        echo "ERROR: failed to remove $TARGET/"
        exit 1
      fi
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
    local source_rel="${entry#*:}"
    local source_dir="$PROJECT_ROOT/$source_rel"
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
      "$transform_fn" "$target_name" "$source_rel/SKILL.md" <"$source_dir/SKILL.md" >"$tmp_transformed"
    else
      _finalize_skill_markdown "$target_name" "$source_rel/SKILL.md" <"$source_dir/SKILL.md" >"$tmp_transformed"
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
          local source_ref_rel="$source_rel/references/$basename"
          if declare -f "$ref_transform" >/dev/null 2>&1; then
            "$ref_transform" "$target_name" "$source_ref_rel" <"$ref_file" >"$tmp_ref"
          else
            _finalize_reference_markdown "$target_name" "$source_ref_rel" <"$ref_file" >"$tmp_ref"
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
