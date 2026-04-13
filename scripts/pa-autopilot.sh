#!/usr/bin/env bash
# pa-autopilot.sh - nightly vault gardening daemon.
#
# This script runs a five-stage nightly PA maintenance pass.
# It refreshes local infrastructure, optionally runs Claude headless gardening, and writes a daily report.

set -euo pipefail

# Core paths and runtime defaults.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
VAULT_PATH="${PA_VAULT_PATH:-}"
MAX_BUDGET="${PA_AUTOPILOT_MAX_BUDGET_USD:-10}"
LOG_DIR="$HOME/Library/Logs/ouroboros"
LOG_FILE="$LOG_DIR/pa-autopilot.log"
LOCK_DIR="$HOME/Library/Caches/ouroboros/pa-autopilot.lock"
TEMPLATE_PATH="$PLUGIN_DIR/templates/pa/gardening-report.md"
RUN_DATE="$(date +%Y-%m-%d)"
STARTED_AT="$(date '+%Y-%m-%dT%H:%M:%S%z')"
RUNS_DIR=""
RUN_JSON_PATH=""
VISIBLE_NOTE_PATH=""

# CLI flags.
DRY_RUN=0
INFRA_ONLY=0
GARDENING_ONLY=0
NO_SYNC=0

# Preflight state.
HAVE_QMD=0
HAVE_OB=0
HAVE_CLAUDE=0
AUTH_OK=0
POSTURE="unknown"

# Stage execution state.
SKIP_CODE=10
STAGE_SEP=$'\034'
CURRENT_STAGE_ERR_FILE=""
STAGE_REASON=""
REPORT_NOTES=""
declare -a STAGES=()

usage() {
  cat <<'EOF'
pa-autopilot.sh - nightly vault gardening daemon

Usage:
  pa-autopilot.sh [options]

Options:
  --dry-run          Check paths, tools, auth without executing
  --infra-only       Run infrastructure only (no Claude)
  --gardening-only   Run gardening only (no infra)
  --no-sync          Skip Obsidian Sync steps

Environment:
  PA_VAULT_PATH      Vault path (required)

Crontab:
  30 2 * * * /path/to/pa-autopilot.sh >> ~/Library/Logs/ouroboros/pa-autopilot.log 2>&1
EOF
}

# Logging always goes to stderr and the persistent log file.
log() {
  local ts line
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  line="[$ts] $*"
  printf '%s\n' "$line" >>"$LOG_FILE"
  printf '%s\n' "$line" >&2
}

die() {
  log "Error: $*"
  exit 1
}

# JSON helpers keep the machine artifact valid without jq.
json_bool() {
  if [ "$1" -eq 1 ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'
}

# Text helpers normalize stage notes for JSON and Markdown output.
sanitize_single_line() {
  printf '%s\n' "$1" |
    paste -sd ' ' - |
    sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

stderr_tail() {
  if [ -s "$1" ]; then
    tail -n 10 "$1" |
      paste -sd ' ' - |
      sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//' |
      cut -c1-500
  fi
}

# Preflight checks collect capability state without failing on optional tools.
check_binaries() {
  command -v qmd >/dev/null 2>&1 && HAVE_QMD=1 || true
  command -v ob >/dev/null 2>&1 && HAVE_OB=1 || true
  command -v claude >/dev/null 2>&1 && HAVE_CLAUDE=1 || true
}

check_vault_path() {
  [ -n "$VAULT_PATH" ] || die "PA_VAULT_PATH is not set. Export it or pass it as an environment variable."
  [ -d "$VAULT_PATH" ] || die "Vault path does not exist: $VAULT_PATH"
  [ -f "$VAULT_PATH/.pa/settings.json" ] || die "Missing vault settings: $VAULT_PATH/.pa/settings.json"
  RUNS_DIR="$VAULT_PATH/.pa/autopilot/runs"
  RUN_JSON_PATH="$RUNS_DIR/$RUN_DATE.json"
  VISIBLE_NOTE_PATH="$VAULT_PATH/PA Gardening Report.md"
}

check_auth() {
  local output
  AUTH_OK=0
  [ "$HAVE_CLAUDE" -eq 1 ] || return 0
  output="$(claude auth status 2>&1 || true)"
  if printf '%s\n' "$output" | grep -Eqi 'loggedIn[^[:alpha:]]*[:=][[:space:]]*(true|1|yes)'; then
    AUTH_OK=1
  fi
}

check_posture() {
  local raw
  raw="$(tr -d '\n' <"$VAULT_PATH/.pa/settings.json" | sed -n 's/.*"automation_posture"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  if [ -n "$raw" ]; then
    POSTURE="$raw"
  else
    POSTURE="unknown"
  fi
}

# The lock prevents overlapping cron runs from trampling each other.
acquire_lock() {
  mkdir -p "$HOME/Library/Caches/ouroboros"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    log "Already running"
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

# run_stage never aborts the whole pipeline.
# It captures command stderr, records timing, and stores a normalized stage result.
run_stage() {
  local name="$1"
  local fn="$2"
  local err_file rc status duration_ms tail_text start_s

  err_file="$(mktemp)"
  CURRENT_STAGE_ERR_FILE="$err_file"
  STAGE_REASON=""
  start_s="$SECONDS"

  log "Stage start: $name"
  set +e
  "$fn"
  rc=$?
  set -e
  duration_ms=$(((SECONDS - start_s) * 1000))
  tail_text="$(stderr_tail "$err_file")"
  rm -f "$err_file"
  CURRENT_STAGE_ERR_FILE=""

  case "$rc" in
    0)
      status="ok"
      ;;
    "$SKIP_CODE")
      status="skipped"
      [ -n "$tail_text" ] || tail_text="$STAGE_REASON"
      ;;
    *)
      status="failed"
      [ -n "$tail_text" ] || tail_text="${STAGE_REASON:-command failed with exit $rc}"
      log "Warning: stage failed: $name"
      ;;
  esac

  STAGES+=("$name${STAGE_SEP}$status${STAGE_SEP}$duration_ms${STAGE_SEP}$tail_text")
  log "Stage finish: $name ($status, ${duration_ms}ms)"
}

# Stage 0 pulls remote changes before any local work starts.
stage_pre_sync() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$NO_SYNC" -eq 1 ]; then
    STAGE_REASON="sync disabled"
    return "$SKIP_CODE"
  fi
  if [ "$HAVE_OB" -eq 0 ]; then
    STAGE_REASON="ob not available"
    return "$SKIP_CODE"
  fi
  ob sync --path "$VAULT_PATH" >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Stage 1a refreshes QMD indexes and embeddings.
stage_infra_qmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$GARDENING_ONLY" -eq 1 ]; then
    STAGE_REASON="gardening-only"
    return "$SKIP_CODE"
  fi
  if [ "$HAVE_QMD" -eq 0 ]; then
    STAGE_REASON="qmd not available"
    return "$SKIP_CODE"
  fi
  qmd update >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
  qmd embed >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Stage 1b regenerates the masked shadow vault.
stage_infra_shadow() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$GARDENING_ONLY" -eq 1 ]; then
    STAGE_REASON="gardening-only"
    return "$SKIP_CODE"
  fi
  [ -f "$PLUGIN_DIR/scripts/pa-shadow.sh" ] || {
    STAGE_REASON="missing pa-shadow.sh"
    return 1
  }
  bash "$PLUGIN_DIR/scripts/pa-shadow.sh" sync "$VAULT_PATH" >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Stage 1c rebuilds the hash index used by privacy masking.
stage_infra_hash_index() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$GARDENING_ONLY" -eq 1 ]; then
    STAGE_REASON="gardening-only"
    return "$SKIP_CODE"
  fi
  [ -f "$PLUGIN_DIR/scripts/pa-mask.sh" ] || {
    STAGE_REASON="missing pa-mask.sh"
    return 1
  }
  PA_VAULT_PATH="$VAULT_PATH" bash "$PLUGIN_DIR/scripts/pa-mask.sh" hash-index >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Stage 2 runs unattended Claude gardening only when auth and posture allow it.
stage_gardening() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$INFRA_ONLY" -eq 1 ]; then
    STAGE_REASON="infra-only"
    return "$SKIP_CODE"
  fi
  if [ "$HAVE_CLAUDE" -eq 0 ]; then
    STAGE_REASON="claude not available"
    return "$SKIP_CODE"
  fi
  if [ "$AUTH_OK" -eq 0 ]; then
    STAGE_REASON="claude auth not ready"
    return "$SKIP_CODE"
  fi
  if [ "$POSTURE" != "operate" ]; then
    STAGE_REASON="automation_posture=$POSTURE"
    return "$SKIP_CODE"
  fi
  [ -f "$PLUGIN_DIR/.mcp.json" ] || {
    STAGE_REASON="missing .mcp.json"
    return 1
  }

  claude -p \
    --plugin-dir "$PLUGIN_DIR" \
    --add-dir "$VAULT_PATH" \
    --permission-mode bypassPermissions \
    --max-budget-usd "$MAX_BUDGET" \
    --mcp-config "$PLUGIN_DIR/.mcp.json" \
    --append-system-prompt "You are running unattended nightly PA autopilot. Never ask follow-up questions. If a step would require confirmation, emit a report-only recommendation and continue. Never delete, archive, rename, or move notes automatically." \
    "Run /pa steward" >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Stage 3 pushes resulting changes back to Obsidian Sync.
stage_post_sync() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  if [ "$NO_SYNC" -eq 1 ]; then
    STAGE_REASON="sync disabled"
    return "$SKIP_CODE"
  fi
  if [ "$HAVE_OB" -eq 0 ]; then
    STAGE_REASON="ob not available"
    return "$SKIP_CODE"
  fi
  ob sync --path "$VAULT_PATH" >>"$LOG_FILE" 2>>"$CURRENT_STAGE_ERR_FILE"
}

# Reporting helpers render the collected stage state into JSON and Markdown.
render_summary() {
  local entry name status duration note ok_count fail_count skip_count
  ok_count=0
  fail_count=0
  skip_count=0

  for entry in "${STAGES[@]}"; do
    IFS="$STAGE_SEP" read -r name status duration note <<<"$entry"
    case "$status" in
      ok) ok_count=$((ok_count + 1)) ;;
      failed) fail_count=$((fail_count + 1)) ;;
      skipped) skip_count=$((skip_count + 1)) ;;
    esac
  done

  printf '%s\n' "ok: $ok_count, failed: $fail_count, skipped: $skip_count"
}

render_stage_table() {
  local entry name status duration note clean_note
  printf '| Stage | Status | Duration | Notes |\n'
  printf '| --- | --- | ---: | --- |\n'
  for entry in "${STAGES[@]}"; do
    IFS="$STAGE_SEP" read -r name status duration note <<<"$entry"
    clean_note="$(sanitize_single_line "$note" | sed 's/|/\\|/g')"
    [ -n "$clean_note" ] || clean_note='-'
    printf '| %s | %s | %sms | %s |\n' "$name" "$status" "$duration" "$clean_note"
  done
}

# The visible note uses a simple token template.
# If the repo template is missing, the script falls back to a built-in default.
default_template() {
  cat <<'EOF'
# PA Gardening Report

- Date: {{DATE}}
- Vault: `{{VAULT_PATH}}`
- Mode: `{{MODE}}`
- Claude auth: `{{AUTH_OK}}`
- Posture: `{{POSTURE}}`
- Sync: `{{SYNC_MODE}}`

## Summary

{{SUMMARY}}

## Stages

{{STAGE_TABLE}}

## Notes

{{NOTES}}
EOF
}

generate_run_json() {
  local tmp now total i entry name status duration note

  mkdir -p "$RUNS_DIR"
  tmp="$(mktemp)"
  now="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  total="${#STAGES[@]}"

  {
    printf '{\n'
    printf '  "date": "%s",\n' "$(json_escape "$RUN_DATE")"
    printf '  "started_at": "%s",\n' "$(json_escape "$STARTED_AT")"
    printf '  "finished_at": "%s",\n' "$(json_escape "$now")"
    printf '  "vault_path": "%s",\n' "$(json_escape "$VAULT_PATH")"
    printf '  "plugin_dir": "%s",\n' "$(json_escape "$PLUGIN_DIR")"
    printf '  "dry_run": %s,\n' "$(json_bool "$DRY_RUN")"
    printf '  "infra_only": %s,\n' "$(json_bool "$INFRA_ONLY")"
    printf '  "gardening_only": %s,\n' "$(json_bool "$GARDENING_ONLY")"
    printf '  "no_sync": %s,\n' "$(json_bool "$NO_SYNC")"
    printf '  "auth_ok": %s,\n' "$(json_bool "$AUTH_OK")"
    printf '  "posture": "%s",\n' "$(json_escape "$POSTURE")"
    printf '  "binaries": {"qmd": %s, "ob": %s, "claude": %s},\n' \
      "$(json_bool "$HAVE_QMD")" "$(json_bool "$HAVE_OB")" "$(json_bool "$HAVE_CLAUDE")"
    printf '  "summary": "%s",\n' "$(json_escape "$(render_summary)")"
    printf '  "stages": [\n'
    i=0
    for entry in "${STAGES[@]}"; do
      IFS="$STAGE_SEP" read -r name status duration note <<<"$entry"
      i=$((i + 1))
      printf '    {"name": "%s", "status": "%s", "duration_ms": %s, "stderr_tail": "%s"}' \
        "$(json_escape "$name")" \
        "$(json_escape "$status")" \
        "$duration" \
        "$(json_escape "$note")"
      [ "$i" -lt "$total" ] && printf ','
      printf '\n'
    done
    printf '  ]\n'
    printf '}\n'
  } >"$tmp"

  mv "$tmp" "$RUN_JSON_PATH"
}

generate_visible_note() {
  local template_file tmp mode sync_mode auth_word notes_text stage_table summary_text

  template_file="$(mktemp)"
  default_template >"$template_file"

  mode="full"
  [ "$INFRA_ONLY" -eq 1 ] && mode="infra-only"
  [ "$GARDENING_ONLY" -eq 1 ] && mode="gardening-only"

  sync_mode="enabled"
  [ "$NO_SYNC" -eq 1 ] && sync_mode="disabled"

  auth_word="false"
  [ "$AUTH_OK" -eq 1 ] && auth_word="true"

  notes_text="${REPORT_NOTES:-No additional notes.}"
  stage_table="$(render_stage_table)"
  summary_text="$(render_summary)"
  tmp="$(mktemp)"

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'{{DATE}}'*) line="${line//\{\{DATE\}\}/$RUN_DATE}" ;;
    esac
    case "$line" in
      *'{{VAULT_PATH}}'*) line="${line//\{\{VAULT_PATH\}\}/$VAULT_PATH}" ;;
    esac
    case "$line" in
      *'{{MODE}}'*) line="${line//\{\{MODE\}\}/$mode}" ;;
    esac
    case "$line" in
      *'{{AUTH_OK}}'*) line="${line//\{\{AUTH_OK\}\}/$auth_word}" ;;
    esac
    case "$line" in
      *'{{POSTURE}}'*) line="${line//\{\{POSTURE\}\}/$POSTURE}" ;;
    esac
    case "$line" in
      *'{{SYNC_MODE}}'*) line="${line//\{\{SYNC_MODE\}\}/$sync_mode}" ;;
    esac
    case "$line" in
      '{{SUMMARY}}')
        printf '%s\n' "$summary_text"
        continue
        ;;
      '{{STAGE_TABLE}}')
        printf '%s\n' "$stage_table"
        continue
        ;;
      '{{NOTES}}')
        printf '%s\n' "$notes_text"
        continue
        ;;
    esac
    printf '%s\n' "$line"
  done <"$template_file" >"$tmp"

  mv "$tmp" "$VISIBLE_NOTE_PATH"
  rm -f "$template_file"
}

# Stage 4 is split into machine and visible artifacts.
stage_report_json() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  generate_run_json
}

stage_report_note() {
  if [ "$DRY_RUN" -eq 1 ]; then
    STAGE_REASON="dry-run"
    return "$SKIP_CODE"
  fi
  generate_visible_note
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --infra-only) INFRA_ONLY=1 ;;
      --gardening-only) GARDENING_ONLY=1 ;;
      --no-sync) NO_SYNC=1 ;;
      --help | -h)
        usage
        exit 0
        ;;
      *)
        usage
        die "Unknown option: $1"
        ;;
    esac
    shift
  done

  if [ "$INFRA_ONLY" -eq 1 ] && [ "$GARDENING_ONLY" -eq 1 ]; then
    die "--infra-only and --gardening-only cannot be used together"
  fi
}

main() {
  local rc

  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"

  parse_args "$@"
  acquire_lock
  check_binaries
  check_vault_path
  check_auth
  check_posture

  log "Vault: $VAULT_PATH"
  log "Binaries: qmd=$HAVE_QMD ob=$HAVE_OB claude=$HAVE_CLAUDE"
  log "Preflight: auth_ok=$AUTH_OK posture=$POSTURE dry_run=$DRY_RUN infra_only=$INFRA_ONLY gardening_only=$GARDENING_ONLY no_sync=$NO_SYNC"

  run_stage "0-pre-sync" stage_pre_sync
  run_stage "1a-qmd-refresh" stage_infra_qmd
  run_stage "1b-shadow-sync" stage_infra_shadow
  run_stage "1c-hash-index" stage_infra_hash_index
  run_stage "2-gardening" stage_gardening
  run_stage "3-post-sync" stage_post_sync
  run_stage "4a-run-json" stage_report_json
  run_stage "4b-visible-note" stage_report_note

  if [ "$DRY_RUN" -eq 0 ]; then
    set +e
    generate_run_json
    rc=$?
    set -e
    [ "$rc" -eq 0 ] || log "Warning: final run JSON refresh failed"
  fi

  log "Summary: $(render_summary)"
}

main "$@"
