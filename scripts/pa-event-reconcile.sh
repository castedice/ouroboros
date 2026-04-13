#!/usr/bin/env bash
# pa-event-reconcile.sh - deferred vault event detection for PA.
#
# Actions:
#   reconcile
#   status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PA_SHADOW_SCRIPT="$SCRIPT_DIR/pa-shadow.sh"

VAULT_PATH=""
PA_DIR=""
SETTINGS_PATH=""
DERIVATION_STATE_PATH=""
EVENT_INDEX_PATH=""

usage() {
  cat <<'EOF'
pa-event-reconcile.sh <action>

Actions:
  reconcile
  status
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

warn() {
  echo "Warning: $1" >&2
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
  DERIVATION_STATE_PATH="$PA_DIR/derivation-state.json"
  EVENT_INDEX_PATH="$PA_DIR/event-index.json"
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die_user ".pa directory not found: $PA_DIR"
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

write_default_event_index() {
  mkdir -p "$PA_DIR" || die_system "Failed to create PA directory: $PA_DIR"
  cat >"$EVENT_INDEX_PATH" <<'EOF'
{
  "version": 1,
  "last_scan": null,
  "notes": {}
}
EOF
}

ensure_event_index_initialized() {
  if [[ -f "$EVENT_INDEX_PATH" ]]; then
    validate_json "$EVENT_INDEX_PATH"
    return
  fi

  write_default_event_index
}

write_default_derivation_state() {
  mkdir -p "$PA_DIR" || die_system "Failed to create PA directory: $PA_DIR"
  cat >"$DERIVATION_STATE_PATH" <<'EOF'
{
  "version": 1,
  "dirty_paths": []
}
EOF
}

ensure_derivation_state_initialized() {
  if [[ -f "$DERIVATION_STATE_PATH" ]]; then
    validate_json "$DERIVATION_STATE_PATH"
    return
  fi

  write_default_derivation_state
}

find_vault_markdown_files() {
  find "$VAULT_PATH" \
    \( \
    -path "$VAULT_PATH/.obsidian" -o \
    -path "$VAULT_PATH/.trash" -o \
    -path "$VAULT_PATH/.git" -o \
    -path "$VAULT_PATH/.pa" \
    \) -prune -o \
    -type f -name '*.md' -print0
}

relative_note_path() {
  local absolute_path="$1"

  printf '%s\n' "${absolute_path#"$VAULT_PATH"/}"
}

file_mtime() {
  local path="$1"
  local value=""

  value="$(stat -f '%m' "$path" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    value="$(stat -c '%Y' "$path" 2>/dev/null || true)"
  fi
  [[ -n "$value" ]] || die_system "Failed to read mtime: $path"
  printf '%s\n' "$value"
}

file_size() {
  local path="$1"
  local value=""

  value="$(stat -f '%z' "$path" 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    value="$(stat -c '%s' "$path" 2>/dev/null || true)"
  fi
  [[ -n "$value" ]] || die_system "Failed to read size: $path"
  printf '%s\n' "$value"
}

content_hash() {
  local path="$1"

  shasum -a 256 "$path" | cut -c1-8
}

build_current_notes_json() {
  local tmp_entries=""
  local source_path=""
  local relative_path=""
  local mtime=""
  local size=""
  local hash=""

  tmp_entries="$(mktemp)"

  while IFS= read -r -d '' source_path; do
    relative_path="$(relative_note_path "$source_path")"
    mtime="$(file_mtime "$source_path")"
    size="$(file_size "$source_path")"
    hash="$(content_hash "$source_path")"

    jq -nc \
      --arg path "$relative_path" \
      --argjson mtime "$mtime" \
      --argjson size "$size" \
      --arg content_hash "$hash" \
      '{path: $path, mtime: $mtime, size: $size, content_hash: $content_hash}' >>"$tmp_entries" || {
      rm -f "$tmp_entries"
      die_system "Failed to build event index entries"
    }
  done < <(find_vault_markdown_files)

  if [[ -s "$tmp_entries" ]]; then
    jq -s '
      map({(.path): {mtime: .mtime, size: .size, content_hash: .content_hash}})
      | add
    ' "$tmp_entries"
  else
    printf '{}\n'
  fi

  rm -f "$tmp_entries"
}

build_changes_json() {
  local snapshot_notes_path="$1"
  local current_notes_path="$2"
  local queued_at="$3"

  jq -n \
    --slurpfile old "$snapshot_notes_path" \
    --slurpfile new "$current_notes_path" \
    --arg queued_at "$queued_at" \
    '
      ($old[0] // {}) as $old_notes
      | ($new[0] // {}) as $new_notes
      |
      def event(path; kind; hash):
        {
          path: path,
          event: kind,
          content_hash: hash,
          queued_at: $queued_at,
          shadow_status: "pending",
          ontology_status: "pending"
        };

      {
        created: (
          $new_notes
          | to_entries
          | map(select(($old_notes[.key] | type) == "null"))
          | map(event(.key; "create"; (.value.content_hash // "")))
        ),
        modified: (
          $new_notes
          | to_entries
          | map(
              select(($old_notes[.key] | type) == "object")
              | select(
                  (
                    (.value.mtime != $old_notes[.key].mtime)
                    or (.value.size != $old_notes[.key].size)
                  )
                  and (.value.content_hash != $old_notes[.key].content_hash)
                )
              | event(.key; "modify"; (.value.content_hash // ""))
            )
        ),
        deleted: (
          $old_notes
          | to_entries
          | map(select(($new_notes[.key] | type) == "null"))
          | map(event(.key; "delete"; (.value.content_hash // "")))
        )
      }
      | .all = (.created + .modified + .deleted)
    '
}

update_derivation_state() {
  local changes_json_path="$1"
  local timestamp="$2"
  local total=""
  local tmp_file=""

  total="$(jq '.all | length' "$changes_json_path")"
  tmp_file="$(mktemp)"

  jq \
    --slurpfile changes "$changes_json_path" \
    --arg timestamp "$timestamp" \
    --argjson total "$total" \
    '
      .version = (.version // 1)
      | .dirty_paths = ((if (.dirty_paths | type) == "array" then .dirty_paths else [] end) + (($changes[0].all) // []))
      | .last_event_reconcile = {
          timestamp: $timestamp,
          source: "reconcile",
          changed_paths: $total
        }
    ' "$DERIVATION_STATE_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update derivation state: $DERIVATION_STATE_PATH"
  }

  mv "$tmp_file" "$DERIVATION_STATE_PATH"
}

write_event_index() {
  local current_notes_path="$1"
  local timestamp="$2"
  local tmp_file=""

  tmp_file="$(mktemp)"

  jq -n \
    --arg timestamp "$timestamp" \
    --slurpfile notes "$current_notes_path" \
    '{
      version: 1,
      last_scan: $timestamp,
      notes: ($notes[0] // {})
    }' >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to build event index"
  }

  mv "$tmp_file" "$EVENT_INDEX_PATH"
}

shadow_is_configured() {
  if [[ -n "${PA_SHADOW_ROOT:-}" ]]; then
    return 0
  fi

  [[ -f "$SETTINGS_PATH" ]] || return 1
  jq empty "$SETTINGS_PATH" >/dev/null 2>&1 || return 1
  [[ "$(jq -r 'if (.shadow_root // "") != "" then "true" else "false" end' "$SETTINGS_PATH" 2>/dev/null || printf 'false')" == "true" ]]
}

pending_dirty_paths_count() {
  [[ -f "$DERIVATION_STATE_PATH" ]] || {
    printf '0\n'
    return
  }

  jq '
    (.dirty_paths // [])
    | map(
        if type == "string" then
          .
        elif type == "object" and (
          (.shadow_status // "pending") != "synced"
          or (.ontology_status // "pending") != "refreshed"
        ) then
          .
        else
          empty
        end
      )
    | length
  ' "$DERIVATION_STATE_PATH" 2>/dev/null || printf '0\n'
}

action_reconcile() {
  local timestamp=""
  local snapshot_notes_path=""
  local current_notes_path=""
  local changes_json_path=""
  local created=0
  local modified=0
  local deleted=0
  local total=0

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  ensure_event_index_initialized
  ensure_derivation_state_initialized

  timestamp="$(iso_timestamp)"
  snapshot_notes_path="$(mktemp)"
  current_notes_path="$(mktemp)"
  changes_json_path="$(mktemp)"

  jq '.notes // {}' "$EVENT_INDEX_PATH" >"$snapshot_notes_path" || {
    rm -f "$snapshot_notes_path" "$current_notes_path" "$changes_json_path"
    die_system "Failed to read event index notes: $EVENT_INDEX_PATH"
  }
  build_current_notes_json >"$current_notes_path"
  build_changes_json "$snapshot_notes_path" "$current_notes_path" "$timestamp" >"$changes_json_path"

  created="$(jq '.created | length' "$changes_json_path")"
  modified="$(jq '.modified | length' "$changes_json_path")"
  deleted="$(jq '.deleted | length' "$changes_json_path")"
  total="$(jq '.all | length' "$changes_json_path")"

  update_derivation_state "$changes_json_path" "$timestamp"
  write_event_index "$current_notes_path" "$timestamp"

  if [[ "$total" -gt 0 ]] && [[ -f "$PA_SHADOW_SCRIPT" ]] && shadow_is_configured; then
    if ! bash "$PA_SHADOW_SCRIPT" sync "$VAULT_PATH" --incremental >/dev/null; then
      warn "Dirty paths were queued, but pa-shadow incremental sync failed."
    fi
  fi

  rm -f "$snapshot_notes_path" "$current_notes_path" "$changes_json_path"

  printf '%s created, %s modified, %s deleted, %s dirty paths queued\n' "$created" "$modified" "$deleted" "$total"
}

action_status() {
  local last_scan=""
  local snapshot_size="0"
  local pending_count="0"

  ensure_jq
  set_vault_context "$(resolve_vault_path "")"
  ensure_pa_root
  ensure_event_index_initialized

  last_scan="$(jq -r '.last_scan // "never"' "$EVENT_INDEX_PATH")"
  snapshot_size="$(jq '.notes | length' "$EVENT_INDEX_PATH")"
  pending_count="$(pending_dirty_paths_count)"

  printf 'Last reconcile: %s\n' "$last_scan"
  printf 'Snapshot notes: %s\n' "$snapshot_size"
  printf 'Pending dirty paths: %s\n' "$pending_count"
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  reconcile)
    action_reconcile "$@"
    ;;
  status)
    action_status "$@"
    ;;
  *)
    usage
    die_user "Unknown action: ${ACTION:-<none>}"
    ;;
esac
