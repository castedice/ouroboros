#!/usr/bin/env bash
# codex-parse.sh — Extract JSON or text from codex exec JSONL output
#
# Usage: codex-parse.sh <raw-jsonl-file> [--json output.json] [--thread-file thread.txt]
#
# Reads a raw JSONL file produced by `codex exec --json` and extracts:
# - Agent message text (the actual Codex response)
# - JSON objects within the message (for evaluation/plan results)
# - Thread ID from thread.started events
#
# Modes:
#   --json output.json    Extract the largest JSON object from the last agent_message
#                         and write it to output.json. Exit 1 if no valid JSON found.
#   --thread-file f.txt   Extract thread_id from thread.started event, write to file.
#   (no flags)            Print all agent_message text to stdout.
#
# Exit codes:
#   0 — success
#   1 — no content found or JSON extraction failed

set -euo pipefail

usage() {
  echo "Usage: codex-parse.sh <raw-jsonl-file> [--json output.json] [--thread-file thread.txt]" >&2
  exit 1
}

RAW_FILE="${1:-}"

if [[ -z "$RAW_FILE" ]] || [[ "$RAW_FILE" == -* ]]; then
  usage
fi

shift || true

JSON_OUTPUT=""
THREAD_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      [[ $# -ge 2 ]] || usage
      JSON_OUTPUT="$2"
      shift 2
      ;;
    --thread-file)
      [[ $# -ge 2 ]] || usage
      THREAD_FILE="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [[ ! -f "$RAW_FILE" ]]; then
  echo "Error: raw JSONL file not found at $RAW_FILE" >&2
  exit 1
fi

STDOUT_MODE=0
if [[ -z "$JSON_OUTPUT" ]] && [[ -z "$THREAD_FILE" ]]; then
  STDOUT_MODE=1
fi

python3 - "$RAW_FILE" "$JSON_OUTPUT" "$THREAD_FILE" "$STDOUT_MODE" <<'PY'
import json
import sys
from pathlib import Path


def iter_candidate_objects(text: str):
    text_length = len(text)
    for start, char in enumerate(text):
        if char != "{":
            continue

        depth = 0
        in_string = False
        escape = False

        for end in range(start, text_length):
            current = text[end]

            if in_string:
                if escape:
                    escape = False
                elif current == "\\":
                    escape = True
                elif current == "\"":
                    in_string = False
                continue

            if current == "\"":
                in_string = True
            elif current == "{":
                depth += 1
            elif current == "}":
                depth -= 1
                if depth == 0:
                    yield text[start : end + 1]
                    break
                if depth < 0:
                    break


def extract_largest_json_object(text: str):
    best_text = None
    best_obj = None

    for candidate in iter_candidate_objects(text):
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            continue

        if not isinstance(parsed, dict):
            continue

        if best_text is None or len(candidate) > len(best_text):
            best_text = candidate
            best_obj = parsed

    return best_obj


raw_path = Path(sys.argv[1])
json_output = sys.argv[2]
thread_file = sys.argv[3]
stdout_mode = sys.argv[4] == "1"

messages = []
thread_id = None

with raw_path.open("r", encoding="utf-8") as handle:
    for raw_line in handle:
        line = raw_line.strip()
        if not line:
            continue

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        if event.get("type") == "thread.started" and isinstance(event.get("thread_id"), str):
            thread_id = event["thread_id"]

        item = event.get("item")
        if isinstance(item, dict) and item.get("type") == "agent_message":
            text = item.get("text")
            if isinstance(text, str):
                messages.append(text)
            continue

        if event.get("type") == "agent_message" and isinstance(event.get("text"), str):
            messages.append(event["text"])

failed = False

if thread_file:
    if thread_id:
        Path(thread_file).write_text(f"{thread_id}\n", encoding="utf-8")
    else:
        failed = True

if json_output:
    if messages:
        parsed = extract_largest_json_object(messages[-1])
    else:
        parsed = None

    if parsed is None:
        failed = True
    else:
        with Path(json_output).open("w", encoding="utf-8") as handle:
            json.dump(parsed, handle, indent=2, ensure_ascii=False)
            handle.write("\n")

if stdout_mode:
    if messages:
        sys.stdout.write("\n\n".join(messages))
        if not messages[-1].endswith("\n"):
            sys.stdout.write("\n")
    else:
        failed = True

sys.exit(1 if failed else 0)
PY
