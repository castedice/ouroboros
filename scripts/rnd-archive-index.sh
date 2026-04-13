#!/usr/bin/env bash
# Archive index lifecycle manager for completed RnD studies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE_ROOT="$PROJECT_ROOT/docs/research"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"
INDEX_FILE="$PROJECT_ROOT/.rnd/archive-index.json"
SIMILARITY_SCRIPT="$SCRIPT_DIR/kb-similarity.sh"
SCHEMA_VERSION="rnd-archive-index.v1"

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <build|update|search|status> ..." >&2
  exit 2
fi
shift || true

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-archive-index.sh build
  rnd-archive-index.sh update <session-id>
  rnd-archive-index.sh search <query>
  rnd-archive-index.sh status
EOF
}

die_usage() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  usage
  exit 2
}

die_validation() {
  local message="${1:?Missing error message}"
  echo "Error: $message" >&2
  exit 1
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    die_validation "jq is required."
  fi
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

path_rel() {
  local path="${1:?Missing path}"
  if [[ "$path" == "$PROJECT_ROOT/"* ]]; then
    printf '%s\n' "${path#$PROJECT_ROOT/}"
    return
  fi
  printf '%s\n' "$path"
}

normalize_text() {
  perl -0pe '
    s/<!--.*?-->//gs;
    s/\[([^\]]+)\]\([^)]+\)/$1/g;
    s/`//g;
    s/\*\*([^*]+)\*\*/$1/g;
    s/\*([^*]+)\*/$1/g;
    s/^#{1,6}\s+//mg;
    s/^\s*[-*+]\s+//mg;
    s/^\s*\d+\.\s+//mg;
    s/^\s*>\s+//mg;
    s/\|/ /g;
    s/\r//g;
    s/[[:space:]]+/ /g;
    s/^\s+//;
    s/\s+$//;
  '
}

markdown_section() {
  local file_path="${1:?Missing file path}"
  local heading="${2:?Missing heading}"
  awk -v heading="$heading" '
    function rtrim(value) {
      sub(/[[:space:]]+$/, "", value)
      return value
    }
    BEGIN { in_section = 0 }
    {
      line = rtrim($0)
      if (line == "## " heading) {
        in_section = 1
        next
      }
      if (in_section && (line ~ /^## / || line == "---")) {
        exit
      }
      if (in_section) {
        print
      }
    }
  ' "$file_path"
}

markdown_first_line_after_heading() {
  local file_path="${1:?Missing file path}"
  local heading="${2:?Missing heading}"
  markdown_section "$file_path" "$heading" |
    awk '
      /^[[:space:]]*$/ { next }
      /^<!--/ { next }
      { print; exit }
    ' |
    normalize_text
}

markdown_first_paragraph_after_heading() {
  local file_path="${1:?Missing file path}"
  local heading="${2:?Missing heading}"
  markdown_section "$file_path" "$heading" |
    awk '
      BEGIN { started = 0 }
      /^<!--/ { next }
      /^### / { next }
      /^[[:space:]]*$/ {
        if (started) {
          exit
        }
        next
      }
      {
        print
        started = 1
      }
    ' |
    normalize_text
}

markdown_section_text() {
  local file_path="${1:?Missing file path}"
  local heading="${2:?Missing heading}"
  markdown_section "$file_path" "$heading" | normalize_text
}

markdown_h1_title() {
  local file_path="${1:?Missing file path}"
  sed -n 's/^# \+//p' "$file_path" | head -1 | normalize_text
}

markdown_emphasis_value() {
  local file_path="${1:?Missing file path}"
  local label="${2:?Missing label}"
  awk -v label="$label" '
    function trim(value) {
      gsub(/^[ \t]+|[ \t]+$/, "", value)
      return value
    }
    {
      line = $0
      if (line ~ ("^\\*+" label "\\*+:")) {
        sub("^\\*+" label "\\*+:?[[:space:]]*", "", line)
        gsub(/`/, "", line)
        print trim(line)
        exit
      }
    }
  ' "$file_path"
}

derive_tags_json() {
  local question="${1:-}"
  printf '%s\n' "$question" |
    tr '[:upper:]' '[:lower:]' |
    tr -cs '[:alnum:]' '\n' |
    awk '
      length >= 3 &&
      !/^(the|and|for|with|from|that|this|into|onto|about|your|what|when|where|will|would|should|could|their|there|have|has|had|are|was|were|but|not|you|use|used|using|via|over|under|than|then|them|they|our|out|most|study|key)$/ {
        print
      }
    ' |
    sort -u |
    jq -Rn '[inputs | select(length > 0)]'
}

report_claim_rows() {
  local report_path="${1:?Missing report path}"
  markdown_section "$report_path" "Claims & Evidence Table" |
    awk -F'|' '
      function trim(value) {
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        return value
      }
      /^### / { exit }
      started && !/^\|/ { exit }
      /^\|/ {
        started = 1
        id = trim($2)
        claim = trim($3)
        if (id == "" || id == "ID" || id ~ /^-+$/) {
          next
        }
        if (claim == "" || claim == "Claim") {
          next
        }
        print id "\t" claim
      }
    '
}

claims_json() {
  local report_path="${1:?Missing report path}"
  report_claim_rows "$report_path" |
    jq -Rn '[inputs | split("\t") | .[0] | select(length > 0)]'
}

claim_text_summary() {
  local report_path="${1:?Missing report path}"
  report_claim_rows "$report_path" |
    awk -F'\t' '{ print $2 }' |
    normalize_text
}

review_scores_json() {
  local review_path="${1:?Missing review path}"
  markdown_section "$review_path" "Rubric Scores (C1-C5)" |
    awk -F'|' '
      function trim(value) {
        gsub(/^[ \t]+|[ \t]+$/, "", value)
        return value
      }
      /^\|/ {
        criterion = trim($2)
        score = trim($3)
        if (criterion == "" || criterion == "Criterion" || criterion ~ /^-+$/) {
          next
        }
        if (match(criterion, /(C[1-5])/)) {
          criterion_id = substr(criterion, RSTART, RLENGTH)
          if (match(score, /[0-9]+/)) {
            print criterion_id "\t" substr(score, RSTART, RLENGTH)
          }
        }
      }
    ' |
    jq -Rn '
      reduce (inputs | split("\t") | select(length == 2)) as $item
        ({};
         .[$item[0]] = ($item[1] | tonumber))
    '
}

review_verdict() {
  local review_path="${1:?Missing review path}"
  markdown_first_line_after_heading "$review_path" "Release Verdict" |
    tr '[:upper:]' '[:lower:]'
}

count_prefixed_headings() {
  local file_path="${1:?Missing file path}"
  local prefix="${2:?Missing prefix}"

  if [[ ! -f "$file_path" ]]; then
    printf '0\n'
    return
  fi

  grep -Ec "^### ${prefix}[0-9]+" "$file_path" 2>/dev/null || true
}

stage_durations_json_from_budget() {
  local budget_path="${1:?Missing budget path}"
  jq -c --argjson stages '["scope","prior-work","perspectives","hypotheses","experiment-design","probes","analyze-prune","report","review","meta-learn"]' '
    (.phases // {}) as $phases
    | ([ $stages[] | ($phases[.]?.wall_clock_seconds // 0) ] | add) as $total
    | if $total > 0 then
        reduce $stages[] as $stage
          ({};
           .[$stage] = ($phases[$stage]?.wall_clock_seconds // 0))
      else
        null
      end
  ' "$budget_path"
}

budget_utilization_json() {
  local budget_path="${1:?Missing budget path}"
  jq -c '
    def ratio($used; $limit):
      if ($limit // 0) > 0 then
        (($used // 0) / $limit)
      else
        null
      end;
    {
      wall_clock: ratio(.usage.wall_clock_seconds; .limits.wall_clock_seconds),
      web_search: ratio(.usage.web_search_calls; .limits.web_search_calls),
      web_fetch: ratio(.usage.web_fetch_calls; .limits.web_fetch_calls),
      model_route: ratio(.usage.model_route_calls; .limits.model_route_calls),
      probes: ratio(.usage.probe_calls; .limits.probe_calls)
    }
  ' "$budget_path"
}

composite_summary() {
  local question="${1:-}"
  local executive_summary="${2:-}"
  local claim_summary="${3:-}"
  local next_questions="${4:-}"
  local open_gaps="${5:-}"
  {
    [[ -n "$question" ]] && printf 'Question: %s\n' "$question"
    [[ -n "$executive_summary" ]] && printf 'Executive Summary: %s\n' "$executive_summary"
    [[ -n "$claim_summary" ]] && printf 'Claims: %s\n' "$claim_summary"
    [[ -n "$open_gaps" ]] && printf 'Open Gaps: %s\n' "$open_gaps"
    [[ -n "$next_questions" ]] && printf 'Next Questions: %s\n' "$next_questions"
  } | normalize_text
}

study_title() {
  local report_path="${1:?Missing report path}"
  local question="${2:-}"
  local title
  title="$(markdown_h1_title "$report_path")"
  case "$title" in
    ""|"Study Report"|"Report")
      printf '%s\n' "$question"
      ;;
    *)
      printf '%s\n' "$title"
      ;;
  esac
}

session_state_path() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s/state.json\n' "$SESSION_ROOT" "$session_id"
}

find_state_for_archive_dir() {
  local archive_dir_rel="${1:?Missing archive dir}"
  local state_path
  local matched=""

  if [[ ! -d "$SESSION_ROOT" ]]; then
    return 1
  fi

  while IFS= read -r state_path; do
    [[ -n "$state_path" ]] || continue
    if [[ "$(jq -r --arg archive_dir "$archive_dir_rel" '.archive_dir == $archive_dir' "$state_path")" == "true" ]]; then
      matched="$state_path"
    fi
  done < <(find "$SESSION_ROOT" -maxdepth 2 -name state.json -print | sort)

  [[ -n "$matched" ]] || return 1
  printf '%s\n' "$matched"
}

ensure_completed_state() {
  local state_path="${1:?Missing state path}"
  local session_id
  local run_status

  session_id="$(jq -r '.session_id // ""' "$state_path")"
  run_status="$(jq -r '.run_status // ""' "$state_path")"
  if [[ "$run_status" != "completed" ]]; then
    die_validation "Session '$session_id' is not completed."
  fi
}

extract_study_json() {
  local study_dir_rel="${1:?Missing study dir}"
  local state_path="${2:-}"
  local study_dir_abs="$PROJECT_ROOT/$study_dir_rel"
  local brief_path="$study_dir_abs/brief.md"
  local report_path="$study_dir_abs/report.md"
  local review_path="$study_dir_abs/review.md"
  local prior_work_path="$study_dir_abs/prior-work-map.md"
  local path_rel_report
  local study_id=""
  local slug=""
  local year=""
  local mode=""
  local question=""
  local title=""
  local executive_summary=""
  local claim_summary=""
  local next_questions=""
  local open_gaps=""
  local summary=""
  local verdict=""
  local completed_at=""
  local tags_json="[]"
  local claims_json_value="[]"
  local review_scores_json_value="{}"
  local stage_durations_json_value="null"
  local budget_utilization_json_value="null"
  local source_count="null"
  local probe_count="null"
  local budget_path=""
  local meta_learning_path="$study_dir_abs/meta-learning.md"
  local meta_lesson_count="null"

  [[ -f "$brief_path" ]] || die_validation "Missing brief.md in '$study_dir_rel'."
  [[ -f "$report_path" ]] || die_validation "Missing report.md in '$study_dir_rel'."
  [[ -f "$review_path" ]] || die_validation "Missing review.md in '$study_dir_rel'."

  path_rel_report="$(path_rel "$report_path")"

  if [[ -n "$state_path" && -f "$state_path" ]]; then
    study_id="$(jq -r '.session_id // ""' "$state_path")"
    slug="$(jq -r '.slug // ""' "$state_path")"
    year="$(jq -r '.year // ""' "$state_path")"
    mode="$(jq -r '.mode // ""' "$state_path")"
    question="$(jq -r '.question // ""' "$state_path")"
    completed_at="$(jq -r '.completed_at // ""' "$state_path")"
    budget_path="$(dirname "$state_path")/budget.json"
    if [[ "$(jq -r '.final_summary.total_sources != null' "$state_path")" == "true" ]]; then
      source_count="$(jq -r '.final_summary.total_sources' "$state_path")"
    fi
    if [[ "$(jq -r '.final_summary.total_probes != null' "$state_path")" == "true" ]]; then
      probe_count="$(jq -r '.final_summary.total_probes' "$state_path")"
    fi
    if [[ -f "$budget_path" ]]; then
      stage_durations_json_value="$(stage_durations_json_from_budget "$budget_path")"
      budget_utilization_json_value="$(budget_utilization_json "$budget_path")"
    fi
  fi

  if [[ -f "$meta_learning_path" ]]; then
    meta_lesson_count="$(count_prefixed_headings "$meta_learning_path" "ML-")"
    if [[ "$meta_lesson_count" == "0" ]]; then
      meta_lesson_count="null"
    fi
  fi

  [[ -n "$slug" ]] || slug="$(basename "$study_dir_rel")"
  [[ -n "$question" ]] || question="$(markdown_first_line_after_heading "$brief_path" "Question")"
  [[ -n "$question" ]] || question="$(markdown_emphasis_value "$report_path" "Question")"
  [[ -n "$study_id" ]] || study_id="$(markdown_emphasis_value "$brief_path" "Study ID")"
  [[ -n "$study_id" ]] || study_id="$(markdown_emphasis_value "$report_path" "Study ID")"
  [[ -n "$study_id" ]] || study_id="$slug"
  [[ -n "$year" ]] || year="$(basename "$(dirname "$study_dir_rel")")"
  [[ -n "$mode" ]] || mode="$(markdown_first_line_after_heading "$brief_path" "Mode")"

  title="$(study_title "$report_path" "$question")"
  executive_summary="$(markdown_first_paragraph_after_heading "$report_path" "Executive Summary")"
  claim_summary="$(claim_text_summary "$report_path")"
  next_questions="$(markdown_section_text "$report_path" "Next Questions")"
  if [[ -f "$prior_work_path" ]]; then
    open_gaps="$(markdown_section_text "$prior_work_path" "Open Gaps")"
  fi
  summary="$(composite_summary "$question" "$executive_summary" "$claim_summary" "$next_questions" "$open_gaps")"
  tags_json="$(derive_tags_json "$question")"
  claims_json_value="$(claims_json "$report_path")"
  verdict="$(review_verdict "$review_path")"
  review_scores_json_value="$(review_scores_json "$review_path")"

  jq -n \
    --arg study_id "$study_id" \
    --arg slug "$slug" \
    --arg question "$question" \
    --arg title "$title" \
    --arg path "$path_rel_report" \
    --arg study_path "$study_dir_rel" \
    --arg summary "$summary" \
    --arg verdict "$verdict" \
    --arg completed_at "$completed_at" \
    --arg year "$year" \
    --arg mode "$mode" \
    --argjson tags "$tags_json" \
    --argjson claims "$claims_json_value" \
    --argjson review_scores "$review_scores_json_value" \
    --argjson stage_durations "$stage_durations_json_value" \
    --argjson budget_utilization "$budget_utilization_json_value" \
    --argjson source_count "$source_count" \
    --argjson probe_count "$probe_count" \
    --argjson meta_lesson_count "$meta_lesson_count" \
    '
      {
        study_id: $study_id,
        slug: $slug,
        question: $question,
        title: $title,
        path: $path,
        study_path: $study_path,
        tags: $tags,
        summary: $summary,
        claims: $claims,
        verdict: (if $verdict == "" then null else $verdict end),
        review_scores: $review_scores,
        stage_durations: $stage_durations,
        budget_utilization: $budget_utilization,
        source_count: $source_count,
        probe_count: $probe_count,
        meta_lesson_count: $meta_lesson_count,
        completed_at: (if $completed_at == "" then null else $completed_at end),
        year: $year,
        mode: $mode
      }
    '
}

write_index_file() {
  local index_json="${1:?Missing index json}"
  mkdir -p "$(dirname "$INDEX_FILE")"
  printf '%s\n' "$index_json" >"$INDEX_FILE"
}

existing_index_base_json() {
  if [[ ! -f "$INDEX_FILE" ]]; then
    jq -n --arg schema_version "$SCHEMA_VERSION" '{schema_version: $schema_version, studies: []}'
    return
  fi

  jq -e '
    type == "object"
    and (.schema_version // "") != ""
    and ((.studies // null) | type) == "array"
  ' "$INDEX_FILE" >/dev/null 2>&1 || die_validation "Existing archive index is malformed: $(path_rel "$INDEX_FILE")."

  jq '{schema_version, studies}' "$INDEX_FILE"
}

build_index_json() {
  local studies_json="${1:?Missing studies json}"
  local ts
  local existing_base

  ts="$(timestamp_utc)"
  if [[ -f "$INDEX_FILE" ]]; then
    existing_base="$(existing_index_base_json)"
    if jq -e --argjson studies "$studies_json" '
      (.schema_version == "'"$SCHEMA_VERSION"'")
      and (.studies == $studies)
    ' <<<"$existing_base" >/dev/null 2>&1; then
      jq --argjson studies "$studies_json" '
        .studies = $studies
      ' "$INDEX_FILE"
      return
    fi
  fi

  jq -n \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg rebuilt_at "$ts" \
    --argjson studies "$studies_json" \
    '{schema_version: $schema_version, rebuilt_at: $rebuilt_at, studies: $studies}'
}

action_build() {
  local report_path
  local study_dir_abs
  local study_dir_rel
  local state_path
  local entry
  local studies_lines=()
  local studies_json
  local index_json
  local indexed_count

  if [[ $# -ne 0 ]]; then
    die_usage "build does not accept extra arguments."
  fi

  if [[ ! -d "$ARCHIVE_ROOT" ]]; then
    studies_json='[]'
    index_json="$(build_index_json "$studies_json")"
    write_index_file "$index_json"
    echo "Archive index rebuilt: 0 studies"
    return 0
  fi

  while IFS= read -r report_path; do
    [[ -n "$report_path" ]] || continue
    study_dir_abs="$(dirname "$report_path")"
    if [[ ! -f "$study_dir_abs/brief.md" || ! -f "$study_dir_abs/review.md" ]]; then
      continue
    fi

    study_dir_rel="$(path_rel "$study_dir_abs")"
    state_path="$(find_state_for_archive_dir "$study_dir_rel" || true)"
    if [[ -n "$state_path" ]]; then
      if [[ "$(jq -r '.run_status // ""' "$state_path")" != "completed" ]]; then
        continue
      fi
    fi

    entry="$(extract_study_json "$study_dir_rel" "$state_path")"
    studies_lines+=("$entry")
  done < <(find "$ARCHIVE_ROOT" -type f -name report.md -print | sort)

  if [[ ${#studies_lines[@]} -eq 0 ]]; then
    studies_json='[]'
  else
    studies_json="$(printf '%s\n' "${studies_lines[@]}" | jq -s 'sort_by(.year, .slug, .study_id, .path)')"
  fi

  index_json="$(build_index_json "$studies_json")"
  write_index_file "$index_json"
  indexed_count="$(jq -r '.studies | length' "$INDEX_FILE")"
  echo "Archive index rebuilt: $indexed_count studies"
}

action_update() {
  local session_id="${1:-}"
  local state_path
  local study_dir_rel
  local entry_json
  local base_json
  local studies_json
  local index_json
  local ts

  if [[ -z "$session_id" || $# -ne 1 ]]; then
    die_usage "update requires <session-id>."
  fi

  state_path="$(session_state_path "$session_id")"
  [[ -f "$state_path" ]] || die_validation "Session state not found for '$session_id'."
  ensure_completed_state "$state_path"

  study_dir_rel="$(jq -r '.archive_dir // ""' "$state_path")"
  [[ -n "$study_dir_rel" ]] || die_validation "Session '$session_id' is missing archive_dir."

  entry_json="$(extract_study_json "$study_dir_rel" "$state_path")"
  base_json="$(existing_index_base_json)"
  studies_json="$(jq -n \
    --argjson existing "$(jq '.studies' <<<"$base_json")" \
    --argjson entry "$entry_json" \
    '
      ($existing | map(select(.study_id != $entry.study_id))) + [$entry]
      | sort_by(.year, .slug, .study_id, .path)
    '
  )"
  ts="$(timestamp_utc)"
  index_json="$(jq -n \
    --arg schema_version "$SCHEMA_VERSION" \
    --arg rebuilt_at "$ts" \
    --argjson studies "$studies_json" \
    '{schema_version: $schema_version, rebuilt_at: $rebuilt_at, studies: $studies}'
  )"
  write_index_file "$index_json"

  echo "Archive index updated: $session_id"
  echo "  study_path=$study_dir_rel"
}

action_search() {
  local query="$*"

  if [[ -z "$query" ]]; then
    die_usage "search requires <query>."
  fi

  if [[ ! -f "$INDEX_FILE" ]]; then
    printf '[]\n'
    return 0
  fi

  bash "$SIMILARITY_SCRIPT" "$query" --corpus "$INDEX_FILE" --threshold 0.3 --top 5 --format json
}

action_status() {
  local count="0"
  local rebuilt_at=""

  if [[ ! -f "$INDEX_FILE" ]]; then
    echo "=== Archive Index ==="
    echo "Path: $(path_rel "$INDEX_FILE")"
    echo "Study count: 0"
    echo "Rebuilt at: "
    echo "Study slugs: none"
    return 0
  fi

  jq -e '
    type == "object"
    and ((.studies // null) | type) == "array"
  ' "$INDEX_FILE" >/dev/null 2>&1 || die_validation "Archive index is malformed: $(path_rel "$INDEX_FILE")."

  count="$(jq -r '.studies | length' "$INDEX_FILE")"
  rebuilt_at="$(jq -r '.rebuilt_at // ""' "$INDEX_FILE")"

  echo "=== Archive Index ==="
  echo "Path: $(path_rel "$INDEX_FILE")"
  echo "Study count: $count"
  echo "Rebuilt at: $rebuilt_at"
  echo "Study slugs:"
  if [[ "$count" == "0" ]]; then
    echo "- none"
    return 0
  fi
  jq -r '.studies[] | .slug // ""' "$INDEX_FILE" | while IFS= read -r slug; do
    echo "- $slug"
  done
}

require_jq

case "$ACTION" in
  build) action_build "$@" ;;
  update) action_update "$@" ;;
  search) action_search "$@" ;;
  status) action_status "$@" ;;
  *)
    die_usage "Unknown action '$ACTION'."
    ;;
esac
