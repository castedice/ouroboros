#!/usr/bin/env bash
# pa-standing-orders.sh - declarative standing order engine for PA.
#
# Actions:
#   validate
#   sync
#   list
#   run <order-id>
#   history [--order <id>] [--limit N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PA_SCHEDULER_SCRIPT="$SCRIPT_DIR/pa-scheduler.sh"
PA_NOTIFY_SCRIPT="$SCRIPT_DIR/pa-notify.sh"
SCHEDULER_REGISTRY_PATH="$HOME/.config/ouroboros/schedules.json"

VAULT_PATH=""
PA_DIR=""
SETTINGS_PATH=""
HEARTBEAT_PATH=""
ORDERS_PATH=""
RUN_LOG_PATH=""

VALIDATION_ORDER_COUNT=0
RUN_TEMPORARY_ENTRY="false"

usage() {
  cat <<'EOF'
pa-standing-orders.sh <action> [args]

Actions:
  validate
  sync
  list
  run <order-id>
  history [--order <id>] [--limit N]
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

resolve_vault_path() {
  local explicit_path="${1:-}"
  local detected_path=""

  if [[ -n "$explicit_path" ]]; then
    resolve_absolute_dir "$explicit_path"
    return
  fi

  detected_path="$(detect_default_vault_path)"
  [[ -n "$detected_path" ]] || die_user "vault path required. Set PA_VAULT_PATH, rely on QMD collection discovery, or run from the vault root."
  printf '%s\n' "$detected_path"
}

set_vault_context() {
  VAULT_PATH="$1"
  PA_DIR="$VAULT_PATH/.pa"
  SETTINGS_PATH="$PA_DIR/settings.json"
  HEARTBEAT_PATH="$PA_DIR/heartbeat.json"
  ORDERS_PATH="$PA_DIR/standing-orders.json"
  RUN_LOG_PATH="$PA_DIR/standing-order-runs.jsonl"
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die_user ".pa directory not found: $PA_DIR"
}

write_default_orders_file() {
  mkdir -p "$PA_DIR" || die_system "Failed to create PA directory: $PA_DIR"
  cat >"$ORDERS_PATH" <<'EOF'
{
  "version": 1,
  "orders": []
}
EOF
}

ensure_orders_file_initialized() {
  if [[ -f "$ORDERS_PATH" ]]; then
    validate_json "$ORDERS_PATH"
    return
  fi

  write_default_orders_file
}

ensure_scheduler_script() {
  [[ -f "$PA_SCHEDULER_SCRIPT" ]] || die_system "Required script not found: $PA_SCHEDULER_SCRIPT"
}

ensure_notify_script_if_present() {
  [[ -f "$PA_NOTIFY_SCRIPT" ]]
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

normalize_iso_input() {
  printf '%s' "$1" | sed -E 's/Z$/+0000/; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/'
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

now_epoch() {
  date '+%s'
}

normalize_whitespace() {
  printf '%s\n' "$1" | awk '{$1=$1; print}'
}

cron_expression_valid() {
  local cron=""

  cron="$(normalize_whitespace "$1")"
  printf '%s\n' "$cron" | awk '
    NF != 5 { exit 1 }
    {
      for (i = 1; i <= 5; i++) {
        if ($i !~ /^[0-9*\/,\-]+$/) {
          exit 1
        }
      }
    }
  ' >/dev/null 2>&1
}

validate_order_id() {
  local order_id="$1"

  [[ -n "$order_id" ]] || return 1
  [[ "$order_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

validate_runner() {
  case "$1" in
    claude | script)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_posture() {
  case "$1" in
    observe | propose | apply-low-risk | operate)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_rule_type() {
  case "$1" in
    exit_code | artifact_exists | json_field | file_contains)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_escalation_mode() {
  case "$1" in
    none | propose)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

validate_notify_priority() {
  case "$1" in
    none | info | warning | critical)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

posture_rank() {
  case "$1" in
    observe)
      printf '1\n'
      ;;
    propose)
      printf '2\n'
      ;;
    apply-low-risk)
      printf '3\n'
      ;;
    operate)
      printf '4\n'
      ;;
    *)
      return 1
      ;;
  esac
}

posture_meets_minimum() {
  local current="$1"
  local minimum="$2"
  local current_rank=""
  local minimum_rank=""

  validate_posture "$current" || return 1
  validate_posture "$minimum" || return 1

  current_rank="$(posture_rank "$current")"
  minimum_rank="$(posture_rank "$minimum")"
  [[ "$current_rank" -ge "$minimum_rank" ]]
}

append_validation_error() {
  local error_file="$1"
  local message="$2"

  printf '%s\n' "$message" >>"$error_file"
}

validate_orders_schema() {
  local error_file="$1"
  local order_count="0"
  local duplicate_ids=""
  local index=0
  local order_json=""
  local order_type=""
  local order_id=""
  local order_name=""
  local command_text=""
  local schedule=""
  local runner=""
  local enabled_type=""
  local created=""
  local minimum_posture=""
  local heartbeat_type=""
  local escalation_mode=""
  local notify_level=""
  local cooldown_type=""
  local rule_count=0
  local rule_index=0
  local rule_json=""
  local rule_type=""
  local rule_value_type=""

  VALIDATION_ORDER_COUNT=0
  : >"$error_file"

  ensure_orders_file_initialized
  validate_json "$ORDERS_PATH"

  if [[ "$(jq -r '.version // empty' "$ORDERS_PATH")" != "1" ]]; then
    append_validation_error "$error_file" "version must be 1"
  fi

  if [[ "$(jq -r '(.orders | type) == "array"' "$ORDERS_PATH" 2>/dev/null || printf 'false')" != "true" ]]; then
    append_validation_error "$error_file" "orders must be an array"
    return 1
  fi

  order_count="$(jq '.orders | length' "$ORDERS_PATH")"
  VALIDATION_ORDER_COUNT="$order_count"

  duplicate_ids="$(jq -r '
    (.orders // [])
    | map(.id // empty)
    | map(select(. != ""))
    | group_by(.)
    | map(select(length > 1) | .[0])
    | .[]
  ' "$ORDERS_PATH" 2>/dev/null || true)"
  if [[ -n "$duplicate_ids" ]]; then
    while IFS= read -r duplicate_id; do
      [[ -n "$duplicate_id" ]] || continue
      append_validation_error "$error_file" "duplicate order id: $duplicate_id"
    done <<<"$duplicate_ids"
  fi

  while [[ "$index" -lt "$order_count" ]]; do
    order_json="$(jq -c ".orders[$index]" "$ORDERS_PATH")"
    order_type="$(jq -r 'type' <<<"$order_json")"
    if [[ "$order_type" != "object" ]]; then
      append_validation_error "$error_file" "orders[$index] must be an object"
      index=$((index + 1))
      continue
    fi

    order_id="$(jq -r '.id // empty' <<<"$order_json")"
    if ! validate_order_id "$order_id"; then
      append_validation_error "$error_file" "orders[$index].id is required and must match [A-Za-z0-9._-]"
    fi

    order_name="$(jq -r '.name // empty' <<<"$order_json")"
    [[ -n "$order_name" ]] || append_validation_error "$error_file" "orders[$index].name is required"

    command_text="$(jq -r '.command // empty' <<<"$order_json")"
    [[ -n "$command_text" ]] || append_validation_error "$error_file" "orders[$index].command is required"

    schedule="$(jq -r '.schedule // empty' <<<"$order_json")"
    if [[ -z "$schedule" ]] || ! cron_expression_valid "$schedule"; then
      append_validation_error "$error_file" "orders[$index].schedule must be a valid 5-field cron expression"
    fi

    runner="$(jq -r '.runner // empty' <<<"$order_json")"
    if ! validate_runner "$runner"; then
      append_validation_error "$error_file" "orders[$index].runner must be claude or script"
    fi

    enabled_type="$(jq -r 'if has("enabled") then (.enabled | type) else "missing" end' <<<"$order_json")"
    if [[ "$enabled_type" != "boolean" ]]; then
      append_validation_error "$error_file" "orders[$index].enabled must be a boolean"
    fi

    created="$(jq -r '.created // empty' <<<"$order_json")"
    if [[ ! "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
      append_validation_error "$error_file" "orders[$index].created must be YYYY-MM-DD"
    fi

    if [[ "$(jq -r '(.scope | type) == "object"' <<<"$order_json" 2>/dev/null || printf 'false')" != "true" ]]; then
      append_validation_error "$error_file" "orders[$index].scope must be an object"
    fi

    if [[ "$(jq -r '(.scope.verify.rules | type) == "array"' <<<"$order_json" 2>/dev/null || printf 'false')" != "true" ]]; then
      append_validation_error "$error_file" "orders[$index].scope.verify.rules must be an array"
      rule_count=0
    else
      rule_count="$(jq '.scope.verify.rules | length' <<<"$order_json")"
    fi

    rule_index=0
    while [[ "$rule_index" -lt "$rule_count" ]]; do
      rule_json="$(jq -c ".scope.verify.rules[$rule_index]" <<<"$order_json")"
      if [[ "$(jq -r 'type' <<<"$rule_json")" != "object" ]]; then
        append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index] must be an object"
        rule_index=$((rule_index + 1))
        continue
      fi

      rule_type="$(jq -r '.type // empty' <<<"$rule_json")"
      if ! validate_rule_type "$rule_type"; then
        append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].type is invalid"
        rule_index=$((rule_index + 1))
        continue
      fi

      case "$rule_type" in
        exit_code)
          rule_value_type="$(jq -r 'if has("equals") then (.equals | type) else "missing" end' <<<"$rule_json")"
          if [[ "$rule_value_type" != "number" ]]; then
            append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].equals must be a number"
          fi
          ;;
        artifact_exists)
          [[ -n "$(jq -r '.path // empty' <<<"$rule_json")" ]] || append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].path is required"
          ;;
        json_field)
          [[ -n "$(jq -r '.path // empty' <<<"$rule_json")" ]] || append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].path is required"
          if [[ "$(jq -r '((has("jq") and (.jq | type) == "string" and .jq != "") or (has("expression") and (.expression | type) == "string" and .expression != ""))' <<<"$rule_json")" != "true" ]]; then
            append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index] must define jq or expression"
          fi
          if [[ "$(jq -r 'has("equals")' <<<"$rule_json")" != "true" ]]; then
            append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].equals is required"
          fi
          ;;
        file_contains)
          [[ -n "$(jq -r '.path // empty' <<<"$rule_json")" ]] || append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].path is required"
          [[ -n "$(jq -r '.pattern // empty' <<<"$rule_json")" ]] || append_validation_error "$error_file" "orders[$index].scope.verify.rules[$rule_index].pattern is required"
          ;;
      esac

      rule_index=$((rule_index + 1))
    done

    if [[ "$(jq -r '(.approval_gate | type) == "object"' <<<"$order_json" 2>/dev/null || printf 'false')" != "true" ]]; then
      append_validation_error "$error_file" "orders[$index].approval_gate must be an object"
    else
      minimum_posture="$(jq -r '.approval_gate.minimum_posture // empty' <<<"$order_json")"
      if ! validate_posture "$minimum_posture"; then
        append_validation_error "$error_file" "orders[$index].approval_gate.minimum_posture is invalid"
      fi

      heartbeat_type="$(jq -r 'if .approval_gate | has("require_healthy_heartbeat") then .approval_gate.require_healthy_heartbeat | type else "missing" end' <<<"$order_json")"
      if [[ "$heartbeat_type" != "boolean" ]]; then
        append_validation_error "$error_file" "orders[$index].approval_gate.require_healthy_heartbeat must be a boolean"
      fi
    fi

    if [[ "$(jq -r '(.escalation | type) == "object"' <<<"$order_json" 2>/dev/null || printf 'false')" != "true" ]]; then
      append_validation_error "$error_file" "orders[$index].escalation must be an object"
    else
      escalation_mode="$(jq -r '.escalation.on_verify_fail // "none"' <<<"$order_json")"
      if ! validate_escalation_mode "$escalation_mode"; then
        append_validation_error "$error_file" "orders[$index].escalation.on_verify_fail is invalid"
      fi

      notify_level="$(jq -r '.escalation.notify // "none"' <<<"$order_json")"
      if ! validate_notify_priority "$notify_level"; then
        append_validation_error "$error_file" "orders[$index].escalation.notify is invalid"
      fi

      cooldown_type="$(jq -r 'if .escalation | has("cooldown_hours") then .escalation.cooldown_hours | type else "missing" end' <<<"$order_json")"
      if [[ "$cooldown_type" != "number" ]]; then
        append_validation_error "$error_file" "orders[$index].escalation.cooldown_hours must be a number"
      fi
    fi

    index=$((index + 1))
  done

  [[ ! -s "$error_file" ]]
}

scheduler_entry_name() {
  printf 'standing-order:%s\n' "$1"
}

scheduler_registry_valid() {
  [[ -f "$SCHEDULER_REGISTRY_PATH" ]] || return 1
  jq empty "$SCHEDULER_REGISTRY_PATH" >/dev/null 2>&1 || die_system "Failed to parse scheduler registry: $SCHEDULER_REGISTRY_PATH"
}

scheduler_entry_json() {
  local entry_name="$1"

  scheduler_registry_valid || return 1
  jq -c --arg name "$entry_name" '.schedules[]? | select(.name == $name)' "$SCHEDULER_REGISTRY_PATH"
}

scheduler_entry_exists() {
  local entry_name="$1"
  local entry_json=""

  entry_json="$(scheduler_entry_json "$entry_name" 2>/dev/null || true)"
  [[ -n "$entry_json" ]]
}

scheduler_entry_matches() {
  local entry_name="$1"
  local schedule="$2"
  local runner="$3"
  local command_text="$4"
  local entry_json=""

  entry_json="$(scheduler_entry_json "$entry_name" 2>/dev/null || true)"
  [[ -n "$entry_json" ]] || return 1
  [[ "$(jq -r '.cron' <<<"$entry_json")" == "$schedule" ]] || return 1
  [[ "$(jq -r '.runner' <<<"$entry_json")" == "$runner" ]] || return 1
  [[ "$(jq -r '.command' <<<"$entry_json")" == "$command_text" ]] || return 1
  [[ "$(jq -r 'if .enabled == true then "true" else "false" end' <<<"$entry_json")" == "true" ]]
}

register_scheduler_entry() {
  local entry_name="$1"
  local schedule="$2"
  local command_text="$3"
  local runner="$4"

  PA_VAULT_PATH="$VAULT_PATH" \
    bash "$PA_SCHEDULER_SCRIPT" register "$entry_name" "$schedule" "$command_text" --runner "$runner" --notify none >/dev/null
}

remove_scheduler_entry() {
  local entry_name="$1"

  if scheduler_entry_exists "$entry_name"; then
    bash "$PA_SCHEDULER_SCRIPT" remove "$entry_name" >/dev/null
  fi
}

sync_order_entry() {
  local order_json="$1"
  local mode="${2:-respect_enabled}"
  local order_id=""
  local schedule=""
  local command_text=""
  local runner=""
  local enabled="false"
  local entry_name=""
  local should_exist="false"
  local existed="false"

  order_id="$(jq -r '.id' <<<"$order_json")"
  schedule="$(normalize_whitespace "$(jq -r '.schedule' <<<"$order_json")")"
  command_text="$(jq -r '.command' <<<"$order_json")"
  runner="$(jq -r '.runner' <<<"$order_json")"
  enabled="$(jq -r 'if .enabled == true then "true" else "false" end' <<<"$order_json")"
  entry_name="$(scheduler_entry_name "$order_id")"

  if [[ "$mode" == "ensure" ]] || [[ "$enabled" == "true" ]]; then
    should_exist="true"
  fi

  if scheduler_entry_exists "$entry_name"; then
    existed="true"
  fi

  if [[ "$should_exist" != "true" ]]; then
    if [[ "$existed" == "true" ]]; then
      remove_scheduler_entry "$entry_name"
      printf 'removed\n'
    else
      printf 'unchanged\n'
    fi
    return
  fi

  if scheduler_entry_matches "$entry_name" "$schedule" "$runner" "$command_text"; then
    printf 'unchanged\n'
    return
  fi

  if [[ "$existed" == "true" ]]; then
    remove_scheduler_entry "$entry_name"
    register_scheduler_entry "$entry_name" "$schedule" "$command_text" "$runner"
    printf 'updated\n'
    return
  fi

  register_scheduler_entry "$entry_name" "$schedule" "$command_text" "$runner"
  printf 'added\n'
}

current_standing_scheduler_entries() {
  scheduler_registry_valid || return 0
  jq -r '
    (.schedules // [])
    | map(select(.name | startswith("standing-order:")))
    | .[]
    | .name
  ' "$SCHEDULER_REGISTRY_PATH"
}

get_order_json() {
  local order_id="$1"

  jq -c --arg id "$order_id" '.orders[]? | select(.id == $id)' "$ORDERS_PATH"
}

read_current_posture() {
  local posture=""

  [[ -f "$SETTINGS_PATH" ]] || return 1
  jq empty "$SETTINGS_PATH" >/dev/null 2>&1 || return 1
  posture="$(jq -r '.automation_posture // .posture // empty' "$SETTINGS_PATH" 2>/dev/null || true)"
  validate_posture "$posture" || return 1
  printf '%s\n' "$posture"
}

heartbeat_is_healthy() {
  local status=""
  local highest=""

  [[ -f "$HEARTBEAT_PATH" ]] || return 1
  jq empty "$HEARTBEAT_PATH" >/dev/null 2>&1 || return 1
  status="$(jq -r '.status // empty' "$HEARTBEAT_PATH" 2>/dev/null || true)"
  highest="$(jq -r '.highest_severity // empty' "$HEARTBEAT_PATH" 2>/dev/null || true)"
  [[ "$status" != "error" ]] || return 1
  [[ "$status" != "errors" ]] || return 1
  [[ "$highest" != "error" ]]
}

resolve_rule_path() {
  local raw_path="$1"

  [[ -n "$raw_path" ]] || return 1

  case "$raw_path" in
    /*)
      printf '%s\n' "$raw_path"
      ;;
    ./*)
      printf '%s/%s\n' "$VAULT_PATH" "${raw_path#./}"
      ;;
    .pa/*)
      printf '%s/%s\n' "$VAULT_PATH" "$raw_path"
      ;;
    */*)
      printf '%s/%s\n' "$VAULT_PATH" "$raw_path"
      ;;
    *)
      printf '%s/.pa/%s\n' "$VAULT_PATH" "$raw_path"
      ;;
  esac
}

append_failed_rule() {
  local failed_file="$1"
  local rule_type="$2"
  local reason="$3"

  jq -nc \
    --arg type "$rule_type" \
    --arg reason "$reason" \
    '{type: $type, reason: $reason}' >>"$failed_file" || die_system "Failed to record verification result"
}

verify_order_rules() {
  local order_json="$1"
  local execution_exit_code="$2"
  local failed_file=""
  local rule_count=0
  local rule_index=0
  local rule_json=""
  local rule_type=""
  local expected=""
  local resolved_path=""
  local query=""
  local actual=""
  local failed_rules_json="[]"

  failed_file="$(mktemp)"
  rule_count="$(jq '.scope.verify.rules | length' <<<"$order_json")"

  while [[ "$rule_index" -lt "$rule_count" ]]; do
    rule_json="$(jq -c ".scope.verify.rules[$rule_index]" <<<"$order_json")"
    rule_type="$(jq -r '.type' <<<"$rule_json")"

    case "$rule_type" in
      exit_code)
        expected="$(jq -r '.equals' <<<"$rule_json")"
        if [[ "$execution_exit_code" -ne "$expected" ]]; then
          append_failed_rule "$failed_file" "$rule_type" "expected exit_code=$expected, got $execution_exit_code"
        fi
        ;;
      artifact_exists)
        resolved_path="$(resolve_rule_path "$(jq -r '.path' <<<"$rule_json")")"
        if [[ ! -e "$resolved_path" ]]; then
          append_failed_rule "$failed_file" "$rule_type" "artifact missing: ${resolved_path#$VAULT_PATH/}"
        fi
        ;;
      json_field)
        resolved_path="$(resolve_rule_path "$(jq -r '.path' <<<"$rule_json")")"
        if [[ ! -f "$resolved_path" ]]; then
          append_failed_rule "$failed_file" "$rule_type" "JSON file missing: ${resolved_path#$VAULT_PATH/}"
        else
          query="$(jq -r '.jq // .expression // empty' <<<"$rule_json")"
          actual="$(jq -c "$query" "$resolved_path" 2>/dev/null | paste -sd '\n' - || true)"
          if [[ -z "$actual" ]]; then
            append_failed_rule "$failed_file" "$rule_type" "jq query returned no result for ${resolved_path#$VAULT_PATH/}"
          else
            expected="$(jq -c '.equals' <<<"$rule_json")"
            if [[ "$actual" != "$expected" ]]; then
              append_failed_rule "$failed_file" "$rule_type" "expected $expected, got $actual for ${resolved_path#$VAULT_PATH/}"
            fi
          fi
        fi
        ;;
      file_contains)
        resolved_path="$(resolve_rule_path "$(jq -r '.path' <<<"$rule_json")")"
        if [[ ! -f "$resolved_path" ]]; then
          append_failed_rule "$failed_file" "$rule_type" "file missing: ${resolved_path#$VAULT_PATH/}"
        else
          if ! grep -Eq -- "$(jq -r '.pattern' <<<"$rule_json")" "$resolved_path"; then
            append_failed_rule "$failed_file" "$rule_type" "pattern not found in ${resolved_path#$VAULT_PATH/}"
          fi
        fi
        ;;
      *)
        append_failed_rule "$failed_file" "$rule_type" "unknown verification rule"
        ;;
    esac

    rule_index=$((rule_index + 1))
  done

  if [[ -s "$failed_file" ]]; then
    failed_rules_json="$(jq -cs '.' "$failed_file")"
    jq -nc --argjson failed_rules "$failed_rules_json" '{passed: false, failed_rules: $failed_rules}'
  else
    jq -nc '{passed: true, failed_rules: []}'
  fi

  rm -f "$failed_file"
}

append_run_log() {
  local order_id="$1"
  local executed_at="$2"
  local status="$3"
  local exit_code_json="$4"
  local verification_json="$5"
  local escalated_to="$6"
  local notified_json="$7"

  mkdir -p "$PA_DIR" || die_system "Failed to create PA directory: $PA_DIR"

  jq -nc \
    --arg order_id "$order_id" \
    --arg executed_at "$executed_at" \
    --arg status "$status" \
    --argjson exit_code "$exit_code_json" \
    --argjson verification "$verification_json" \
    --arg escalated_to "$escalated_to" \
    --argjson notified "$notified_json" \
    '{
      order_id: $order_id,
      executed_at: $executed_at,
      status: $status,
      exit_code: $exit_code,
      verification: $verification,
      escalated_to: (if $escalated_to == "" then null else $escalated_to end),
      notified: $notified
    }' >>"$RUN_LOG_PATH" || die_system "Failed to append standing order run log: $RUN_LOG_PATH"
}

last_status_for_order() {
  local order_id="$1"
  local value=""

  [[ -f "$RUN_LOG_PATH" ]] || {
    printf '%s\n' "-"
    return
  }

  value="$(jq -sr --arg id "$order_id" '
    map(select(.order_id == $id))
    | if length == 0 then "-" else (last.status // "-") end
  ' "$RUN_LOG_PATH" 2>/dev/null || true)"

  [[ -n "$value" ]] || value="-"
  printf '%s\n' "$value"
}

notification_allowed_by_cooldown() {
  local order_id="$1"
  local cooldown_hours="$2"
  local last_notified_at=""
  local last_epoch=""
  local cutoff_seconds=0
  local current_epoch=0

  [[ -f "$RUN_LOG_PATH" ]] || return 0
  [[ "$cooldown_hours" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 0

  if ! awk "BEGIN { exit !($cooldown_hours > 0) }" >/dev/null 2>&1; then
    return 0
  fi

  last_notified_at="$(jq -sr --arg id "$order_id" '
    map(select(.order_id == $id and .notified == true))
    | if length == 0 then "" else (last.executed_at // "") end
  ' "$RUN_LOG_PATH" 2>/dev/null || true)"

  [[ -n "$last_notified_at" ]] || return 0
  last_epoch="$(iso_to_epoch "$last_notified_at" 2>/dev/null || true)"
  [[ -n "$last_epoch" ]] || return 0

  cutoff_seconds="$(awk "BEGIN { printf \"%d\", ($cooldown_hours * 3600) }")"
  current_epoch="$(now_epoch)"
  [[ $((current_epoch - last_epoch)) -ge "$cutoff_seconds" ]]
}

escalate_verify_failure() {
  local order_json="$1"
  local verification_json="$2"
  local order_id=""
  local order_name=""
  local notify_level=""
  local cooldown_hours=""
  local failed_count=""
  local notified="false"

  order_id="$(jq -r '.id' <<<"$order_json")"
  order_name="$(jq -r '.name' <<<"$order_json")"
  notify_level="$(jq -r '.escalation.notify // "none"' <<<"$order_json")"
  cooldown_hours="$(jq -r '.escalation.cooldown_hours // 0' <<<"$order_json")"

  if [[ "$notify_level" != "none" ]] && ensure_notify_script_if_present; then
    if notification_allowed_by_cooldown "$order_id" "$cooldown_hours"; then
      failed_count="$(jq '.failed_rules | length' <<<"$verification_json")"
      PA_NOTIFY_SOURCE="standing-order" \
        bash "$PA_NOTIFY_SCRIPT" send \
          "PA:standing-order:$order_id" \
          "Standing order \"$order_name\" failed verification in vault \"$(basename "$VAULT_PATH")\" with $failed_count failed rule(s)." \
          --priority "$notify_level" \
          --tags "standing-order,warning" >/dev/null && notified="true" || true
    fi
  fi

  printf '%s\n' "$notified"
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

load_validated_orders() {
  local error_file=""

  error_file="$(mktemp)"
  if ! validate_orders_schema "$error_file"; then
    cat "$error_file" >&2
    rm -f "$error_file"
    exit 1
  fi
  rm -f "$error_file"
}

action_validate() {
  local error_file=""

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  error_file="$(mktemp)"

  if validate_orders_schema "$error_file"; then
    printf 'Valid: %s orders\n' "$VALIDATION_ORDER_COUNT"
    rm -f "$error_file"
    return
  fi

  cat "$error_file"
  rm -f "$error_file"
  exit 1
}

action_sync() {
  local added=0
  local updated=0
  local removed=0
  local unchanged=0
  local result=""
  local entry_name=""
  local orphan_id=""

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  ensure_scheduler_script
  load_validated_orders

  while IFS= read -r order_json; do
    [[ -n "$order_json" ]] || continue
    result="$(sync_order_entry "$order_json")"
    case "$result" in
      added)
        added=$((added + 1))
        ;;
      updated)
        updated=$((updated + 1))
        ;;
      removed)
        removed=$((removed + 1))
        ;;
      unchanged)
        unchanged=$((unchanged + 1))
        ;;
      *)
        die_system "Unknown sync result: $result"
        ;;
    esac
  done < <(jq -c '.orders[]?' "$ORDERS_PATH")

  while IFS= read -r entry_name; do
    [[ -n "$entry_name" ]] || continue
    orphan_id="${entry_name#standing-order:}"
    if ! jq -e --arg id "$orphan_id" '.orders[]? | select(.id == $id and .enabled == true)' "$ORDERS_PATH" >/dev/null 2>&1; then
      remove_scheduler_entry "$entry_name"
      removed=$((removed + 1))
    fi
  done < <(current_standing_scheduler_entries)

  printf 'Sync complete: added=%s updated=%s removed=%s unchanged=%s\n' "$added" "$updated" "$removed" "$unchanged"
}

action_list() {
  local tsv_file=""
  local order_id=""
  local order_name=""
  local schedule=""
  local enabled=""
  local last_status=""

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  load_validated_orders

  if [[ "$VALIDATION_ORDER_COUNT" -eq 0 ]]; then
    echo "No standing orders configured."
    return
  fi

  tsv_file="$(mktemp)"
  printf 'id\tname\tschedule\tenabled\tlast_status\n' >"$tsv_file"

  while IFS= read -r order_json; do
    [[ -n "$order_json" ]] || continue
    order_id="$(jq -r '.id' <<<"$order_json")"
    order_name="$(jq -r '.name' <<<"$order_json")"
    schedule="$(jq -r '.schedule' <<<"$order_json")"
    enabled="$(jq -r 'if .enabled == true then "true" else "false" end' <<<"$order_json")"
    last_status="$(last_status_for_order "$order_id")"
    printf '%s\t%s\t%s\t%s\t%s\n' "$order_id" "$order_name" "$schedule" "$enabled" "$last_status" >>"$tsv_file"
  done < <(jq -c '.orders[]?' "$ORDERS_PATH")

  print_table_from_tsv <"$tsv_file"
  rm -f "$tsv_file"
}

prepare_entry_for_run() {
  local order_json="$1"
  local enabled=""
  local result=""

  enabled="$(jq -r 'if .enabled == true then "true" else "false" end' <<<"$order_json")"
  result="$(sync_order_entry "$order_json" "ensure")"
  RUN_TEMPORARY_ENTRY="false"
  if [[ "$enabled" != "true" ]]; then
    RUN_TEMPORARY_ENTRY="true"
  fi
  [[ -n "$result" ]] || die_system "Failed to prepare scheduler entry"
}

cleanup_temporary_entry() {
  local order_id="$1"
  local entry_name=""

  if [[ "$RUN_TEMPORARY_ENTRY" == "true" ]]; then
    entry_name="$(scheduler_entry_name "$order_id")"
    remove_scheduler_entry "$entry_name"
    RUN_TEMPORARY_ENTRY="false"
  fi
}

action_run() {
  local order_id="${1:-}"
  local order_json=""
  local entry_name=""
  local minimum_posture=""
  local require_healthy_heartbeat="false"
  local current_posture=""
  local executed_at=""
  local execution_exit_code=0
  local exit_code_json="null"
  local verification_json='{"passed":false,"failed_rules":[]}'
  local status="failed"
  local escalated_to=""
  local notified_json="false"
  local return_code=2

  validate_order_id "$order_id" || die_user "Usage: pa-standing-orders.sh run <order-id>"

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  ensure_scheduler_script
  load_validated_orders

  order_json="$(get_order_json "$order_id")"
  [[ -n "$order_json" ]] || die_user "standing order not found: $order_id"

  executed_at="$(iso_timestamp)"
  minimum_posture="$(jq -r '.approval_gate.minimum_posture' <<<"$order_json")"
  require_healthy_heartbeat="$(jq -r 'if .approval_gate.require_healthy_heartbeat == true then "true" else "false" end' <<<"$order_json")"

  current_posture="$(read_current_posture 2>/dev/null || true)"
  if ! posture_meets_minimum "$current_posture" "$minimum_posture"; then
    status="blocked"
    append_run_log "$order_id" "$executed_at" "$status" "$exit_code_json" "$verification_json" "$escalated_to" "$notified_json"
    printf 'Blocked: posture %s does not meet minimum %s\n' "${current_posture:-unknown}" "$minimum_posture"
    return 1
  fi

  if [[ "$require_healthy_heartbeat" == "true" ]] && ! heartbeat_is_healthy; then
    status="blocked"
    append_run_log "$order_id" "$executed_at" "$status" "$exit_code_json" "$verification_json" "$escalated_to" "$notified_json"
    echo "Blocked: heartbeat is missing, malformed, or unhealthy"
    return 1
  fi

  prepare_entry_for_run "$order_json"
  entry_name="$(scheduler_entry_name "$order_id")"

  set +e
  PA_VAULT_PATH="$VAULT_PATH" bash "$PA_SCHEDULER_SCRIPT" run "$entry_name"
  execution_exit_code=$?
  set -e
  exit_code_json="$execution_exit_code"

  verification_json="$(verify_order_rules "$order_json" "$execution_exit_code")"

  if [[ "$(jq -r '.passed' <<<"$verification_json")" == "true" ]]; then
    status="success"
    return_code=0
  else
    status="verify-failed"
    return_code=1
    escalated_to="$(jq -r '.escalation.on_verify_fail // "none"' <<<"$order_json")"
    if [[ "$escalated_to" == "none" ]]; then
      escalated_to=""
    fi
    notified_json="$(escalate_verify_failure "$order_json" "$verification_json")"
  fi

  cleanup_temporary_entry "$order_id"
  append_run_log "$order_id" "$executed_at" "$status" "$exit_code_json" "$verification_json" "$escalated_to" "$notified_json"

  case "$status" in
    success)
      printf 'Standing order succeeded: %s\n' "$order_id"
      ;;
    verify-failed)
      printf 'Standing order verification failed: %s\n' "$order_id"
      ;;
    *)
      printf 'Standing order failed: %s\n' "$order_id"
      ;;
  esac

  return "$return_code"
}

action_history() {
  local order_filter=""
  local limit="10"
  local history_tsv=""

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  ensure_orders_file_initialized

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --order)
        shift || die_user "--order requires a value"
        [[ $# -gt 0 ]] || die_user "--order requires a value"
        validate_order_id "$1" || die_user "invalid order id: $1"
        order_filter="$1"
        ;;
      --limit)
        shift || die_user "--limit requires a value"
        [[ $# -gt 0 ]] || die_user "--limit requires a value"
        [[ "$1" =~ ^[0-9]+$ ]] || die_user "--limit must be a positive integer"
        limit="$1"
        ;;
      *)
        die_user "Unknown option: $1"
        ;;
    esac
    shift || true
  done

  [[ -f "$RUN_LOG_PATH" ]] || {
    echo "No standing order runs recorded."
    return
  }

  history_tsv="$(jq -sr --arg order "$order_filter" --argjson limit "$limit" '
    map(select($order == "" or .order_id == $order))
    | reverse
    | .[0:$limit]
    | if length == 0 then
        ""
      else
        (
          ["executed_at", "order_id", "status", "exit_code", "notified", "escalated_to"],
          (
            .[] | [
              (.executed_at // "-"),
              (.order_id // "-"),
              (.status // "-"),
              ((.exit_code // "-") | tostring),
              ((.notified // false) | tostring),
              (.escalated_to // "-")
            ]
          )
        ) | @tsv
      end
  ' "$RUN_LOG_PATH" 2>/dev/null || true)"

  [[ -n "$history_tsv" ]] || {
    echo "No standing order runs recorded."
    return
  }

  printf '%s\n' "$history_tsv" | print_table_from_tsv
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  validate)
    action_validate "$@"
    ;;
  sync)
    action_sync "$@"
    ;;
  list)
    action_list "$@"
    ;;
  run)
    action_run "$@"
    ;;
  history)
    action_history "$@"
    ;;
  *)
    usage
    die_user "Unknown action: ${ACTION:-<none>}"
    ;;
esac
