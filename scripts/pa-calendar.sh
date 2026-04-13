#!/usr/bin/env bash
# pa-calendar.sh - Google Calendar sync helper for the PA content pipeline.
#
# Actions:
#   config [--calendar <id>] [--show]
#   sync [--date YYYY-MM-DD|today] [--days N] [--calendar <id>]
#   today
#   upcoming [--days N]
#   status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

CONFIG_PATH="$HOME/.config/ouroboros/integrations.json"
DEFAULT_CALENDAR_ID="primary"
DEFAULT_SYNC_DAYS=1

VAULT_PATH=""
PA_DIR=""
EVENTS_PATH=""
STATE_PATH=""
SYNC_START_DATE=""
SYNC_END_DATE=""
SYNC_SYNCED_COUNT=0

usage() {
  cat <<'EOF'
pa-calendar.sh <action> [args]

Actions:
  config [--calendar <id>] [--show]  - Store or display Google Calendar integration config
  sync [--date YYYY-MM-DD|today] [--days N] [--calendar <id>]  - Sync events into .pa/calendar-events.jsonl
  today  - Sync today's events and output them as JSON
  upcoming [--days N]  - Sync upcoming events and output them as JSON
  status  - Check gws availability, sync state, and event counts
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

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die_system "jq is required."
}

ensure_gws() {
  command -v gws >/dev/null 2>&1 || die_system "gws is required."
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

  [[ -n "$path" ]] || die_user "vault path is required"
  [[ -d "$path" ]] || die_user "vault path is not a directory: $path"

  (
    cd "$path" && pwd -P
  ) || die_system "Failed to resolve vault path: $path"
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
    if [[ -d "$env_path" ]] && [[ -d "$env_path/.pa" || -d "$env_path/.obsidian" ]]; then
      resolve_absolute_dir "$env_path"
      return
    fi
  fi

  if command -v qmd >/dev/null 2>&1; then
    collections=$(qmd collection list 2>/dev/null | sed -n 's/^\([a-zA-Z0-9_-]*\) (qmd:.*/\1/p' || true)
    for coll in $collections; do
      vault_path=$(qmd collection show "$coll" 2>/dev/null | awk '/Path:/{print $2}' || true)
      [[ -n "$vault_path" ]] || continue
      settings_path="$vault_path/.pa/settings.json"
      [[ -f "$settings_path" ]] || continue
      vault_root=$(jq -r '.vault_root // empty' "$settings_path" 2>/dev/null || true)
      if [[ -n "$vault_root" ]] && [[ -d "$vault_root/.pa" || -d "$vault_root/.obsidian" ]]; then
        resolve_absolute_dir "$vault_root"
        return
      fi
      if [[ -d "$vault_path/.pa" || -d "$vault_path/.obsidian" ]]; then
        resolve_absolute_dir "$vault_path"
        return
      fi
    done
  fi

  if [[ -d ".pa" || -d ".obsidian" ]]; then
    pwd -P
    return
  fi

  printf '\n'
}

resolve_vault_path() {
  local detected_path=""

  detected_path="$(detect_default_vault_path)"
  [[ -n "$detected_path" ]] || die_user "vault path required. Set PA_VAULT_PATH, rely on QMD collection discovery, or run from the vault root."
  printf '%s\n' "$detected_path"
}

set_vault_context() {
  VAULT_PATH="$1"
  PA_DIR="$VAULT_PATH/.pa"
  EVENTS_PATH="$PA_DIR/calendar-events.jsonl"
  STATE_PATH="$PA_DIR/integrations-state.json"
}

ensure_config_dir() {
  mkdir -p "$(dirname "$CONFIG_PATH")"
}

ensure_config_file() {
  ensure_config_dir

  if [[ ! -f "$CONFIG_PATH" ]]; then
    printf '{}\n' >"$CONFIG_PATH"
  fi

  jq empty "$CONFIG_PATH" >/dev/null 2>&1 || die_system "Invalid JSON config file: $CONFIG_PATH"
}

ensure_state_file() {
  local tmp_file=""

  mkdir -p "$PA_DIR"

  if [[ ! -f "$STATE_PATH" ]]; then
    tmp_file="$(mktemp)"
    jq -n '{version: 1}' >"$tmp_file"
    mv "$tmp_file" "$STATE_PATH"
  fi

  jq empty "$STATE_PATH" >/dev/null 2>&1 || die_system "Invalid JSON state file: $STATE_PATH"
}

ensure_events_file() {
  mkdir -p "$PA_DIR"
  touch "$EVENTS_PATH"
}

iso_timestamp() {
  local ts=""

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

today_date() {
  date '+%Y-%m-%d'
}

date_to_epoch() {
  local input="$1"
  local epoch=""

  [[ -n "$input" ]] || return 1

  epoch=$(date -j -f '%Y-%m-%d %H:%M:%S' "$input 00:00:00" '+%s' 2>/dev/null || true)
  if [[ -z "$epoch" ]]; then
    epoch=$(date -d "$input 00:00:00" '+%s' 2>/dev/null || true)
  fi

  [[ -n "$epoch" ]] || return 1
  printf '%s\n' "$epoch"
}

epoch_to_utc_iso() {
  local epoch="$1"
  local iso=""

  iso="$(date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  if [[ -z "$iso" ]]; then
    iso="$(date -u -d "@$epoch" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  fi

  [[ -n "$iso" ]] || return 1
  printf '%s\n' "$iso"
}

date_to_utc_iso_start() {
  local input="$1"
  local epoch=""

  epoch="$(date_to_epoch "$input")" || return 1
  epoch_to_utc_iso "$epoch"
}

date_add_days() {
  local input="$1"
  local days="${2:-0}"
  local result=""

  [[ "$days" =~ ^[0-9]+$ ]] || die_system "day offset must be a non-negative integer."

  if ((days == 0)); then
    date_to_epoch "$input" >/dev/null 2>&1 || return 1
    printf '%s\n' "$input"
    return
  fi

  result="$(date -j -v+"$days"d -f '%Y-%m-%d' "$input" '+%Y-%m-%d' 2>/dev/null || true)"
  if [[ -z "$result" ]]; then
    result="$(date -d "$input +$days days" '+%Y-%m-%d' 2>/dev/null || true)"
  fi
  if [[ -z "$result" ]]; then
    result="$(date -d "$input $days days" '+%Y-%m-%d' 2>/dev/null || true)"
  fi

  [[ -n "$result" ]] || return 1
  printf '%s\n' "$result"
}

ensure_integer() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[0-9]+$ ]] || die_user "$label must be a non-negative integer."
}

read_config_calendar_id() {
  [[ -f "$CONFIG_PATH" ]] || {
    printf '%s\n' "$DEFAULT_CALENDAR_ID"
    return
  }

  jq -r --arg default "$DEFAULT_CALENDAR_ID" '.calendar.calendar_id // $default' "$CONFIG_PATH" 2>/dev/null || printf '%s\n' "$DEFAULT_CALENDAR_ID"
}

read_state_last_sync_at() {
  [[ -f "$STATE_PATH" ]] || {
    printf '\n'
    return
  }

  jq -r '.calendar.last_sync_at // empty' "$STATE_PATH" 2>/dev/null || true
}

show_config() {
  local calendar_id="$DEFAULT_CALENDAR_ID"

  if [[ -f "$CONFIG_PATH" ]]; then
    ensure_config_file
    calendar_id="$(read_config_calendar_id)"
  fi

  jq -n --arg calendar_id "$calendar_id" '{calendar_id: $calendar_id}'
}

update_config() {
  local calendar_id="$1"
  local tmp_file=""

  ensure_config_file
  tmp_file="$(mktemp)"

  jq \
    --arg calendar_id "$calendar_id" \
    '
      . as $root
      | ($root // {})
      | .calendar = ((.calendar // {}) + {
          calendar_id: $calendar_id
        })
    ' "$CONFIG_PATH" >"$tmp_file"

  mv "$tmp_file" "$CONFIG_PATH"
}

resolve_sync_calendar_id() {
  local explicit="${1:-}"

  if [[ -n "$explicit" ]]; then
    printf '%s\n' "$explicit"
    return
  fi

  read_config_calendar_id
}

resolve_sync_date() {
  local explicit="${1:-}"

  if [[ -z "$explicit" ]] || [[ "$explicit" == "today" ]]; then
    today_date
    return
  fi

  date_to_epoch "$explicit" >/dev/null 2>&1 || die_user "Invalid --date value: $explicit"
  printf '%s\n' "$explicit"
}

extract_gws_error_message() {
  local body="${1:-}"
  local message=""

  message="$(printf '%s\n' "$body" | jq -r '.error.message // .error // .message // empty' 2>/dev/null || true)"
  printf '%s\n' "$message"
}

gws_calendar_events_json() {
  local calendar_id="$1"
  local time_min="$2"
  local time_max="$3"
  local output=""
  local exit_code=0
  local message=""

  ensure_gws

  local params_json=""
  params_json=$(jq -nc \
    --arg calendarId "$calendar_id" \
    --arg timeMin "$time_min" \
    --arg timeMax "$time_max" \
    '{calendarId: $calendarId, timeMin: $timeMin, timeMax: $timeMax, singleEvents: true, orderBy: "startTime"}')

  local stderr_file=""
  stderr_file="$(mktemp "${TMPDIR:-/tmp}/pa-calendar-gws.XXXXXX")"

  set +e
  output="$(gws calendar events list --params "$params_json" 2>"$stderr_file")"
  exit_code=$?
  set -e

  local stderr_content=""
  stderr_content="$(cat "$stderr_file" 2>/dev/null)"
  [[ -f "$stderr_file" ]] && command rm -f "$stderr_file"

  if ((exit_code != 0)); then
    message="$(extract_gws_error_message "$output")"
    [[ -z "$message" ]] && message="$stderr_content"
    die_system "gws calendar events list failed: ${message:-unknown error}"
  fi

  printf '%s\n' "$output" | jq empty >/dev/null 2>&1 || die_system "gws returned invalid JSON."

  message="$(extract_gws_error_message "$output")"
  if [[ -n "$message" ]] && [[ "$(printf '%s\n' "$output" | jq -r 'has("items")' 2>/dev/null || printf 'false')" != "true" ]]; then
    die_system "gws calendar events list failed: $message"
  fi

  printf '%s\n' "$output"
}

preserve_events_outside_range() {
  local start_date="$1"
  local end_date="$2"

  [[ -f "$EVENTS_PATH" ]] || return 0

  jq -c \
    --arg start_date "$start_date" \
    --arg end_date "$end_date" \
    'select((.date // "") < $start_date or (.date // "") > $end_date)' \
    "$EVENTS_PATH"
}

append_synced_events() {
  local response_json="$1"
  local synced_at="$2"
  local calendar_id="$3"

  printf '%s\n' "$response_json" |
    jq -c \
      --arg synced_at "$synced_at" \
      --arg calendar_id "$calendar_id" \
      '
        .items[]?
        | . as $event
        | ($event.start.dateTime // null) as $sdt
        | ($event.end.dateTime // null) as $edt
        | ($event.start.date // null) as $sd
        | ($event.end.date // null) as $ed
        | (if $sdt then $sdt else $sd end) as $start_val
        | (if $edt then $edt else $ed end) as $end_val
        | (if $sdt then $sdt[0:10] elif $sd then $sd else null end) as $date_val
        | select($event.id != null and $event.id != "")
        | select($start_val != null)
        | select($end_val != null)
        | {
            event_id: $event.id,
            title: ($event.summary // "Untitled"),
            date: $date_val,
            start: $start_val,
            end: $end_val,
            all_day: ($sdt == null),
            location: ($event.location // ""),
            attendees: [($event.attendees // [])[] | .email // empty],
            status: ($event.status // ""),
            calendar: $calendar_id,
            source: "calendar",
            synced_at: $synced_at
          }
      '
}

rewrite_events_file() {
  local response_json="$1"
  local synced_at="$2"
  local calendar_id="$3"
  local start_date="$4"
  local end_date="$5"
  local tmp_file=""

  tmp_file="$(mktemp)"
  : >"$tmp_file"

  preserve_events_outside_range "$start_date" "$end_date" >"$tmp_file"
  append_synced_events "$response_json" "$synced_at" "$calendar_id" >>"$tmp_file"

  mv "$tmp_file" "$EVENTS_PATH"
}

update_sync_state() {
  local synced_count="$1"
  local synced_at="$2"
  local tmp_file=""

  ensure_state_file
  tmp_file="$(mktemp)"

  jq \
    --arg synced_at "$synced_at" \
    --argjson synced_count "$synced_count" \
    '
      .version = 1
      | .calendar = ((.calendar // {}) + {
          last_sync_at: $synced_at,
          last_sync_count: $synced_count
        })
    ' "$STATE_PATH" >"$tmp_file"

  mv "$tmp_file" "$STATE_PATH"
}

events_array_for_range() {
  local start_date="$1"
  local end_date="$2"

  [[ -f "$EVENTS_PATH" ]] || {
    printf '[]\n'
    return
  }

  jq -sc \
    --arg start_date "$start_date" \
    --arg end_date "$end_date" \
    'map(select((.date // "") >= $start_date and (.date // "") <= $end_date))' \
    "$EVENTS_PATH"
}

events_count_for_range() {
  local start_date="$1"
  local end_date="$2"

  events_array_for_range "$start_date" "$end_date" | jq 'length'
}

total_events_count() {
  [[ -f "$EVENTS_PATH" ]] || {
    printf '0\n'
    return
  }

  jq -sc 'length' "$EVENTS_PATH"
}

run_sync() {
  local date_arg="${1:-today}"
  local days_arg="${2:-$DEFAULT_SYNC_DAYS}"
  local calendar_arg="${3:-}"
  local calendar_id=""
  local start_date=""
  local end_date_exclusive=""
  local end_date_inclusive=""
  local time_min=""
  local time_max=""
  local synced_at=""
  local response_json=""
  local synced_count=0

  ensure_integer "$days_arg" "days"
  ((days_arg > 0)) || die_user "days must be greater than zero."

  ensure_config_file
  calendar_id="$(resolve_sync_calendar_id "$calendar_arg")"
  [[ -n "$calendar_id" ]] || die_user "calendar id must not be empty."

  start_date="$(resolve_sync_date "$date_arg")"
  end_date_exclusive="$(date_add_days "$start_date" "$days_arg")" || die_system "Failed to compute sync end date."
  end_date_inclusive="$(date_add_days "$start_date" "$((days_arg - 1))")" || die_system "Failed to compute sync range."
  time_min="$(date_to_utc_iso_start "$start_date")" || die_system "Failed to compute timeMin."
  time_max="$(date_to_utc_iso_start "$end_date_exclusive")" || die_system "Failed to compute timeMax."
  synced_at="$(iso_timestamp)"

  set_vault_context "$(resolve_vault_path)"
  ensure_state_file
  ensure_events_file

  response_json="$(gws_calendar_events_json "$calendar_id" "$time_min" "$time_max")"
  synced_count="$(printf '%s\n' "$response_json" | jq '(.items // []) | length')"

  rewrite_events_file "$response_json" "$synced_at" "$calendar_id" "$start_date" "$end_date_inclusive"
  update_sync_state "$synced_count" "$synced_at"

  SYNC_START_DATE="$start_date"
  SYNC_END_DATE="$end_date_inclusive"
  SYNC_SYNCED_COUNT="$synced_count"
}

config_action() {
  local calendar_id=""
  local show_only="false"

  while (($# > 0)); do
    case "$1" in
      --calendar)
        shift
        [[ $# -gt 0 ]] || die_user "--calendar requires a value"
        calendar_id="$1"
        ;;
      --show)
        show_only="true"
        ;;
      *)
        die_user "Unknown config option: $1"
        ;;
    esac
    shift
  done

  if [[ -z "$calendar_id" ]]; then
    if [[ "$show_only" == "true" ]]; then
      show_config
      return
    fi
    calendar_id="$DEFAULT_CALENDAR_ID"
  fi

  update_config "$calendar_id"

  if [[ "$show_only" == "true" ]]; then
    show_config
  else
    jq -n --arg calendar_id "$calendar_id" '{configured: true, calendar_id: $calendar_id}'
  fi
}

sync_action() {
  local date_arg="today"
  local days_arg="$DEFAULT_SYNC_DAYS"
  local calendar_arg=""

  while (($# > 0)); do
    case "$1" in
      --date)
        shift
        [[ $# -gt 0 ]] || die_user "--date requires a value"
        date_arg="$1"
        ;;
      --days)
        shift
        [[ $# -gt 0 ]] || die_user "--days requires a value"
        days_arg="$1"
        ;;
      --calendar)
        shift
        [[ $# -gt 0 ]] || die_user "--calendar requires a value"
        calendar_arg="$1"
        ;;
      *)
        die_user "Unknown sync option: $1"
        ;;
    esac
    shift
  done

  run_sync "$date_arg" "$days_arg" "$calendar_arg"

  jq -n \
    --argjson synced "$SYNC_SYNCED_COUNT" \
    --arg date_range "$SYNC_START_DATE to $SYNC_END_DATE" \
    '{
      synced: $synced,
      date_range: $date_range
    }'
}

today_action() {
  (($# == 0)) || die_user "today does not accept arguments"

  run_sync "today" "$DEFAULT_SYNC_DAYS" ""
  events_array_for_range "$SYNC_START_DATE" "$SYNC_END_DATE"
}

upcoming_action() {
  local days_arg="7"

  while (($# > 0)); do
    case "$1" in
      --days)
        shift
        [[ $# -gt 0 ]] || die_user "--days requires a value"
        days_arg="$1"
        ;;
      *)
        die_user "Unknown upcoming option: $1"
        ;;
    esac
    shift
  done

  run_sync "today" "$days_arg" ""
  events_array_for_range "$SYNC_START_DATE" "$SYNC_END_DATE"
}

status_action() {
  local gws_installed="false"
  local calendar_id="$DEFAULT_CALENDAR_ID"
  local last_sync_at=""
  local today_value=""

  set_vault_context "$(resolve_vault_path)"
  ensure_state_file
  ensure_events_file

  if command -v gws >/dev/null 2>&1; then
    gws_installed="true"
  fi

  if [[ -f "$CONFIG_PATH" ]]; then
    ensure_config_file
    calendar_id="$(read_config_calendar_id)"
  fi

  last_sync_at="$(read_state_last_sync_at)"
  today_value="$(today_date)"

  jq -n \
    --argjson gws_installed "$gws_installed" \
    --arg calendar_id "$calendar_id" \
    --arg last_sync_at "$last_sync_at" \
    --arg today_value "$today_value" \
    --argjson today_events "$(events_count_for_range "$today_value" "$today_value")" \
    --argjson total_events "$(total_events_count)" \
    '{
      gws_installed: $gws_installed,
      calendar_id: $calendar_id,
      last_sync_at: (if $last_sync_at == "" then null else $last_sync_at end),
      today_events: $today_events,
      total_events: $total_events
    }'
}

main() {
  local action="${1:-}"

  ensure_jq

  case "$action" in
    config)
      shift
      config_action "$@"
      ;;
    sync)
      shift
      sync_action "$@"
      ;;
    today)
      shift
      today_action "$@"
      ;;
    upcoming)
      shift
      upcoming_action "$@"
      ;;
    status)
      shift
      status_action "$@"
      ;;
    "" | -h | --help | help)
      usage
      ;;
    *)
      die_user "Unknown action: $action"
      ;;
  esac
}

main "$@"
