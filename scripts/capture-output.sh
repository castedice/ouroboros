#!/usr/bin/env bash
# SubagentStop hook: capture ouroboros agent output for evaluation
# Opt-in via OUROBOROS_CAPTURE=1. Saves last_assistant_message to .captures/.
# Designed for async execution (non-blocking).
# Idempotency: each capture creates a unique timestamped file — no overwrite risk.
# No security role — does not filter or validate agent output content.

# Opt-in only
[[ "${OUROBOROS_CAPTURE:-}" != "1" ]] && exit 0

INPUT=$(cat)

# Graceful exit on JSON parse failure (required by hook contract)
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null) || exit 0
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty' 2>/dev/null) || exit 0
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null) || exit 0

# Only capture ouroboros agent types
OUROBOROS_PATTERN="^ouroboros:(core|swe):(evaluator|researcher|generator|brainstormer|reconciler|analyst|implementer|reviewer)$"
if [[ ! "$AGENT_TYPE" =~ $OUROBOROS_PATTERN ]]; then
  exit 0
fi

# Skip if no output
[[ -z "$LAST_MSG" ]] && exit 0

# Prepare capture directory
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
CAPTURE_DIR="$PLUGIN_ROOT/.captures"
mkdir -p "$CAPTURE_DIR"

# Generate filename: timestamp-agenttype-idprefix.md
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TYPE_SHORT=$(echo "$AGENT_TYPE" | sed 's/ouroboros:[^:]*://')
ID_PREFIX="${AGENT_ID:0:8}"
FILENAME="${TIMESTAMP}-${TYPE_SHORT}-${ID_PREFIX}.md"

# Write capture file with frontmatter
cat >"$CAPTURE_DIR/$FILENAME" <<EOF
---
agent_type: $AGENT_TYPE
agent_id: $AGENT_ID
captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

$LAST_MSG
EOF

exit 0
