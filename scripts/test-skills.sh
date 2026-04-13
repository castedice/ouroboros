#!/usr/bin/env bash
# Tier 2 skill fixture runner.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE_DIR="$ROOT_DIR/dev/test-sets/skill-fixtures"
OUT_DIR="$ROOT_DIR/.tmp/skill-tests"

usage() {
  echo "Usage: scripts/test-skills.sh [fixture.json ...]" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: missing required tool '$1'" >&2
    exit 1
  }
}

run_fixture() {
  local fixture="$1"
  local id query raw result run_exit status stage

  id="$(jq -r '.id // empty' "$fixture")"
  query="$(jq -r '.query // empty' "$fixture")"
  [[ -n "$id" && -n "$query" ]] || {
    echo "FAIL $(basename "$fixture")"
    echo "  evidence: missing required fixture fields"
    return 1
  }

  raw="$OUT_DIR/${id}.claude.json"
  result="$OUT_DIR/${id}.result.json"
  run_exit=0

  if command -v claude >/dev/null 2>&1; then
    claude -p --output-format json "$query" >"$raw" 2>&1 || run_exit=$?
  else
    printf 'claude CLI not found\n' >"$raw"
    run_exit=127
  fi

  python3 - "$fixture" "$raw" "$result" "$run_exit" <<'PY'
import json
import sys
from pathlib import Path


def extract_text(payload):
    if isinstance(payload, list):
        result_texts = []
        assistant_texts = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            if item.get("type") == "result" and isinstance(item.get("result"), str):
                result_texts.append(item["result"])
            if item.get("type") == "assistant":
                message = item.get("message") or {}
                for block in message.get("content") or []:
                    if isinstance(block, dict) and block.get("type") == "text":
                        assistant_texts.append(block.get("text", ""))
        texts = result_texts or assistant_texts
        return "\n".join(part for part in texts if part).strip()
    if isinstance(payload, dict):
        if isinstance(payload.get("result"), str):
            return payload["result"].strip()
        if isinstance(payload.get("output"), str):
            return payload["output"].strip()
    return ""


def match_terms(terms, text):
    matched = []
    missing = []
    haystack = text.casefold()
    for term in terms:
        if not term:
            continue
        (matched if term.casefold() in haystack else missing).append(term)
    return matched, missing


fixture_path = Path(sys.argv[1])
raw_path = Path(sys.argv[2])
result_path = Path(sys.argv[3])
run_exit = int(sys.argv[4])
fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
raw_text = raw_path.read_text(encoding="utf-8")
warnings = []
payload = None

try:
    payload = json.loads(raw_text)
except json.JSONDecodeError:
    warnings.append("claude response was not valid JSON")

output_text = extract_text(payload) if payload is not None else raw_text.strip()
workspace_setup = fixture.get("workspace_setup")
if workspace_setup not in (None, "", {}):
    warnings.append("workspace_setup present but not applied by minimal harness")

expected_loads = fixture.get("expected_loads") or []
forbidden_loads = fixture.get("forbidden_loads") or []
expected_behaviors = fixture.get("expected_behaviors") or []
activation_matched, activation_missing = match_terms(expected_loads, output_text)
forbidden_hits, _ = match_terms(forbidden_loads, output_text)
behavior_matched, behavior_missing = match_terms(expected_behaviors, output_text)

activation_ok = run_exit == 0 and not activation_missing and not forbidden_hits
execution_ok = run_exit == 0 and not behavior_missing
status = "PASS" if activation_ok and execution_ok else "FAIL"
stage = "run" if run_exit != 0 else "activation" if not activation_ok else "execution" if not execution_ok else None

result = {
    "id": fixture.get("id"),
    "fixture_path": str(fixture_path),
    "skill": fixture.get("skill"),
    "query": fixture.get("query"),
    "judge_rubric": fixture.get("judge_rubric"),
    "baseline_output": fixture.get("baseline_output"),
    "status": status,
    "first_broken_stage": stage,
    "run": {"ok": run_exit == 0, "exit_code": run_exit, "raw_response_path": str(raw_path)},
    "activation": {
        "ok": activation_ok,
        "matched": activation_matched,
        "missing": activation_missing,
        "forbidden_hits": forbidden_hits,
    },
    "execution": {
        "ok": execution_ok,
        "matched": behavior_matched,
        "missing": behavior_missing,
    },
    "warnings": warnings,
    "output_text": output_text,
}

result_path.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

  status="$(jq -r '.status' "$result")"
  stage="$(jq -r '.first_broken_stage // "none"' "$result")"
  echo "$status $id"
  echo "  stage: $stage"
  echo "  activation matched: $(jq -r '.activation.matched | join(", ") // ""' "$result")"
  echo "  activation missing: $(jq -r '.activation.missing | join(", ") // ""' "$result")"
  echo "  forbidden hits: $(jq -r '.activation.forbidden_hits | join(", ") // ""' "$result")"
  echo "  execution missing: $(jq -r '.execution.missing | join(", ") // ""' "$result")"
  echo "  evidence: $(jq -r '.output_text | split("\n")[0] // ""' "$result")"
  echo "  result: $result"
  [[ "$status" == "PASS" ]]
}

main() {
  local fixtures=() failed=0

  require_tool jq
  require_tool python3
  mkdir -p "$OUT_DIR"

  if [[ $# -gt 0 ]]; then
    [[ "$1" != "--help" ]] || usage
    fixtures=("$@")
  else
    shopt -s nullglob
    fixtures=("$FIXTURE_DIR"/*.json)
    shopt -u nullglob
  fi

  [[ ${#fixtures[@]} -gt 0 ]] || {
    echo "No fixture files found." >&2
    exit 1
  }

  for fixture in "${fixtures[@]}"; do
    run_fixture "$fixture" || failed=1
  done

  exit "$failed"
}

main "$@"
