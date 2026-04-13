#!/usr/bin/env bash
# PA schema migration harness.
#
# Transforms must remain additive so pre-migration files stay readable.
#
# Actions:
#   dry-run <version>   - Analyze the migration plan without modifying .pa/
#   snapshot            - Create a timestamped .pa snapshot in .pa/.snapshots/
#   apply <version>     - Snapshot, run registered transforms, and update schema_version
#   rollback [snapshot] - Restore .pa/ from the latest or specified snapshot

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=scripts/learning-lib.sh
source "$SCRIPT_DIR/learning-lib.sh"

VAULT_ROOT="${PA_VAULT_PATH:-$(pwd -P)}"
PA_DIR="$VAULT_ROOT/.pa"
SETTINGS_PATH="$PA_DIR/settings.json"
SNAPSHOT_DIR="$PA_DIR/.snapshots"

declare -A VERSION_TRANSFORMS=(
  ["2.4.0"]="transform_2_4_0"
)

declare -A PLANNED_FILE_REASONS=()
declare -a PLANNED_TRANSFORMS=()
declare -a PLANNED_NOTES=()

usage() {
  cat <<'EOF'
pa-migrate.sh <action> [args]

Actions:
  dry-run <version>      Analyze the migration plan without modifying .pa/
  snapshot               Create a timestamped .pa snapshot
  apply <version>        Snapshot, run transforms, and update schema_version
  rollback [snapshot]    Restore the latest or specified snapshot
EOF
}

die() {
  echo "Error: $1" >&2
  exit 1
}

warn() {
  echo "Warning: $1" >&2
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die "Missing .pa/ directory at $PA_DIR"
}

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die "jq is required."
}

ensure_tar() {
  command -v tar >/dev/null 2>&1 || die "tar is required."
}

validate_settings_json() {
  if [[ -f "$SETTINGS_PATH" ]]; then
    jq empty "$SETTINGS_PATH" >/dev/null 2>&1 || die "Malformed JSON in $SETTINGS_PATH"
  fi
}

snapshot_timestamp() {
  learning_timestamp_utc | sed -E 's/[-:]//g; s/T/-/; s/Z$//'
}

snapshot_path_for_timestamp() {
  local ts="${1:?Missing snapshot timestamp}"
  printf '%s/pa-snapshot-%s.tar.gz\n' "$SNAPSHOT_DIR" "$ts"
}

latest_snapshot_path() {
  [[ -d "$SNAPSHOT_DIR" ]] || return 1

  find "$SNAPSHOT_DIR" -maxdepth 1 -type f -name 'pa-snapshot-*.tar.gz' -print | sort | tail -n 1
}

resolve_snapshot_path() {
  local requested="${1:-}"

  if [[ -z "$requested" ]]; then
    latest_snapshot_path
    return
  fi

  if [[ -f "$requested" ]]; then
    printf '%s\n' "$requested"
    return
  fi

  if [[ -f "$SNAPSHOT_DIR/$requested" ]]; then
    printf '%s\n' "$SNAPSHOT_DIR/$requested"
    return
  fi

  die "Snapshot not found: $requested"
}

display_schema_version() {
  local version="${1:-}"

  if [[ -n "$version" ]]; then
    printf '%s\n' "$version"
    return
  fi

  printf 'unversioned\n'
}

schema_version_from_settings() {
  if [[ ! -f "$SETTINGS_PATH" ]]; then
    printf '\n'
    return
  fi

  validate_settings_json
  jq -r '
    if .schema_version == null then
      ""
    elif (.schema_version | type) == "string" then
      .schema_version
    else
      error("schema_version must be a string")
    end
  ' "$SETTINGS_PATH" 2>/dev/null || die "Failed to read schema_version from $SETTINGS_PATH"
}

version_key() {
  local version="${1:-0.0.0}"
  local major="0"
  local minor="0"
  local patch="0"

  IFS='.' read -r major minor patch <<<"$version"
  printf '%08d.%08d.%08d\n' "${major:-0}" "${minor:-0}" "${patch:-0}"
}

version_le() {
  [[ "$(version_key "$1")" < "$(version_key "$2")" || "$(version_key "$1")" == "$(version_key "$2")" ]]
}

version_lt() {
  [[ "$(version_key "$1")" < "$(version_key "$2")" ]]
}

version_gt() {
  version_lt "$2" "$1"
}

version_registered() {
  local version="${1:?Missing version}"
  [[ -n "${VERSION_TRANSFORMS[$version]:-}" ]]
}

sorted_registered_versions() {
  local version=""

  for version in "${!VERSION_TRANSFORMS[@]}"; do
    printf '%s\t%s\n' "$(version_key "$version")" "$version"
  done | sort | awk -F '\t' '{print $2}'
}

record_file_change() {
  local relative_path="${1:?Missing relative path}"
  local reason="${2:?Missing reason}"

  if [[ -n "${PLANNED_FILE_REASONS[$relative_path]:-}" ]]; then
    PLANNED_FILE_REASONS["$relative_path"]="${PLANNED_FILE_REASONS[$relative_path]}; $reason"
    return
  fi

  PLANNED_FILE_REASONS["$relative_path"]="$reason"
}

record_plan_note() {
  local note="${1:?Missing note}"
  PLANNED_NOTES+=("$note")
}

reset_plan() {
  PLANNED_FILE_REASONS=()
  PLANNED_TRANSFORMS=()
  PLANNED_NOTES=()
}

relative_path_from_vault() {
  local path="${1:?Missing path}"

  if [[ "$path" == "$VAULT_ROOT/"* ]]; then
    printf '%s\n' "${path#$VAULT_ROOT/}"
    return
  fi

  printf '%s\n' "$path"
}

normalize_date_value() {
  local value="${1:-}"

  if [[ "$value" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

file_mtime_date() {
  local path="${1:?Missing file path}"
  local value=""

  [[ -f "$path" ]] || return 1

  if value="$(stat -f '%Sm' -t '%Y-%m-%d' "$path" 2>/dev/null)"; then
    printf '%s\n' "$value"
    return 0
  fi

  if value="$(stat -c '%y' "$path" 2>/dev/null)"; then
    normalize_date_value "$value"
    return $?
  fi

  return 1
}

resolve_existing_path() {
  local candidate="${1:-}"

  [[ -n "$candidate" ]] || return 1

  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  if [[ "$candidate" != /* ]] && [[ -f "$VAULT_ROOT/$candidate" ]]; then
    printf '%s\n' "$VAULT_ROOT/$candidate"
    return 0
  fi

  return 1
}

json_record_kind() {
  local record_json="${1:?Missing record json}"

  printf '%s\n' "$record_json" | jq -r '
    if type != "object" then
      "other"
    elif has("source_type") and has("fetch_date") then
      "source-packet"
    elif has("kind") and has("date") and has("source_docs") then
      "timeline"
    else
      "other"
    end
  ' 2>/dev/null || printf 'other\n'
}

record_has_document_date() {
  local record_json="${1:?Missing record json}"
  local value=""

  value="$(printf '%s\n' "$record_json" | jq -r '.document_date? // empty' 2>/dev/null || true)"
  [[ -n "$value" ]]
}

normalized_date_from_record_fields() {
  local record_json="${1:?Missing record json}"
  local jq_filter="${2:?Missing jq filter}"
  local value=""
  local normalized=""

  while IFS= read -r value; do
    normalized="$(normalize_date_value "$value" || true)"
    if [[ -n "$normalized" ]]; then
      printf '%s\n' "$normalized"
      return 0
    fi
  done < <(printf '%s\n' "$record_json" | jq -r "$jq_filter" 2>/dev/null || true)

  return 1
}

derive_source_packet_document_date() {
  local record_json="${1:?Missing record json}"
  local normalized=""
  local source_path=""
  local resolved_path=""

  if normalized="$(normalized_date_from_record_fields "$record_json" '[.metadata.publish_date?, .metadata.published?, .metadata.created?, .metadata.created_at?, .metadata.date?, .publish_date?, .published?, .created?, .created_at?, .date?] | .[]?')" && [[ -n "$normalized" ]]; then
    printf '%s\n' "$normalized"
    return 0
  fi

  source_path="$(printf '%s\n' "$record_json" | jq -r '.source_path? // empty' 2>/dev/null || true)"
  if [[ -n "$source_path" ]]; then
    resolved_path="$(resolve_existing_path "$source_path" || true)"
    if [[ -n "$resolved_path" ]]; then
      normalized="$(file_mtime_date "$resolved_path" || true)"
      if [[ -n "$normalized" ]]; then
        printf '%s\n' "$normalized"
        return 0
      fi
    fi
  fi

  if normalized="$(normalized_date_from_record_fields "$record_json" '[.fetch_date?] | .[]?')" && [[ -n "$normalized" ]]; then
    printf '%s\n' "$normalized"
    return 0
  fi

  return 1
}

derive_timeline_document_date() {
  local record_json="${1:?Missing record json}"
  local normalized=""
  local kind=""
  local source_doc=""
  local resolved_path=""
  local latest_mtime=""

  kind="$(printf '%s\n' "$record_json" | jq -r '.kind? // empty' 2>/dev/null || true)"
  if [[ "$kind" == "note-date" ]]; then
    normalized="$(normalized_date_from_record_fields "$record_json" '[.date?] | .[]?' || true)"
    if [[ -n "$normalized" ]]; then
      printf '%s\n' "$normalized"
      return 0
    fi
  fi

  normalized="$(normalized_date_from_record_fields "$record_json" '[.published?, .created?, .created_at?, .note_date?, .metadata.publish_date?, .metadata.created?, .metadata.created_at?] | .[]?' || true)"
  if [[ -n "$normalized" ]]; then
    printf '%s\n' "$normalized"
    return 0
  fi

  while IFS= read -r source_doc; do
    [[ -n "$source_doc" ]] || continue
    resolved_path="$(resolve_existing_path "$source_doc" || true)"
    [[ -n "$resolved_path" ]] || continue
    normalized="$(file_mtime_date "$resolved_path" || true)"
    [[ -n "$normalized" ]] || continue
    if [[ -z "$latest_mtime" || "$normalized" > "$latest_mtime" ]]; then
      latest_mtime="$normalized"
    fi
  done < <(printf '%s\n' "$record_json" | jq -r '.source_docs[]?' 2>/dev/null || true)

  if [[ -n "$latest_mtime" ]]; then
    printf '%s\n' "$latest_mtime"
    return 0
  fi

  return 1
}

derive_document_date_for_record() {
  local record_json="${1:?Missing record json}"
  local kind=""
  local derived=""

  if record_has_document_date "$record_json"; then
    return 1
  fi

  kind="$(json_record_kind "$record_json")"
  case "$kind" in
    source-packet)
      derived="$(derive_source_packet_document_date "$record_json" || true)"
      ;;
    timeline)
      derived="$(derive_timeline_document_date "$record_json" || true)"
      ;;
    *)
      return 1
      ;;
  esac

  if [[ -n "$derived" ]]; then
    printf '%s\t%s\n' "$kind" "$derived"
    return 0
  fi

  return 1
}

apply_document_date_to_json_record() {
  local record_json="${1:?Missing record json}"
  local document_date="${2:?Missing document date}"

  printf '%s\n' "$record_json" | jq -c --arg document_date "$document_date" '.document_date = $document_date'
}

process_jsonl_file() {
  local file_path="${1:?Missing file path}"
  local mode="${2:?Missing mode}"
  local tmp_path=""
  local line=""
  local line_number=0
  local derived_info=""
  local record_kind=""
  local document_date=""
  local source_updates=0
  local timeline_updates=0
  local changed=0

  if [[ "$mode" == "apply" ]]; then
    tmp_path="$(mktemp "$PA_DIR/jsonl-backfill.XXXXXX")"
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))

    if [[ -z "$line" ]]; then
      if [[ "$mode" == "apply" ]]; then
        printf '\n' >>"$tmp_path"
      fi
      continue
    fi

    if ! printf '%s\n' "$line" | jq empty >/dev/null 2>&1; then
      warn "Skipping malformed JSONL line $line_number in $(relative_path_from_vault "$file_path")"
      if [[ "$mode" == "apply" ]]; then
        printf '%s\n' "$line" >>"$tmp_path"
      fi
      continue
    fi

    derived_info="$(derive_document_date_for_record "$line" || true)"
    if [[ -n "$derived_info" ]]; then
      IFS=$'\t' read -r record_kind document_date <<<"$derived_info"
      case "$record_kind" in
        source-packet)
          source_updates=$((source_updates + 1))
          ;;
        timeline)
          timeline_updates=$((timeline_updates + 1))
          ;;
      esac
      if [[ "$mode" == "apply" ]]; then
        line="$(apply_document_date_to_json_record "$line" "$document_date")"
        changed=1
      fi
    fi

    if [[ "$mode" == "apply" ]]; then
      printf '%s\n' "$line" >>"$tmp_path"
    fi
  done <"$file_path"

  if [[ "$mode" == "apply" ]]; then
    if [[ "$changed" -eq 1 ]]; then
      mv "$tmp_path" "$file_path"
    else
      rm -f "$tmp_path"
    fi
  fi

  printf '%s\t%s\t%s\n' "$source_updates" "$timeline_updates" "$changed"
}

process_json_file() {
  local file_path="${1:?Missing file path}"
  local mode="${2:?Missing mode}"
  local json_type=""
  local record_json=""
  local derived_info=""
  local record_kind=""
  local document_date=""
  local source_updates=0
  local timeline_updates=0
  local changed=0
  local array_length=0
  local index=0
  local tmp_path=""
  local tmp_apply_path=""

  json_type="$(jq -r 'type' "$file_path" 2>/dev/null || printf 'invalid')"
  case "$json_type" in
    object)
      record_json="$(jq -c '.' "$file_path" 2>/dev/null || true)"
      derived_info="$(derive_document_date_for_record "$record_json" || true)"
      if [[ -n "$derived_info" ]]; then
        IFS=$'\t' read -r record_kind document_date <<<"$derived_info"
        case "$record_kind" in
          source-packet)
            source_updates=1
            ;;
          timeline)
            timeline_updates=1
            ;;
        esac
        if [[ "$mode" == "apply" ]]; then
          tmp_path="$(mktemp "$PA_DIR/json-backfill.XXXXXX")"
          apply_document_date_to_json_record "$record_json" "$document_date" | jq '.' >"$tmp_path"
          mv "$tmp_path" "$file_path"
          changed=1
        fi
      fi
      ;;
    array)
      array_length="$(jq 'length' "$file_path" 2>/dev/null || printf '0')"
      if [[ "$mode" == "apply" ]]; then
        tmp_path="$(mktemp "$PA_DIR/json-array-backfill.XXXXXX")"
        cp "$file_path" "$tmp_path"
      fi
      for ((index = 0; index < array_length; index++)); do
        if [[ "$mode" == "apply" ]]; then
          record_json="$(jq -c ".[$index]" "$tmp_path" 2>/dev/null || true)"
        else
          record_json="$(jq -c ".[$index]" "$file_path" 2>/dev/null || true)"
        fi
        derived_info="$(derive_document_date_for_record "$record_json" || true)"
        if [[ -z "$derived_info" ]]; then
          continue
        fi
        IFS=$'\t' read -r record_kind document_date <<<"$derived_info"
        case "$record_kind" in
          source-packet)
            source_updates=$((source_updates + 1))
            ;;
          timeline)
            timeline_updates=$((timeline_updates + 1))
            ;;
        esac
        if [[ "$mode" == "apply" ]]; then
          tmp_apply_path="$(mktemp "$PA_DIR/json-array-apply.XXXXXX")"
          jq --arg document_date "$document_date" ".[$index].document_date = \$document_date" "$tmp_path" >"$tmp_apply_path"
          mv "$tmp_apply_path" "$tmp_path"
          changed=1
        fi
      done
      if [[ "$mode" == "apply" ]]; then
        if [[ "$changed" -eq 1 ]]; then
          mv "$tmp_path" "$file_path"
        else
          rm -f "$tmp_path"
        fi
      fi
      ;;
    invalid)
      warn "Skipping malformed JSON file $(relative_path_from_vault "$file_path")"
      ;;
  esac

  printf '%s\t%s\t%s\n' "$source_updates" "$timeline_updates" "$changed"
}

process_temporal_backfill_file() {
  local file_path="${1:?Missing file path}"
  local mode="${2:?Missing mode}"

  case "$file_path" in
    *.jsonl)
      process_jsonl_file "$file_path" "$mode"
      ;;
    *.json)
      process_json_file "$file_path" "$mode"
      ;;
    *)
      printf '0\t0\t0\n'
      ;;
  esac
}

scan_temporal_backfill_targets() {
  local mode="${1:?Missing mode}"
  local file_path=""
  local result=""
  local source_updates=0
  local timeline_updates=0
  local total_source_updates=0
  local total_timeline_updates=0
  local total_files=0
  local relative_path=""
  local reason=""

  while IFS= read -r file_path; do
    [[ -n "$file_path" ]] || continue
    result="$(process_temporal_backfill_file "$file_path" "$mode")"
    IFS=$'\t' read -r source_updates timeline_updates _ <<<"$result"
    if (( source_updates == 0 && timeline_updates == 0 )); then
      continue
    fi

    total_files=$((total_files + 1))
    total_source_updates=$((total_source_updates + source_updates))
    total_timeline_updates=$((total_timeline_updates + timeline_updates))

    if [[ "$mode" == "plan" ]]; then
      relative_path="$(relative_path_from_vault "$file_path")"
      reason="backfill document_date for $source_updates source-packet record(s) and $timeline_updates timeline record(s)"
      record_file_change "$relative_path" "$reason"
    fi
  done < <(find "$PA_DIR" -type f \( -name '*.json' -o -name '*.jsonl' \) ! -path "$SNAPSHOT_DIR/*" -print | sort)

  if [[ "$mode" == "plan" ]]; then
    if (( total_source_updates > 0 || total_timeline_updates > 0 )); then
      record_plan_note "Temporal backfill candidates found in $total_files file(s): $total_source_updates source-packet record(s) and $total_timeline_updates timeline record(s) can gain explicit document_date."
    else
      record_plan_note "No existing source-packet or timeline records can gain explicit document_date via conservative backfill."
    fi
    record_plan_note "2.4.0 backfill only populates document_date from reliable artifact-date signals such as publish dates, file mtimes, note-date anchors, or fetch_date fallback."
    record_plan_note "2.4.0 backfill never guesses event_date fields retroactively."
  fi
}

handle_entity_revision_seed() {
  local mode="${1:?Missing mode}"
  local entities_path="$PA_DIR/entities.json"
  local revisions_path="$PA_DIR/entity-revisions.jsonl"

  [[ -f "$entities_path" ]] || return 0
  [[ -f "$revisions_path" ]] && return 0

  case "$mode" in
    plan)
      record_file_change ".pa/entity-revisions.jsonl" "create empty append-only entity revision log because entities.json already exists"
      record_plan_note "entities.json exists without entity-revisions.jsonl. Apply will create an empty revision log to seed history."
      record_plan_note "2.4.0 does not synthesize historical entity revisions retroactively. It only creates the append log so future identity changes can be recorded safely."
      ;;
    apply)
      : >"$revisions_path"
      ;;
    *)
      die "Unknown entity revision seed mode: $mode"
      ;;
  esac
}

transform_2_4_0() {
  local mode="${1:?Missing mode}"

  case "$mode" in
    plan)
      scan_temporal_backfill_targets plan
      handle_entity_revision_seed plan
      ;;
    apply)
      scan_temporal_backfill_targets apply
      handle_entity_revision_seed apply
      ;;
    *)
      die "Unknown transform mode: $mode"
      ;;
  esac
}

build_plan() {
  local target_version="${1:?Missing target version}"
  local current_version="${2:-}"
  local baseline_version="${current_version:-0.0.0}"
  local version=""
  local transform_fn=""

  reset_plan

  version_registered "$target_version" || die "Unknown target version: $target_version"

  if [[ -n "$current_version" ]] && version_gt "$current_version" "$target_version"; then
    die "Current schema_version $(display_schema_version "$current_version") is newer than target $target_version. Use rollback instead."
  fi

  if [[ -z "$current_version" ]] || [[ "$current_version" != "$target_version" ]]; then
    if [[ -f "$SETTINGS_PATH" ]]; then
      record_file_change ".pa/settings.json" "update schema_version to $target_version"
    else
      record_file_change ".pa/settings.json" "create settings.json with schema_version $target_version"
    fi
  fi

  while IFS= read -r version; do
    [[ -n "$version" ]] || continue
    if version_le "$version" "$target_version" && version_lt "$baseline_version" "$version"; then
      PLANNED_TRANSFORMS+=("$version")
      transform_fn="${VERSION_TRANSFORMS[$version]}"
      "$transform_fn" plan
    fi
  done < <(sorted_registered_versions)

  if [[ "${#PLANNED_TRANSFORMS[@]}" -eq 0 ]] && [[ "${#PLANNED_FILE_REASONS[@]}" -eq 0 ]]; then
    record_plan_note "No migration steps are required."
  fi
}

write_schema_version() {
  local target_version="${1:?Missing target version}"
  local tmp_path=""

  if [[ -f "$SETTINGS_PATH" ]]; then
    tmp_path="$(mktemp "$PA_DIR/settings.json.tmp.XXXXXX")"
    jq --arg schema_version "$target_version" '.schema_version = $schema_version' "$SETTINGS_PATH" >"$tmp_path"
    mv "$tmp_path" "$SETTINGS_PATH"
    return
  fi

  cat >"$SETTINGS_PATH" <<EOF
{
  "schema_version": "$target_version"
}
EOF
}

create_snapshot() {
  local ts=""
  local snapshot_path=""

  ensure_tar
  mkdir -p "$SNAPSHOT_DIR"

  while :; do
    ts="$(snapshot_timestamp)"
    snapshot_path="$(snapshot_path_for_timestamp "$ts")"
    [[ ! -e "$snapshot_path" ]] && break
    sleep 1
  done

  tar -czf "$snapshot_path" --exclude='.pa/.snapshots' -C "$VAULT_ROOT" .pa
  printf '%s\n' "$snapshot_path"
}

print_plan() {
  local current_version="${1:-}"
  local target_version="${2:?Missing target version}"
  local path=""

  printf 'Current schema version: %s\n' "$(display_schema_version "$current_version")"
  printf 'Target schema version: %s\n' "$target_version"

  if [[ "${#PLANNED_TRANSFORMS[@]}" -gt 0 ]]; then
    printf 'Transform chain:\n'
    for path in "${PLANNED_TRANSFORMS[@]}"; do
      printf '  - %s\n' "$path"
    done
  else
    printf 'Transform chain: none\n'
  fi

  if [[ "${#PLANNED_FILE_REASONS[@]}" -gt 0 ]]; then
    printf 'Affected files:\n'
    for path in $(printf '%s\n' "${!PLANNED_FILE_REASONS[@]}" | sort); do
      printf '  - %s: %s\n' "$path" "${PLANNED_FILE_REASONS[$path]}"
    done
  else
    printf 'Affected files: none\n'
  fi

  if [[ "${#PLANNED_NOTES[@]}" -gt 0 ]]; then
    printf 'Notes:\n'
    for path in "${PLANNED_NOTES[@]}"; do
      printf '  - %s\n' "$path"
    done
  fi
}

run_dry_run() {
  local target_version="${1:-}"
  local current_version=""

  [[ -n "$target_version" ]] || die "Usage: pa-migrate.sh dry-run <version>"
  ensure_jq
  current_version="$(schema_version_from_settings)"
  build_plan "$target_version" "$current_version"
  print_plan "$current_version" "$target_version"
}

run_apply() {
  local target_version="${1:-}"
  local current_version=""
  local snapshot_path=""
  local version=""
  local transform_fn=""

  [[ -n "$target_version" ]] || die "Usage: pa-migrate.sh apply <version>"
  ensure_jq
  current_version="$(schema_version_from_settings)"
  build_plan "$target_version" "$current_version"

  if [[ "${#PLANNED_TRANSFORMS[@]}" -eq 0 ]] && [[ "${#PLANNED_FILE_REASONS[@]}" -eq 0 ]]; then
    print_plan "$current_version" "$target_version"
    return
  fi

  snapshot_path="$(create_snapshot)"

  for version in "${PLANNED_TRANSFORMS[@]}"; do
    transform_fn="${VERSION_TRANSFORMS[$version]}"
    "$transform_fn" apply
  done

  write_schema_version "$target_version"

  print_plan "$current_version" "$target_version"
  printf 'Snapshot created: %s\n' "$snapshot_path"
  printf 'Applied schema version: %s\n' "$target_version"
}

run_snapshot() {
  local snapshot_path=""

  snapshot_path="$(create_snapshot)"
  printf '%s\n' "$snapshot_path"
}

run_rollback() {
  local requested_snapshot="${1:-}"
  local snapshot_path=""

  ensure_tar
  snapshot_path="$(resolve_snapshot_path "$requested_snapshot")"
  [[ -n "$snapshot_path" ]] || die "No snapshots found in $SNAPSHOT_DIR"
  [[ -f "$snapshot_path" ]] || die "Snapshot not found: $snapshot_path"

  tar -tzf "$snapshot_path" >/dev/null 2>&1 || die "Snapshot archive is unreadable: $snapshot_path"

  mkdir -p "$SNAPSHOT_DIR"
  find "$PA_DIR" -mindepth 1 -maxdepth 1 ! -name '.snapshots' -exec rm -rf {} +
  tar -xzf "$snapshot_path" -C "$VAULT_ROOT"

  printf 'Restored snapshot: %s\n' "$snapshot_path"
  local restored_version=""
  if [[ -f "$SETTINGS_PATH" ]]; then
    ensure_jq
    restored_version="$(schema_version_from_settings)"
    printf 'Current schema version: %s\n' "$(display_schema_version "$restored_version")"
  else
    warn "settings.json is absent after rollback."
  fi
}

main() {
  local action="${1:-}"

  [[ -n "$action" ]] || {
    usage >&2
    exit 1
  }

  case "$action" in
    -h | --help | help)
      usage
      ;;
    dry-run)
      ensure_pa_root
      shift
      run_dry_run "${1:-}"
      ;;
    snapshot)
      ensure_pa_root
      shift
      run_snapshot
      ;;
    apply)
      ensure_pa_root
      shift
      run_apply "${1:-}"
      ;;
    rollback)
      ensure_pa_root
      shift
      run_rollback "${1:-}"
      ;;
    *)
      die "Unknown action: $action"
      ;;
  esac
}

main "$@"
