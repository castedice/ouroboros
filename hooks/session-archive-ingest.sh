#!/usr/bin/env bash
# SessionEnd hook for session archive enqueue-only ingestion.

set -euo pipefail
set -o errtrace

STDIN_DATA=""
SESSION_ID="unknown"
TRANSCRIPT_PATH=""
ARCHIVE_DATA_ROOT="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/ouroboros-inline}"
ARCHIVE_ROOT="$ARCHIVE_DATA_ROOT/session-archive"
QUEUE_FILE="$ARCHIVE_ROOT/queue.jsonl"

# shellcheck disable=SC2329
fail_open() {
  echo "[session-archive-ingest] fail-open: session=$SESSION_ID $1" >&2
  exit 0
}

trap 'fail_open "unexpected error at line ${LINENO}"' ERR

read_hook_context() {
  if ! [ -t 0 ]; then
    STDIN_DATA="$(cat)"
  fi

  [[ -n "$STDIN_DATA" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  SESSION_ID="$(printf '%s' "$STDIN_DATA" | jq -r '.session_id // .session // "unknown"' 2>/dev/null || printf 'unknown')"
  TRANSCRIPT_PATH="$(printf '%s' "$STDIN_DATA" | jq -r '.transcript_path // .transcript // empty' 2>/dev/null || printf '')"
}

append_queue_path() {
  local source_path="${1-}"
  [[ -n "$source_path" ]] || return 0
  mkdir -p "$ARCHIVE_ROOT" 2>/dev/null || return 0
  touch "$QUEUE_FILE" 2>/dev/null || return 0
  printf '%s\n' "$source_path" >>"$QUEUE_FILE" 2>/dev/null || true
}

enqueue_subagents() {
  local subagent_dir=""
  local subagent_file=""

  [[ -n "$TRANSCRIPT_PATH" ]] || return 0
  [[ -f "$TRANSCRIPT_PATH" ]] || return 0

  subagent_dir="${TRANSCRIPT_PATH%.jsonl}/subagents"
  [[ -d "$subagent_dir" ]] || return 0

  while IFS= read -r subagent_file; do
    [[ -n "$subagent_file" ]] || continue
    append_queue_path "$subagent_file"
  done < <(find "$subagent_dir" -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null | sort)
}

main() {
  read_hook_context
  append_queue_path "$TRANSCRIPT_PATH"
  enqueue_subagents
}

main "$@"
exit 0
