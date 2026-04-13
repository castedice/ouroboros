#!/usr/bin/env bash
# Tier 3 judge wrapper for saved skill fixture results.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULT_FILE="${1:-}"
RUBRIC_FILE="${2:-}"
OUT_DIR="$ROOT_DIR/.tmp/skill-tests"

[[ -n "$RESULT_FILE" ]] || {
  echo "Usage: scripts/judge-skill-output.sh <fixture-result.json> [rubric.md]" >&2
  exit 1
}

[[ -f "$RESULT_FILE" ]] || {
  echo "Error: result file not found: $RESULT_FILE" >&2
  exit 1
}

if [[ -z "$RUBRIC_FILE" ]]; then
  RUBRIC_FILE="$(jq -r '.judge_rubric // empty' "$RESULT_FILE")"
fi

[[ -n "$RUBRIC_FILE" && -f "$RUBRIC_FILE" ]] || {
  echo "Error: rubric file not found: ${RUBRIC_FILE:-<empty>}" >&2
  exit 1
}

mkdir -p "$OUT_DIR"
BASE_NAME="$(basename "$RESULT_FILE" .json)"
PROMPT_FILE="$(mktemp "$OUT_DIR/${BASE_NAME}.judge.prompt.XXXXXX.txt")"
RAW_FILE="$OUT_DIR/${BASE_NAME}.judge.raw"
OUT_FILE="$OUT_DIR/${BASE_NAME}.judge.json"
trap 'rm -f "$PROMPT_FILE"' EXIT

cat >"$PROMPT_FILE" <<EOF
You are judging a skill fixture result against a rubric.
Return exactly one JSON object with keys verdict, score, strengths, misses, and summary.
Use verdict values pass, fail, or unavailable.
Keep strengths and misses as arrays of short strings.

## Rubric
$(cat "$RUBRIC_FILE")

## Fixture Result
$(cat "$RESULT_FILE")
EOF

if bash "$ROOT_DIR/scripts/codex-relay.sh" "$PROMPT_FILE" --output "$OUT_FILE" --raw "$RAW_FILE" --effort high --timeout 60 >/dev/null 2>&1; then
  jq '{verdict, score, summary, strengths, misses}' "$OUT_FILE"
  echo "judge_result: $OUT_FILE"
  exit 0
fi

jq -n \
  --arg verdict "unavailable" \
  --arg summary "Judge relay failed. Inspect raw output for details." \
  --arg raw "$RAW_FILE" \
  '{verdict: $verdict, score: null, summary: $summary, strengths: [], misses: [], raw_output: $raw}' \
  | tee "$OUT_FILE"

echo "judge_result: $OUT_FILE"
