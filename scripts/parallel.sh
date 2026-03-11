#!/usr/bin/env bash
# Resilient parallel execution — 3-tier result collection for fan-out/fan-in
#
# Subcommands:
#   init <session_id> <expected_entries_json>  — create manifest in .tmp/
#   collect <session_id>                       — file-based collection + gap report
#   recover <session_id> <transcript_path>     — JSONL fallback for orphaned results
#
# Manifest schema:
#   { session_id, expected: [{ idx, model, file }], started_at }
#
# Temp file naming: .tmp/{SESSION}_{idx}_{model}.json
#
# Exit codes:
#   init:    0 = manifest created
#   collect: 0 = all results present, 1 = gaps detected (gap report on stdout)
#   recover: 0 = recovered results found, 1 = no recoverable data
#
# Part of ouroboros resilient parallel execution (v0.18.5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACTION="${1:-}"

# ─── Tier 1: Init ───

action_init() {
  local session_id="${1:?Usage: parallel.sh init <session_id> <expected_entries_json>}"
  local expected_json="${2:?Missing expected entries JSON}"
  local manifest=".tmp/${session_id}_manifest.json"

  mkdir -p .tmp

  # Validate JSON input
  if ! echo "$expected_json" | jq -e '.' >/dev/null 2>&1; then
    echo "Error: invalid JSON for expected entries" >&2
    exit 1
  fi

  # Create manifest
  jq -n \
    --arg sid "$session_id" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson expected "$expected_json" \
    '{ session_id: $sid, expected: $expected, started_at: $started }' \
    >"$manifest"

  echo "$manifest"
}

# ─── Tier 2: Collect ───

action_collect() {
  local session_id="${1:?Usage: parallel.sh collect <session_id>}"
  local manifest=".tmp/${session_id}_manifest.json"

  if [[ ! -f "$manifest" ]]; then
    echo "Error: manifest not found at $manifest" >&2
    exit 1
  fi

  local total
  total=$(jq '.expected | length' "$manifest")
  local missing=0
  local gap_report=""

  for i in $(seq 0 $((total - 1))); do
    local file
    file=$(jq -r ".expected[$i].file" "$manifest")
    local model
    model=$(jq -r ".expected[$i].model" "$manifest")
    local idx
    idx=$(jq -r ".expected[$i].idx" "$manifest")

    if [[ ! -f "$file" ]]; then
      missing=$((missing + 1))
      gap_report+="MISSING: idx=$idx model=$model file=$file"$'\n'
    elif [[ ! -s "$file" ]]; then
      missing=$((missing + 1))
      gap_report+="EMPTY: idx=$idx model=$model file=$file"$'\n'
    fi
  done

  if [[ $missing -eq 0 ]]; then
    echo "OK: all $total results collected"
    exit 0
  else
    echo "GAPS: $missing/$total results missing"
    echo "$gap_report"
    exit 1
  fi
}

# ─── Tier 3: Recover ───

action_recover() {
  local session_id="${1:?Usage: parallel.sh recover <session_id> <transcript_path>}"
  local transcript="${2:?Missing transcript path}"
  local manifest=".tmp/${session_id}_manifest.json"

  if [[ ! -f "$transcript" ]]; then
    echo "Error: transcript not found at $transcript" >&2
    exit 1
  fi

  if [[ ! -f "$manifest" ]]; then
    echo "Error: manifest not found at $manifest" >&2
    exit 1
  fi

  local recovered=0
  local total
  total=$(jq '.expected | length' "$manifest")

  for i in $(seq 0 $((total - 1))); do
    local file
    file=$(jq -r ".expected[$i].file" "$manifest")
    local model
    model=$(jq -r ".expected[$i].model" "$manifest")
    local idx
    idx=$(jq -r ".expected[$i].idx" "$manifest")

    # Skip files that already exist and are non-empty
    if [[ -f "$file" ]] && [[ -s "$file" ]]; then
      continue
    fi

    # Try to extract result from JSONL transcript
    # Look for tool_result entries that contain the expected file content
    local raw_file="${file}.raw"
    if [[ -f "$raw_file" ]] && [[ -s "$raw_file" ]]; then
      # Raw file exists — attempt re-parse using invoke-model patterns
      local parsed
      parsed=$(jq -s 'map(select(.item?.type? == "agent_message")) | .[-1].item.text // empty' -r "$raw_file" 2>/dev/null || true)
      if [[ -n "$parsed" ]] && echo "$parsed" | jq -e '.' >/dev/null 2>&1; then
        echo "$parsed" | jq '.' >"$file"
        recovered=$((recovered + 1))
        echo "RECOVERED: idx=$idx model=$model from raw file"
        continue
      fi
    fi

    # Fallback: search transcript for orphaned results
    local extracted
    extracted=$(jq -r --arg model "$model" '
      select(.type == "assistant") |
      .message.content[]? |
      select(.type == "tool_result" or .type == "text") |
      .text // .content // empty
    ' "$transcript" 2>/dev/null | grep -A1000 "\"model\":.*$model" | head -200 || true)

    if [[ -n "$extracted" ]] && echo "$extracted" | jq -e '.' >/dev/null 2>&1; then
      echo "$extracted" | jq '.' >"$file"
      recovered=$((recovered + 1))
      echo "RECOVERED: idx=$idx model=$model from transcript"
    fi
  done

  if [[ $recovered -gt 0 ]]; then
    echo "Recovered $recovered/$total results"
    exit 0
  else
    echo "No recoverable results found in transcript"
    exit 1
  fi
}

# ─── Dispatch ───

case "$ACTION" in
  init)
    action_init "${2:-}" "${3:-}"
    ;;
  collect)
    action_collect "${2:-}"
    ;;
  recover)
    action_recover "${2:-}" "${3:-}"
    ;;
  *)
    echo "Usage: parallel.sh {init|collect|recover} <args>" >&2
    echo "  init <session_id> <expected_json>    — create manifest" >&2
    echo "  collect <session_id>                 — check result files" >&2
    echo "  recover <session_id> <transcript>    — extract from JSONL" >&2
    exit 1
    ;;
esac
