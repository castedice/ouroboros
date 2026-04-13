#!/usr/bin/env bash
# Meta-research metrics extractor and aggregator for completed RnD studies.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SESSION_ROOT="$PROJECT_ROOT/.rnd/sessions"
ARCHIVE_INDEX_FILE="$PROJECT_ROOT/.rnd/archive-index.json"
AGGREGATE_FILE="$PROJECT_ROOT/.rnd/meta-aggregate.json"
AGGREGATE_TEMPLATE="$PROJECT_ROOT/templates/rnd/meta-aggregate.json"

STAGES_JSON='["scope","prior-work","perspectives","hypotheses","experiment-design","probes","analyze-prune","report","review","meta-learn"]'

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  echo "Usage: $(basename "$0") <extract|aggregate|status> ..." >&2
  exit 2
fi
shift || true

usage() {
  cat >&2 <<'EOF'
Usage:
  rnd-meta.sh extract <session-id>
  rnd-meta.sh aggregate
  rnd-meta.sh status
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

session_dir() {
  local session_id="${1:?Missing session id}"
  printf '%s/%s\n' "$SESSION_ROOT" "$session_id"
}

state_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/state.json\n' "$(session_dir "$session_id")"
}

budget_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/budget.json\n' "$(session_dir "$session_id")"
}

metrics_file() {
  local session_id="${1:?Missing session id}"
  printf '%s/study-metrics.json\n' "$(session_dir "$session_id")"
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

claim_count_from_report() {
  local report_path="${1:?Missing report path}"
  local count
  count="$(report_claim_rows "$report_path" | awk 'END { print NR + 0 }')"
  printf '%s\n' "$count"
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

prefixed_heading_ids_json() {
  local file_path="${1:?Missing file path}"
  local prefix="${2:?Missing prefix}"
  local matches=""

  if [[ ! -f "$file_path" ]]; then
    printf '[]\n'
    return
  fi

  matches="$(grep -Eo "^### ${prefix}[0-9]+" "$file_path" 2>/dev/null || true)"
  if [[ -z "$matches" ]]; then
    printf '[]\n'
    return
  fi

  printf '%s\n' "$matches" |
    sed 's/^### //' |
    jq -Rn '[inputs | select(length > 0)]'
}

archive_entry_json() {
  local study_id="${1:?Missing study id}"

  if [[ ! -f "$ARCHIVE_INDEX_FILE" ]]; then
    printf 'null\n'
    return
  fi

  jq -c --arg study_id "$study_id" '
    ([.studies[]? | select(.study_id == $study_id)][0] // null)
  ' "$ARCHIVE_INDEX_FILE"
}

budget_detail_json() {
  local budget_path="${1:?Missing budget path}"
  jq -c '
    def metric($used; $limit):
      {
        used: ($used // 0),
        limit: ($limit // 0),
        utilization: (if ($limit // 0) > 0 then (($used // 0) / $limit) else null end)
      };
    {
      wall_clock: metric(.usage.wall_clock_seconds; .limits.wall_clock_seconds),
      web_search: metric(.usage.web_search_calls; .limits.web_search_calls),
      web_fetch: metric(.usage.web_fetch_calls; .limits.web_fetch_calls),
      model_route: metric(.usage.model_route_calls; .limits.model_route_calls),
      probes: metric(.usage.probe_calls; .limits.probe_calls)
    }
  ' "$budget_path"
}

stage_durations_from_budget_json() {
  local budget_path="${1:?Missing budget path}"
  jq -c --argjson stages "$STAGES_JSON" '
    (.phases // {}) as $phases
    | ([ $stages[] | ($phases[.]?.wall_clock_seconds // 0) ] | add) as $total
    | if $total > 0 then
        {
          source: "budget-phases",
          total_seconds: $total,
          stages: reduce $stages[] as $stage
            ({};
             ($phases[$stage]?.wall_clock_seconds // 0) as $seconds
             | .[$stage] = {
                 seconds: $seconds,
                 fraction: (if $total > 0 then ($seconds / $total) else 0 end)
               })
        }
      else
        empty
      end
  ' "$budget_path"
}

stage_durations_from_transitions_json() {
  local state_path="${1:?Missing state path}"
  jq -c --argjson stages "$STAGES_JSON" '
    (.transitions // []) as $transitions
    | [
        range(0; (($transitions | length) - 1)) as $i
        | $transitions[$i] as $current
        | $transitions[$i + 1] as $next
        | select(($current.to // "") != "" and ($current.to // "") != "completed")
        | {
            stage: $current.to,
            seconds: (
              (($next.timestamp // "") | fromdateiso8601)
              - (($current.timestamp // "") | fromdateiso8601)
            )
          }
      ] as $durations
    | ($durations | map(.seconds) | add // 0) as $total
    | {
        source: "state-transitions",
        total_seconds: $total,
        stages: reduce $stages[] as $stage
          ({};
           ([ $durations[] | select(.stage == $stage) | .seconds ] | add // 0) as $seconds
           | .[$stage] = {
               seconds: $seconds,
               fraction: (if $total > 0 then ($seconds / $total) else 0 end)
             })
      }
  ' "$state_path"
}

stage_durations_json() {
  local budget_path="${1:?Missing budget path}"
  local state_path="${2:?Missing state path}"
  local from_budget=""

  if [[ -f "$budget_path" ]]; then
    from_budget="$(stage_durations_from_budget_json "$budget_path" || true)"
  fi

  if [[ -n "$from_budget" ]]; then
    printf '%s\n' "$from_budget"
    return
  fi

  stage_durations_from_transitions_json "$state_path"
}

probe_metrics_json() {
  local ledger_path="${1:?Missing ledger path}"
  jq -cs '
    def entry_kind:
      .entry_kind // .entry_type // "";
    def normalized_probe_type($planned):
      .planned_probe_type // .executed_probe_type // .probe_type // $planned[.contract_id] // "unknown";
    def normalized_status:
      (.result // .status // "") as $raw
      | if $raw == "success" or $raw == "supportive" then
          "success"
        elif ($raw | test("^partial")) or $raw == "partial" then
          "partial"
        elif $raw == "failure" or $raw == "insufficient" then
          "failure"
        else
          "unknown"
        end;
    . as $entries
    | (reduce ($entries[] | select(entry_kind == "planned")) as $item
        ({};
         .[$item.contract_id] = ($item.planned_probe_type // $item.executed_probe_type // $item.probe_type // null))) as $planned_types
    | ([ $entries[] | select(entry_kind == "planned") ]) as $planned
    | ([ $entries[] | select(entry_kind == "executed") ]) as $executed
    | ($executed | map(
        . + {
          normalized_probe_type: normalized_probe_type($planned_types),
          normalized_status: normalized_status
        }
      )) as $enriched
    | {
        planned_probe_count: ($planned | length),
        executed_probe_count: ($enriched | length),
        success_count: ($enriched | map(select(.normalized_status == "success")) | length),
        partial_count: ($enriched | map(select(.normalized_status == "partial")) | length),
        failure_count: ($enriched | map(select(.normalized_status == "failure")) | length),
        unknown_count: ($enriched | map(select(.normalized_status == "unknown")) | length),
        success_rate: (if ($enriched | length) > 0 then (($enriched | map(select(.normalized_status == "success")) | length) / ($enriched | length)) else 0 end),
        partial_rate: (if ($enriched | length) > 0 then (($enriched | map(select(.normalized_status == "partial")) | length) / ($enriched | length)) else 0 end),
        failure_rate: (if ($enriched | length) > 0 then (($enriched | map(select(.normalized_status == "failure")) | length) / ($enriched | length)) else 0 end),
        probe_types:
          reduce (($planned | map(.planned_probe_type // .executed_probe_type // .probe_type // "unknown")) + ($enriched | map(.normalized_probe_type)) | unique | sort[]) as $type
            ({};
             ($planned | map(select((.planned_probe_type // .executed_probe_type // .probe_type // "unknown") == $type)) | length) as $planned_count
             | ($enriched | map(select(.normalized_probe_type == $type)) | length) as $executed_count
             | ($enriched | map(select(.normalized_probe_type == $type and .normalized_status == "success")) | length) as $success_count
             | ($enriched | map(select(.normalized_probe_type == $type and .normalized_status == "partial")) | length) as $partial_count
             | ($enriched | map(select(.normalized_probe_type == $type and .normalized_status == "failure")) | length) as $failure_count
             | ($enriched | map(select(.normalized_probe_type == $type and .normalized_status == "unknown")) | length) as $unknown_count
             | .[$type] = {
                 planned: $planned_count,
                 executed: $executed_count,
                 success: $success_count,
                 partial: $partial_count,
                 failure: $failure_count,
                 unknown: $unknown_count,
                 success_rate: (if $executed_count > 0 then ($success_count / $executed_count) else 0 end),
                 partial_rate: (if $executed_count > 0 then ($partial_count / $executed_count) else 0 end),
                 failure_rate: (if $executed_count > 0 then ($failure_count / $executed_count) else 0 end)
               })
      }
  ' "$ledger_path"
}

ledger_source_count() {
  local ledger_path="${1:?Missing ledger path}"
  jq -cs '
    [
      .[]
      | .source_ids[]?, .evidence_refs[]?
      | select(type == "string" and test("^src"))
    ]
    | unique
    | length
  ' "$ledger_path"
}

ledger_executed_count() {
  local ledger_path="${1:?Missing ledger path}"
  jq -cs '
    [ .[] | select((.entry_kind // .entry_type // "") == "executed") ]
    | length
  ' "$ledger_path"
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

write_json_file() {
  local file_path="${1:?Missing file path}"
  local content="${2:?Missing content}"
  local tmp_path="${file_path}.tmp"
  mkdir -p "$(dirname "$file_path")"
  printf '%s\n' "$content" >"$tmp_path"
  mv "$tmp_path" "$file_path"
}

action_extract() {
  local session_id="${1:-}"
  local state_path
  local budget_path
  local metrics_path
  local archive_dir_rel
  local archive_dir_abs
  local ledger_path
  local review_path
  local meta_learning_path
  local report_path
  local question
  local mode
  local completed_at
  local updated_at
  local archive_entry
  local budget_json
  local stage_durations
  local probe_metrics
  local lesson_ids
  local deferred_change_ids
  local quality_scores
  local quality_verdict
  local claim_count
  local source_count
  local probe_count
  local metrics_json

  if [[ -z "$session_id" || $# -ne 1 ]]; then
    die_usage "extract requires <session-id>."
  fi

  state_path="$(state_file "$session_id")"
  budget_path="$(budget_file "$session_id")"
  metrics_path="$(metrics_file "$session_id")"

  [[ -f "$state_path" ]] || die_validation "Session state not found for '$session_id'."
  [[ -f "$budget_path" ]] || die_validation "Budget file not found for '$session_id'."
  ensure_completed_state "$state_path"

  archive_dir_rel="$(jq -r '.archive_dir // ""' "$state_path")"
  [[ -n "$archive_dir_rel" ]] || die_validation "Session '$session_id' is missing archive_dir."
  archive_dir_abs="$PROJECT_ROOT/$archive_dir_rel"

  ledger_path="$archive_dir_abs/experiment-ledger.jsonl"
  review_path="$archive_dir_abs/review.md"
  meta_learning_path="$archive_dir_abs/meta-learning.md"
  report_path="$archive_dir_abs/report.md"

  [[ -f "$ledger_path" ]] || die_validation "Missing experiment-ledger.jsonl for '$session_id'."
  [[ -f "$review_path" ]] || die_validation "Missing review.md for '$session_id'."
  [[ -f "$meta_learning_path" ]] || die_validation "Missing meta-learning.md for '$session_id'."
  [[ -f "$report_path" ]] || die_validation "Missing report.md for '$session_id'."

  question="$(jq -r '.question // ""' "$state_path")"
  mode="$(jq -r '.mode // "literature-only"' "$state_path")"
  completed_at="$(jq -r '.completed_at // ""' "$state_path")"
  updated_at="$(timestamp_utc)"
  archive_entry="$(archive_entry_json "$session_id")"

  budget_json="$(budget_detail_json "$budget_path")"
  stage_durations="$(stage_durations_json "$budget_path" "$state_path")"
  probe_metrics="$(probe_metrics_json "$ledger_path")"
  lesson_ids="$(prefixed_heading_ids_json "$meta_learning_path" "ML-")"
  deferred_change_ids="$(prefixed_heading_ids_json "$meta_learning_path" "DC-")"

  if [[ "$(jq -r 'type == "object"' <<<"$archive_entry")" == "true" ]]; then
    quality_scores="$(jq -c '.review_scores // {}' <<<"$archive_entry")"
    quality_verdict="$(jq -r '.verdict // ""' <<<"$archive_entry")"
    claim_count="$(jq -r '(.claims // []) | length' <<<"$archive_entry")"
    source_count="$(jq -r '
      if .source_count != null then
        .source_count
      else
        empty
      end
    ' <<<"$archive_entry")"
    probe_count="$(jq -r '
      if .probe_count != null then
        .probe_count
      else
        empty
      end
    ' <<<"$archive_entry")"
  else
    quality_scores="{}"
    quality_verdict=""
    claim_count=""
    source_count=""
    probe_count=""
  fi

  if [[ -z "$quality_verdict" ]]; then
    quality_verdict="$(review_verdict "$review_path")"
  fi
  if [[ "$quality_scores" == "{}" ]]; then
    quality_scores="$(review_scores_json "$review_path")"
  fi
  if [[ -z "$claim_count" ]]; then
    claim_count="$(claim_count_from_report "$report_path")"
  fi
  if [[ -z "$source_count" ]]; then
    source_count="$(jq -r '.final_summary.total_sources // empty' "$state_path")"
  fi
  if [[ -z "$probe_count" ]]; then
    probe_count="$(jq -r '.final_summary.total_probes // empty' "$state_path")"
  fi
  if [[ -z "$source_count" ]]; then
    source_count="$(ledger_source_count "$ledger_path")"
  fi
  if [[ -z "$probe_count" ]]; then
    probe_count="$(ledger_executed_count "$ledger_path")"
  fi

  metrics_json="$(jq -n \
    --arg schema_version "rnd-study-metrics.v1" \
    --arg study_id "$session_id" \
    --arg artifact "study-metrics.json" \
    --arg producer_stage "meta-learn" \
    --arg updated_at "$updated_at" \
    --arg question "$question" \
    --arg mode "$mode" \
    --arg study_path "$archive_dir_rel" \
    --arg completed_at "$completed_at" \
    --arg verdict "$quality_verdict" \
    --argjson budget "$budget_json" \
    --argjson stage_durations "$stage_durations" \
    --argjson resource_efficiency "$probe_metrics" \
    --argjson quality_scores "$quality_scores" \
    --argjson claim_count "$claim_count" \
    --argjson source_count "$source_count" \
    --argjson probe_count "$probe_count" \
    --argjson lesson_ids "$lesson_ids" \
    --argjson deferred_change_ids "$deferred_change_ids" \
    '
      {
        schema_version: $schema_version,
        study_id: $study_id,
        artifact: $artifact,
        producer_stage: $producer_stage,
        updated_at: $updated_at,
        question: $question,
        mode: $mode,
        study_path: $study_path,
        completed_at: (if $completed_at == "" then null else $completed_at end),
        budget: $budget,
        stage_durations: $stage_durations,
        resource_efficiency: $resource_efficiency,
        quality: {
          verdict: (if $verdict == "" then null else $verdict end),
          scores: {
            C1: ($quality_scores.C1 // null),
            C2: ($quality_scores.C2 // null),
            C3: ($quality_scores.C3 // null),
            C4: ($quality_scores.C4 // null),
            C5: ($quality_scores.C5 // null)
          },
          mean_score: (
            [ $quality_scores.C1, $quality_scores.C2, $quality_scores.C3, $quality_scores.C4, $quality_scores.C5 ]
            | map(select(. != null))
            | if length > 0 then (add / length) else null end
          )
        },
        derived_ratios: {
          claim_count: $claim_count,
          source_count: $source_count,
          probe_count: $probe_count,
          probes_per_claim: (if $claim_count > 0 then ($probe_count / $claim_count) else null end),
          sources_per_claim: (if $claim_count > 0 then ($source_count / $claim_count) else null end),
          sources_per_probe: (if $probe_count > 0 then ($source_count / $probe_count) else null end),
          successful_probe_rate: (if ($resource_efficiency.executed_probe_count // 0) > 0 then (($resource_efficiency.success_count // 0) / $resource_efficiency.executed_probe_count) else null end),
          partial_or_better_probe_rate: (if ($resource_efficiency.executed_probe_count // 0) > 0 then ((($resource_efficiency.success_count // 0) + ($resource_efficiency.partial_count // 0)) / $resource_efficiency.executed_probe_count) else null end)
        },
        meta_learning: {
          lesson_count: ($lesson_ids | length),
          lesson_ids: $lesson_ids,
          deferred_change_count: ($deferred_change_ids | length),
          deferred_change_ids: $deferred_change_ids
        },
        process_signals: {
          loopbacks_used: 0,
          critic_revision_fires: (
            if ($verdict == "release" or $verdict == "") then
              0
            else
              1
            end
          ),
          budget_exhausted_dimensions: [
            if ($budget.wall_clock.utilization // 0) >= 1 then "wall_clock" else empty end,
            if ($budget.web_search.utilization // 0) >= 1 then "web_search" else empty end,
            if ($budget.web_fetch.utilization // 0) >= 1 then "web_fetch" else empty end,
            if ($budget.model_route.utilization // 0) >= 1 then "model_route" else empty end,
            if ($budget.probes.utilization // 0) >= 1 then "probes" else empty end
          ]
        }
      }
    ')"

  metrics_json="$(jq --argjson loopbacks "$(jq '.usage.loopbacks // 0' "$budget_path")" '
    .process_signals.loopbacks_used = $loopbacks
  ' <<<"$metrics_json")"

  write_json_file "$metrics_path" "$metrics_json"

  echo "Study metrics extracted: $session_id"
  echo "  study_path=$archive_dir_rel"
  echo "  stage_duration_source=$(jq -r '.stage_durations.source' <<<"$metrics_json")"
  echo "  probes=$(jq -r '.resource_efficiency.executed_probe_count' <<<"$metrics_json")"
  echo "  verdict=$(jq -r '.quality.verdict // "unknown"' <<<"$metrics_json")"
}

action_aggregate() {
  local metrics_files=()
  local metrics_path
  local aggregate_json
  local updated_at

  if [[ $# -ne 0 ]]; then
    die_usage "aggregate does not accept extra arguments."
  fi

  while IFS= read -r metrics_path; do
    [[ -n "$metrics_path" ]] || continue
    metrics_files+=("$metrics_path")
  done < <(find "$SESSION_ROOT" -maxdepth 2 -name study-metrics.json -print | sort)

  updated_at="$(timestamp_utc)"

  if [[ ${#metrics_files[@]} -eq 0 ]]; then
    aggregate_json="$(jq --arg updated_at "$updated_at" '
      .updated_at = $updated_at
    ' "$AGGREGATE_TEMPLATE")"
    write_json_file "$AGGREGATE_FILE" "$aggregate_json"
    echo "Meta aggregate updated: 0 studies"
    return 0
  fi

  aggregate_json="$(jq -s --arg schema_version "rnd-meta-aggregate.v1" --arg artifact "meta-aggregate.json" --arg producer_stage "meta-analyze" --arg updated_at "$updated_at" --argjson stages "$STAGES_JSON" '
    def num_series($values):
      ($values | map(select(. != null))) as $vals
      | if ($vals | length) == 0 then
          {mean: null, min: null, max: null, values: []}
        else
          {mean: (($vals | add) / ($vals | length)), min: ($vals | min), max: ($vals | max), values: $vals}
        end;
    . as $studies
    | {
        schema_version: $schema_version,
        artifact: $artifact,
        producer_stage: $producer_stage,
        updated_at: $updated_at,
        study_count: ($studies | length),
        study_ids: ($studies | map(.study_id) | sort),
        budget_utilization_distribution: {
          wall_clock: num_series([ $studies[] | .budget.wall_clock.utilization ]),
          web_search: num_series([ $studies[] | .budget.web_search.utilization ]),
          web_fetch: num_series([ $studies[] | .budget.web_fetch.utilization ]),
          model_route: num_series([ $studies[] | .budget.model_route.utilization ]),
          probes: num_series([ $studies[] | .budget.probes.utilization ])
        },
        stage_time_distribution: reduce $stages[] as $stage
          ({};
           .[$stage] = {
             seconds: num_series([ $studies[] | .stage_durations.stages[$stage].seconds ]),
             fraction: num_series([ $studies[] | .stage_durations.stages[$stage].fraction ])
           }),
        quality_distribution: {
          scores: {
            C1: num_series([ $studies[] | .quality.scores.C1 ]),
            C2: num_series([ $studies[] | .quality.scores.C2 ]),
            C3: num_series([ $studies[] | .quality.scores.C3 ]),
            C4: num_series([ $studies[] | .quality.scores.C4 ]),
            C5: num_series([ $studies[] | .quality.scores.C5 ])
          },
          verdicts: reduce ($studies[] | .quality.verdict // empty) as $verdict
            ({};
             .[$verdict] = ((.[$verdict] // 0) + 1))
        },
        efficiency_trends: {
          probes_per_claim: num_series([ $studies[] | .derived_ratios.probes_per_claim ]),
          sources_per_claim: num_series([ $studies[] | .derived_ratios.sources_per_claim ]),
          sources_per_probe: num_series([ $studies[] | .derived_ratios.sources_per_probe ]),
          successful_probe_rate: num_series([ $studies[] | .derived_ratios.successful_probe_rate ]),
          partial_or_better_probe_rate: num_series([ $studies[] | .derived_ratios.partial_or_better_probe_rate ]),
          probe_type_performance:
            reduce ([ $studies[] | .resource_efficiency.probe_types | keys[]? ] | unique | sort[]) as $type
              ({};
               .[$type] = {
                 study_count: ([ $studies[] | select(.resource_efficiency.probe_types[$type] != null) ] | length),
                 executed_total: ([ $studies[] | .resource_efficiency.probe_types[$type].executed ] | map(select(. != null)) | add // 0),
                 success_total: ([ $studies[] | .resource_efficiency.probe_types[$type].success ] | map(select(. != null)) | add // 0),
                 partial_total: ([ $studies[] | .resource_efficiency.probe_types[$type].partial ] | map(select(. != null)) | add // 0),
                 failure_total: ([ $studies[] | .resource_efficiency.probe_types[$type].failure ] | map(select(. != null)) | add // 0),
                 success_rate: num_series([ $studies[] | .resource_efficiency.probe_types[$type].success_rate ]),
                 partial_rate: num_series([ $studies[] | .resource_efficiency.probe_types[$type].partial_rate ]),
                 failure_rate: num_series([ $studies[] | .resource_efficiency.probe_types[$type].failure_rate ])
               })
        },
        process_patterns: {
          loopbacks_used: num_series([ $studies[] | .process_signals.loopbacks_used ]),
          critic_revision_fires: num_series([ $studies[] | .process_signals.critic_revision_fires ]),
          budget_exhaustion_frequency: reduce ($studies[] | .process_signals.budget_exhausted_dimensions[]?) as $dimension
            ({};
             .[$dimension] = ((.[$dimension] // 0) + 1)),
          stage_duration_sources: reduce ($studies[] | .stage_durations.source // empty) as $source
            ({};
             .[$source] = ((.[$source] // 0) + 1))
        },
        meta_learning_patterns: {
          lesson_count: num_series([ $studies[] | .meta_learning.lesson_count ]),
          deferred_change_count: num_series([ $studies[] | .meta_learning.deferred_change_count ]),
          deferred_change_frequency: reduce ($studies[] | .meta_learning.deferred_change_ids[]?) as $change_id
            ({};
             .[$change_id] = ((.[$change_id] // 0) + 1))
        }
      }
  ' "${metrics_files[@]}")"

  write_json_file "$AGGREGATE_FILE" "$aggregate_json"

  echo "Meta aggregate updated: $(jq -r '.study_count' <<<"$aggregate_json") studies"
  echo "  path=$(path_rel "$AGGREGATE_FILE")"
  echo "  verdicts=$(jq -cr '.quality_distribution.verdicts' <<<"$aggregate_json")"
}

action_status() {
  local completed_count="0"
  local extracted_count="0"
  local aggregate_count="0"
  local aggregate_updated_at=""
  local latest_metrics_updated_at=""
  local staleness="missing"
  local metrics_files=()
  local metrics_path

  if [[ $# -ne 0 ]]; then
    die_usage "status does not accept extra arguments."
  fi

  if [[ -d "$SESSION_ROOT" ]]; then
    completed_count="$(find "$SESSION_ROOT" -maxdepth 2 -name state.json -print | sort | while IFS= read -r state_path; do
      [[ -n "$state_path" ]] || continue
      if [[ "$(jq -r '.run_status // ""' "$state_path")" == "completed" ]]; then
        echo 1
      fi
    done | awk 'END { print NR + 0 }')"
  fi

  while IFS= read -r metrics_path; do
    [[ -n "$metrics_path" ]] || continue
    metrics_files+=("$metrics_path")
  done < <(find "$SESSION_ROOT" -maxdepth 2 -name study-metrics.json -print | sort)

  extracted_count="${#metrics_files[@]}"

  if [[ ${#metrics_files[@]} -gt 0 ]]; then
    latest_metrics_updated_at="$(jq -rs 'map(.updated_at // empty) | sort | last // ""' "${metrics_files[@]}")"
  fi

  if [[ -f "$AGGREGATE_FILE" ]]; then
    aggregate_count="$(jq -r '.study_count // 0' "$AGGREGATE_FILE")"
    aggregate_updated_at="$(jq -r '.updated_at // ""' "$AGGREGATE_FILE")"
    if [[ "$extracted_count" -lt "$completed_count" ]]; then
      staleness="stale"
    elif [[ "$aggregate_count" != "$extracted_count" ]]; then
      staleness="stale"
    elif [[ -n "$latest_metrics_updated_at" && -n "$aggregate_updated_at" && "$latest_metrics_updated_at" > "$aggregate_updated_at" ]]; then
      staleness="stale"
    else
      staleness="current"
    fi
  fi

  echo "=== Meta Research ==="
  echo "Study count: $completed_count"
  echo "Extracted count: $extracted_count"
  echo "Last aggregate time: $aggregate_updated_at"
  echo "Staleness: $staleness"
}

require_jq

case "$ACTION" in
  extract) action_extract "$@" ;;
  aggregate) action_aggregate "$@" ;;
  status) action_status "$@" ;;
  *)
    die_usage "Unknown action '$ACTION'."
    ;;
esac
