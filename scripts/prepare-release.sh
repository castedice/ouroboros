#!/usr/bin/env bash
# prepare-release.sh — Extract plugin deliverables for public release
#
# Usage: bash scripts/prepare-release.sh [TARGET_DIR]
# Default target: ../ouroboros-release/
#
# Copies only the plugin deliverables (no dev/ internals, no experiments,
# no session artifacts). The resulting directory is ready to initialize
# as a separate git repo and push to GitHub.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-$(dirname "$PLUGIN_ROOT")/ouroboros-release}"

if [[ -d "$TARGET" ]]; then
  echo "Error: Target directory already exists: $TARGET"
  echo "Remove it first or specify a different path."
  exit 1
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
cp "$PLUGIN_ROOT/LICENSE" "$TARGET/"
cp "$PLUGIN_ROOT/.gitignore" "$TARGET/"
cp "$PLUGIN_ROOT/.editorconfig" "$TARGET/"
cp "$PLUGIN_ROOT/.rumdl.toml" "$TARGET/"
cp "$PLUGIN_ROOT/.shellcheckrc" "$TARGET/"

# Selected dev docs (architecture + decisions only)
mkdir -p "$TARGET/docs"
cp "$PLUGIN_ROOT/dev/VISION.md" "$TARGET/docs/"
cp "$PLUGIN_ROOT/dev/DECISIONS.md" "$TARGET/docs/"

# Knowledge entries (curated, useful for users)
if [[ -d "$PLUGIN_ROOT/docs/knowledge" ]]; then
  cp -r "$PLUGIN_ROOT/docs/knowledge" "$TARGET/docs/"
fi

# Clean up internal-only files from target
# Remove experiment scripts with hardcoded paths
find "$TARGET" -name "*.json.raw" -delete 2>/dev/null || true
find "$TARGET" -name "*.log" -path "*/experiments/*" -delete 2>/dev/null || true

# Remove dev-only directories that shouldn't be in release
# (dev/experiments, dev/evaluations, dev/archive are NOT copied — only VISION.md and DECISIONS.md)

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
echo "  README.md, CLAUDE.md, LICENSE"
echo "  docs/VISION.md, docs/DECISIONS.md"
if [[ -d "$TARGET/docs/knowledge" ]]; then
  echo "  docs/knowledge/: $(find "$TARGET/docs/knowledge" -name "*.md" | wc -l | tr -d ' ') entries"
fi
echo ""
echo "Total files: $(find "$TARGET" -type f | wc -l | tr -d ' ')"
echo ""
echo "=== Next steps ==="
echo "  cd $TARGET"
echo "  git init && git add -A && git commit -m 'Initial release'"
echo "  gh repo create ouroboros --public --source=. --push"
