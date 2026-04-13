#!/usr/bin/env bash
# Codebase triage diagnostics from git history.

set -euo pipefail

FORMAT="json"
SINCE="1 year ago"
TOP="20"
SCOPE_PATH="."

HIGH_CHURN_TSV=""
AUTHORS_TSV=""
BUG_HOTSPOTS_TSV=""
VELOCITY_TSV=""
CRISIS_TSV=""

usage() {
  cat >&2 <<'EOF'
Usage: codebase-triage.sh [options]

Options:
  --format text|json   Output format (default: json)
  --since <period>     Git --since period (default: "1 year ago")
  --top <n>            Number of ranked files to include (default: 20)
  --path <dir>         Limit diagnostics to a path (default: ".")
  --help               Show this help
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

require_command() {
  local name="${1:?Missing command name}"
  command -v "$name" >/dev/null 2>&1 || die_error "$name is required."
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        [[ $# -ge 2 ]] || die_usage "--format requires a value"
        FORMAT="$2"
        shift 2
        ;;
      --since)
        [[ $# -ge 2 ]] || die_usage "--since requires a value"
        SINCE="$2"
        shift 2
        ;;
      --top)
        [[ $# -ge 2 ]] || die_usage "--top requires a value"
        TOP="$2"
        shift 2
        ;;
      --path)
        [[ $# -ge 2 ]] || die_usage "--path requires a value"
        SCOPE_PATH="$2"
        shift 2
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *)
        die_usage "unknown option: $1"
        ;;
    esac
  done
}

validate_args() {
  case "$FORMAT" in
    json | text) ;;
    *) die_usage "--format must be text or json" ;;
  esac

  case "$TOP" in
    '' | *[!0-9]*) die_usage "--top must be a positive integer" ;;
    0) die_usage "--top must be a positive integer" ;;
  esac

  [[ -n "$SINCE" ]] || die_usage "--since must not be empty"
  [[ -n "$SCOPE_PATH" ]] || die_usage "--path must not be empty"
}

ensure_runtime() {
  require_command git
  require_command jq
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die_error "not inside a git repository."
}

counted_path_rows() {
  awk 'NF > 0' |
    sort |
    uniq -c |
    sort -nr |
    awk -v top="$TOP" '
      NF > 1 && emitted < top {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        printf "%s\t%s\n", count, $0
        emitted++
      }
    '
}

diagnostic_high_churn() {
  git log --format=format: --name-only --since="$SINCE" -- "$SCOPE_PATH" |
    counted_path_rows
}

diagnostic_author_ownership() {
  git shortlog -sn --no-merges --since="$SINCE" HEAD -- "$SCOPE_PATH" |
    awk '
      NF > 1 {
        count = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        printf "%s\t%s\n", count, $0
      }
    '
}

diagnostic_bug_hotspots() {
  git log -i -E --grep="fix|bug|broken|hotfix" --name-only --format='' --since="$SINCE" -- "$SCOPE_PATH" |
    counted_path_rows
}

diagnostic_velocity_curve() {
  git log --format='%ad' --date=format:'%Y-%m' --since="$SINCE" -- "$SCOPE_PATH" |
    sort |
    uniq -c |
    awk '
      NF > 1 {
        printf "%s\t%s\n", $1, $2
      }
    '
}

diagnostic_crisis_detection() {
  local log_output
  log_output="$(git log --oneline --since="$SINCE" -- "$SCOPE_PATH")"

  printf '%s\n' "$log_output" |
    grep -iE 'revert|hotfix|emergency|rollback|BREAKING' |
    awk '
      NF > 1 {
        hash = $1
        $1 = ""
        sub(/^[[:space:]]+/, "")
        printf "%s\t%s\n", hash, $0
      }
    ' || true
}

run_diagnostics() {
  HIGH_CHURN_TSV="$(diagnostic_high_churn)"
  AUTHORS_TSV="$(diagnostic_author_ownership)"
  BUG_HOTSPOTS_TSV="$(diagnostic_bug_hotspots)"
  VELOCITY_TSV="$(diagnostic_velocity_curve)"
  CRISIS_TSV="$(diagnostic_crisis_detection)"
}

build_json() {
  jq -n \
    --arg triage_date "$(timestamp_utc)" \
    --arg since "$SINCE" \
    --arg path "$SCOPE_PATH" \
    --arg high_churn "$HIGH_CHURN_TSV" \
    --arg authors "$AUTHORS_TSV" \
    --arg bug_hotspots "$BUG_HOTSPOTS_TSV" \
    --arg velocity "$VELOCITY_TSV" \
    --arg crisis "$CRISIS_TSV" \
    '
      def lines($text):
        $text | split("\n") | map(select(length > 0));

      def count_file_rows($text; $count_key):
        lines($text)
        | map(split("\t"))
        | map(select(length >= 2) | {file: (.[1:] | join("\t")), ($count_key): (.[0] | tonumber)});

      def author_rows($text):
        lines($text)
        | map(split("\t"))
        | map(select(length >= 2) | {name: (.[1:] | join("\t")), commits: (.[0] | tonumber)});

      def velocity_rows($text):
        lines($text)
        | map(split("\t"))
        | map(select(length >= 2) | {month: .[1], commits: (.[0] | tonumber)});

      def crisis_rows($text):
        lines($text)
        | map(split("\t"))
        | map(select(length >= 2) | {hash: .[0], message: (.[1:] | join("\t"))});

      def avg:
        if length == 0 then 0 else add / length end;

      def month_index($month):
        ($month | split("-")) as $parts
        | (($parts[0] | tonumber) * 12) + ($parts[1] | tonumber);

      def velocity_trend($rows):
        if ($rows | length) == 0 then
          "stable"
        else
          ($rows | map(. + {month_index: month_index(.month)})) as $indexed
          | ($indexed | min_by(.month_index).month_index) as $first_month
          | ($indexed | max_by(.month_index).month_index) as $last_month
          | if (($last_month - $first_month + 1) < 6) then
              "stable"
            else
              ($indexed | reduce .[] as $row ({}; .[($row.month_index | tostring)] = $row.commits)) as $counts
              | [range($last_month - 5; $last_month + 1) | ($counts[(. | tostring)] // 0)] as $last_six
              | ($last_six[0:3] | avg) as $previous_avg
              | ($last_six[3:6] | avg) as $last_avg
              | if $last_avg > $previous_avg then
                  "accelerating"
                elif $last_avg < $previous_avg then
                  "decelerating"
                else
                  "stable"
                end
            end
        end;

      def overlap_count($left; $right):
        ($left | map(.file) | unique) as $left_files
        | ($right | map(.file) | unique) as $right_files
        | [$left_files[] as $file | select($right_files | index($file))]
        | length;

      count_file_rows($high_churn; "changes") as $high_churn_rows
      | author_rows($authors) as $author_rows
      | count_file_rows($bug_hotspots; "bug_commits") as $bug_hotspot_rows
      | velocity_rows($velocity) as $velocity_rows
      | crisis_rows($crisis) as $crisis_rows
      | (($author_rows | map(.commits) | add) // 0) as $author_total
      | {
          triage_date: $triage_date,
          since: $since,
          path: $path,
          high_churn: $high_churn_rows,
          authors: $author_rows,
          bug_hotspots: $bug_hotspot_rows,
          velocity: $velocity_rows,
          crisis_signals: $crisis_rows,
          summary: {
            total_churn_files: ($high_churn_rows | length),
            top_author_pct: (
              if $author_total == 0 then
                0
              else
                (((($author_rows[0].commits // 0) * 1000 / $author_total) | round) / 10)
              end
            ),
            bug_hotspot_overlap: overlap_count($high_churn_rows; $bug_hotspot_rows),
            crisis_count: ($crisis_rows | length),
            velocity_trend: velocity_trend($velocity_rows)
          }
        }
    '
}

output_text() {
  local json="${1:?Missing JSON input}"
  jq -r '
    "Codebase triage",
    "Date: \(.triage_date)",
    "Since: \(.since)",
    "Path: \(.path)",
    "",
    "High-churn files:",
    (if (.high_churn | length) == 0 then "  (none)" else (.high_churn[] | "  \(.changes)\t\(.file)") end),
    "",
    "Author ownership:",
    (if (.authors | length) == 0 then "  (none)" else (.authors[] | "  \(.commits)\t\(.name)") end),
    "",
    "Bug hotspots:",
    (if (.bug_hotspots | length) == 0 then "  (none)" else (.bug_hotspots[] | "  \(.bug_commits)\t\(.file)") end),
    "",
    "Velocity curve:",
    (if (.velocity | length) == 0 then "  (none)" else (.velocity[] | "  \(.commits)\t\(.month)") end),
    "",
    "Crisis signals:",
    (if (.crisis_signals | length) == 0 then "  (none)" else (.crisis_signals[] | "  \(.hash)\t\(.message)") end),
    "",
    "Summary:",
    "  total_churn_files: \(.summary.total_churn_files)",
    "  top_author_pct: \(.summary.top_author_pct)%",
    "  bug_hotspot_overlap: \(.summary.bug_hotspot_overlap)",
    "  crisis_count: \(.summary.crisis_count)",
    "  velocity_trend: \(.summary.velocity_trend)"
  ' <<<"$json"
}

main() {
  parse_args "$@"
  validate_args
  ensure_runtime
  run_diagnostics

  local output_json
  output_json="$(build_json)"

  if [[ "$FORMAT" == "json" ]]; then
    printf '%s\n' "$output_json"
  else
    output_text "$output_json"
  fi
}

main "$@"
