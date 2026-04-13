#!/usr/bin/env bash
# Per-agent project-local calibration memory CRUD.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

AGENT_MEMORY_DIR="$(learning_project_root)/.claude/agent-memory"
AGENT_MEMORY_ID_DIR="$AGENT_MEMORY_DIR/.ids"

usage() {
  cat <<'EOF' >&2
Usage:
  agent-memory.sh read <agent-id>
  agent-memory.sh write <agent-id> <rule-id|auto> <kind> <confidence> <instruction> <evidence-ref>
  agent-memory.sh list
EOF
  exit 1
}

canonical_agent_id() {
  local agent_id="${1:?Missing agent id}"
  if [[ "$agent_id" == *:* ]]; then
    printf '%s\n' "$agent_id"
    return 0
  fi
  printf '%s\n' "${agent_id//--/:}"
}

encode_agent_id() {
  local agent_id="${1:?Missing agent id}"
  printf '%s\n' "${agent_id//:/--}"
}

agent_memory_path() {
  local agent_id="${1:?Missing agent id}"
  local canonical_id=""
  canonical_id="$(canonical_agent_id "$agent_id")"
  printf '%s\n' "$AGENT_MEMORY_DIR/$(encode_agent_id "$canonical_id").json"
}

next_rule_id() {
  local day_key=""
  local counter_file=""
  local lock_dir=""
  local counter_value=0
  local attempt=0
  local fallback_value=0

  day_key="$(date -u +%Y%m%d)"
  mkdir -p "$AGENT_MEMORY_ID_DIR"
  counter_file="$AGENT_MEMORY_ID_DIR/AGM-${day_key}.count"
  lock_dir="${counter_file}.lock"

  while [ "$attempt" -lt 20 ]; do
    if mkdir "$lock_dir" 2>/dev/null; then
      if [ -f "$counter_file" ]; then
        counter_value="$(cat "$counter_file" 2>/dev/null || printf '0')"
      fi
      [[ "$counter_value" =~ ^[0-9]+$ ]] || counter_value=0
      counter_value=$((counter_value + 1))
      printf '%s\n' "$counter_value" >"$counter_file"
      rmdir "$lock_dir" 2>/dev/null || true
      printf 'AGM-%s-%03d\n' "$day_key" "$counter_value"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.05
  done

  fallback_value=$(( (10#$(date -u +%H%M%S) + $$) % 1000 ))
  printf 'AGM-%s-%03d\n' "$day_key" "$fallback_value"
}

read_memory() {
  local agent_id="${1:?Missing agent id}"
  local memory_path=""
  memory_path="$(agent_memory_path "$agent_id")"
  [ -f "$memory_path" ] || return 0
  cat "$memory_path"
}

write_rule() {
  local agent_id="${1:?Missing agent id}"
  local rule_id="${2-}"
  local kind="${3:?Missing kind}"
  local confidence="${4:?Missing confidence}"
  local instruction="${5:?Missing instruction}"
  local evidence_ref="${6-}"
  local canonical_id=""
  local memory_path=""
  local temp_path=""
  local timestamp=""

  command -v jq >/dev/null 2>&1 || {
    echo "jq is required." >&2
    exit 1
  }

  canonical_id="$(canonical_agent_id "$agent_id")"
  if [ -z "$rule_id" ] || [ "$rule_id" = "auto" ] || [ "$rule_id" = "-" ]; then
    rule_id="$(next_rule_id)"
  fi

  memory_path="$(agent_memory_path "$canonical_id")"
  mkdir -p "$AGENT_MEMORY_DIR"
  timestamp="$(learning_timestamp_utc)"
  temp_path="$(mktemp "${TMPDIR:-/tmp}/agent-memory.XXXXXX")"

  if [ -f "$memory_path" ]; then
    jq \
      --arg agent "$canonical_id" \
      --arg updated_at "$timestamp" \
      --arg rule_id "$rule_id" \
      --arg kind "$kind" \
      --argjson confidence "$confidence" \
      --arg instruction "$instruction" \
      --arg evidence_ref "$evidence_ref" \
      '
      .version = 1 |
      .agent = $agent |
      .updated_at = $updated_at |
      .rules = (
        (.rules // []) as $rules |
        if ($rules | map(.id) | index($rule_id)) != null then
          $rules | map(
            if .id == $rule_id then
              .kind = $kind |
              .confidence = $confidence |
              .instruction = $instruction |
              .last_seen = $updated_at |
              .evidence_refs = (((.evidence_refs // []) + (if $evidence_ref == "" then [] else [$evidence_ref] end)) | unique)
            else
              .
            end
          )
        else
          $rules + [{
            id:$rule_id,
            kind:$kind,
            confidence:$confidence,
            instruction:$instruction,
            evidence_refs:(if $evidence_ref == "" then [] else [$evidence_ref] end),
            last_seen:$updated_at
          }]
        end
      )
      ' "$memory_path" >"$temp_path"
  else
    jq -n \
      --arg agent "$canonical_id" \
      --arg updated_at "$timestamp" \
      --arg rule_id "$rule_id" \
      --arg kind "$kind" \
      --argjson confidence "$confidence" \
      --arg instruction "$instruction" \
      --arg evidence_ref "$evidence_ref" \
      '{
        version:1,
        agent:$agent,
        updated_at:$updated_at,
        rules:[
          {
            id:$rule_id,
            kind:$kind,
            confidence:$confidence,
            instruction:$instruction,
            evidence_refs:(if $evidence_ref == "" then [] else [$evidence_ref] end),
            last_seen:$updated_at
          }
        ]
      }' >"$temp_path"
  fi

  mv "$temp_path" "$memory_path"
}

list_agents() {
  [ -d "$AGENT_MEMORY_DIR" ] || return 0
  find "$AGENT_MEMORY_DIR" -maxdepth 1 -type f -name '*.json' 2>/dev/null \
    | sed -E 's#^.*/##; s#\.json$##; s#--#:#g' \
    | sort
}

main() {
  local action="${1:-}"

  case "$action" in
    read)
      [ "$#" -eq 2 ] || usage
      read_memory "$2"
      ;;
    write)
      [ "$#" -eq 7 ] || usage
      write_rule "$2" "$3" "$4" "$5" "$6" "$7"
      ;;
    list)
      [ "$#" -eq 1 ] || usage
      list_agents
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"
