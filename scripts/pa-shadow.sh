#!/usr/bin/env bash
# Shadow vault sync — external cache directory
#
# Shadow location (checked in order):
#   1. PA_SHADOW_ROOT env var
#   2. settings.json "shadow_root" field
#   3. Fallback: ~/.cache/ouroboros/shadow/{vault-basename}
#
# Actions:
#   sync <vault-path> [--incremental] — create or refresh masked shadow copies
#   status [vault-path]               — show shadow vault status
#
# Usage:
#   bash scripts/pa-shadow.sh sync ~/obsidian/my-vault
#   bash scripts/pa-shadow.sh sync ~/obsidian/my-vault --incremental
#   bash scripts/pa-shadow.sh status
#   PA_VAULT_PATH=~/obsidian/my-vault bash scripts/pa-shadow.sh status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PA_MASK_SCRIPT="$SCRIPT_DIR/pa-mask.sh"

VAULT_PATH=""
SHADOW_DIR=""
NOTES_PROCESSED=0
PRIVATE_STUBS=0
REMOVED_COUNT=0

usage() {
  cat <<'EOF'
pa-shadow.sh <action> [args]

Actions:
  sync <vault-path> [--incremental]  — Create or refresh the shadow vault
  status [vault-path]                — Show shadow vault status
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

ensure_pa_mask_script() {
  [[ -f "$PA_MASK_SCRIPT" ]] || die_system "Required script not found: $PA_MASK_SCRIPT"
}

resolve_absolute_dir() {
  local path="$1"

  [[ -n "$path" ]] || die_user "vault path is required"
  [[ -d "$path" ]] || die_user "vault path is not a directory: $path"

  (
    cd "$path" && pwd -P
  ) || die_system "Failed to resolve vault path: $path"
}

resolve_sync_vault_path() {
  local path="${1:-}"

  [[ -n "$path" ]] || die_user "vault path required. Usage: pa-shadow.sh sync <vault-path> [--incremental]"
  resolve_absolute_dir "$path"
}

resolve_status_vault_path() {
  local path="${1:-}"

  if [[ -n "$path" ]]; then
    resolve_absolute_dir "$path"
    return
  fi

  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    resolve_absolute_dir "$PA_VAULT_PATH"
    return
  fi

  if [[ -d ".obsidian" || -d ".pa" ]]; then
    pwd -P
    return
  fi

  die_user "vault path required for status. Provide a path, set PA_VAULT_PATH, or run from the vault root."
}

generate_vault_id() {
  local vault_realpath="$1"
  local basename
  basename=$(basename "$vault_realpath")
  local hash
  hash=$(printf '%s' "$vault_realpath" | shasum -a 256 | cut -c1-8)
  printf '%s-%s\n' "$basename" "$hash"
}

resolve_shadow_dir() {
  local vault_path="$1"

  # 1. PA_SHADOW_ROOT env var
  if [[ -n "${PA_SHADOW_ROOT:-}" ]]; then
    printf '%s\n' "$PA_SHADOW_ROOT"
    return
  fi

  # 2. settings.json "shadow_root" field
  local settings_path="$vault_path/.pa/settings.json"
  if [[ -f "$settings_path" ]]; then
    local shadow_root
    shadow_root=$(jq -r '.shadow_root // empty' "$settings_path" 2>/dev/null || true)
    if [[ -n "$shadow_root" ]]; then
      # Expand ~ if present
      shadow_root="${shadow_root/#\~/$HOME}"
      printf '%s\n' "$shadow_root"
      return
    fi
  fi

  # 3. Fallback: ~/.cache/ouroboros/shadow/{vault-id}
  local vault_id
  vault_id=$(generate_vault_id "$vault_path")
  printf '%s/.cache/ouroboros/shadow/%s\n' "$HOME" "$vault_id"
}

set_vault_context() {
  VAULT_PATH="$1"
  SHADOW_DIR=$(resolve_shadow_dir "$VAULT_PATH")
}

iso_timestamp() {
  local ts
  ts=$(date "+%Y-%m-%dT%H:%M:%S%z")
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

mask_map_path() {
  printf '%s/.pa/mask-map.json\n' "$VAULT_PATH"
}

derivation_state_path() {
  printf '%s/.pa/derivation-state.json\n' "$VAULT_PATH"
}

ledger_path() {
  printf '%s/.pa/transmission-ledger.jsonl\n' "$VAULT_PATH"
}

shadow_relative_path() {
  local path="$1"

  printf '%s\n' "${path#"$VAULT_PATH"/}"
}

normalize_relative_note_path() {
  local path="$1"

  [[ -n "$path" ]] || return 1

  if [[ "$path" == "$VAULT_PATH" ]]; then
    return 1
  fi

  if [[ "$path" == "$VAULT_PATH/"* ]]; then
    path="${path#"$VAULT_PATH"/}"
  fi

  path="${path#./}"
  path="${path#/}"

  [[ -n "$path" ]] || return 1
  [[ "$path" == *.md ]] || return 1

  case "$path" in
    .obsidian/* | .trash/* | .git/* | .pa/*)
      return 1
      ;;
  esac

  printf '%s\n' "$path"
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

find_shadow_markdown_files() {
  [[ -d "$SHADOW_DIR" ]] || return 0

  find "$SHADOW_DIR" -type f -name '*.md' -print0
}

is_private_note() {
  local source_path="$1"

  if ! head -n 1 "$source_path" | grep -qx -- '---'; then
    return 1
  fi

  sed -n '2,/^---[[:space:]]*$/p' "$source_path" |
    grep -Eq '^[[:space:]]*private:[[:space:]]*true[[:space:]]*$'
}

write_private_stub() {
  local shadow_path="$1"

  printf '# [PRIVATE NOTE]\n\nThis note is marked as private and its content is not available.\n' >"$shadow_path"
}

mask_map_version() {
  local path
  path=$(mask_map_path)

  if [[ ! -f "$path" ]]; then
    printf '0\n'
    return
  fi

  validate_json "$path"
  jq -r '.version // 1' "$path"
}

append_sync_ledger() {
  local path
  path=$(ledger_path)

  mkdir -p "$(dirname "$path")"

  jq -nc \
    --arg ts "$(iso_timestamp)" \
    --arg action "shadow-sync" \
    --argjson notes_processed "$NOTES_PROCESSED" \
    --argjson private_stubs "$PRIVATE_STUBS" \
    --argjson mask_map_version "$(mask_map_version)" \
    '{
      ts: $ts,
      action: $action,
      notes_processed: $notes_processed,
      private_stubs: $private_stubs,
      mask_map_version: $mask_map_version
    }' >>"$path" || die_system "Failed to append transmission ledger: $path"
}

process_relative_note() {
  local relative_path="$1"
  local source_path="$VAULT_PATH/$relative_path"
  local shadow_path="$SHADOW_DIR/$relative_path"
  local tmp_file=""

  if [[ ! -f "$source_path" ]]; then
    if [[ -f "$shadow_path" ]]; then
      rm -f "$shadow_path"
      REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
    return
  fi

  mkdir -p "$(dirname "$shadow_path")"

  if is_private_note "$source_path"; then
    write_private_stub "$shadow_path"
    PRIVATE_STUBS=$((PRIVATE_STUBS + 1))
    NOTES_PROCESSED=$((NOTES_PROCESSED + 1))
    touch -r "$source_path" "$shadow_path" 2>/dev/null || true
    return
  fi

  tmp_file=$(mktemp)

  if ! PA_VAULT_PATH="$VAULT_PATH" bash "$PA_MASK_SCRIPT" --full <"$source_path" >"$tmp_file"; then
    rm -f "$tmp_file"
    die_system "Failed to mask note: $source_path"
  fi

  mv "$tmp_file" "$shadow_path"
  NOTES_PROCESSED=$((NOTES_PROCESSED + 1))
  touch -r "$source_path" "$shadow_path" 2>/dev/null || true
}

remove_orphaned_shadow_files() {
  local shadow_path=""
  local relative_path=""
  local source_path=""

  while IFS= read -r -d '' shadow_path; do
    relative_path="${shadow_path#"$SHADOW_DIR"/}"
    source_path="$VAULT_PATH/$relative_path"

    if [[ ! -f "$source_path" ]]; then
      rm -f "$shadow_path"
      REMOVED_COUNT=$((REMOVED_COUNT + 1))
    fi
  done < <(find_shadow_markdown_files)

  [[ -d "$SHADOW_DIR" ]] && find "$SHADOW_DIR" -depth -type d -empty -delete 2>/dev/null || true
}

sync_full() {
  local source_path=""
  local relative_path=""

  mkdir -p "$SHADOW_DIR"

  while IFS= read -r -d '' source_path; do
    relative_path=$(shadow_relative_path "$source_path")
    process_relative_note "$relative_path"
  done < <(find_vault_markdown_files)

  remove_orphaned_shadow_files
  append_sync_ledger

  printf 'Shadow vault synced: %s notes processed, %s private stubs, %s removed\n' "$NOTES_PROCESSED" "$PRIVATE_STUBS" "$REMOVED_COUNT"
}

dirty_paths_json() {
  local state_path
  state_path=$(derivation_state_path)

  jq -c '.dirty_paths // []' "$state_path"
}

collect_incremental_paths() {
  local state_path
  state_path=$(derivation_state_path)

  jq -r '
    (.dirty_paths // [])[]
    | if type == "string" then
        .
      elif type == "object" then
        (.path // empty)
      else
        empty
      end
  ' "$state_path"
}

clear_processed_dirty_paths() {
  local processed_list_path="$1"
  local state_path
  local tmp_file
  local processed_json

  state_path=$(derivation_state_path)
  tmp_file=$(mktemp)

  processed_json=$(jq -R . <"$processed_list_path" | jq -s .)

  # Statusful queue: mark shadow_status=synced instead of deleting entries.
  # Entries are only fully removed when all statuses (shadow + ontology) are complete.
  jq \
    --argjson processed "$processed_json" \
    '
      def dirty_path_value:
        if type == "string" then
          .
        elif type == "object" then
          (.path // null)
        else
          null
        end;

      .dirty_paths = (
        (.dirty_paths // [])
        | map(
            . as $entry
            | (dirty_path_value) as $path
            | if $path != null and ($processed | index($path)) then
                # Mark shadow as synced, preserve entry for ontology refresh
                if type == "object" then
                  .shadow_status = "synced"
                else
                  # Upgrade string entry to object
                  {path: ., event: "unknown", shadow_status: "synced", ontology_status: "pending"}
                end
              else
                .
              end
          )
      )
    ' "$state_path" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update dirty_paths in $state_path"
  }

  mv "$tmp_file" "$state_path"
}

# Remove dirty entries where all statuses are complete
cleanup_completed_dirty_paths() {
  local state_path
  local tmp_file

  state_path=$(derivation_state_path)
  tmp_file=$(mktemp)

  jq '
    .dirty_paths = (
      (.dirty_paths // [])
      | map(
          select(
            type == "string"
            or (type == "object" and (
              (.shadow_status // "pending") != "synced"
              or (.ontology_status // "pending") != "refreshed"
            ))
          )
        )
    )
  ' "$state_path" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to cleanup dirty_paths in $state_path"
  }

  mv "$tmp_file" "$state_path"
}

sync_incremental() {
  local state_path
  local dirty_json
  local candidate_path=""
  local relative_path=""
  local processed_tmp

  state_path=$(derivation_state_path)
  [[ -f "$state_path" ]] || die_user "derivation-state.json not found: $state_path"
  validate_json "$state_path"

  dirty_json=$(dirty_paths_json)
  if [[ "$dirty_json" == "[]" ]]; then
    echo "No dirty paths — shadow vault is up to date"
    return
  fi

  mkdir -p "$SHADOW_DIR"
  processed_tmp=$(mktemp)

  while IFS= read -r candidate_path; do
    [[ -n "$candidate_path" ]] || continue

    if ! relative_path=$(normalize_relative_note_path "$candidate_path"); then
      continue
    fi

    process_relative_note "$relative_path"
    printf '%s\n' "$candidate_path" >>"$processed_tmp"
  done < <(collect_incremental_paths)

  if [[ ! -s "$processed_tmp" ]]; then
    rm -f "$processed_tmp"
    echo "No dirty paths — shadow vault is up to date"
    return
  fi

  clear_processed_dirty_paths "$processed_tmp"
  rm -f "$processed_tmp"

  [[ -d "$SHADOW_DIR" ]] && find "$SHADOW_DIR" -depth -type d -empty -delete 2>/dev/null || true

  append_sync_ledger

  printf 'Shadow vault synced: %s notes processed, %s private stubs, %s removed\n' "$NOTES_PROCESSED" "$PRIVATE_STUBS" "$REMOVED_COUNT"
}

count_vault_files() {
  local count=0
  local source_path=""

  while IFS= read -r -d '' source_path; do
    count=$((count + 1))
  done < <(find_vault_markdown_files)

  printf '%s\n' "$count"
}

count_shadow_files() {
  local count=0
  local shadow_path=""

  while IFS= read -r -d '' shadow_path; do
    count=$((count + 1))
  done < <(find_shadow_markdown_files)

  printf '%s\n' "$count"
}

last_shadow_sync_timestamp() {
  local path
  path=$(ledger_path)

  if [[ ! -f "$path" ]]; then
    printf 'never\n'
    return
  fi

  jq -sr '
    map(select(.action == "shadow-sync"))
    | if length == 0 then "never" else .[-1].ts end
  ' "$path" || die_system "Failed to read transmission ledger: $path"
}

count_stale_shadow_files() {
  local count=0
  local shadow_path=""
  local relative_path=""
  local source_path=""

  while IFS= read -r -d '' shadow_path; do
    relative_path="${shadow_path#"$SHADOW_DIR"/}"
    source_path="$VAULT_PATH/$relative_path"

    if [[ -f "$source_path" && "$shadow_path" -ot "$source_path" ]]; then
      count=$((count + 1))
    fi
  done < <(find_shadow_markdown_files)

  printf '%s\n' "$count"
}

action_sync() {
  local vault_arg="${1:-}"
  local mode="${2:-}"

  if [[ -z "$vault_arg" ]]; then
    die_user "vault path required. Usage: pa-shadow.sh sync <vault-path> [--incremental]"
  fi

  if [[ -n "$mode" ]] && [[ "$mode" != "--incremental" ]]; then
    die_user "unknown sync option: $mode"
  fi

  if [[ $# -gt 2 ]]; then
    die_user "sync accepts only <vault-path> and optional --incremental"
  fi

  set_vault_context "$(resolve_sync_vault_path "$vault_arg")"

  ensure_jq
  ensure_pa_mask_script

  if [[ ! -f "$(mask_map_path)" ]]; then
    warn "mask-map.json not found in $VAULT_PATH/.pa/ — privacy will be incomplete"
  else
    validate_json "$(mask_map_path)"
  fi

  if [[ "$mode" == "--incremental" ]]; then
    sync_incremental
  else
    sync_full
  fi
}

action_status() {
  local vault_arg="${1:-}"
  local vault_files=0
  local shadow_files=0
  local last_sync=""
  local stale_files=0

  if [[ $# -gt 1 ]]; then
    die_user "status accepts at most one optional vault path"
  fi

  set_vault_context "$(resolve_status_vault_path "$vault_arg")"

  ensure_jq

  vault_files=$(count_vault_files)
  shadow_files=$(count_shadow_files)
  last_sync=$(last_shadow_sync_timestamp)
  stale_files=$(count_stale_shadow_files)

  printf 'Shadow directory: %s\n' "$SHADOW_DIR"
  if [[ -d "$SHADOW_DIR" ]]; then
    echo "Shadow exists: yes"
  else
    echo "Shadow exists: no"
  fi
  printf 'Files: %s shadow / %s vault\n' "$shadow_files" "$vault_files"
  printf 'Last sync: %s\n' "$last_sync"
  printf 'Stale files: %s\n' "$stale_files"
}

ACTION="${1:-}"

case "$ACTION" in
  sync)
    shift
    action_sync "$@"
    ;;
  status)
    shift
    action_status "$@"
    ;;
  help | --help | -h)
    usage
    ;;
  "")
    usage >&2
    exit 1
    ;;
  *)
    die_user "unknown action: $ACTION"
    ;;
esac
