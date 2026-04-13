#!/usr/bin/env bash
# pa-relationship.sh - relationship staleness and upcoming date checker for PA.
#
# Actions:
#   check [vault-path]
#   upcoming [--days N] [vault-path]

set -euo pipefail

DEFAULT_UPCOMING_DAYS=7

VAULT_PATH=""
PA_DIR=""
PEOPLE_PROFILES_DIR=""

STALE_ROWS=()
UPCOMING_ROWS=()

usage() {
  cat <<'EOF'
pa-relationship.sh <action> [args]

Actions:
  check [vault-path]                 - Output stale relationships and upcoming dates within 7 days
  upcoming [--days N] [vault-path]  - Output upcoming dates only within N days (default: 7)
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
  PEOPLE_PROFILES_DIR="$PA_DIR/people/profiles"
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die_user ".pa directory not found: $PA_DIR"
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

date_to_epoch() {
  local input="$1"
  local epoch=""

  [[ -n "$input" ]] || return 1

  epoch=$(date -j -f '%Y-%m-%d' "$input" '+%s' 2>/dev/null || true)
  if [[ -z "$epoch" ]]; then
    epoch=$(date -d "$input" '+%s' 2>/dev/null || true)
  fi

  [[ -n "$epoch" ]] || return 1
  printf '%s\n' "$epoch"
}

today_date() {
  date '+%Y-%m-%d'
}

today_epoch() {
  date_to_epoch "$(today_date)"
}

threshold_days_for_trust_level() {
  case "$1" in
    inner-circle)
      printf '30\n'
      ;;
    restricted)
      printf '90\n'
      ;;
    standard | *)
      printf '60\n'
      ;;
  esac
}

json_array_from_rows() {
  local mode="$1"
  shift
  local -a rows=("$@")

  if [[ "${#rows[@]}" -eq 0 ]]; then
    printf '[]\n'
    return
  fi

  case "$mode" in
    stale)
      printf '%s\n' "${rows[@]}" | jq -s 'sort_by(-.days_stale, .mask_id)'
      ;;
    upcoming)
      printf '%s\n' "${rows[@]}" | jq -s 'sort_by(.days_until, .mask_id, .label)'
      ;;
    *)
      die_system "Unknown row mode: $mode"
      ;;
  esac
}

record_stale_relationship() {
  local mask_id="$1"
  local relationship_type="$2"
  local last_interaction="$3"
  local days_stale="$4"

  STALE_ROWS+=("$(jq -nc \
    --arg mask_id "$mask_id" \
    --arg relationship_type "$relationship_type" \
    --arg last_interaction "$last_interaction" \
    --argjson days_stale "$days_stale" \
    '{
      mask_id: $mask_id,
      relationship_type: $relationship_type,
      last_interaction: $last_interaction,
      days_stale: $days_stale
    }')"
  )
}

record_upcoming_date() {
  local mask_id="$1"
  local label="$2"
  local date_value="$3"
  local days_until="$4"
  local notify="$5"

  UPCOMING_ROWS+=("$(jq -nc \
    --arg mask_id "$mask_id" \
    --arg label "$label" \
    --arg date "$date_value" \
    --argjson days_until "$days_until" \
    --argjson notify "$notify" \
    '{
      mask_id: $mask_id,
      label: $label,
      date: $date,
      days_until: $days_until,
      notify: $notify
    }')"
  )
}

scan_last_interaction() {
  local profile_path="$1"
  local mask_id="$2"
  local relationship_type="$3"
  local trust_level="$4"
  local last_interaction="$5"
  local threshold_days="0"
  local interaction_epoch=""
  local stale_days="0"
  local current_epoch="0"

  [[ -n "$last_interaction" ]] || return 0

  interaction_epoch="$(date_to_epoch "$last_interaction" 2>/dev/null || true)"
  [[ -n "$interaction_epoch" ]] || return

  threshold_days="$(threshold_days_for_trust_level "$trust_level")"
  current_epoch="$(today_epoch)"
  stale_days=$(( (current_epoch - interaction_epoch) / 86400 ))
  if [[ "$stale_days" -lt 0 ]]; then
    stale_days=0
  fi

  if [[ "$stale_days" -gt "$threshold_days" ]]; then
    record_stale_relationship "$mask_id" "$relationship_type" "$last_interaction" "$stale_days"
  fi
}

next_occurrence_epoch() {
  local date_value="$1"
  local candidate=""
  local epoch=""
  local current_year=""
  local current_epoch="0"

  current_year="$(date '+%Y')"
  current_epoch="$(today_epoch)"

  case "$date_value" in
    ????-??-??)
      epoch="$(date_to_epoch "$date_value" 2>/dev/null || true)"
      [[ -n "$epoch" ]] || return 1
      printf '%s\n' "$epoch"
      return
      ;;
    ??-??)
      candidate="${current_year}-${date_value}"
      epoch="$(date_to_epoch "$candidate" 2>/dev/null || true)"
      [[ -n "$epoch" ]] || return 1
      if [[ "$epoch" -lt "$current_epoch" ]]; then
        candidate="$((current_year + 1))-${date_value}"
        epoch="$(date_to_epoch "$candidate" 2>/dev/null || true)"
        [[ -n "$epoch" ]] || return 1
      fi
      printf '%s\n' "$epoch"
      return
      ;;
    *)
      return 1
      ;;
  esac
}

scan_profile_dates() {
  local profile_path="$1"
  local mask_id="$2"
  local days_limit="$3"
  local entry=""
  local label=""
  local date_value=""
  local notify="false"
  local event_epoch=""
  local remaining_days="0"
  local current_epoch="0"

  current_epoch="$(today_epoch)"

  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue

    label="$(printf '%s\n' "$entry" | jq -r '.label // "date"' 2>/dev/null || printf 'date')"
    date_value="$(printf '%s\n' "$entry" | jq -r '.date // empty' 2>/dev/null || true)"
    notify="$(printf '%s\n' "$entry" | jq -r 'if .notify == true then "true" else "false" end' 2>/dev/null || printf 'false')"
    [[ -n "$date_value" ]] || continue

    event_epoch="$(next_occurrence_epoch "$date_value" 2>/dev/null || true)"
    [[ -n "$event_epoch" ]] || continue

    remaining_days=$(( (event_epoch - current_epoch) / 86400 ))
    if [[ "$remaining_days" -lt 0 ]]; then
      continue
    fi

    if [[ "$remaining_days" -le "$days_limit" ]]; then
      record_upcoming_date "$mask_id" "$label" "$date_value" "$remaining_days" "$notify"
    fi
  done < <(jq -c '.dates // [] | if type == "array" then .[] else empty end' "$profile_path" 2>/dev/null || true)
}

scan_profiles() {
  local days_limit="$1"
  local profile_path=""
  local mask_id=""
  local relationship_type=""
  local trust_level=""
  local last_interaction=""

  STALE_ROWS=()
  UPCOMING_ROWS=()

  [[ -d "$PEOPLE_PROFILES_DIR" ]] || return 0

  shopt -s nullglob
  for profile_path in "$PEOPLE_PROFILES_DIR"/*.json; do
    jq empty "$profile_path" >/dev/null 2>&1 || die_system "Failed to parse JSON: $profile_path"

    mask_id="$(jq -r '.mask_id // empty' "$profile_path" 2>/dev/null || true)"
    relationship_type="$(jq -r '.relationship_type // "other"' "$profile_path" 2>/dev/null || printf 'other')"
    trust_level="$(jq -r '.trust_level // "standard"' "$profile_path" 2>/dev/null || printf 'standard')"
    last_interaction="$(jq -r '.last_interaction // empty' "$profile_path" 2>/dev/null || true)"

    [[ -n "$mask_id" ]] || continue

    scan_last_interaction "$profile_path" "$mask_id" "$relationship_type" "$trust_level" "$last_interaction"
    scan_profile_dates "$profile_path" "$mask_id" "$days_limit"
  done
  shopt -u nullglob
}

build_check_json() {
  local days_limit="$1"
  local checked_at=""
  local stale_json=""
  local upcoming_json=""

  scan_profiles "$days_limit"
  checked_at="$(iso_timestamp)"
  stale_json="$(json_array_from_rows stale "${STALE_ROWS[@]}")"
  upcoming_json="$(json_array_from_rows upcoming "${UPCOMING_ROWS[@]}")"

  jq -n \
    --arg checked_at "$checked_at" \
    --argjson stale_relationships "$stale_json" \
    --argjson upcoming_dates "$upcoming_json" \
    '{
      checked_at: $checked_at,
      stale_relationships: $stale_relationships,
      upcoming_dates: $upcoming_dates
    }'
}

action_check() {
  [[ $# -le 1 ]] || die_user "Usage: pa-relationship.sh check [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root
  build_check_json "$DEFAULT_UPCOMING_DAYS"
}

action_upcoming() {
  local days="$DEFAULT_UPCOMING_DAYS"
  local explicit_path=""
  local output_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days)
        shift
        [[ $# -gt 0 ]] || die_user "Usage: pa-relationship.sh upcoming [--days N] [vault-path]"
        [[ "$1" =~ ^[0-9]+$ ]] || die_user "--days requires a non-negative integer"
        days="$1"
        shift
        ;;
      --days=*)
        days="${1#--days=}"
        [[ "$days" =~ ^[0-9]+$ ]] || die_user "--days requires a non-negative integer"
        shift
        ;;
      *)
        [[ -z "$explicit_path" ]] || die_user "Usage: pa-relationship.sh upcoming [--days N] [vault-path]"
        explicit_path="$1"
        shift
        ;;
    esac
  done

  ensure_jq
  set_vault_context "$(resolve_vault_path "$explicit_path")"
  ensure_pa_root

  output_json="$(build_check_json "$days")"
  printf '%s\n' "$output_json" | jq '{checked_at, upcoming_dates}'
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  check)
    action_check "$@"
    ;;
  upcoming)
    action_upcoming "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die_user "Unknown action: $ACTION"
    ;;
esac
