#!/usr/bin/env bash
# codex-relay.sh — Unified codex exec interface
#
# Usage: codex-relay.sh <prompt-file> [options]
#   --sandbox read-only|workspace-write  (default: read-only)
#   --effort low|medium|high|xhigh       (default: high)
#   --timeout N                          (override auto timeout)
#   --output <file>                      (parse JSON result to file via codex-parse.sh)
#   --text-output <file>                 (save plain text response to file)
#   --thread-id <id>                     (resume existing thread)
#   --save-thread <file>                 (save new thread_id to file)
#   --meta                               (save output sidecar; auto-on with --output/--text-output)
#   --raw <file>                         (raw JSONL path; default: {output}.raw or prompt.raw)
#   --model <model>                      (default: gpt-5.4)
#   --no-git                             (allow running outside a git repo)
#   --add-dir <dir>                      (additional writable directory)
#
# Exit codes:
#   0 — success (JSON parsed to --output, or exec completed for write mode)
#   1 — parse failed (raw file preserved for LLM fallback)
#   2 — codex exec error (auth, timeout, empty response)
#
# Effort-based default timeouts:
#   xhigh=1800s, high=600s, medium=300s, low=300s

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

usage() {
  echo "Usage: codex-relay.sh <prompt-file> [options]" >&2
  echo "  --sandbox read-only|workspace-write" >&2
  echo "  --effort low|medium|high|xhigh" >&2
  echo "  --timeout N" >&2
  echo "  --output <file>" >&2
  echo "  --text-output <file>" >&2
  echo "  --thread-id <id>" >&2
  echo "  --save-thread <file>" >&2
  echo "  --meta" >&2
  echo "  --raw <file>" >&2
  echo "  --model <model>" >&2
  echo "  --no-git" >&2
  echo "  --add-dir <dir>" >&2
  exit 2
}

default_timeout() {
  case "$1" in
    xhigh) echo 1800 ;;
    high) echo 600 ;;
    medium | low) echo 300 ;;
    *) return 1 ;;
  esac
}

default_raw_file() {
  local source="$1"
  local dir
  local base
  local stem

  dir=$(dirname "$source")
  base=$(basename "$source")

  if [[ "$base" == *.* ]]; then
    stem="${base%.*}"
  else
    stem="$base"
  fi

  echo "$dir/$stem.raw"
}

default_meta_file() {
  local source="$1"
  local dir
  local base
  local stem

  dir=$(dirname "$source")
  base=$(basename "$source")

  if [[ "$base" == *.* ]]; then
    stem="${base%.*}"
  else
    stem="$base"
  fi

  echo "$dir/$stem.meta.json"
}

timeout_command() {
  if command -v timeout >/dev/null 2>&1; then
    echo "timeout"
    return
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    echo "gtimeout"
    return
  fi

  echo ""
}

PROMPT_FILE="${1:-}"

if [[ -z "$PROMPT_FILE" ]] || [[ "$PROMPT_FILE" == -* ]]; then
  usage
fi

shift || true

SANDBOX="read-only"
EFFORT="high"
TIMEOUT=""
OUTPUT_FILE=""
TEXT_OUTPUT_FILE=""
THREAD_ID=""
SAVE_THREAD=""
RAW_FILE=""
MODEL="gpt-5.4"
WRITE_META=0
NO_GIT=0
ADD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sandbox)
      [[ $# -ge 2 ]] || usage
      SANDBOX="$2"
      shift 2
      ;;
    --effort)
      [[ $# -ge 2 ]] || usage
      EFFORT="$2"
      shift 2
      ;;
    --timeout)
      [[ $# -ge 2 ]] || usage
      TIMEOUT="$2"
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || usage
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --text-output)
      [[ $# -ge 2 ]] || usage
      TEXT_OUTPUT_FILE="$2"
      shift 2
      ;;
    --thread-id)
      [[ $# -ge 2 ]] || usage
      THREAD_ID="$2"
      shift 2
      ;;
    --save-thread)
      [[ $# -ge 2 ]] || usage
      SAVE_THREAD="$2"
      shift 2
      ;;
    --meta)
      WRITE_META=1
      shift
      ;;
    --raw)
      [[ $# -ge 2 ]] || usage
      RAW_FILE="$2"
      shift 2
      ;;
    --model)
      [[ $# -ge 2 ]] || usage
      MODEL="$2"
      shift 2
      ;;
    --no-git)
      NO_GIT=1
      shift
      ;;
    --add-dir)
      [[ $# -ge 2 ]] || usage
      ADD_DIR="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ -n "$OUTPUT_FILE" && -n "$TEXT_OUTPUT_FILE" ]]; then
  echo "Error: --output and --text-output are mutually exclusive" >&2
  exit 2
fi

PARSED_OUTPUT_FILE="${OUTPUT_FILE:-$TEXT_OUTPUT_FILE}"
OUTPUT_MODE="stdout"
if [[ -n "$OUTPUT_FILE" ]]; then
  OUTPUT_MODE="json"
elif [[ -n "$TEXT_OUTPUT_FILE" ]]; then
  OUTPUT_MODE="text"
fi

if [[ -n "$PARSED_OUTPUT_FILE" ]]; then
  WRITE_META=1
fi

case "$SANDBOX" in
  read-only | workspace-write) ;;
  *)
    echo "Error: invalid sandbox '$SANDBOX'" >&2
    exit 2
    ;;
esac

case "$EFFORT" in
  low | medium | high | xhigh) ;;
  *)
    echo "Error: invalid effort '$EFFORT'" >&2
    exit 2
    ;;
esac

if [[ -z "$TIMEOUT" ]]; then
  TIMEOUT="$(default_timeout "$EFFORT")"
fi

if [[ ! "$TIMEOUT" =~ ^[0-9]+$ ]]; then
  echo "Error: timeout must be an integer number of seconds" >&2
  exit 2
fi

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: prompt file not found at $PROMPT_FILE" >&2
  exit 2
fi

if [[ -z "$RAW_FILE" ]]; then
  if [[ -n "$PARSED_OUTPUT_FILE" ]]; then
    RAW_FILE="${PARSED_OUTPUT_FILE}.raw"
  else
    RAW_FILE="$(default_raw_file "$PROMPT_FILE")"
  fi
fi

TIMEOUT_BIN="$(timeout_command)"

if [[ -z "$TIMEOUT_BIN" ]]; then
  echo "Error: timeout command not found (expected 'timeout' or 'gtimeout')" >&2
  exit 2
fi

run_exit=0

EXTRA_ARGS=()
if [[ "$NO_GIT" -eq 1 ]]; then
  EXTRA_ARGS+=(--skip-git-repo-check)
fi
if [[ -n "$ADD_DIR" ]]; then
  EXTRA_ARGS+=(--add-dir "$ADD_DIR")
fi

if [[ -n "$THREAD_ID" ]]; then
  # Resume mode: codex exec resume <session_id> <prompt> --json -m MODEL ...
  # resume subcommand takes session_id and prompt as positional args
  "$TIMEOUT_BIN" "$TIMEOUT" codex exec \
    --json \
    -m "$MODEL" \
    -c "model_reasoning_effort=$EFFORT" \
    --sandbox "$SANDBOX" \
    "${EXTRA_ARGS[@]}" \
    resume "$THREAD_ID" \
    "$(cat "$PROMPT_FILE")" \
    >"$RAW_FILE" 2>&1
  run_exit=$?
else
  # New session: codex exec --json -m MODEL --sandbox ... - (stdin)
  CODEX_ARGS=(
    codex exec
    --json
    -m "$MODEL"
    -c "model_reasoning_effort=$EFFORT"
    --sandbox "$SANDBOX"
    "${EXTRA_ARGS[@]}"
    -
  )
  "$TIMEOUT_BIN" "$TIMEOUT" bash -c '
    prompt_file="$1"
    shift
    cat "$prompt_file" | "$@"
  ' _ "$PROMPT_FILE" "${CODEX_ARGS[@]}" >"$RAW_FILE" 2>&1
  run_exit=$?
fi

if [[ $run_exit -eq 124 ]]; then
  echo "TIMEOUT: codex exec exceeded ${TIMEOUT}s limit" >&2
  exit 2
fi

if [[ $run_exit -ne 0 ]]; then
  echo "CODEX_ERROR: codex exec failed with exit code $run_exit" >&2
  exit 2
fi

if [[ ! -s "$RAW_FILE" ]]; then
  echo "EMPTY_RESPONSE: No output from codex exec" >&2
  exit 2
fi

parse_failed=0
META_FILE=""
TEMP_THREAD_FILE=""

if [[ -n "$SAVE_THREAD" ]]; then
  bash "$SCRIPT_DIR/safe-rm.sh" -f "$SAVE_THREAD"
  if [[ -n "$THREAD_ID" ]]; then
    printf '%s\n' "$THREAD_ID" >"$SAVE_THREAD"
  elif ! bash "$SCRIPT_DIR/codex-parse.sh" "$RAW_FILE" --thread-file "$SAVE_THREAD"; then
    parse_failed=1
  fi
fi

if [[ -n "$OUTPUT_FILE" ]]; then
  bash "$SCRIPT_DIR/safe-rm.sh" -f "$OUTPUT_FILE"
  if ! bash "$SCRIPT_DIR/codex-parse.sh" "$RAW_FILE" --json "$OUTPUT_FILE"; then
    parse_failed=1
  fi
elif [[ -n "$TEXT_OUTPUT_FILE" ]]; then
  bash "$SCRIPT_DIR/safe-rm.sh" -f "$TEXT_OUTPUT_FILE"
  if ! bash "$SCRIPT_DIR/codex-parse.sh" "$RAW_FILE" >"$TEXT_OUTPUT_FILE"; then
    parse_failed=1
  fi
else
  if ! bash "$SCRIPT_DIR/codex-parse.sh" "$RAW_FILE"; then
    parse_failed=1
  fi
fi

if [[ $parse_failed -ne 0 ]]; then
  exit 1
fi

if [[ "$WRITE_META" -eq 1 ]]; then
  META_FILE="$(default_meta_file "$PARSED_OUTPUT_FILE")"
  bash "$SCRIPT_DIR/safe-rm.sh" -f "$META_FILE"

  META_THREAD_ID="$THREAD_ID"

  if [[ -z "$META_THREAD_ID" && -n "$SAVE_THREAD" && -f "$SAVE_THREAD" ]]; then
    META_THREAD_ID="$(tr -d '\n' <"$SAVE_THREAD")"
  fi

  if [[ -z "$META_THREAD_ID" ]]; then
    TEMP_THREAD_FILE="$(mktemp "${TMPDIR:-/tmp}/codex-relay-thread.XXXXXX")"
    if bash "$SCRIPT_DIR/codex-parse.sh" "$RAW_FILE" --thread-file "$TEMP_THREAD_FILE" >/dev/null 2>&1; then
      META_THREAD_ID="$(tr -d '\n' <"$TEMP_THREAD_FILE")"
    fi
    rm -f "$TEMP_THREAD_FILE"
  fi

  python3 - "$META_FILE" "$META_THREAD_ID" "$MODEL" "$EFFORT" "$SANDBOX" "$OUTPUT_MODE" "$PARSED_OUTPUT_FILE" "$RAW_FILE" <<'PY'
import json
import sys
from pathlib import Path

meta_path, thread_id, model, effort, sandbox, output_mode, output_file, raw_file = sys.argv[1:]
payload = {
    "thread_id": thread_id or None,
    "model": model,
    "effort": effort,
    "sandbox": sandbox,
    "output_mode": output_mode,
    "output_file": output_file,
    "raw_file": raw_file,
}
Path(meta_path).write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY
fi

exit 0
