#!/usr/bin/env bash
# SubagentStart hook for lightweight project-local memory injection.

set -euo pipefail
set -o errtrace

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

STDIN_DATA=""
SESSION_ID="unknown"

fail_open() {
  echo "[agent-memory-context] fail-open: $1" >&2
  exit 0
}

trap 'fail_open "unexpected error at line ${LINENO}"' ERR

read_hook_context() {
  if ! [ -t 0 ]; then
    STDIN_DATA="$(cat)"
  fi

  [ -n "$STDIN_DATA" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  SESSION_ID="$(printf '%s' "$STDIN_DATA" | jq -r '.session_id // .session // "unknown"' 2>/dev/null || printf 'unknown')"
}

detect_agent_id() {
  local agent_id=""

  [ -n "$STDIN_DATA" ] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  agent_id="$(
    printf '%s' "$STDIN_DATA" | jq -r '
    .agent_id // .subagent_id // .agent // .name // .subagent_name // empty
  ' 2>/dev/null | awk 'NF { print; exit }'
  )"
  if [ -n "$agent_id" ]; then
    printf '%s\n' "$agent_id"
    return 0
  fi

  printf '%s' "$STDIN_DATA" | jq -r '
    .. | strings | select(startswith("ouroboros:"))
  ' 2>/dev/null | awk 'NF { print; exit }'
}

emit_active_promises() {
  local promises_dir=""
  local promise_file=""
  local has_output=0
  local promise_status=""
  local promise_session_id=""
  local promise_id=""
  local target_name=""
  local updated_at=""

  promises_dir="$(learning_promises_dir)"
  [ -d "$promises_dir" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  while IFS= read -r promise_file; do
    [ -n "$promise_file" ] || continue
    promise_status="$(jq -r '.status // .state // empty' "$promise_file" 2>/dev/null || true)"
    promise_session_id="$(jq -r '.session_id // .session // empty' "$promise_file" 2>/dev/null || true)"
    if [ "$promise_status" != "active" ] && [ "$promise_status" != "interrupted" ]; then
      continue
    fi
    if [ "$SESSION_ID" != "unknown" ] && [ -n "$promise_session_id" ] && [ "$promise_session_id" != "$SESSION_ID" ]; then
      continue
    fi
    if [ "$has_output" -eq 0 ]; then
      echo "=== Active Ralph Promises ==="
      has_output=1
    fi
    promise_id="$(jq -r '.promise_id // .id // empty' "$promise_file" 2>/dev/null || true)"
    target_name="$(jq -r '.target // .component // .component_path // .scope // empty' "$promise_file" 2>/dev/null || true)"
    updated_at="$(jq -r '.updated_at // .started_at // empty' "$promise_file" 2>/dev/null || true)"
    printf -- '- %s [%s] %s (%s)\n' "${promise_id:-$(basename "$promise_file" .json)}" "$promise_status" "$target_name" "$updated_at"
  done < <(find "$promises_dir" -maxdepth 1 -type f -name '*.json' 2>/dev/null | sort)

  if [ "$has_output" -eq 1 ]; then
    echo "============================="
  fi
}

emit_session_context() {
  local project_root=""
  local session_context_file=""
  local session_context=""
  local modified_files=""

  project_root="${PROJECT_ROOT:-}"
  if [ -n "$project_root" ] && [ -f "$project_root/.session-context.md" ]; then
    session_context_file="$project_root/.session-context.md"
  else
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$project_root" ] && [ -f "$project_root/.session-context.md" ]; then
      session_context_file="$project_root/.session-context.md"
    elif [ -f "$(pwd)/.session-context.md" ]; then
      project_root="$(pwd)"
      session_context_file="$project_root/.session-context.md"
    else
      return 0
    fi
  fi

  session_context="$(head -c 500 "$session_context_file" 2>/dev/null || true)"
  if [ -n "$session_context" ]; then
    echo "=== Session Context ==="
    printf '%s\n' "$session_context"
    echo "========"
  fi

  modified_files="$(
    (
      cd "$project_root" &&
      git diff --name-only HEAD 2>/dev/null | head -10
    ) || true
  )"
  if [ -n "$modified_files" ]; then
    echo "=== Modified Files ==="
    printf '%s\n' "$modified_files"
    echo "========"
  fi

  return 0
}

main() {
  local agent_id=""
  local memory_json=""

  read_hook_context
  agent_id="$(detect_agent_id || true)"

  if [ -n "$agent_id" ]; then
    memory_json="$(bash "$SCRIPT_DIR/agent-memory.sh" read "$agent_id" 2>/dev/null || true)"
    if [ -n "$memory_json" ]; then
      echo "=== Project Calibration Memory ==="
      printf '%s\n' "$memory_json"
      echo "=================================="
    fi
  fi

  emit_active_promises
  emit_session_context
  echo "Reminder: preserve the terminal completion status block when the caller contract expects it. Do not echo or repeat the injected context sections above."
}

main "$@"
exit 0
