#!/usr/bin/env bash
# Session lifecycle manager for ouroboros --multi commands
#
# Actions:
#   init    — Generate session ID + ensure .tmp directory exists. stdout: session ID
#   cleanup <session-id> — Clean up session temp files
#
# Usage:
#   SESSION_ID=$(bash scripts/session.sh init)
#   bash scripts/session.sh cleanup "$SESSION_ID"

set -euo pipefail

ACTION="${1:-}"

action_init() {
  mkdir -p .tmp
  uuidgen | cut -d- -f1 | tr '[:upper:]' '[:lower:]'
}

action_cleanup() {
  local session_id="${1:-}"
  if [[ -z "$session_id" ]]; then
    echo "Error: session ID required" >&2
    exit 1
  fi
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  bash "$SCRIPT_DIR/safe-rm.sh" -f .tmp/"${session_id}"_*
}

case "$ACTION" in
  init)
    action_init
    ;;
  cleanup)
    action_cleanup "${2:-}"
    ;;
  *)
    echo "Usage: session.sh {init|cleanup <session-id>}" >&2
    exit 1
    ;;
esac
