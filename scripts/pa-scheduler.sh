#!/usr/bin/env bash
# pa-scheduler.sh - crontab-based PA command scheduler.
#
# Actions:
#   register <name> <cron> <command> [--runner claude|script] [--notify push|digest|none]
#   list
#   remove <name>
#   enable <name>
#   disable <name>
#   status
#   run <name>
#   install
#   uninstall

set -euo pipefail

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REGISTRY_PATH="$HOME/.config/ouroboros/schedules.json"
LOG_DIR="$HOME/.local/log/ouroboros"
LOG_FILE="$LOG_DIR/scheduler.log"
LOCK_ROOT="$HOME/.cache/ouroboros/pa-scheduler"
CRONTAB_BEGIN="# BEGIN ouroboros-pa-scheduler"
CRONTAB_END="# END ouroboros-pa-scheduler"

usage() {
  cat <<'EOF'
pa-scheduler.sh <action> [args]

Actions:
  register <name> <cron> <command> [--runner claude|script] [--notify push|digest|none]
  list
  remove <name>
  enable <name>
  disable <name>
  status
  run <name>
  install
  uninstall
EOF
}

die_user() {
  echo "Error: $1" >&2
  exit 1
}

die_system() {
  echo "Error: $1" >&2
  exit 2
}

log() {
  local ts
  mkdir -p "$LOG_DIR" || die_system "Failed to create log directory: $LOG_DIR"
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] %s\n' "$ts" "$*" >>"$LOG_FILE"
}

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die_system "jq is required."
}

ensure_crontab() {
  command -v crontab >/dev/null 2>&1 || die_system "crontab is required."
}

ensure_claude() {
  command -v claude >/dev/null 2>&1 || return 1
}

validate_json() {
  local path="$1"
  jq empty "$path" >/dev/null 2>&1 || die_system "Failed to parse JSON: $path"
}

expand_home_path() {
  local path="${1:-}"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path#\~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

resolve_absolute_dir() {
  local path="$1"

  [[ -n "$path" ]] || die_user "directory path is required"
  [[ -d "$path" ]] || die_user "directory not found: $path"

  (
    cd "$path" && pwd -P
  ) || die_system "Failed to resolve directory: $path"
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

normalize_whitespace() {
  printf '%s\n' "$1" | awk '{$1=$1; print}'
}

validate_schedule_name() {
  local name="$1"

  [[ -n "$name" ]] || die_user "schedule name is required"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._:-]*$ ]] || die_user "invalid schedule name: $name"
}

validate_runner() {
  local runner="$1"

  case "$runner" in
    claude | script)
      ;;
    *)
      die_user "invalid runner: $runner"
      ;;
  esac
}

validate_notify() {
  local notify="$1"

  case "$notify" in
    push | digest | none)
      ;;
    *)
      die_user "invalid notify mode: $notify"
      ;;
  esac
}

validate_cron_expression() {
  local cron="$1"

  cron="$(normalize_whitespace "$cron")"
  printf '%s\n' "$cron" | awk 'NF == 5 { exit 0 } { exit 1 }' || die_user "invalid cron expression: $cron"
  printf '%s\n' "$cron"
}

shell_quote() {
  local value="$1"

  printf "'%s'" "$(printf '%s' "$value" | sed "s/'/'\\\\''/g")"
}

detect_default_vault_path() {
  local env_path=""
  local collections=""
  local coll=""
  local vault_path=""
  local settings_path=""
  local vault_root=""

  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    env_path="$(expand_home_path "$PA_VAULT_PATH")"
    if [[ -d "$env_path" ]] && [[ -d "$env_path/.pa" ]]; then
      resolve_absolute_dir "$env_path"
      return
    fi
  fi

  if ! command -v qmd >/dev/null 2>&1; then
    printf '\n'
    return
  fi

  collections=$(qmd collection list 2>/dev/null | sed -n 's/^\([a-zA-Z0-9_-]*\) (qmd:.*/\1/p' || true)
  for coll in $collections; do
    vault_path=$(qmd collection show "$coll" 2>/dev/null | awk '/Path:/{print $2}' || true)
    [[ -n "$vault_path" ]] || continue
    settings_path="$vault_path/.pa/settings.json"
    [[ -f "$settings_path" ]] || continue
    vault_root=$(jq -r '.vault_root // empty' "$settings_path" 2>/dev/null || true)
    if [[ -n "$vault_root" ]] && [[ -d "$vault_root/.pa" ]]; then
      resolve_absolute_dir "$vault_root"
      return
    fi
    if [[ -d "$vault_path/.pa" ]]; then
      resolve_absolute_dir "$vault_path"
      return
    fi
  done

  printf '\n'
}

write_registry_file() {
  local mode="$1"
  local default_vault_path=""
  local mcp_config_path="$PLUGIN_DIR/.mcp.json"

  default_vault_path="$(detect_default_vault_path)"
  mkdir -p "$(dirname "$REGISTRY_PATH")" || die_system "Failed to create registry directory: $(dirname "$REGISTRY_PATH")"

  case "$mode" in
    empty)
      cat >"$REGISTRY_PATH" <<EOF
{
  "version": 1,
  "default_vault_path": $(jq -Rn --arg value "$default_vault_path" '$value'),
  "plugin_dir": $(jq -Rn --arg value "$PLUGIN_DIR" '$value'),
  "mcp_config_path": $(jq -Rn --arg value "$mcp_config_path" '$value'),
  "max_budget_usd": 10,
  "schedules": []
}
EOF
      ;;
    default)
      cat >"$REGISTRY_PATH" <<EOF
{
  "version": 1,
  "default_vault_path": $(jq -Rn --arg value "$default_vault_path" '$value'),
  "plugin_dir": $(jq -Rn --arg value "$PLUGIN_DIR" '$value'),
  "mcp_config_path": $(jq -Rn --arg value "$mcp_config_path" '$value'),
  "max_budget_usd": 10,
  "schedules": [
    {
      "name": "morning-brief",
      "cron": "0 7 * * 1-5",
      "runner": "claude",
      "command": "/pa day --mode morning",
      "notify": "digest",
      "enabled": true,
      "last_run": null,
      "last_status": null
    },
    {
      "name": "weekly-review",
      "cron": "0 9 * * 5",
      "runner": "claude",
      "command": "/pa reset --horizon week",
      "notify": "push",
      "enabled": true,
      "last_run": null,
      "last_status": null
    },
    {
      "name": "nightly-garden",
      "cron": "0 3 * * *",
      "runner": "script",
      "command": "scripts/pa-autopilot.sh",
      "notify": "none",
      "enabled": true,
      "last_run": null,
      "last_status": null
    },
    {
      "name": "heartbeat",
      "cron": "0 */6 * * *",
      "runner": "script",
      "command": "scripts/pa-heartbeat.sh",
      "notify": "push",
      "enabled": true,
      "last_run": null,
      "last_status": null
    }
  ]
}
EOF
      ;;
    *)
      die_system "Unknown registry seed mode: $mode"
      ;;
  esac
}

normalize_registry() {
  local tmp_file
  local env_default_vault_path=""

  [[ -f "$REGISTRY_PATH" ]] || return 0
  validate_json "$REGISTRY_PATH"

  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    env_default_vault_path="$(expand_home_path "$PA_VAULT_PATH")"
    if [[ -d "$env_default_vault_path" ]] && [[ -d "$env_default_vault_path/.pa" ]]; then
      env_default_vault_path="$(resolve_absolute_dir "$env_default_vault_path")"
    else
      env_default_vault_path=""
    fi
  fi

  tmp_file=$(mktemp)
  jq \
    --arg default_vault_path "$(detect_default_vault_path)" \
    --arg env_default_vault_path "$env_default_vault_path" \
    --arg plugin_dir "$PLUGIN_DIR" \
    --arg mcp_config_path "$PLUGIN_DIR/.mcp.json" \
    '
      .version = 1
      | .default_vault_path = (
          if $env_default_vault_path != "" then
            $env_default_vault_path
          else
            (.default_vault_path // $default_vault_path)
          end
        )
      | .plugin_dir = (.plugin_dir // $plugin_dir)
      | .mcp_config_path = (.mcp_config_path // $mcp_config_path)
      | .max_budget_usd = (.max_budget_usd // 10)
      | .schedules = (
          (.schedules // [])
          | map(
              . + {
                runner: (.runner // "claude"),
                notify: (.notify // "none"),
                enabled: (.enabled // true),
                last_run: (.last_run // null),
                last_status: (.last_status // null)
              }
            )
        )
    ' "$REGISTRY_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to normalize registry: $REGISTRY_PATH"
  }
  mv "$tmp_file" "$REGISTRY_PATH"
}

ensure_registry() {
  local mode="${1:-empty}"

  if [[ ! -f "$REGISTRY_PATH" ]]; then
    write_registry_file "$mode"
  fi

  normalize_registry
}

registry_has_schedule() {
  local name="$1"

  jq -e --arg name "$name" '.schedules[] | select(.name == $name)' "$REGISTRY_PATH" >/dev/null 2>&1
}

get_schedule_json() {
  local name="$1"

  jq -c --arg name "$name" '.schedules[] | select(.name == $name)' "$REGISTRY_PATH"
}

update_registry() {
  local tmp_file

  tmp_file=$(mktemp)
  jq "$@" "$REGISTRY_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update registry: $REGISTRY_PATH"
  }
  mv "$tmp_file" "$REGISTRY_PATH"
}

update_schedule_result() {
  local name="$1"
  local last_run="$2"
  local exit_code="$3"
  local tmp_file

  tmp_file=$(mktemp)

  if [[ "$exit_code" -eq 0 ]]; then
    jq \
      --arg name "$name" \
      --arg last_run "$last_run" \
      --arg last_status "success" \
      '
        .schedules |= map(
          if .name == $name then
            .last_run = $last_run | .last_status = $last_status
          else
            .
          end
        )
      ' "$REGISTRY_PATH" >"$tmp_file" || {
      rm -f "$tmp_file"
      die_system "Failed to update schedule status: $name"
    }
  else
    jq \
      --arg name "$name" \
      --arg last_run "$last_run" \
      --argjson last_status "$exit_code" \
      '
        .schedules |= map(
          if .name == $name then
            .last_run = $last_run | .last_status = $last_status
          else
            .
          end
        )
      ' "$REGISTRY_PATH" >"$tmp_file" || {
      rm -f "$tmp_file"
      die_system "Failed to update schedule status: $name"
    }
  fi

  mv "$tmp_file" "$REGISTRY_PATH"
}

current_crontab() {
  crontab -l 2>/dev/null || true
}

strip_managed_block() {
  awk -v begin="$CRONTAB_BEGIN" -v end="$CRONTAB_END" '
    $0 == begin { skip = 1; next }
    $0 == end { skip = 0; next }
    skip != 1 { print }
  '
}

has_managed_block() {
  current_crontab | grep -Fqx "$CRONTAB_BEGIN"
}

render_crontab_block() {
  local cron=""
  local name=""
  local script_path_quoted=""
  local log_file_quoted=""

  script_path_quoted="$(shell_quote "$SCRIPT_PATH")"
  log_file_quoted="$(shell_quote "$LOG_FILE")"

  printf '%s\n' "$CRONTAB_BEGIN"
  while IFS=$'\t' read -r cron name; do
    [[ -n "$cron" ]] || continue
    printf '%s bash %s run %s >> %s 2>&1\n' \
      "$cron" \
      "$script_path_quoted" \
      "$(shell_quote "$name")" \
      "$log_file_quoted"
  done < <(
    jq -r '
      (.schedules // [])
      | map(select(.enabled == true))
      | .[]
      | [.cron, .name]
      | @tsv
    ' "$REGISTRY_PATH"
  )
  printf '%s\n' "$CRONTAB_END"
}

install_crontab_contents() {
  local content="$1"
  local tmp_file

  tmp_file=$(mktemp)
  printf '%s\n' "$content" >"$tmp_file"
  crontab "$tmp_file" >/dev/null 2>&1 || {
    rm -f "$tmp_file"
    die_system "Failed to install crontab entries."
  }
  rm -f "$tmp_file"
}

notify_schedule_result() {
  local name="$1"
  local notify="$2"
  local runner="$3"
  local command="$4"
  local last_run="$5"
  local exit_code="$6"
  local last_status="$7"
  local notify_script="$PLUGIN_DIR/scripts/pa-notify.sh"

  [[ "$notify" != "none" ]] || return 0
  [[ -f "$notify_script" ]] || return 0

  PA_SCHEDULE_NAME="$name" \
  PA_SCHEDULE_NOTIFY="$notify" \
  PA_SCHEDULE_RUNNER="$runner" \
  PA_SCHEDULE_COMMAND="$command" \
  PA_SCHEDULE_LAST_RUN="$last_run" \
  PA_SCHEDULE_LAST_STATUS="$last_status" \
  PA_SCHEDULE_EXIT_CODE="$exit_code" \
  PA_SCHEDULE_LOG_FILE="$LOG_FILE" \
    bash "$notify_script" send >>"$LOG_FILE" 2>&1 || log "Notification failed for schedule: $name"
}

run_claude_schedule() {
  local vault_path="$1"
  local plugin_dir="$2"
  local mcp_config_path="$3"
  local max_budget="$4"
  local command_text="$5"

  [[ -n "$vault_path" ]] || {
    log "Missing default_vault_path for claude schedule."
    return 1
  }
  [[ -d "$vault_path" ]] || {
    log "Vault path not found: $vault_path"
    return 1
  }
  [[ -d "$plugin_dir" ]] || {
    log "Plugin directory not found: $plugin_dir"
    return 1
  }
  ensure_claude || {
    log "claude CLI is required for runner=claude."
    return 127
  }

  if [[ -n "$mcp_config_path" ]] && [[ -f "$mcp_config_path" ]]; then
    claude -p \
      --plugin-dir "$plugin_dir" \
      --add-dir "$vault_path" \
      --permission-mode bypassPermissions \
      --max-budget-usd "$max_budget" \
      --mcp-config "$mcp_config_path" \
      --append-system-prompt "You are running in unattended mode. Do not ask questions. If confirmation is needed, skip and report." \
      "$command_text" >>"$LOG_FILE" 2>&1
  else
    claude -p \
      --plugin-dir "$plugin_dir" \
      --add-dir "$vault_path" \
      --permission-mode bypassPermissions \
      --max-budget-usd "$max_budget" \
      --append-system-prompt "You are running in unattended mode. Do not ask questions. If confirmation is needed, skip and report." \
      "$command_text" >>"$LOG_FILE" 2>&1
  fi
}

run_script_schedule() {
  local plugin_dir="$1"
  local command_path="$2"

  [[ -d "$plugin_dir" ]] || {
    log "Plugin directory not found: $plugin_dir"
    return 1
  }

  (
    cd "$plugin_dir" || exit 1
    bash "$command_path"
  ) >>"$LOG_FILE" 2>&1
}

print_table_from_tsv() {
  awk -F'\t' '
    {
      for (i = 1; i <= NF; i++) {
        rows[NR, i] = $i
        if (length($i) > widths[i]) {
          widths[i] = length($i)
        }
      }
      if (NF > max_nf) {
        max_nf = NF
      }
    }
    END {
      for (row = 1; row <= NR; row++) {
        for (col = 1; col <= max_nf; col++) {
          value = rows[row, col]
          printf "%-*s", widths[col], value
          if (col < max_nf) {
            printf "  "
          } else {
            printf "\n"
          }
        }
      }
    }
  '
}

action_register() {
  local name="${1:-}"
  local cron="${2:-}"
  local command_text="${3:-}"
  local runner="claude"
  local notify="none"

  [[ $# -ge 3 ]] || die_user "Usage: pa-scheduler.sh register <name> <cron> <command> [--runner claude|script] [--notify push|digest|none]"
  shift 3 || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --runner)
        shift || die_user "--runner requires a value"
        [[ $# -gt 0 ]] || die_user "--runner requires a value"
        runner="$1"
        ;;
      --notify)
        shift || die_user "--notify requires a value"
        [[ $# -gt 0 ]] || die_user "--notify requires a value"
        notify="$1"
        ;;
      *)
        die_user "Unknown option: $1"
        ;;
    esac
    shift || true
  done

  validate_schedule_name "$name"
  cron="$(validate_cron_expression "$cron")"
  [[ -n "$command_text" ]] || die_user "command is required"
  validate_runner "$runner"
  validate_notify "$notify"

  ensure_jq
  ensure_registry empty

  registry_has_schedule "$name" && die_user "schedule already exists: $name"

  update_registry \
    --arg name "$name" \
    --arg cron "$cron" \
    --arg runner "$runner" \
    --arg command "$command_text" \
    --arg notify "$notify" \
    '
      .schedules += [
        {
          name: $name,
          cron: $cron,
          runner: $runner,
          command: $command,
          notify: $notify,
          enabled: true,
          last_run: null,
          last_status: null
        }
      ]
    '

  printf 'Registered schedule: %s\n' "$name"
  printf 'Run `bash %s install` to refresh crontab.\n' "$SCRIPT_PATH"
}

action_list() {
  ensure_jq
  ensure_registry empty

  if [[ "$(jq '.schedules | length' "$REGISTRY_PATH")" -eq 0 ]]; then
    echo "No schedules registered."
    return
  fi

  jq -r '
    ["name", "cron", "runner", "command", "enabled", "last_run", "last_status"],
    ((.schedules // [])[] | [
      .name,
      .cron,
      .runner,
      .command,
      (.enabled | tostring),
      (.last_run // "-"),
      (.last_status // "-" | tostring)
    ]) | @tsv
  ' "$REGISTRY_PATH" | print_table_from_tsv
}

action_remove() {
  local name="${1:-}"

  validate_schedule_name "$name"
  ensure_jq
  ensure_registry empty

  registry_has_schedule "$name" || die_user "schedule not found: $name"

  update_registry --arg name "$name" '.schedules |= map(select(.name != $name))'

  printf 'Removed schedule: %s\n' "$name"
  printf 'Run `bash %s install` to refresh crontab.\n' "$SCRIPT_PATH"
}

set_schedule_enabled() {
  local name="$1"
  local enabled_json="$2"

  ensure_jq
  ensure_registry empty
  registry_has_schedule "$name" || die_user "schedule not found: $name"

  update_registry \
    --arg name "$name" \
    --argjson enabled "$enabled_json" \
    '
      .schedules |= map(
        if .name == $name then
          .enabled = $enabled
        else
          .
        end
      )
    '
}

action_enable() {
  local name="${1:-}"

  validate_schedule_name "$name"
  set_schedule_enabled "$name" true
  printf 'Enabled schedule: %s\n' "$name"
  printf 'Run `bash %s install` to refresh crontab.\n' "$SCRIPT_PATH"
}

action_disable() {
  local name="${1:-}"

  validate_schedule_name "$name"
  set_schedule_enabled "$name" false
  printf 'Disabled schedule: %s\n' "$name"
  printf 'Run `bash %s install` to refresh crontab.\n' "$SCRIPT_PATH"
}

action_status() {
  local total=""
  local enabled=""
  local disabled=""
  local installed="no"

  ensure_jq
  ensure_registry empty

  total=$(jq '.schedules | length' "$REGISTRY_PATH")
  enabled=$(jq '[.schedules[] | select(.enabled == true)] | length' "$REGISTRY_PATH")
  disabled=$((total - enabled))

  has_managed_block && installed="yes" || true

  printf 'Registry: %s\n' "$REGISTRY_PATH"
  printf 'Vault path: %s\n' "$(jq -r '.default_vault_path // ""' "$REGISTRY_PATH")"
  printf 'Plugin dir: %s\n' "$(jq -r '.plugin_dir // ""' "$REGISTRY_PATH")"
  printf 'MCP config: %s\n' "$(jq -r '.mcp_config_path // ""' "$REGISTRY_PATH")"
  printf 'Max budget USD: %s\n' "$(jq -r '.max_budget_usd // 10' "$REGISTRY_PATH")"
  printf 'Crontab installed: %s\n' "$installed"
  printf 'Schedules: total=%s enabled=%s disabled=%s\n' "$total" "$enabled" "$disabled"

  if [[ "$total" -eq 0 ]]; then
    echo "Last runs: none"
    return
  fi

  echo "Last runs:"
  jq -r '
    (.schedules // [])
    | sort_by(.name)
    | .[]
    | [
        .name,
        (.last_run // "never"),
        (.last_status // "-" | tostring)
      ]
    | @tsv
  ' "$REGISTRY_PATH" | awk -F'\t' '{ printf "  %-20s %-25s %s\n", $1, $2, $3 }'
}

action_run() {
  local name="${1:-}"
  local schedule_json=""
  local cron=""
  local runner=""
  local command_text=""
  local notify=""
  local default_vault_path=""
  local plugin_dir=""
  local mcp_config_path=""
  local max_budget=""
  local started_at=""
  local exit_code=0
  local lock_dir=""
  local last_status="success"

  validate_schedule_name "$name"
  ensure_jq
  ensure_registry empty

  registry_has_schedule "$name" || die_user "schedule not found: $name"
  schedule_json="$(get_schedule_json "$name")"
  cron="$(jq -r '.cron' <<<"$schedule_json")"
  runner="$(jq -r '.runner' <<<"$schedule_json")"
  command_text="$(jq -r '.command' <<<"$schedule_json")"
  notify="$(jq -r '.notify' <<<"$schedule_json")"
  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    default_vault_path="$(expand_home_path "$PA_VAULT_PATH")"
  else
    default_vault_path="$(expand_home_path "$(jq -r '.default_vault_path // ""' "$REGISTRY_PATH")")"
  fi
  plugin_dir="$(expand_home_path "$(jq -r '.plugin_dir // ""' "$REGISTRY_PATH")")"
  mcp_config_path="$(expand_home_path "$(jq -r '.mcp_config_path // ""' "$REGISTRY_PATH")")"
  max_budget="$(jq -r '.max_budget_usd // 10' "$REGISTRY_PATH")"
  started_at="$(iso_timestamp)"
  lock_dir="$LOCK_ROOT/$name.lock"

  mkdir -p "$LOCK_ROOT" || die_system "Failed to create lock directory: $LOCK_ROOT"
  mkdir -p "$LOG_DIR" || die_system "Failed to create log directory: $LOG_DIR"
  touch "$LOG_FILE" || die_system "Failed to write log file: $LOG_FILE"

  if ! mkdir "$lock_dir" 2>/dev/null; then
    log "Schedule already running: $name"
    echo "Schedule already running: $name"
    exit 0
  fi
  trap "rmdir $(shell_quote "$lock_dir") 2>/dev/null || true" EXIT

  log "Run start: name=$name runner=$runner cron=$cron command=$command_text"

  case "$runner" in
    claude)
      set +e
      run_claude_schedule "$default_vault_path" "$plugin_dir" "$mcp_config_path" "$max_budget" "$command_text"
      exit_code=$?
      set -e
      ;;
    script)
      set +e
      run_script_schedule "$plugin_dir" "$command_text"
      exit_code=$?
      set -e
      ;;
    *)
      log "Unknown runner configured for $name: $runner"
      exit_code=1
      ;;
  esac

  update_schedule_result "$name" "$started_at" "$exit_code"

  if [[ "$exit_code" -eq 0 ]]; then
    last_status="success"
  else
    last_status="$exit_code"
  fi

  notify_schedule_result "$name" "$notify" "$runner" "$command_text" "$started_at" "$exit_code" "$last_status"
  log "Run finish: name=$name status=$last_status"

  if [[ "$exit_code" -eq 0 ]]; then
    printf 'Run complete: %s (%s)\n' "$name" "$last_status"
  else
    printf 'Run failed: %s (%s)\n' "$name" "$last_status"
  fi

  return "$exit_code"
}

action_install() {
  local existing=""
  local stripped=""
  local block=""
  local merged=""
  local enabled_count=""

  ensure_jq
  ensure_crontab
  ensure_registry default

  mkdir -p "$LOG_DIR" || die_system "Failed to create log directory: $LOG_DIR"
  touch "$LOG_FILE" || die_system "Failed to create log file: $LOG_FILE"

  existing="$(current_crontab)"
  stripped="$(printf '%s\n' "$existing" | strip_managed_block)"
  block="$(render_crontab_block)"

  if [[ -n "$stripped" ]]; then
    merged="$(printf '%s\n%s\n' "$stripped" "$block")"
  else
    merged="$(printf '%s\n' "$block")"
  fi

  install_crontab_contents "$merged"
  enabled_count="$(jq '[.schedules[] | select(.enabled == true)] | length' "$REGISTRY_PATH")"

  printf 'Installed scheduler crontab block with %s enabled schedule(s).\n' "$enabled_count"
}

action_uninstall() {
  local existing=""
  local stripped=""

  ensure_crontab

  existing="$(current_crontab)"
  stripped="$(printf '%s\n' "$existing" | strip_managed_block)"
  install_crontab_contents "$(printf '%s' "$stripped")"

  echo "Removed scheduler crontab block."
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  register)
    action_register "$@"
    ;;
  list)
    action_list "$@"
    ;;
  remove)
    action_remove "$@"
    ;;
  enable)
    action_enable "$@"
    ;;
  disable)
    action_disable "$@"
    ;;
  status)
    action_status "$@"
    ;;
  run)
    action_run "$@"
    ;;
  install)
    action_install "$@"
    ;;
  uninstall)
    action_uninstall "$@"
    ;;
  *)
    usage
    die_user "Unknown action: ${ACTION:-<none>}"
    ;;
esac
