#!/usr/bin/env bash
# pa-notify.sh - mobile push notification helper for PA scheduler results.
#
# Actions:
#   send <title> <message> [--priority info|warning|critical] [--tags tag1,tag2]
#   test
#   config [--backend ntfy] [--server-url URL] [--topic TOPIC] [--priority-filter LEVEL] [--enable|--disable]
#   digest-flush

set -euo pipefail

CONFIG_PATH="$HOME/.config/ouroboros/notify.json"
DIGEST_PATH="$HOME/.config/ouroboros/notify-digest.jsonl"

CONFIG_BACKEND=""
CONFIG_SERVER_URL=""
CONFIG_TOPIC=""
CONFIG_PRIORITY_FILTER=""
CONFIG_ENABLED=""

LAST_DELIVERY_STATUS=""
LAST_DELIVERY_RESPONSE=""

usage() {
  cat <<'EOF'
pa-notify.sh <action> [args]

Actions:
  send <title> <message> [--priority info|warning|critical] [--tags tag1,tag2]
  test
  config [--backend ntfy] [--server-url URL] [--topic TOPIC] [--priority-filter LEVEL] [--enable|--disable]
  digest-flush

Config file:
  ~/.config/ouroboros/notify.json

Notes:
  - Randomized topics are recommended for privacy.
  - Self-hosted ntfy servers are supported with --server-url.
  - Notifications should contain masked summaries only, not raw vault note content.
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

ensure_curl() {
  command -v curl >/dev/null 2>&1 || die_system "curl is required for the ntfy backend."
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

sanitize_header_value() {
  printf '%s' "$1" |
    tr '\r\n' ' ' |
    sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

validate_backend() {
  local backend="$1"

  case "$backend" in
    ntfy)
      ;;
    *)
      die_user "invalid backend: $backend"
      ;;
  esac
}

validate_priority() {
  local priority="$1"

  case "$priority" in
    info | warning | critical)
      ;;
    *)
      die_user "invalid priority: $priority"
      ;;
  esac
}

validate_topic() {
  local topic="$1"

  [[ -z "$topic" ]] && return 0
  [[ "$topic" =~ ^[A-Za-z0-9._-]+$ ]] || die_user "invalid topic: $topic"
}

priority_rank() {
  local priority="$1"

  case "$priority" in
    info)
      printf '1\n'
      ;;
    warning)
      printf '2\n'
      ;;
    critical)
      printf '3\n'
      ;;
    *)
      die_system "Unknown priority rank: $priority"
      ;;
  esac
}

priority_to_ntfy() {
  local priority="$1"

  case "$priority" in
    info)
      printf '3\n'
      ;;
    warning)
      printf '4\n'
      ;;
    critical)
      printf '5\n'
      ;;
    *)
      die_system "Unknown ntfy priority: $priority"
      ;;
  esac
}

priority_below_filter() {
  local priority="$1"
  local filter="$2"
  local priority_value
  local filter_value

  priority_value="$(priority_rank "$priority")"
  filter_value="$(priority_rank "$filter")"
  [[ "$priority_value" -lt "$filter_value" ]]
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

  if command -v qmd >/dev/null 2>&1; then
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
  fi

  if [[ -d ".pa" || -d ".obsidian" ]]; then
    pwd -P
    return
  fi

  printf '\n'
}

random_hex_8() {
  od -An -N4 -tx1 /dev/urandom | tr -d ' \n'
}

generate_random_topic() {
  local vault_path=""
  local vault_base="vault"
  local random_suffix=""

  vault_path="$(detect_default_vault_path)"
  if [[ -n "$vault_path" ]]; then
    vault_base="$(basename "$vault_path")"
  fi

  vault_base=$(printf '%s' "$vault_base" |
    tr '[:upper:]' '[:lower:]' |
    tr -cs 'a-z0-9._-' '-' |
    sed 's/^-*//; s/-*$//')
  [[ -n "$vault_base" ]] || vault_base="vault"

  random_suffix="$(random_hex_8)"
  printf 'pa-%s-%s\n' "$vault_base" "$random_suffix"
}

write_default_config() {
  local topic="$1"

  mkdir -p "$(dirname "$CONFIG_PATH")" || die_system "Failed to create config directory: $(dirname "$CONFIG_PATH")"
  jq -n \
    --arg topic "$topic" \
    '{
      version: 1,
      backend: "ntfy",
      server_url: "https://ntfy.sh",
      topic: $topic,
      priority_filter: "warning",
      enabled: true
    }' >"$CONFIG_PATH" || die_system "Failed to write config: $CONFIG_PATH"
}

ensure_config_initialized() {
  local topic="${1:-}"

  ensure_jq

  if [[ -f "$CONFIG_PATH" ]]; then
    validate_json "$CONFIG_PATH"
    return
  fi

  write_default_config "$topic"
}

normalize_config() {
  local tmp_file

  tmp_file="$(mktemp)"
  jq '
    .version = 1
    | .backend = (.backend // "ntfy")
    | .server_url = (.server_url // "https://ntfy.sh")
    | .topic = (.topic // "")
    | .priority_filter = (.priority_filter // "warning")
    | .enabled = (if .enabled == false then false else true end)
  ' "$CONFIG_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to normalize config: $CONFIG_PATH"
  }
  mv "$tmp_file" "$CONFIG_PATH"
}

load_config() {
  ensure_config_initialized ""
  normalize_config
  validate_json "$CONFIG_PATH"

  CONFIG_BACKEND="$(jq -r '.backend // "ntfy"' "$CONFIG_PATH")"
  CONFIG_SERVER_URL="$(jq -r '.server_url // "https://ntfy.sh"' "$CONFIG_PATH")"
  CONFIG_TOPIC="$(jq -r '.topic // empty' "$CONFIG_PATH")"
  CONFIG_PRIORITY_FILTER="$(jq -r '.priority_filter // "warning"' "$CONFIG_PATH")"
  CONFIG_ENABLED="$(jq -r 'if .enabled == false then "false" else "true" end' "$CONFIG_PATH")"

  validate_backend "$CONFIG_BACKEND"
  validate_priority "$CONFIG_PRIORITY_FILTER"
  validate_topic "$CONFIG_TOPIC"
  [[ -n "$CONFIG_SERVER_URL" ]] || die_system "server_url must not be empty in $CONFIG_PATH"
}

digest_source() {
  local title="$1"
  local source="${PA_NOTIFY_SOURCE:-}"

  if [[ -n "$source" ]]; then
    printf '%s\n' "$source"
    return
  fi

  if [[ "$title" == PA:* ]]; then
    source="${title#PA:}"
    source=$(printf '%s' "$source" |
      tr '[:upper:]' '[:lower:]' |
      tr -cs 'a-z0-9._-' '-' |
      sed 's/^-*//; s/-*$//')
    if [[ -n "$source" ]]; then
      printf '%s\n' "$source"
      return
    fi
  fi

  printf 'manual\n'
}

append_digest_item() {
  local priority="$1"
  local title="$2"
  local message="$3"
  local source=""

  mkdir -p "$(dirname "$DIGEST_PATH")" || die_system "Failed to create digest directory: $(dirname "$DIGEST_PATH")"
  source="$(digest_source "$title")"

  jq -cn \
    --arg ts "$(iso_timestamp)" \
    --arg source "$source" \
    --arg priority "$priority" \
    --arg title "$title" \
    --arg message "$message" \
    '{
      ts: $ts,
      source: $source,
      priority: $priority,
      title: $title,
      message: $message
    }' >>"$DIGEST_PATH" || die_system "Failed to append digest queue: $DIGEST_PATH"
}

deliver_ntfy() {
  local title="$1"
  local message="$2"
  local priority="$3"
  local tags="$4"
  local url=""
  local header_title=""
  local header_tags=""
  local ntfy_priority=""
  local response=""
  local http_status=""
  local body=""

  ensure_curl

  header_title="$(sanitize_header_value "$title")"
  header_tags="$(sanitize_header_value "$tags")"
  ntfy_priority="$(priority_to_ntfy "$priority")"
  url="${CONFIG_SERVER_URL%/}/$CONFIG_TOPIC"

  if [[ -n "$header_tags" ]]; then
    response=$(curl -sS \
      -H "Title: $header_title" \
      -H "Priority: $ntfy_priority" \
      -H "Tags: $header_tags" \
      --data-binary "$message" \
      -w $'\nHTTP_STATUS:%{http_code}' \
      "$url" 2>&1) || {
      LAST_DELIVERY_STATUS="failed"
      LAST_DELIVERY_RESPONSE="$response"
      return 1
    }
  else
    response=$(curl -sS \
      -H "Title: $header_title" \
      -H "Priority: $ntfy_priority" \
      --data-binary "$message" \
      -w $'\nHTTP_STATUS:%{http_code}' \
      "$url" 2>&1) || {
      LAST_DELIVERY_STATUS="failed"
      LAST_DELIVERY_RESPONSE="$response"
      return 1
    }
  fi

  http_status=$(printf '%s\n' "$response" | sed -n 's/^HTTP_STATUS://p' | tail -1)
  body=$(printf '%s\n' "$response" | sed '/^HTTP_STATUS:/d')

  if [[ -n "$http_status" ]] && [[ "$http_status" =~ ^2[0-9][0-9]$ ]]; then
    LAST_DELIVERY_STATUS="sent"
    LAST_DELIVERY_RESPONSE="$body"
    return 0
  fi

  LAST_DELIVERY_STATUS="failed"
  LAST_DELIVERY_RESPONSE="$body"
  return 1
}

deliver_notification_direct() {
  local title="$1"
  local message="$2"
  local priority="$3"
  local tags="${4:-}"

  if [[ "$CONFIG_ENABLED" != "true" ]] || [[ -z "$CONFIG_TOPIC" ]]; then
    LAST_DELIVERY_STATUS="skipped"
    LAST_DELIVERY_RESPONSE="notifications disabled or topic missing"
    return 0
  fi

  case "$CONFIG_BACKEND" in
    ntfy)
      deliver_ntfy "$title" "$message" "$priority" "$tags"
      ;;
    *)
      die_system "Unsupported backend in $CONFIG_PATH: $CONFIG_BACKEND"
      ;;
  esac
}

send_notification() {
  local title="$1"
  local message="$2"
  local priority="$3"
  local tags="${4:-}"

  load_config

  if [[ "$CONFIG_ENABLED" != "true" ]] || [[ -z "$CONFIG_TOPIC" ]]; then
    LAST_DELIVERY_STATUS="skipped"
    LAST_DELIVERY_RESPONSE="notifications disabled or topic missing"
    return 0
  fi

  if priority_below_filter "$priority" "$CONFIG_PRIORITY_FILTER"; then
    append_digest_item "$priority" "$title" "$message"
    LAST_DELIVERY_STATUS="queued"
    LAST_DELIVERY_RESPONSE="queued to digest"
    return 0
  fi

  deliver_notification_direct "$title" "$message" "$priority" "$tags"
}

compose_digest_message() {
  jq -cs '
    def clean:
      (. // "")
      | gsub("[\r\n]+"; " ")
      | gsub("  +"; " ")
      | sub("^ "; "")
      | sub(" $"; "");
    def trunc:
      if (length > 100) then .[0:97] + "..." else . end;
    "PA Daily Digest: \((length)) items\n"
    + (
        map(
          "- \((.title // "Untitled") | clean | trunc): \((.message // "") | clean | trunc)"
        )
        | join("\n")
      )
  ' "$DIGEST_PATH"
}

action_send() {
  local title="${1:-}"
  local message="${2:-}"
  local priority="info"
  local tags=""

  [[ $# -ge 2 ]] || die_user "Usage: pa-notify.sh send <title> <message> [--priority info|warning|critical] [--tags tag1,tag2]"
  shift 2

  [[ -n "$title" ]] || die_user "title is required"
  [[ -n "$message" ]] || die_user "message is required"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --priority)
        shift || die_user "--priority requires a value"
        [[ $# -gt 0 ]] || die_user "--priority requires a value"
        priority="$1"
        ;;
      --tags)
        shift || die_user "--tags requires a value"
        [[ $# -gt 0 ]] || die_user "--tags requires a value"
        tags="$1"
        ;;
      *)
        die_user "Unknown option: $1"
        ;;
    esac
    shift
  done

  validate_priority "$priority"

  send_notification "$title" "$message" "$priority" "$tags"
}

action_test() {
  local title="PA Notify Test"
  local message="If you see this, notifications work!"

  if send_notification "$title" "$message" "warning" ""; then
    printf 'success: %s\n' "$LAST_DELIVERY_STATUS"
    printf '%s\n' "$LAST_DELIVERY_RESPONSE"
    return 0
  fi

  printf 'failure: %s\n' "$LAST_DELIVERY_STATUS"
  printf '%s\n' "$LAST_DELIVERY_RESPONSE" >&2
  return 1
}

action_config() {
  local backend=""
  local server_url=""
  local topic=""
  local priority_filter=""
  local enabled_mode=""
  local initial_topic=""
  local tmp_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        shift || die_user "--backend requires a value"
        [[ $# -gt 0 ]] || die_user "--backend requires a value"
        backend="$1"
        ;;
      --server-url)
        shift || die_user "--server-url requires a value"
        [[ $# -gt 0 ]] || die_user "--server-url requires a value"
        server_url="$1"
        ;;
      --topic)
        shift || die_user "--topic requires a value"
        [[ $# -gt 0 ]] || die_user "--topic requires a value"
        topic="$1"
        ;;
      --priority-filter)
        shift || die_user "--priority-filter requires a value"
        [[ $# -gt 0 ]] || die_user "--priority-filter requires a value"
        priority_filter="$1"
        ;;
      --enable)
        [[ -z "$enabled_mode" ]] || die_user "Use only one of --enable or --disable"
        enabled_mode="true"
        ;;
      --disable)
        [[ -z "$enabled_mode" ]] || die_user "Use only one of --enable or --disable"
        enabled_mode="false"
        ;;
      *)
        die_user "Unknown option: $1"
        ;;
    esac
    shift
  done

  [[ -z "$backend" ]] || validate_backend "$backend"
  [[ -z "$priority_filter" ]] || validate_priority "$priority_filter"
  [[ -z "$topic" ]] || validate_topic "$topic"
  [[ -z "$server_url" ]] || [[ -n "$server_url" ]] || die_user "server_url must not be empty"

  if [[ ! -f "$CONFIG_PATH" ]]; then
    initial_topic="$topic"
    if [[ -z "$initial_topic" ]]; then
      initial_topic="$(generate_random_topic)"
    fi
    write_default_config "$initial_topic"
  fi

  ensure_config_initialized ""
  normalize_config

  tmp_file="$(mktemp)"
  jq \
    --arg backend "$backend" \
    --arg server_url "$server_url" \
    --arg topic "$topic" \
    --arg priority_filter "$priority_filter" \
    --arg enabled_mode "$enabled_mode" \
    '
      .backend = (if $backend == "" then .backend else $backend end)
      | .server_url = (if $server_url == "" then .server_url else $server_url end)
      | .topic = (if $topic == "" and .topic != "" then .topic else if $topic == "" then .topic else $topic end end)
      | .priority_filter = (if $priority_filter == "" then .priority_filter else $priority_filter end)
      | .enabled = (
          if $enabled_mode == "true" then true
          elif $enabled_mode == "false" then false
          else .enabled
          end
        )
    ' "$CONFIG_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update config: $CONFIG_PATH"
  }
  mv "$tmp_file" "$CONFIG_PATH"

  load_config
  jq '.' "$CONFIG_PATH"
}

action_digest_flush() {
  local digest_message=""

  load_config

  [[ -f "$DIGEST_PATH" ]] || return 0
  [[ -s "$DIGEST_PATH" ]] || return 0
  jq -cs '.' "$DIGEST_PATH" >/dev/null 2>&1 || die_system "Failed to parse digest queue: $DIGEST_PATH"

  digest_message="$(compose_digest_message)"
  [[ -n "$digest_message" ]] || return 0

  if deliver_notification_direct "PA Daily Digest" "$digest_message" "info" "digest"; then
    if [[ "$LAST_DELIVERY_STATUS" == "sent" ]]; then
      : >"$DIGEST_PATH" || die_system "Failed to clear digest queue: $DIGEST_PATH"
    fi
    return 0
  fi

  return 1
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  send)
    action_send "$@"
    ;;
  test)
    action_test "$@"
    ;;
  config)
    action_config "$@"
    ;;
  digest-flush)
    action_digest_flush "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die_user "Unknown action: $ACTION"
    ;;
esac
