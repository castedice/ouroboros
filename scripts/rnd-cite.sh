#!/usr/bin/env bash
# Citation extractor for RnD study archives.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"

usage() {
  cat >&2 <<'EOF'
Usage: rnd-cite.sh <action> [options]
  extract <session-id>    Extract cited sources -> references.bib
  status <session-id>     Show citation status (total sources, cited, uncited)
EOF
}

die_usage() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  usage
  exit 2
}

die_error() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  exit 1
}

session_state_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s/state.json\n' "$SESSION_ROOT" "$session_id"
}

resolve_path() {
  local path="${1:?Missing path}"
  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
    return
  fi
  printf '%s/%s\n' "$PROJECT_ROOT" "$path"
}

path_rel() {
  local path="${1:?Missing path}"
  if [[ "$path" == "$PROJECT_ROOT/"* ]]; then
    printf '%s\n' "${path#$PROJECT_ROOT/}"
    return
  fi
  printf '%s\n' "$path"
}

read_json_string() {
  local file_path="${1:?Missing file path}"
  local key="${2:?Missing key}"

  awk -v key="$key" '
    $0 ~ ("^[[:space:]]*\"" key "\"[[:space:]]*:[[:space:]]*\"") {
      line = $0
      sub("^[[:space:]]*\"" key "\"[[:space:]]*:[[:space:]]*\"", "", line)
      sub("\"[[:space:]]*,?[[:space:]]*$", "", line)
      gsub(/\\"/, "\"", line)
      gsub(/\\\\/, "\\", line)
      print line
      exit
    }
  ' "$file_path"
}

extract_source_ids_from_file() {
  local file_path="${1:?Missing file path}"
  [[ -f "$file_path" ]] || return 0

  awk '
    {
      line = $0
      while (match(line, /src(-new)?-[0-9]+/)) {
        print substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$file_path"
}

sort_ids() {
  awk '
    NF {
      id = $0
      if (seen[id]++) {
        next
      }

      prefix_order = 9
      number = 0

      if (id ~ /^src-[0-9]+$/) {
        prefix_order = 1
        number = id
        sub(/^src-/, "", number)
      } else if (id ~ /^src-new-[0-9]+$/) {
        prefix_order = 2
        number = id
        sub(/^src-new-/, "", number)
      } else {
        number = id
        sub(/^.*-/, "", number)
      }

      if (number !~ /^[0-9]+$/) {
        number = 0
      }

      printf "%d\t%09d\t%s\n", prefix_order, number + 0, id
    }
  ' | sort -t "$(printf '\t')" -k1,1n -k2,2n -k3,3 | cut -f3
}

parse_source_metadata() {
  local file_path="${1:?Missing file path}"

  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function clean(value) {
      gsub(/\r/, "", value)
      value = trim(value)
      gsub(/[[:space:]]+/, " ", value)
      sub(/^`+/, "", value)
      sub(/`+$/, "", value)
      sub(/^\*\*+/, "", value)
      sub(/\*\*+$/, "", value)
      sub(/^_+/, "", value)
      sub(/_+$/, "", value)
      return trim(value)
    }

    function split_table_row(line,   raw_count, raw, i) {
      delete cells
      cell_count = 0
      raw_count = split(line, raw, /\|/)
      for (i = 2; i < raw_count; i++) {
        cell_count++
        cells[cell_count] = clean(raw[i])
      }
    }

    function is_separator_row(   i) {
      if (cell_count == 0) {
        return 0
      }
      for (i = 1; i <= cell_count; i++) {
        if (cells[i] !~ /^:?-+:?$/) {
          return 0
        }
      }
      return 1
    }

    function parse_header(   i, header_name) {
      header_title = 0
      header_authors = 0
      header_date = 0
      header_family = 0
      header_subqs = 0

      for (i = 1; i <= cell_count; i++) {
        header_name = tolower(cells[i])
        if (header_name ~ /^title/) {
          header_title = i
        } else if (header_name == "authors") {
          header_authors = i
        } else if (header_name == "date" || header_name == "year") {
          header_date = i
        } else if (header_name == "family" || header_name == "type") {
          header_family = i
        } else if (header_name ~ /^sub-q/) {
          header_subqs = i
        }
      }
    }

    function emit_record(id, title, authors, date, family, subqs) {
      id = clean(id)
      title = clean(title)
      authors = clean(authors)
      date = clean(date)
      family = clean(family)
      subqs = clean(subqs)

      if (id == "") {
        return
      }

      printf "%s\t%s\t%s\t%s\t%s\t%s\n", id, title, authors, date, family, subqs
    }

    BEGIN {
      header_title = 0
      header_authors = 0
      header_date = 0
      header_family = 0
      header_subqs = 0
    }

    /^\|/ {
      split_table_row($0)
      if (is_separator_row()) {
        next
      }
      if (cell_count == 0) {
        next
      }

      if (cells[1] ~ /^src(-new)?-[0-9]+$/) {
        if (header_title > 0) {
          title = (header_title <= cell_count) ? cells[header_title] : ""
          authors = (header_authors > 0 && header_authors <= cell_count) ? cells[header_authors] : ""
          date = (header_date > 0 && header_date <= cell_count) ? cells[header_date] : ""
          family = (header_family > 0 && header_family <= cell_count) ? cells[header_family] : ""
          subqs = (header_subqs > 0 && header_subqs <= cell_count) ? cells[header_subqs] : ""
          emit_record(cells[1], title, authors, date, family, subqs)
        }
        next
      }

      parse_header()
      next
    }

    {
      line = $0
      if (line ~ /^[[:space:]]*[-*+>]?[[:space:]]*src(-new)?-[0-9]+[[:space:]]*[|:-][[:space:]]*/) {
        work = line
        sub(/^[[:space:]]*[-*+>]?[[:space:]]*/, "", work)

        id = work
        sub(/[[:space:]]*[|:-].*$/, "", id)

        rest = work
        sub(/^src(-new)?-[0-9]+[[:space:]]*[|:-][[:space:]]*/, "", rest)

        part_count = split(rest, parts, /\|/)
        title = (part_count >= 1) ? parts[1] : ""
        authors = (part_count >= 2) ? parts[2] : ""
        date = (part_count >= 3) ? parts[3] : ""
        family = (part_count >= 4) ? parts[4] : ""
        subqs = (part_count >= 5) ? parts[5] : ""
        emit_record(id, title, authors, date, family, subqs)
      }
    }
  ' "$file_path"
}

parse_source_urls() {
  local file_path="${1:?Missing file path}"

  awk '
    function trim(value) {
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      return value
    }

    function clean_url(value) {
      value = trim(value)
      sub(/[.,;:]+$/, "", value)
      sub(/[)]+$/, "", value)
      if (value != "" && value !~ /^https?:\/\//) {
        value = "https://" value
      }
      return value
    }

    function first_url(text,   value) {
      if (match(text, /(https?:\/\/[^[:space:])>|]+|github\.com\/[^[:space:])>|]+|arxiv\.org\/[^[:space:])>|]+|[A-Za-z0-9.-]+\.com\/[^[:space:])>|]+)/)) {
        value = substr(text, RSTART, RLENGTH)
        return clean_url(value)
      }
      return ""
    }

    {
      url = first_url($0)
      if (url == "") {
        next
      }

      line = $0
      while (match(line, /src(-new)?-[0-9]+/)) {
        print substr(line, RSTART, RLENGTH) "\t" url
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' "$file_path"
}

join_ids() {
  awk '
    NF {
      if (out == "") {
        out = $0
      } else {
        out = out ", " $0
      }
    }
    END {
      if (out == "") {
        print "none"
      } else {
        print out
      }
    }
  '
}

bibtex_escape() {
  printf '%s' "${1:-}" |
    sed \
      -e 's/\\/\\\\/g' \
      -e 's/{/\\{/g' \
      -e 's/}/\\}/g' \
      -e 's/%/\\%/g' \
      -e 's/&/\\&/g' \
      -e 's/_/\\_/g' \
      -e 's/#/\\#/g'
}

extract_year() {
  local raw_date="${1:-}"
  printf '%s\n' "$raw_date" | sed -n 's/.*\([0-9][0-9][0-9][0-9]\).*/\1/p' | head -1
}

resolve_session_paths() {
  local session_id="${1:?Missing session id}"
  local state_file=""
  local archive_dir_rel=""

  state_file="$(session_state_file "$session_id")"
  [[ -f "$state_file" ]] || die_error "Session state not found: $state_file"

  archive_dir_rel="$(read_json_string "$state_file" "archive_dir")"
  [[ -n "$archive_dir_rel" ]] || die_error "archive_dir not found in $state_file"

  SESSION_ID="$session_id"
  STATE_FILE="$state_file"
  ARCHIVE_DIR_REL="$archive_dir_rel"
  ARCHIVE_DIR_ABS="$(resolve_path "$archive_dir_rel")"
  PRIOR_WORK_MAP="$ARCHIVE_DIR_ABS/prior-work-map.md"
  REPORT_FILE="$ARCHIVE_DIR_ABS/report.md"
  BIB_FILE="$ARCHIVE_DIR_ABS/references.bib"
  BIB_FILE_REL="$(path_rel "$BIB_FILE")"
  EXPERIMENT_LEDGER="$ARCHIVE_DIR_ABS/experiment-ledger.jsonl"

  [[ -d "$ARCHIVE_DIR_ABS" ]] || die_error "Archive directory not found: $ARCHIVE_DIR_ABS"
  [[ -f "$PRIOR_WORK_MAP" ]] || die_error "prior-work-map.md not found: $PRIOR_WORK_MAP"
  [[ -f "$REPORT_FILE" ]] || die_error "report.md not found: $REPORT_FILE"
}

load_catalog() {
  declare -gA KNOWN_IDS=()
  declare -gA SOURCE_TITLE=()
  declare -gA SOURCE_AUTHORS=()
  declare -gA SOURCE_DATE=()
  declare -gA SOURCE_FAMILY=()
  declare -gA SOURCE_SUBQS=()
  declare -gA SOURCE_URL=()

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    KNOWN_IDS["$id"]=1
  done < <(extract_source_ids_from_file "$PRIOR_WORK_MAP" | sort_ids)

  if [[ -f "$EXPERIMENT_LEDGER" ]]; then
    while IFS= read -r id; do
      [[ -n "$id" ]] || continue
      KNOWN_IDS["$id"]=1
    done < <(extract_source_ids_from_file "$EXPERIMENT_LEDGER" | sort_ids)
  fi

  while IFS=$'\t' read -r id title authors date family subqs; do
    [[ -n "$id" ]] || continue
    KNOWN_IDS["$id"]=1

    if [[ -n "$title" && -z "${SOURCE_TITLE[$id]-}" ]]; then
      SOURCE_TITLE["$id"]="$title"
    fi
    if [[ -n "$authors" && -z "${SOURCE_AUTHORS[$id]-}" ]]; then
      SOURCE_AUTHORS["$id"]="$authors"
    fi
    if [[ -n "$date" && -z "${SOURCE_DATE[$id]-}" ]]; then
      SOURCE_DATE["$id"]="$date"
    fi
    if [[ -n "$family" && -z "${SOURCE_FAMILY[$id]-}" ]]; then
      SOURCE_FAMILY["$id"]="$family"
    fi
    if [[ -n "$subqs" && -z "${SOURCE_SUBQS[$id]-}" ]]; then
      SOURCE_SUBQS["$id"]="$subqs"
    fi
  done < <(parse_source_metadata "$PRIOR_WORK_MAP")

  while IFS=$'\t' read -r id url; do
    [[ -n "$id" && -n "$url" ]] || continue
    if [[ -z "${SOURCE_URL[$id]-}" ]]; then
      SOURCE_URL["$id"]="$url"
    fi
  done < <(parse_source_urls "$PRIOR_WORK_MAP")
}

load_cited_ids() {
  declare -gA CITED_IDS=()

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    CITED_IDS["$id"]=1
    KNOWN_IDS["$id"]=1
  done < <(extract_source_ids_from_file "$REPORT_FILE" | sort_ids)
}

entry_type_for() {
  local id="${1:?Missing source id}"
  local title="${SOURCE_TITLE[$id]-}"
  local family="${SOURCE_FAMILY[$id]-}"
  local authors="${SOURCE_AUTHORS[$id]-}"
  local date="${SOURCE_DATE[$id]-}"

  if [[ -z "$title" ]]; then
    printf 'misc\n'
    return
  fi

  if [[ "$family" == "technical-report" ]]; then
    printf 'techreport\n'
    return
  fi

  if [[ "$family" == "conference-paper" && -n "$authors" && -n "$date" ]]; then
    printf 'inproceedings\n'
    return
  fi

  if [[ ("$family" == "paper" || "$family" == "preprint") && -n "$authors" && -n "$date" ]]; then
    printf 'article\n'
    return
  fi

  printf 'misc\n'
}

note_for() {
  local id="${1:?Missing source id}"
  local title="${SOURCE_TITLE[$id]-}"
  local family="${SOURCE_FAMILY[$id]-}"
  local subqs="${SOURCE_SUBQS[$id]-}"
  local url="${SOURCE_URL[$id]-}"
  local note=""

  if [[ -z "$title" ]]; then
    note="Metadata incomplete. Source ID: $id"
    if [[ -n "$url" ]]; then
      note="$note. URL: $url"
    fi
    printf '%s\n' "$note"
    return
  fi

  if [[ -n "$family" ]]; then
    note="$family"
  fi
  if [[ -n "$subqs" ]]; then
    if [[ -n "$note" ]]; then
      note="$note. Sub-Qs: $subqs"
    else
      note="Sub-Qs: $subqs"
    fi
  fi
  if [[ -n "$url" ]]; then
    if [[ -n "$note" ]]; then
      note="$note. URL: $url"
    else
      note="URL: $url"
    fi
  fi
  if [[ -z "$note" ]]; then
    note="Source ID: $id"
  fi

  printf '%s\n' "$note"
}

write_entry() {
  local file_path="${1:?Missing file path}"
  local id="${2:?Missing source id}"
  local entry_type=""
  local title=""
  local authors=""
  local year=""
  local note=""

  entry_type="$(entry_type_for "$id")"
  title="${SOURCE_TITLE[$id]-}"
  authors="${SOURCE_AUTHORS[$id]-}"
  year="$(extract_year "${SOURCE_DATE[$id]-}")"
  note="$(note_for "$id")"

  {
    printf '@%s{%s,\n' "$entry_type" "$id"
    if [[ -n "$title" ]]; then
      printf '  title = {%s},\n' "$(bibtex_escape "$title")"
    fi
    if [[ -n "$authors" ]]; then
      printf '  author = {%s},\n' "$(bibtex_escape "$authors")"
    fi
    if [[ -n "$year" ]]; then
      printf '  year = {%s},\n' "$(bibtex_escape "$year")"
    fi
    printf '  note = {%s}\n' "$(bibtex_escape "$note")"
    printf '}\n'
  } >>"$file_path"
}

action_extract() {
  local session_id="${1:-}"
  local tmp_file=""
  local first_entry=1
  local id=""

  [[ -n "$session_id" ]] || die_usage "extract requires <session-id>"
  resolve_session_paths "$session_id"
  load_catalog
  load_cited_ids

  tmp_file="$(mktemp "${BIB_FILE}.tmp.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp_file'" EXIT
  : >"$tmp_file"

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if ((first_entry == 0)); then
      printf '\n' >>"$tmp_file"
    fi
    write_entry "$tmp_file" "$id"
    first_entry=0
  done < <(
    for id in "${!CITED_IDS[@]}"; do
      printf '%s\n' "$id"
    done | sort_ids
  )

  mv "$tmp_file" "$BIB_FILE"
  trap - EXIT
  printf 'Wrote %s\n' "$BIB_FILE_REL"
}

action_status() {
  local session_id="${1:-}"
  local total_sources=0
  local cited_sources=0
  local uncited_list=""
  local id=""

  [[ -n "$session_id" ]] || die_usage "status requires <session-id>"
  resolve_session_paths "$session_id"
  load_catalog
  load_cited_ids

  total_sources="${#KNOWN_IDS[@]}"
  cited_sources="${#CITED_IDS[@]}"

  uncited_list="$(
    {
      for id in "${!KNOWN_IDS[@]}"; do
        if [[ -z "${CITED_IDS[$id]-}" ]]; then
          printf '%s\n' "$id"
        fi
      done
    } | sort_ids | join_ids
  )"

  printf 'Citations: %s cited / %s total sources\n' "$cited_sources" "$total_sources"
  printf 'Uncited: %s\n' "$uncited_list"
  if [[ -f "$BIB_FILE" ]]; then
    printf 'BibTeX: %s (exists)\n' "$BIB_FILE_REL"
  else
    printf 'BibTeX: %s (missing)\n' "$BIB_FILE_REL"
  fi
}

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  usage
  exit 2
fi
shift || true

case "$ACTION" in
  extract)
    [[ $# -eq 1 ]] || die_usage "extract requires exactly one <session-id>"
    action_extract "$1"
    ;;
  status)
    [[ $# -eq 1 ]] || die_usage "status requires exactly one <session-id>"
    action_status "$1"
    ;;
  *)
    die_usage "Unknown action: $ACTION"
    ;;
esac
