#!/usr/bin/env bash
# prepare-release.sh — Extract plugin deliverables for public release
#
# Usage: bash scripts/prepare-release.sh [--force] [TARGET_DIR]
# Default target: ../ouroboros-release/
#
# Copies plugin deliverables + curated dev docs. The resulting directory
# is ready to initialize as a separate git repo and push to GitHub.
#
# Options:
#   --force  Remove existing target directory before extracting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse arguments
FORCE=false
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) TARGET="$arg" ;;
  esac
done
TARGET="${TARGET:-$(dirname "$PLUGIN_ROOT")/ouroboros-release}"

if [[ -d "$TARGET" ]]; then
  if [[ "$FORCE" == true ]]; then
    # Preserve .git/ to keep existing remote/history
    if [[ -d "$TARGET/.git" ]]; then
      echo "Cleaning target (preserving .git/)..."
      find "$TARGET" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
    else
      echo "Cleaning target..."
      rm -rf "$TARGET"
    fi
  else
    echo "Error: Target directory already exists: $TARGET"
    echo "Use --force to replace, or specify a different path."
    exit 1
  fi
fi

echo "=== Ouroboros Release Preparation ==="
echo "Source: $PLUGIN_ROOT"
echo "Target: $TARGET"
echo ""

mkdir -p "$TARGET"

# Plugin manifest
cp -r "$PLUGIN_ROOT/.claude-plugin" "$TARGET/"

# Project-scoped settings (turnkey permissions)
mkdir -p "$TARGET/.claude"
cp "$PLUGIN_ROOT/.claude/settings.json" "$TARGET/.claude/"

# Plugin components
for dir in agents commands skills templates hooks scripts; do
  cp -r "$PLUGIN_ROOT/$dir" "$TARGET/"
done

# Root files
cp "$PLUGIN_ROOT/CLAUDE.md" "$TARGET/"
cp "$PLUGIN_ROOT/README.md" "$TARGET/"
cp "$PLUGIN_ROOT/CHANGELOG.md" "$TARGET/"
cp "$PLUGIN_ROOT/LICENSE" "$TARGET/"
cp "$PLUGIN_ROOT/.gitignore" "$TARGET/"
cp "$PLUGIN_ROOT/.editorconfig" "$TARGET/"
cp "$PLUGIN_ROOT/.rumdl.toml" "$TARGET/"
cp "$PLUGIN_ROOT/.shellcheckrc" "$TARGET/"
cp "$PLUGIN_ROOT/AGENTS.md" "$TARGET/"

# Sanitize references to internal dev docs not included in release
echo "Sanitizing internal references..."
find "$TARGET" -name "*.md" -not -path "*/.git/*" -not -path "*/dev/*" -not -name "CHANGELOG.md" | xargs sed -i '' -E '/dev\/(PA-DESIGN|RND-DESIGN|HANDOVER|REVIEW|references\/resource-analysis)[^)]*\.md/d'

# Dev docs — operational documents referenced by CLAUDE.md, AGENTS.md, hooks, and commands
mkdir -p "$TARGET/dev"
cp "$PLUGIN_ROOT/dev/VISION.md" "$TARGET/dev/"
cp "$PLUGIN_ROOT/dev/DECISIONS.md" "$TARGET/dev/"
# Starter templates for contributors
cat >"$TARGET/dev/STATUS.md" <<'STATUSEOF'
## State: Initial setup

Describe current project state here.

## Immediate Next

> List next tasks here.

## Backlog

- [ ] ...
STATUSEOF
cat >"$TARGET/dev/MILESTONES.md" <<'PLANEOF'
# Ouroboros — Milestones

## Current Version

See `CHANGELOG.md` for release history.

## Backlog

- [ ] ...
PLANEOF

# Curated public documentation
mkdir -p "$TARGET/docs"
cp "$PLUGIN_ROOT/docs/ROADMAP.md" "$TARGET/docs/"
for guide in GUIDE.md ARCHITECTURE.md; do
  [[ -f "$PLUGIN_ROOT/docs/$guide" ]] && cp "$PLUGIN_ROOT/docs/$guide" "$TARGET/docs/"
done

# Design documents
if [[ -d "$PLUGIN_ROOT/docs/designs" ]]; then
  mkdir -p "$TARGET/docs/designs"
  for f in "$PLUGIN_ROOT"/docs/designs/*.md; do
    [[ -f "$f" ]] && cp "$f" "$TARGET/docs/designs/"
  done
fi

# Experiment analysis reports (refined for public release)
mkdir -p "$TARGET/docs/experiments"
for analysis in self-eval-bias model-optimization unanimous-convergence; do
  if [[ -f "$PLUGIN_ROOT/docs/experiments/${analysis}.md" ]]; then
    cp "$PLUGIN_ROOT/docs/experiments/${analysis}.md" "$TARGET/docs/experiments/"
  fi
done

# Final evaluation baselines (latest only)
mkdir -p "$TARGET/docs/evaluations"
for pattern in core-018 swe-012 pa-015; do
  for f in "$PLUGIN_ROOT"/dev/evaluations/${pattern}-*.json; do
    [[ -f "$f" ]] && cp "$f" "$TARGET/docs/evaluations/"
  done
done

echo ""
echo "=== Release contents ==="
echo ""

# Count files by type
echo "Plugin components:"
echo "  Commands: $(find "$TARGET/commands" -name "*.md" | wc -l | tr -d ' ')"
echo "  Agents:   $(find "$TARGET/agents" -name "*.md" | wc -l | tr -d ' ')"
echo "  Skills:   $(find "$TARGET/skills" -name "*.md" | wc -l | tr -d ' ')"
echo "  Templates: $(find "$TARGET/templates" -name "*.md" | wc -l | tr -d ' ')"
echo "  Scripts:  $(find "$TARGET/scripts" -name "*.sh" | wc -l | tr -d ' ')"
echo ""
echo "Documentation:"
echo "  README.md, CLAUDE.md, AGENTS.md, LICENSE"
echo "  dev/VISION.md, dev/DECISIONS.md, dev/STATUS.md (template), dev/MILESTONES.md (template)"
echo "  docs/ROADMAP.md"
if [[ -d "$TARGET/docs/designs" ]]; then
  echo "  docs/designs/: $(find "$TARGET/docs/designs" -name "*.md" | wc -l | tr -d ' ') design docs"
fi
if [[ -d "$TARGET/docs/experiments" ]]; then
  echo "  docs/experiments/: $(find "$TARGET/docs/experiments" -name "*.md" | wc -l | tr -d ' ') analysis reports"
fi
if [[ -d "$TARGET/docs/evaluations" ]]; then
  echo "  docs/evaluations/: $(find "$TARGET/docs/evaluations" -name "*.json" | wc -l | tr -d ' ') baselines"
fi
echo ""
echo "Total files: $(find "$TARGET" -type f -not -path "*/.git/*" | wc -l | tr -d ' ')"

# === Security audit ===
echo ""
echo "=== Security audit ==="
echo ""

AUDIT_FAIL=0

# 1. Actual secret patterns (API keys, tokens)
SECRET_FILES=$(grep -rl --include="*.md" --include="*.sh" --include="*.json" \
  -E '(sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|gho_[a-zA-Z0-9]{36}|AKIA[0-9A-Z]{16}|xox[bpors]-[a-zA-Z0-9-]+)' \
  "$TARGET" 2>/dev/null || true)
if [[ -n "$SECRET_FILES" ]]; then
  echo "FAIL: Actual secret tokens found:"
  echo "$SECRET_FILES" | sed 's/^/  /'
  AUDIT_FAIL=1
else
  echo "PASS: No actual secret tokens"
fi

# 2. Credential files (.env, keys, certificates)
CRED_FILES=$(find "$TARGET" -not -path "*/.git/*" \( -name ".env*" -o -name "credentials*" -o -name "*.pem" -o -name "*.key" \) 2>/dev/null || true)
if [[ -n "$CRED_FILES" ]]; then
  echo "FAIL: Credential files found:"
  echo "$CRED_FILES" | sed 's/^/  /'
  AUDIT_FAIL=1
else
  echo "PASS: No credential files"
fi

# 3. Hardcoded personal paths in scripts/config
# Documentation mentions of paths are acceptable; scripts and config are not
HARDCODED_PATHS=$(grep -rn --include="*.sh" --include="*.json" '/Users/\|/home/' "$TARGET" 2>/dev/null | grep -v '.git/' | grep -v 'prepare-release.sh' || true)
if [[ -n "$HARDCODED_PATHS" ]]; then
  echo "WARN: Hardcoded personal paths in scripts/config:"
  echo "$HARDCODED_PATHS" | sed 's/^/  /'
else
  echo "PASS: No hardcoded personal paths in scripts/config"
fi

# 4. Internal dev file leak check
# dev/VISION.md, dev/DECISIONS.md, dev/STATUS.md, dev/MILESTONES.md are intentionally included
# Check for files that should NOT be in the release
LEAKED_DEV=$(find "$TARGET/dev" -not -path "*/.git/*" -name "*.md" 2>/dev/null | grep -v -E '(VISION|DECISIONS|STATUS|MILESTONES)\.md$' || true)
if [[ -n "$LEAKED_DEV" ]]; then
  echo "FAIL: Unexpected dev files in release:"
  echo "$LEAKED_DEV" | sed 's/^/  /'
  AUDIT_FAIL=1
else
  echo "PASS: Only expected dev files present"
fi

# 5. Required files check
REQUIRED_FILES=(".claude-plugin/plugin.json" ".claude/settings.json" "CLAUDE.md" "AGENTS.md" "README.md" "CHANGELOG.md" "LICENSE" ".gitignore" "dev/VISION.md" "dev/DECISIONS.md")
MISSING=""
for f in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$TARGET/$f" ]]; then
    MISSING="$MISSING  $f\n"
  fi
done
if [[ -n "$MISSING" ]]; then
  echo "FAIL: Required files missing:"
  printf "$MISSING"
  AUDIT_FAIL=1
else
  echo "PASS: All required files present"
fi

# 6. Hook portability — should use ${CLAUDE_PLUGIN_ROOT}, not absolute paths
ABS_IN_HOOKS=$(grep -rn --include="*.json" '/Users/\|/home/' "$TARGET/hooks/" 2>/dev/null || true)
if [[ -n "$ABS_IN_HOOKS" ]]; then
  echo "FAIL: Absolute paths in hooks (should use \${CLAUDE_PLUGIN_ROOT}):"
  echo "$ABS_IN_HOOKS" | sed 's/^/  /'
  AUDIT_FAIL=1
else
  echo "PASS: Hooks use portable paths"
fi

# 7. Broken dev references in non-historical files
BROKEN_DEV_REFS=$(grep -rn --include="*.md" -E 'dev/(PA-DESIGN|RND-DESIGN|HANDOVER|REVIEW)\.md' "$TARGET" 2>/dev/null | grep -v '.git/' | grep -v 'dev/DECISIONS.md' | grep -v 'CHANGELOG.md' || true)
if [[ -n "$BROKEN_DEV_REFS" ]]; then
  echo "WARN: References to excluded dev docs:"
  echo "$BROKEN_DEV_REFS" | sed 's/^/  /'
else
  echo "PASS: No broken dev doc references"
fi

echo ""
if [[ "$AUDIT_FAIL" -eq 1 ]]; then
  echo "=== AUDIT FAILED — fix issues before publishing ==="
  exit 1
else
  echo "=== AUDIT PASSED ==="
fi

echo ""
echo "=== Next steps ==="
echo "  cd $TARGET"
echo "  git init && git add -A && git commit -m 'Initial release'"
echo "  gh repo create ouroboros --public --source=. --push"
