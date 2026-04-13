#!/usr/bin/env bash
# DEPRECATED: Use scripts/codex-relay.sh instead.
# This shim preserves backward compatibility for experiments and old references.
#
# Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file> [effort] [timeout]
# Delegates to codex-relay.sh with translated arguments.

set -uo pipefail

PROVIDER="${1:?Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file> [effort] [timeout]}"
MODEL="${2:?Missing model name}"
PROMPT_FILE="${3:?Missing prompt file path}"
OUTPUT_FILE="${4:?Missing output file path}"
EFFORT="${5:-high}"
TIMEOUT="${6:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$PROVIDER" != "codex" ]]; then
  echo "UNKNOWN_PROVIDER: $PROVIDER (expected: codex)" >&2
  exit 2
fi

ARGS=("$PROMPT_FILE" --output "$OUTPUT_FILE" --effort "$EFFORT" --model "$MODEL")
[[ -n "$TIMEOUT" ]] && ARGS+=(--timeout "$TIMEOUT")

exec "$SCRIPT_DIR/codex-relay.sh" "${ARGS[@]}"
