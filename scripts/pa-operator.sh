#!/usr/bin/env bash
# pa-operator.sh - deterministic vault operation wrapper for PA commands.

set -euo pipefail

VAULT_PATH="${PA_VAULT_PATH:-}"
FORMAT=""
FORMAT_SET=0
PROP_BACKEND=""
usage() {
  cat >&2 <<'EOF'
pa-operator.sh - deterministic PA vault operator

Usage:
  pa-operator.sh [--format json|text] detect
  pa-operator.sh [--format json|text] status
  pa-operator.sh [--format json|text] create <path> [--template <name>]
  pa-operator.sh [--format json|text] move <source> <target>
  pa-operator.sh [--format json|text] property <path> <get|set|delete> <key> [value]
  pa-operator.sh [--format json|text] sync [--direction pull|push]

Environment:
  PA_VAULT_PATH      Vault root for relative paths and ob --path routing.
EOF
}

log() { printf '[pa-operator] %s\n' "$*" >&2; }
die() { log "Error: $*"; exit 1; }
die_usage() { log "Error: $*"; usage; exit 1; }

json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g'; }
json_string() { printf '"%s"' "$(json_escape "$1")"; }
json_string_or_null() { [ -n "${1:-}" ] && json_string "$1" || printf 'null'; }
json_bool() { [ "$1" -eq 1 ] && printf 'true' || printf 'false'; }
fallback_caps() { printf '["create","move","property:get","property:set","property:delete","sync:no-op"]'; }
have_ob() { command -v ob >/dev/null 2>&1; }
ob_has_cap() { have_ob && ob_caps | grep -q "\"$1\""; }
ob_caps() {
  local help="" cap="" sep=""
  set +e; help="$(ob --help 2>&1)"; set -e
  printf '['
  for cap in sync create move properties search daily tasks; do
    if printf '%s\n' "$help" | grep -Eq "^[[:space:]]*$cap([-[:space:]]|$)"; then
      printf '%s"%s"' "$sep" "$cap"; sep=","
    fi
  done
  printf ']'
}

ob_version() {
  local out="" rc=1
  have_ob || return 0
  set +e
  out="$(ob --version 2>/dev/null)"
  rc=$?
  [ "$rc" -eq 0 ] && [ -n "$out" ] || { out="$(ob version 2>/dev/null)"; rc=$?; }
  set -e
  [ "$rc" -eq 0 ] && [ -n "$out" ] && printf '%s\n' "$out" | head -n 1 | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

validate_format() {
  case "$1" in
    json|text) ;;
    *) die_usage "Unknown format: $1" ;;
  esac
}

default_format() {
  [ "$FORMAT_SET" -eq 1 ] && return 0
  case "$1" in
    detect|status) FORMAT="json" ;;
    *) FORMAT="text" ;;
  esac
}

parse_global_flags() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --format)
        [ $# -ge 2 ] || die_usage "--format requires a value."
        FORMAT="$2"; FORMAT_SET=1; validate_format "$FORMAT"; shift 2
        ;;
      -h|--help) usage; exit 0 ;;
      *) break ;;
    esac
  done
  GLOBAL_SHIFTED=$((ORIGINAL_ARGC - $#))
}

parse_format_tail() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --format)
        [ $# -ge 2 ] || die_usage "--format requires a value."
        FORMAT="$2"; FORMAT_SET=1; validate_format "$FORMAT"; shift 2
        ;;
      *) die_usage "Unknown option: $1" ;;
    esac
  done
}

resolve_path() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) [ -n "$VAULT_PATH" ] && printf '%s/%s\n' "${VAULT_PATH%/}" "$1" || printf '%s\n' "$1" ;;
  esac
}

ob_note_arg() {
  local raw="$1" resolved=""
  resolved="$(resolve_path "$raw")"
  if [ -n "$VAULT_PATH" ]; then
    case "$resolved" in
      "$VAULT_PATH"/*) printf '%s\n' "${resolved#"$VAULT_PATH"/}"; return 0 ;;
    esac
  fi
  printf '%s\n' "$raw"
}

ensure_parent_dir() {
  local parent=""
  parent="$(dirname "$1")"
  [ -d "$parent" ] || mkdir -p "$parent"
}

run_ob() {
  if [ -n "$VAULT_PATH" ]; then
    ob "$@" --path "$VAULT_PATH"
  else
    ob "$@"
  fi
}

try_ob() {
  local rc=0
  set +e
  run_ob "$@"
  rc=$?
  set -e
  return "$rc"
}

result_line() {
  local action="$1" backend="$2" path="$3" detail="$4"
  if [ "$FORMAT" = "json" ]; then
    printf '{"ok":true,"action":"%s","backend":"%s","path":"%s","detail":"%s"}\n' \
      "$(json_escape "$action")" "$(json_escape "$backend")" "$(json_escape "$path")" "$(json_escape "$detail")"
  else
    printf '%s: %s (%s)\n' "$detail" "$path" "$backend"
  fi
}

render_detect() {
  local available=0 version=""
  parse_format_tail "$@"
  if have_ob; then available=1; version="$(ob_version)"; fi
  if [ "$FORMAT" = "json" ]; then
    printf '{"available":%s,"version":%s,"capabilities":' "$(json_bool "$available")" "$(json_string_or_null "$version")"
    [ "$available" -eq 1 ] && ob_caps || printf '[]'
    printf '}\n'
  elif [ "$available" -eq 1 ]; then
    printf 'ob available: yes\nversion: %s\ncapabilities: ' "${version:-unknown}"
    ob_caps; printf '\n'
  else
    printf 'ob available: no\n'
  fi
}

render_status() {
  local available=0 version=""
  parse_format_tail "$@"
  if have_ob; then available=1; version="$(ob_version)"; fi
  if [ "$FORMAT" = "json" ]; then
    printf '{"vault_path":%s,"ob":{"available":%s,"version":%s,"capabilities":' \
      "$(json_string_or_null "$VAULT_PATH")" "$(json_bool "$available")" "$(json_string_or_null "$version")"
    [ "$available" -eq 1 ] && ob_caps || printf '[]'
    printf '},"fallback":{"available":true,"capabilities":'
    fallback_caps
    printf '}}\n'
  else
    printf 'vault: %s\n' "${VAULT_PATH:-current working directory}"
    [ "$available" -eq 1 ] && printf 'ob: available (%s)\n' "${version:-unknown}" || printf 'ob: unavailable\n'
    printf 'fallback: create, move, property get/set/delete, sync no-op\n'
  fi
}

action_create() {
  local note="${1:-}" template="" path="" ob_arg="" backend="filesystem"
  [ -n "$note" ] || die_usage "create requires <path>."
  shift || true
  while [ $# -gt 0 ]; do
    case "$1" in
      --template) [ $# -ge 2 ] || die_usage "--template requires a value."; template="$2"; shift 2 ;;
      --format) [ $# -ge 2 ] || die_usage "--format requires a value."; FORMAT="$2"; FORMAT_SET=1; validate_format "$FORMAT"; shift 2 ;;
      *) die_usage "Unknown create option: $1" ;;
    esac
  done
  path="$(resolve_path "$note")"
  ensure_parent_dir "$path"
  if [ -e "$path" ]; then result_line "create" "filesystem" "$path" "Note already exists"; return 0; fi
  ob_arg="$(ob_note_arg "$note")"
  if ob_has_cap create; then
    log "create via ob: $ob_arg"
    if [ -n "$template" ]; then
      if try_ob create "$ob_arg" --template "$template" >/dev/null; then backend="ob"; else log "ob create failed; falling back to filesystem create."; fi
    else
      if try_ob create "$ob_arg" >/dev/null; then backend="ob"; else log "ob create failed; falling back to filesystem create."; fi
    fi
  fi
  if [ "$backend" = "filesystem" ]; then
    [ -n "$template" ] && log "filesystem create fallback does not apply template: $template"
    : >"$path"
  fi
  result_line "create" "$backend" "$path" "Created note"
}

action_move() {
  local source_arg="${1:-}" target_arg="${2:-}" source="" target="" ob_source="" ob_target="" backend="filesystem" detail="Moved note"
  [ -n "$source_arg" ] || die_usage "move requires <source>."
  [ -n "$target_arg" ] || die_usage "move requires <target>."
  shift 2 || true
  parse_format_tail "$@"
  source="$(resolve_path "$source_arg")"
  target="$(resolve_path "$target_arg")"
  [ -f "$source" ] || die "source note not found: $source"
  [ ! -e "$target" ] || die "target already exists: $target"
  ensure_parent_dir "$target"
  ob_source="$(ob_note_arg "$source_arg")"
  ob_target="$(ob_note_arg "$target_arg")"
  if ob_has_cap move; then
    log "move via ob: $ob_source -> $ob_target"
    if try_ob move "$ob_source" "$ob_target" >/dev/null; then backend="ob"; else log "ob move failed; falling back to filesystem move."; fi
  fi
  if [ "$backend" = "filesystem" ]; then
    mv "$source" "$target"
    detail="Moved note; WARNING wikilinks not updated"
    log "WARNING: filesystem move fallback did not update wikilinks."
  fi
  result_line "move" "$backend" "$target" "$detail"
}

fm_status() {
  awk 'NR==1&&$0!="---"{exit 1} NR==1{seen=1;next} seen&&$0=="---"{found=1;exit 0} END{if(seen&&!found)exit 2}' "$1"
}

split_md() {
  local file="$1" fm="$2" body="$3"
  : >"$fm"; : >"$body"
  awk -v fm="$fm" -v body="$body" 'NR==1&&$0=="---"{infm=1;next} NR==1{print>body;next} infm&&$0=="---"{infm=0;next} infm{print>fm;next} {print>body}' "$file"
}

write_md() {
  local file="$1" fm="$2" body="$3" tmp=""
  tmp="$(mktemp)"
  { printf '%s\n' '---'; sed '/^[[:space:]]*{}[[:space:]]*$/d; /^[[:space:]]*null[[:space:]]*$/d' "$fm"; printf '%s\n' '---'; cat "$body"; } >"$tmp"
  mv "$tmp" "$file"
}

prop_get_sed() {
  awk -v key="$2" 'NR==1&&$0!="---"{exit 1} NR==1{infm=1;next} infm&&$0=="---"{exit 1} infm{f=$0;sub(/:.*/,"",f);gsub(/^[ \t]+|[ \t]+$/,"",f);if(f==key){v=$0;sub(/^[^:]*:[ \t]*/,"",v);print v;found=1;exit 0}} END{if(!found)exit 1}' "$1"
}

prop_set_sed() {
  local file="$1" key="$2" value="$3" tmp=""
  if [ ! -s "$file" ]; then { printf '%s\n' '---'; printf '%s: %s\n' "$key" "$value"; printf '%s\n' '---'; } >"$file"; return 0; fi
  tmp="$(mktemp)"
  awk -v key="$key" -v value="$value" 'NR==1&&$0!="---"{print "---";print key ": " value;print "---";print;next} NR==1{print;infm=1;next} infm&&$0=="---"{if(!w)print key ": " value;print;infm=0;next} infm{f=$0;sub(/:.*/,"",f);gsub(/^[ \t]+|[ \t]+$/,"",f);if(f==key){if(!w)print key ": " value;w=1;next}} {print}' "$file" >"$tmp"
  mv "$tmp" "$file"
}

prop_delete_sed() {
  local file="$1" key="$2" tmp=""
  tmp="$(mktemp)"
  awk -v key="$key" 'NR==1&&$0!="---"{print;next} NR==1{print;infm=1;next} infm&&$0=="---"{print;infm=0;next} infm{f=$0;sub(/:.*/,"",f);gsub(/^[ \t]+|[ \t]+$/,"",f);if(f==key){deleted=1;next}} {print} END{if(!deleted)exit 1}' "$file" >"$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file"
}

prop_yq() {
  local file="$1" op="$2" key="$3" value="${4:-}" dir="" fm="" body="" out="" result=""
  command -v yq >/dev/null 2>&1 || return 127
  fm_status "$file" || [ "$?" -eq 1 ] || die "malformed frontmatter: $file"
  dir="$(mktemp -d)"; fm="$dir/fm.yml"; body="$dir/body.md"; out="$dir/out.yml"
  split_md "$file" "$fm" "$body"
  [ -s "$fm" ] || printf '{}\n' >"$fm"
  case "$op" in
    get)
      yq -e "has(\"$key\")" "$fm" >/dev/null 2>&1 || { rm -rf "$dir"; return 1; }
      result="$(yq -r ".\"$key\"" "$fm")" || { rm -rf "$dir"; return 1; }
      printf '%s\n' "$result"
      ;;
    set)
      PROPERTY_VALUE="$value" yq ".\"$key\" = strenv(PROPERTY_VALUE)" "$fm" >"$out" || { rm -rf "$dir"; return 1; }
      mv "$out" "$fm"; write_md "$file" "$fm" "$body"
      ;;
    delete)
      yq -e "has(\"$key\")" "$fm" >/dev/null 2>&1 || { rm -rf "$dir"; return 1; }
      yq "del(.\"$key\")" "$fm" >"$out" || { rm -rf "$dir"; return 1; }
      mv "$out" "$fm"; write_md "$file" "$fm" "$body"
      ;;
  esac
  rm -rf "$dir"
}

prop_fs() {
  local file="$1" op="$2" key="$3" value="${4:-}"
  if prop_yq "$file" "$op" "$key" "$value"; then PROP_BACKEND="yq"; return 0; fi
  PROP_BACKEND="sed"
  case "$op" in
    get) prop_get_sed "$file" "$key" ;;
    set) fm_status "$file" || [ "$?" -eq 1 ] || die "malformed frontmatter: $file"; prop_set_sed "$file" "$key" "$value" ;;
    delete) fm_status "$file" || [ "$?" -eq 1 ] || die "malformed frontmatter: $file"; prop_delete_sed "$file" "$key" ;;
  esac
}

action_property() {
  local note="${1:-}" op="${2:-}" key="${3:-}" value="" path="" ob_arg="" backend="filesystem" result="" result_file=""
  [ -n "$note" ] || die_usage "property requires <path>."
  [ -n "$op" ] || die_usage "property requires <action>."
  [ -n "$key" ] || die_usage "property requires <key>."
  case "$op" in get|set|delete) ;; *) die_usage "property action must be get, set, or delete." ;; esac
  case "$key" in *[!A-Za-z0-9_-]*|"") die_usage "property key must use only letters, numbers, underscore, and hyphen: $key" ;; esac
  shift 3 || true
  if [ "$op" = "set" ]; then [ $# -ge 1 ] || die_usage "property set requires <value>."; value="$1"; shift || true; fi
  parse_format_tail "$@"
  path="$(resolve_path "$note")"
  [ -f "$path" ] || die "note not found: $path"
  ob_arg="$(ob_note_arg "$note")"
  if ob_has_cap properties; then
    log "property via ob: $op $key on $ob_arg"
    if [ "$op" = "set" ]; then
      if try_ob properties "$ob_arg" "$op" "$key" "$value" >/dev/null; then backend="ob"; else log "ob properties failed; falling back to frontmatter edit."; fi
    else
      if result="$(try_ob properties "$ob_arg" "$op" "$key")"; then backend="ob"; else log "ob properties failed; falling back to frontmatter edit."; fi
    fi
  fi
  if [ "$backend" = "filesystem" ]; then
    result_file="$(mktemp)"
    if prop_fs "$path" "$op" "$key" "$value" >"$result_file"; then
      result="$(cat "$result_file")"
      rm -f "$result_file"
    else
      rm -f "$result_file"
      die "property $op failed for $key in $path"
    fi
    backend="$PROP_BACKEND"
  fi
  if [ "$FORMAT" = "json" ]; then
    printf '{"ok":true,"action":"property","operation":"%s","backend":"%s","path":"%s","key":"%s","value":%s}\n' \
      "$(json_escape "$op")" "$(json_escape "$backend")" "$(json_escape "$path")" "$(json_escape "$key")" "$(json_string "$result")"
  else
    case "$op" in
      get) printf '%s: %s (%s)\n' "$key" "$result" "$backend" ;;
      set) printf 'Set %s on %s (%s)\n' "$key" "$path" "$backend" ;;
      delete) printf 'Deleted %s from %s (%s)\n' "$key" "$path" "$backend" ;;
    esac
  fi
}

action_sync() {
  local direction=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --direction) [ $# -ge 2 ] || die_usage "--direction requires pull or push."; direction="$2"; case "$direction" in pull|push) ;; *) die_usage "--direction must be pull or push." ;; esac; shift 2 ;;
      --format) [ $# -ge 2 ] || die_usage "--format requires a value."; FORMAT="$2"; FORMAT_SET=1; validate_format "$FORMAT"; shift 2 ;;
      *) die_usage "Unknown sync option: $1" ;;
    esac
  done
  if ! ob_has_cap sync; then
    log "ob unavailable; sync is a no-op."
    [ "$FORMAT" = "json" ] && printf '{"ok":true,"action":"sync","backend":"none","status":"noop","reason":"ob unavailable"}\n' || printf 'Sync skipped: ob unavailable.\n'
    return 0
  fi
  log "sync via ob${direction:+ ($direction)}"
  if [ -n "$direction" ]; then
    try_ob sync --direction "$direction" >/dev/null || die "ob sync failed."
  else
    try_ob sync >/dev/null || die "ob sync failed."
  fi
  [ "$FORMAT" = "json" ] && printf '{"ok":true,"action":"sync","backend":"ob","direction":%s}\n' "$(json_string_or_null "$direction")" || printf 'Sync complete%s (ob)\n' "${direction:+: $direction}"
}

ORIGINAL_ARGC=$#
GLOBAL_SHIFTED=0
parse_global_flags "$@"
shift "$GLOBAL_SHIFTED"
ACTION="${1:-}"
[ -n "$ACTION" ] || die_usage "Missing action."
shift || true
default_format "$ACTION"

case "$ACTION" in
  detect) render_detect "$@" ;;
  status) render_status "$@" ;;
  create) action_create "$@" ;;
  move) action_move "$@" ;;
  property) action_property "$@" ;;
  sync) action_sync "$@" ;;
  -h|--help) usage ;;
  *) die_usage "Unknown action: $ACTION" ;;
esac
