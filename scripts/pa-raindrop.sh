#!/usr/bin/env bash
# pa-raindrop.sh - Raindrop.io bookmark sync helper for the PA content pipeline.
#
# Actions:
#   config --token <token> [--collection <id>] [--show]
#   sync [--since <date>] [--collection <id>] [--limit <n>]
#   pull [--next | <raindrop-id>]
#   status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

CONFIG_PATH="$HOME/.config/ouroboros/integrations.json"
RAINDROP_API_BASE="https://api.raindrop.io/rest/v1"
DEFAULT_SYNC_LIMIT=100
DEFAULT_SYNC_PAGES=5

VAULT_PATH=""
PA_DIR=""
QUEUE_PATH=""
STATE_PATH=""
HTTP_STATUS=""
HTTP_BODY=""

usage() {
  cat <<'EOF'
pa-raindrop.sh <action> [args]

Actions:
  config --token <token> [--collection <id>] [--show]  - Store or display Raindrop integration config
  sync [--since <date>] [--collection <id>] [--limit <n>]  - Sync bookmarks into .pa/raindrop-queue.jsonl
  pull [--next | <raindrop-id>]  - Output the next pending queue entry or fetch one bookmark directly
  status  - Check token validity, sync state, and queue counts
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
  command -v curl >/dev/null 2>&1 || die_system "curl is required."
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
  QUEUE_PATH="$PA_DIR/raindrop-queue.jsonl"
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

ensure_queue_file() {
  mkdir -p "$PA_DIR"
  touch "$QUEUE_PATH"
}

line_count_or_zero() {
  local path="$1"

  [[ -f "$path" ]] || {
    printf '0\n'
    return
  }

  wc -l <"$path" | awk '{$1=$1; print}'
}

iso_timestamp() {
  local ts=""

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

timestamp_days_ago() {
  local days="${1:-7}"
  local ts=""

  ts="$(date -v-"$days"d '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || true)"
  if [[ -z "$ts" ]]; then
    ts="$(date -d "$days days ago" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || true)"
  fi

  [[ -n "$ts" ]] || die_system "Failed to compute relative timestamp."
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

normalize_iso_input() {
  printf '%s' "$1" | sed -E 's/\.[0-9]+Z$/Z/; s/\.[0-9]+([+-])/\1/; s/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/'
}

iso_to_epoch() {
  local input="$1"
  local normalized=""
  local epoch=""

  [[ -n "$input" ]] || return 1
  normalized="$(normalize_iso_input "$input")"

  if [[ "$normalized" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    epoch=$(date -j -f '%Y-%m-%d' "$normalized" '+%s' 2>/dev/null || true)
    if [[ -z "$epoch" ]]; then
      epoch=$(date -d "$normalized" '+%s' 2>/dev/null || true)
    fi
  else
    epoch=$(date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' 2>/dev/null || true)
    if [[ -z "$epoch" ]]; then
      epoch=$(date -d "$input" '+%s' 2>/dev/null || true)
    fi
  fi

  [[ -n "$epoch" ]] || return 1
  printf '%s\n' "$epoch"
}

ensure_integer() {
  local value="$1"
  local label="$2"

  [[ "$value" =~ ^[0-9]+$ ]] || die_user "$label must be a non-negative integer."
}

mask_token() {
  local token="${1:-}"
  local len=0

  [[ -n "$token" ]] || {
    printf '\n'
    return
  }

  len=${#token}
  if ((len <= 4)); then
    printf '%s\n' "$token"
  else
    printf '****%s\n' "${token: -4}"
  fi
}

read_config_token() {
  [[ -f "$CONFIG_PATH" ]] || {
    printf '\n'
    return
  }

  jq -r '.raindrop.token // empty' "$CONFIG_PATH" 2>/dev/null || true
}

read_config_collection_id() {
  [[ -f "$CONFIG_PATH" ]] || {
    printf '0\n'
    return
  }

  jq -r '(.raindrop.collection_id // 0) | tostring' "$CONFIG_PATH" 2>/dev/null || printf '0\n'
}

read_state_last_sync_at() {
  [[ -f "$STATE_PATH" ]] || {
    printf '\n'
    return
  }

  jq -r '.raindrop.last_sync_at // empty' "$STATE_PATH" 2>/dev/null || true
}

extract_api_error_message() {
  local body="${1:-}"
  local message=""

  message="$(printf '%s\n' "$body" | jq -r '.message // .error // .errorMessage // empty' 2>/dev/null || true)"
  printf '%s\n' "$message"
}

http_get_json() {
  local url="$1"
  local token="$2"
  local attempt=1
  local response=""
  local curl_exit=0

  HTTP_STATUS=""
  HTTP_BODY=""

  while true; do
    set +e
    response="$(
      curl \
        -sS \
        -H 'Accept: application/json' \
        -H "Authorization: Bearer $token" \
        -w $'\n%{http_code}' \
        "$url" 2>&1
    )"
    curl_exit=$?
    set -e

    if ((curl_exit != 0)); then
      HTTP_STATUS="000"
      HTTP_BODY="$response"
      return "$curl_exit"
    fi

    HTTP_STATUS="${response##*$'\n'}"
    HTTP_BODY="${response%$'\n'*}"

    if [[ "$HTTP_STATUS" == "429" ]] && ((attempt == 1)); then
      sleep 2
      attempt=$((attempt + 1))
      continue
    fi

    return 0
  done
}

raindrop_api_get_json() {
  local path="$1"
  local token="$2"
  local url="$RAINDROP_API_BASE$path"
  local message=""

  if ! http_get_json "$url" "$token"; then
    die_system "Failed to reach Raindrop API: ${HTTP_BODY:-unknown error}"
  fi

  case "$HTTP_STATUS" in
    200)
      printf '%s\n' "$HTTP_BODY"
      ;;
    401)
      die_user "Invalid API token"
      ;;
    404)
      die_user "Raindrop resource not found"
      ;;
    429)
      die_system "Raindrop API rate limit exceeded"
      ;;
    *)
      message="$(extract_api_error_message "$HTTP_BODY")"
      if [[ -n "$message" ]]; then
        die_system "Raindrop API request failed ($HTTP_STATUS): $message"
      fi
      die_system "Raindrop API request failed ($HTTP_STATUS)"
      ;;
  esac
}

show_config() {
  local token=""
  local masked_token=""
  local collection_id="0"
  local token_configured="false"

  if [[ -f "$CONFIG_PATH" ]]; then
    ensure_config_file
    token="$(read_config_token)"
    collection_id="$(read_config_collection_id)"
  fi

  if [[ -n "$token" ]]; then
    token_configured="true"
    masked_token="$(mask_token "$token")"
  fi

  jq -n \
    --argjson token_configured "$token_configured" \
    --arg token "${masked_token:-}" \
    --argjson collection_id "$collection_id" \
    '{
      token_configured: $token_configured,
      token: (if $token == "" then null else $token end),
      collection_id: $collection_id
    }'
}

update_config() {
  local token="$1"
  local collection_id="$2"
  local tmp_file=""

  ensure_config_file
  tmp_file="$(mktemp)"

  jq \
    --arg token "$token" \
    --argjson collection_id "$collection_id" \
    '
      . as $root
      | ($root // {})
      | .raindrop = ((.raindrop // {}) + {
          token: $token,
          collection_id: $collection_id
        })
    ' "$CONFIG_PATH" >"$tmp_file"

  mv "$tmp_file" "$CONFIG_PATH"
}

resolve_sync_collection_id() {
  local explicit="${1:-}"
  local configured="0"

  if [[ -n "$explicit" ]]; then
    ensure_integer "$explicit" "collection id"
    printf '%s\n' "$explicit"
    return
  fi

  configured="$(read_config_collection_id)"
  ensure_integer "$configured" "collection id"
  printf '%s\n' "$configured"
}

resolve_since_date() {
  local explicit="${1:-}"
  local stored=""

  if [[ -n "$explicit" ]]; then
    iso_to_epoch "$explicit" >/dev/null 2>&1 || die_user "Invalid --since value: $explicit"
    printf '%s\n' "$explicit"
    return
  fi

  stored="$(read_state_last_sync_at)"
  if [[ -n "$stored" ]]; then
    iso_to_epoch "$stored" >/dev/null 2>&1 || die_system "Invalid last_sync_at in state file."
    printf '%s\n' "$stored"
    return
  fi

  timestamp_days_ago 7
}

pending_entries_json() {
  [[ -f "$QUEUE_PATH" ]] || {
    printf '[]\n'
    return
  }

  jq -sc '
    reduce to_entries[] as $entry (
      {};
      ($entry.value.raindrop_id // $entry.value.bookmark_id // empty | tostring) as $id
      | if $id == "" then
          .
        else
          .[$id] = {
            idx: $entry.key,
            value: $entry.value
          }
        end
    )
    | [ .[] | select(.value.event == "queued") ]
    | sort_by(.idx)
    | map(.value)
  ' "$QUEUE_PATH"
}

pending_count() {
  pending_entries_json | jq 'length'
}

build_highlights_array() {
  local raindrop_id="$1"
  local token="$2"
  local highlight_count="${3:-0}"
  local highlights_body=""

  if [[ ! "$highlight_count" =~ ^[0-9]+$ ]] || ((highlight_count == 0)); then
    printf '[]\n'
    return
  fi

  highlights_body="$(raindrop_api_get_json "/highlights/$raindrop_id" "$token")"
  printf '%s\n' "$highlights_body" |
    jq -c '[.items[]? | {
      text: (.text // ""),
      note: (.note // ""),
      color: (.color // "")
    }]'
}

build_queue_entry_json() {
  local bookmark_json="$1"
  local queued_at="$2"
  local token="$3"
  local fallback_collection_name="$4"
  local raindrop_id=""
  local highlight_count="0"
  local highlights_json="[]"

  raindrop_id="$(printf '%s\n' "$bookmark_json" | jq -r '._id // .id // empty')"
  [[ -n "$raindrop_id" ]] || die_system "Raindrop bookmark is missing an ID."

  # Raindrop API returns .highlights as array (not count). Use array length for count.
  highlight_count="$(printf '%s\n' "$bookmark_json" | jq -r '
    if (.highlights | type) == "array" then (.highlights | length)
    elif (.highlights_count // .highlightsCount // 0) | type == "number" then (.highlights_count // .highlightsCount // 0)
    else 0 end
  ')"
  highlights_json="$(build_highlights_array "$raindrop_id" "$token" "$highlight_count")"

  printf '%s\n' "$bookmark_json" |
    jq -c \
      --arg queued_at "$queued_at" \
      --arg collection_name "$fallback_collection_name" \
      --argjson highlights "$highlights_json" \
      '{
        event: "queued",
        queued_at: $queued_at,
        connector: "raindrop",
        bookmark_id: (._id // .id),
        raindrop_id: (._id // .id),
        title: (.title // .excerpt // .link // "Untitled"),
        link: (.link // ""),
        excerpt: (.excerpt // .note // ""),
        tags: (.tags // []),
        highlights: $highlights,
        collection_name: (.collection.name // .collection.title // .collection_name // $collection_name),
        created: (.created // "")
      }'
}

queue_entry_from_item_response() {
  local response_json="$1"
  local queued_at="$2"
  local token="$3"
  local fallback_collection_name="$4"
  local bookmark_json=""

  bookmark_json="$(printf '%s\n' "$response_json" | jq -c 'if .item? then .item else . end')"
  build_queue_entry_json "$bookmark_json" "$queued_at" "$token" "$fallback_collection_name"
}

append_queue_line() {
  local line="$1"

  [[ -n "$line" ]] || return 0
  printf '%s\n' "$line" >>"$QUEUE_PATH"
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
      | .raindrop = ((.raindrop // {}) + {
          last_sync_at: $synced_at,
          last_sync_count: $synced_count,
          total_synced: ((.raindrop.total_synced // 0) + $synced_count)
        })
    ' "$STATE_PATH" >"$tmp_file"

  mv "$tmp_file" "$STATE_PATH"
}

config_action() {
  local token=""
  local collection_id=""
  local show_only="false"

  while (($# > 0)); do
    case "$1" in
      --token)
        shift
        [[ $# -gt 0 ]] || die_user "--token requires a value"
        token="$1"
        ;;
      --collection)
        shift
        [[ $# -gt 0 ]] || die_user "--collection requires a value"
        collection_id="$1"
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

  if [[ -n "$collection_id" ]]; then
    ensure_integer "$collection_id" "collection id"
  fi

  if [[ -z "$token" ]]; then
    if [[ "$show_only" == "true" ]] && [[ -z "$collection_id" ]]; then
      show_config
      return
    fi
    die_user "--token is required unless using --show"
  fi

  if [[ -z "$collection_id" ]]; then
    collection_id="$(read_config_collection_id)"
  fi

  ensure_integer "$collection_id" "collection id"
  update_config "$token" "$collection_id"

  if [[ "$show_only" == "true" ]]; then
    show_config
  else
    jq -n --argjson collection_id "$collection_id" '{configured: true, collection_id: $collection_id}'
  fi
}

sync_action() {
  local since_arg=""
  local collection_arg=""
  local limit="$DEFAULT_SYNC_LIMIT"
  local token=""
  local collection_id=""
  local since_date=""
  local since_epoch=""
  local max_pages=1
  local now_ts=""
  local synced_count=0
  local page=0
  local page_body=""
  local items_count=0
  local bookmark_json=""
  local created=""
  local created_epoch=""
  local queue_line=""
  local reached_since_boundary="false"
  local remaining=0
  local fallback_collection_name=""

  while (($# > 0)); do
    case "$1" in
      --since)
        shift
        [[ $# -gt 0 ]] || die_user "--since requires a value"
        since_arg="$1"
        ;;
      --collection)
        shift
        [[ $# -gt 0 ]] || die_user "--collection requires a value"
        collection_arg="$1"
        ;;
      --limit)
        shift
        [[ $# -gt 0 ]] || die_user "--limit requires a value"
        limit="$1"
        ;;
      *)
        die_user "Unknown sync option: $1"
        ;;
    esac
    shift
  done

  ensure_integer "$limit" "limit"
  ((limit > 0)) || die_user "limit must be greater than zero."

  ensure_config_file
  token="$(read_config_token)"
  [[ -n "$token" ]] || die_user "Raindrop API token not configured. Run: pa-raindrop.sh config --token <token>"

  set_vault_context "$(resolve_vault_path)"
  ensure_state_file
  ensure_queue_file

  collection_id="$(resolve_sync_collection_id "$collection_arg")"
  since_date="$(resolve_since_date "$since_arg")"
  since_epoch="$(iso_to_epoch "$since_date")" || die_user "Invalid since date: $since_date"
  now_ts="$(iso_timestamp)"
  fallback_collection_name="Collection $collection_id"
  if [[ "$collection_id" == "0" ]]; then
    fallback_collection_name="Unsorted"
  fi

  max_pages=$(((limit + 49) / 50))
  if ((max_pages < 1)); then
    max_pages=1
  fi
  if ((max_pages > DEFAULT_SYNC_PAGES)); then
    max_pages="$DEFAULT_SYNC_PAGES"
  fi

  remaining="$limit"

  for ((page = 0; page < max_pages; page++)); do
    page_body="$(raindrop_api_get_json "/raindrops/$collection_id?sort=-created&perpage=50&page=$page" "$token")"
    items_count="$(printf '%s\n' "$page_body" | jq '(.items // []) | length')"

    if ((items_count == 0)); then
      break
    fi

    while IFS= read -r bookmark_json; do
      [[ -n "$bookmark_json" ]] || continue

      created="$(printf '%s\n' "$bookmark_json" | jq -r '.created // empty')"
      [[ -n "$created" ]] || die_system "Raindrop bookmark is missing a created timestamp."

      created_epoch="$(iso_to_epoch "$created")" || die_system "Invalid bookmark created timestamp: $created"
      if ((created_epoch < since_epoch)); then
        reached_since_boundary="true"
        break
      fi

      queue_line="$(build_queue_entry_json "$bookmark_json" "$now_ts" "$token" "$fallback_collection_name")"
      append_queue_line "$queue_line"
      synced_count=$((synced_count + 1))
      remaining=$((remaining - 1))

      if ((remaining == 0)); then
        reached_since_boundary="true"
        break
      fi
    done < <(printf '%s\n' "$page_body" | jq -c '.items[]?')

    if [[ "$reached_since_boundary" == "true" ]]; then
      break
    fi
  done

  update_sync_state "$synced_count" "$now_ts"

  jq -n \
    --argjson synced "$synced_count" \
    --argjson queue_pending "$(pending_count)" \
    '{
      synced: $synced,
      queue_pending: $queue_pending
    }'
}

pull_next_action() {
  local pending_json=""
  local next_entry=""

  set_vault_context "$(resolve_vault_path)"
  ensure_state_file
  ensure_queue_file

  pending_json="$(pending_entries_json)"
  next_entry="$(printf '%s\n' "$pending_json" | jq -c '.[0] // empty')"

  if [[ -z "$next_entry" ]]; then
    jq -n '{pending: 0}'
    return
  fi

  printf '%s\n' "$next_entry"
}

pull_specific_action() {
  local raindrop_id="$1"
  local token=""
  local response_json=""
  local fallback_collection_name=""

  ensure_integer "$raindrop_id" "raindrop id"
  ensure_config_file

  token="$(read_config_token)"
  [[ -n "$token" ]] || die_user "Raindrop API token not configured. Run: pa-raindrop.sh config --token <token>"

  fallback_collection_name="Collection $(read_config_collection_id)"
  if [[ "$fallback_collection_name" == "Collection 0" ]]; then
    fallback_collection_name="Unsorted"
  fi

  response_json="$(raindrop_api_get_json "/raindrop/$raindrop_id" "$token")"
  queue_entry_from_item_response "$response_json" "$(iso_timestamp)" "$token" "$fallback_collection_name"
}

pull_action() {
  if (($# == 0)); then
    pull_next_action
    return
  fi

  case "$1" in
    --next)
      shift
      (($# == 0)) || die_user "--next does not accept additional arguments"
      pull_next_action
      ;;
    *)
      (($# == 1)) || die_user "pull accepts either --next or one raindrop id"
      pull_specific_action "$1"
      ;;
  esac
}

status_action() {
  local token=""
  local token_configured="false"
  local api_reachable="false"
  local last_sync_at=""

  set_vault_context "$(resolve_vault_path)"
  ensure_state_file
  ensure_queue_file

  if [[ -f "$CONFIG_PATH" ]]; then
    ensure_config_file
    token="$(read_config_token)"
  fi

  if [[ -n "$token" ]]; then
    token_configured="true"
    if http_get_json "$RAINDROP_API_BASE/user" "$token"; then
      if [[ "$HTTP_STATUS" == "200" ]]; then
        api_reachable="true"
      fi
    fi
  fi

  last_sync_at="$(read_state_last_sync_at)"

  jq -n \
    --argjson token_configured "$token_configured" \
    --argjson api_reachable "$api_reachable" \
    --arg last_sync_at "$last_sync_at" \
    --argjson queue_pending "$(pending_count)" \
    --argjson queue_total "$(line_count_or_zero "$QUEUE_PATH")" \
    '{
      token_configured: $token_configured,
      api_reachable: $api_reachable,
      last_sync_at: (if $last_sync_at == "" then null else $last_sync_at end),
      queue_pending: $queue_pending,
      queue_total: $queue_total
    }'
}

main() {
  local action="${1:-}"

  ensure_jq
  ensure_curl

  [[ -n "$action" ]] || {
    usage
    exit 1
  }

  shift || true

  case "$action" in
    config)
      config_action "$@"
      ;;
    sync)
      sync_action "$@"
      ;;
    pull)
      pull_action "$@"
      ;;
    status)
      status_action "$@"
      ;;
    -h | --help | help)
      usage
      ;;
    *)
      die_user "Unknown action: $action"
      ;;
  esac
}

main "$@"
