#!/usr/bin/env bash
# External model CLI invocation with structured output parsing
#
# Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file> [effort]
#   provider:    "codex" or "gemini"
#   model:       model name (e.g., "gpt-5.2", "gemini-3-flash-preview")
#   prompt-file: path to relay prompt text file
#   output-file: path to write parsed JSON result
#   effort:      reasoning effort for Codex (low|medium|high|xhigh, default: high)
#
# Exit codes:
#   0 — success, output-file contains valid parsed JSON
#   1 — all parse attempts failed, raw output saved at {output-file}.raw for LLM inspection
#   2 — CLI invocation error (auth, model not found, empty response)
#
# Side effects:
#   Always creates {output-file}.raw with raw CLI output (preserved for debugging/LLM fallback)
#
# Part of ouroboros multi-model routing (skills/core/routing/)

set -uo pipefail

PROVIDER="${1:?Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file>}"
MODEL="${2:?Missing model name}"
PROMPT_FILE="${3:?Missing prompt file path}"
OUTPUT_FILE="${4:?Missing output file path}"
EFFORT="${5:-high}"
RAW_FILE="${OUTPUT_FILE}.raw"

# ─── Phase 1: CLI Invocation ───

case "$PROVIDER" in
  codex)
    cat "$PROMPT_FILE" |
      codex exec --json -m "$MODEL" -c model_reasoning_effort="$EFFORT" --sandbox read-only - \
        >"$RAW_FILE" 2>&1 || true
    ;;
  gemini)
    cat "$PROMPT_FILE" |
      gemini -m "$MODEL" --output-format json \
        >"$RAW_FILE" 2>&1 || true
    ;;
  *)
    echo "UNKNOWN_PROVIDER: $PROVIDER (expected: codex, gemini)" >&2
    exit 2
    ;;
esac

# ─── Phase 2: Empty Response Check ───

if [ ! -s "$RAW_FILE" ]; then
  echo "EMPTY_RESPONSE: No output from $PROVIDER $MODEL" >&2
  exit 2
fi

# ─── Phase 3: Fatal Error Detection ───
# Check error lines only (not full stack traces) to avoid false positives

ERR_LINE=""
case "$PROVIDER" in
  codex)
    ERR_LINE=$(jq -r 'select(.type == "error" or .type == "turn.failed") | .message // .error.message // empty' "$RAW_FILE" 2>/dev/null | head -1)
    ;;
  gemini)
    ERR_LINE=$(grep -m1 -E "^Error|ModelNotFoundError|AuthenticationError|PermissionDenied" "$RAW_FILE" 2>/dev/null || true)
    ;;
esac

if [ "$ERR_LINE" != "" ]; then
  if echo "$ERR_LINE" | grep -qi "auth\|login\|credentials\|PermissionDenied"; then
    echo "AUTH_ERROR: $ERR_LINE" >&2
    exit 2
  fi
  if echo "$ERR_LINE" | grep -qi "not found\|not supported"; then
    echo "MODEL_ERROR: $ERR_LINE" >&2
    exit 2
  fi
  # Rate limit / transient errors — CLI may have retried, continue to parse
fi

# ─── Phase 4: Primary Parse ───

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/safe-rm.sh" -f "$OUTPUT_FILE"

case "$PROVIDER" in
  codex)
    # JSONL: find agent_message item → extract .item.text → parse inner JSON
    jq -s 'map(select(.item?.type? == "agent_message")) | .[0].item.text' -r "$RAW_FILE" 2>/dev/null |
      jq '.' >"$OUTPUT_FILE" 2>/dev/null || true
    ;;
  gemini)
    # Mixed output: skip non-JSON prefix → extract .response → strip code fences → parse
    awk '/^\{/{found=1} found{print}' "$RAW_FILE" |
      jq -r '.response' 2>/dev/null |
      sed 's/^```json//;s/^```$//' |
      jq '.' >"$OUTPUT_FILE" 2>/dev/null || true
    ;;
esac

# Validation: check for known response structures (evaluation or agent analysis)
if jq -e '(.criteria // .before.criteria // .after.criteria) | length > 0' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi
# Generic JSON validation: any valid JSON object with at least one array field (researcher, generator, etc.)
if jq -e 'type == "object" and (to_entries | map(select(.value | type == "array" and length > 0)) | length > 0)' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi

# ─── Phase 5: Fallback Parse ───

case "$PROVIDER" in
  codex)
    # Fallback: try last agent_message (not first)
    jq -s 'map(select(.item?.type? == "agent_message")) | .[-1].item.text' -r "$RAW_FILE" 2>/dev/null |
      jq '.' >"$OUTPUT_FILE" 2>/dev/null || true
    ;;
  gemini)
    # Fallback: try extracting any JSON object containing known keys
    awk '/^\{/{found=1} found{print}' "$RAW_FILE" |
      jq -s '.[] | select(.criteria? or .response? or .key_findings? or .patterns?) | if .response then (.response | fromjson) else . end' \
        >"$OUTPUT_FILE" 2>/dev/null || true
    ;;
esac

if jq -e '(.criteria // .before.criteria // .after.criteria) | length > 0' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi
# Generic fallback validation
if jq -e 'type == "object" and (to_entries | map(select(.value | type == "array" and length > 0)) | length > 0)' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi

# ─── Phase 6: Parse Failed ───
# Raw file preserved at $RAW_FILE for LLM fallback inspection

bash "$SCRIPT_DIR/safe-rm.sh" -f "$OUTPUT_FILE"
echo "PARSE_FAILED: All mechanical parsing failed. Raw output at $RAW_FILE" >&2
exit 1
