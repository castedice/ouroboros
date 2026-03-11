#!/usr/bin/env bash
# External model CLI invocation with structured output parsing
#
# Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file> [effort] [timeout]
#   provider:    "codex"
#   model:       model name (e.g., "gpt-5.2")
#   prompt-file: path to relay prompt text file
#   output-file: path to write parsed JSON result
#   effort:      reasoning effort for Codex (low|medium|high|xhigh, default: high)
#   timeout:     max seconds for CLI invocation (default: 300)
#
# Exit codes:
#   0 — success, output-file contains valid parsed JSON
#   1 — all parse attempts failed, raw output saved at {output-file}.raw for LLM inspection
#   2 — CLI invocation error (auth, model not found, empty response, timeout)
#
# Retry policy:
#   Max 2 retries with exponential backoff (1s, 2s) for transient failures.
#   No retry for: timeout, auth errors, model errors, unknown provider.
#
# Circuit breaker:
#   This script is stateless. Circuit breaker logic (skip after N failures)
#   is the caller's responsibility. See invocation-protocol.md.
#
# Side effects:
#   Always creates {output-file}.raw with raw CLI output (preserved for debugging/LLM fallback)
#
# Part of ouroboros multi-model routing (skills/core/routing/)

set -uo pipefail

PROVIDER="${1:?Usage: invoke-model.sh <provider> <model> <prompt-file> <output-file> [effort] [timeout]}"
MODEL="${2:?Missing model name}"
PROMPT_FILE="${3:?Missing prompt file path}"
OUTPUT_FILE="${4:?Missing output file path}"
EFFORT="${5:-high}"
TIMEOUT="${6:-300}"
RAW_FILE="${OUTPUT_FILE}.raw"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MAX_RETRIES=2
RETRY_DELAY=1

# ─── CLI Invocation with Retry ───

_invoke_cli() {
  local attempt=0
  local exit_code=0

  while [[ $attempt -le $MAX_RETRIES ]]; do
    if [[ $attempt -gt 0 ]]; then
      local delay=$((RETRY_DELAY * attempt))
      echo "RETRY: attempt $((attempt + 1))/$((MAX_RETRIES + 1)) after ${delay}s delay" >&2
      sleep "$delay"
    fi

    exit_code=0
    case "$PROVIDER" in
      codex)
        timeout "$TIMEOUT" bash -c 'cat "$1" | codex exec --json -m "$2" -c model_reasoning_effort="$3" --sandbox read-only -' _ "$PROMPT_FILE" "$MODEL" "$EFFORT" \
          >"$RAW_FILE" 2>&1 || exit_code=$?
        ;;
      *)
        echo "UNKNOWN_PROVIDER: $PROVIDER (expected: codex)" >&2
        return 2
        ;;
    esac

    # Timeout (exit 124) — no retry, already waited long enough
    if [[ $exit_code -eq 124 ]]; then
      echo "TIMEOUT: $PROVIDER $MODEL exceeded ${TIMEOUT}s limit" >&2
      return 2
    fi

    # Success or non-empty output — proceed to parsing
    if [[ $exit_code -eq 0 ]] || [[ -s "$RAW_FILE" ]]; then
      return 0
    fi

    # Empty output on failure — check if retryable
    if [[ ! -s "$RAW_FILE" ]]; then
      attempt=$((attempt + 1))
      continue
    fi

    # Non-zero exit but with output — proceed to error detection
    return 0
  done

  # All retries exhausted
  return "$exit_code"
}

# ─── Phase 1: CLI Invocation ───

_invoke_cli
invoke_result=$?

if [[ $invoke_result -ne 0 ]]; then
  if [[ ! -s "$RAW_FILE" ]]; then
    echo "EMPTY_RESPONSE: No output from $PROVIDER $MODEL after $((MAX_RETRIES + 1)) attempts" >&2
  fi
  exit 2
fi

# ─── Phase 2: Empty Response Check ───

if [[ ! -s "$RAW_FILE" ]]; then
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
esac

if [[ -n "$ERR_LINE" ]]; then
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

bash "$SCRIPT_DIR/safe-rm.sh" -f "$OUTPUT_FILE"

_parse_primary() {
  case "$PROVIDER" in
    codex)
      # JSONL: find agent_message item → extract .item.text → parse inner JSON
      if ! jq -s 'map(select(.item?.type? == "agent_message")) | .[0].item.text' -r "$RAW_FILE" 2>/dev/null |
        jq '.' >"$OUTPUT_FILE" 2>/dev/null; then
        echo "PARSE_WARN: Primary codex parse failed" >&2
        return 1
      fi
      ;;
  esac
}

_parse_primary

# Validation: check for known response structures (evaluation or agent analysis)
if jq -e '(.criteria // .before.criteria // .after.criteria) | length > 0' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi
# Generic JSON validation: any valid JSON object with at least one array field (researcher, generator, etc.)
if jq -e 'type == "object" and (to_entries | map(select(.value | type == "array" and length > 0)) | length > 0)' "$OUTPUT_FILE" >/dev/null 2>&1; then
  exit 0
fi

# ─── Phase 5: Fallback Parse ───

_parse_fallback() {
  case "$PROVIDER" in
    codex)
      # Fallback: try last agent_message (not first)
      if ! jq -s 'map(select(.item?.type? == "agent_message")) | .[-1].item.text' -r "$RAW_FILE" 2>/dev/null |
        jq '.' >"$OUTPUT_FILE" 2>/dev/null; then
        echo "PARSE_WARN: Fallback codex parse failed" >&2
        return 1
      fi
      ;;
  esac
}

_parse_fallback

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
