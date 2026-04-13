#!/usr/bin/env bash
# eval-consensus.sh — Merge two normalized evaluator results into a consensus JSON.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: eval-consensus.sh <model-a-json> <model-b-json> [--boundary <id1,id2,...>] [-o <output-path>]
EOF
  exit 1
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_tool jq

OUTPUT_PATH=""
BOUNDARY_CSV=""
POSITIONAL=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --boundary)
      [ "$#" -ge 2 ] || usage
      BOUNDARY_CSV="$2"
      shift 2
      ;;
    -o)
      [ "$#" -ge 2 ] || usage
      OUTPUT_PATH="$2"
      shift 2
      ;;
    -)
      POSITIONAL+=("$1")
      shift
      ;;
    -h | --help)
      usage
      ;;
    --)
      shift
      while [ "$#" -gt 0 ]; do
        POSITIONAL+=("$1")
        shift
      done
      ;;
    -*)
      fail "unknown option: $1"
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

[ "${#POSITIONAL[@]}" -eq 2 ] || usage

INPUT_A="${POSITIONAL[0]}"
INPUT_B="${POSITIONAL[1]}"

if [ "$INPUT_A" = "-" ] && [ "$INPUT_B" = "-" ]; then
  fail "only one input may be '-'"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/eval-consensus.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

resolve_input() {
  local input_path="${1:-}"
  local slot="${2:-input}"
  local resolved_path=""

  if [ "$input_path" = "-" ]; then
    resolved_path="$TMP_DIR/${slot}.json"
    cat >"$resolved_path"
    printf '%s\n' "$resolved_path"
    return 0
  fi

  [ -f "$input_path" ] || fail "input file not found: $input_path"
  printf '%s\n' "$input_path"
}

INPUT_A_PATH="$(resolve_input "$INPUT_A" "model-a")"
INPUT_B_PATH="$(resolve_input "$INPUT_B" "model-b")"

JQ_FILTER="$(
  cat <<'JQ'
def trim_text:
  if . == null then
    ""
  elif type == "string" then
    gsub("^\\s+|\\s+$"; "")
  else
    tostring | gsub("^\\s+|\\s+$"; "")
  end;

def normalized_score:
  if . == null then
    null
  elif type == "number" then
    if . == -1 then
      -1
    elif . >= 1 then
      1
    elif . == 0 then
      0
    else
      null
    end
  elif type == "boolean" then
    if . then 1 else 0 end
  elif type == "string" then
    (
      ascii_downcase | gsub("^\\s+|\\s+$"; "")
    ) as $raw |
    if $raw == "-1" then
      -1
    elif ($raw | test("^(1|1\\.0+)$")) then
      1
    elif ($raw | test("^(0|0\\.0+)$")) then
      0
    elif (["pass", "passed", "true", "yes", "met", "meets", "present", "satisfied"] | index($raw)) != null then
      1
    elif (["fail", "failed", "false", "no", "missing", "absent", "unmet"] | index($raw)) != null then
      0
    else
      null
    end
  else
    null
  end;

def normalized_id($raw):
  if $raw == null then
    null
  else
    (
      $raw |
      tostring |
      ascii_upcase
    ) as $text |
    if ($text | test("[A-Z][A-Z0-9]*[0-9]+")) then
      ($text | capture("(?<id>[A-Z][A-Z0-9]*[0-9]+)").id)
    else
      null
    end
  end;

def normalized_boundary_ids:
  if . == null then
    []
  elif type == "array" then
    [.[]? | normalized_id(.) | select(. != null)] | unique
  elif type == "string" then
    [split(",")[]? | normalized_id(.) | select(. != null)] | unique
  else
    []
  end;

def criterion_id:
  (.id // .name // .criterion_id // .criterion // .target // null) as $raw |
  normalized_id($raw);

def criterion_prefix($id):
  ($id | tostring | ascii_upcase | sub("[0-9]+$"; ""));

def criterion_order($id):
  if (criterion_prefix($id)) == "F" then
    0
  elif (criterion_prefix($id)) == "Q" then
    1
  elif (criterion_prefix($id)) == "E" then
    2
  elif (criterion_prefix($id)) == "C" then
    3
  else
    4
  end;

def criterion_number($id):
  (($id | tostring | match("[0-9]+$")?.string) // "0") | tonumber;

def ordered_ids:
  sort_by([criterion_order(.), criterion_number(.), .]);

def round_rate:
  ((. * 10000) | round) / 10000;

def display_model_name:
  (trim_text) as $raw |
  if $raw == "" then
    "Model"
  else
    (
      $raw |
      gsub("[_-]+"; " ") |
      split(" ") |
      map(
        if . == "" then
          .
        else
          (.[0:1] | ascii_upcase) + .[1:]
        end
      ) |
      join(" ")
    )
  end;

def criterion_reasoning:
  (trim_text) as $text |
  if $text == "" then
    "no reasoning provided"
  else
    $text
  end;

def normalized_criteria:
  [
    (.criteria // [])[]? |
    . as $item |
    {
      id: criterion_id,
      score: (($item.score // $item.value // $item.result // $item.passed // $item.judgment // $item.rating) | normalized_score),
      reasoning: (($item.reasoning // $item.rationale // $item.reason // $item.analysis // $item.explanation) | criterion_reasoning)
    } |
    select(.id != null and .score != null)
  ];

def ensure_unique($criteria; $label):
  if ($criteria | map(.id) | unique | length) != ($criteria | length) then
    error($label + " criteria contain duplicate ids")
  else
    $criteria
  end;

def criteria_map($criteria):
  reduce $criteria[] as $criterion (
    {};
    .[$criterion.id] = {
      score: $criterion.score,
      reasoning: $criterion.reasoning
    }
  );

def boundary_criterion($id; $boundary_ids):
  ($boundary_ids | index($id)) != null;

def criteria_tier_pair($criteria; $prefix):
  ([$criteria[] | select(criterion_prefix(.name) == $prefix)]) as $items |
  if ($items | length) == 0 then
    null
  else
    [
      ($items | map(select(.score == 1)) | length),
      ($items | map(criterion_number(.name)) | max)
    ]
  end;

def flat_level($earned; $maximum):
  if $earned >= $maximum then
    4
  elif $earned == ($maximum - 1) then
    3
  elif $earned >= 2 then
    2
  else
    1
  end;

def command_level($f_score; $q_score; $e_score):
  if $f_score <= 3 then
    1
  elif $f_score == 4 then
    2
  elif $f_score == 5 and $q_score <= 3 then
    2
  elif $f_score == 5 and $q_score <= 5 then
    3
  elif $f_score == 5 and $q_score >= 6 and $e_score <= 2 then
    3
  elif $f_score == 5 and $q_score >= 6 and $e_score >= 3 then
    4
  else
    1
  end;

def consensus_summary($criteria):
  ($criteria | map(criterion_prefix(.name))) as $prefixes |
  if ($prefixes | any(. == "F" or . == "Q" or . == "E")) then
    ($criteria | map(select(criterion_prefix(.name) == "F") | select(.score == 1)) | length) as $f_score |
    ($criteria | map(select(criterion_prefix(.name) == "Q") | select(.score == 1)) | length) as $q_score |
    ($criteria | map(select(criterion_prefix(.name) == "E") | select(.score == 1)) | length) as $e_score |
    {
      level: command_level($f_score; $q_score; $e_score),
      f_score: $f_score,
      q_score: $q_score,
      e_score: $e_score
    }
  else
    reduce (
      $criteria |
      map(criterion_prefix(.name)) |
      unique |
      sort_by([criterion_order(.), .])[]
    ) as $prefix (
      {earned: 0, maximum: 0};
      (criteria_tier_pair($criteria; $prefix) // [0, 0]) as $pair |
      .earned += $pair[0] |
      .maximum += $pair[1]
    ) as $totals |
    {
      level: flat_level($totals.earned; $totals.maximum),
      f_score: 0,
      q_score: 0,
      e_score: 0
    }
  end;

def criterion_result($id; $model_a_name; $model_b_name; $map_a; $map_b; $boundary_ids):
  ($map_a[$id]) as $left |
  ($map_b[$id]) as $right |
  if $left.score == $right.score then
    {
      name: $id,
      score: $left.score,
      reasoning: "consensus"
    }
  elif boundary_criterion($id; $boundary_ids) then
    {
      name: $id,
      score: ([$left.score, $right.score] | min),
      reasoning:
        (
          ($model_a_name | display_model_name) + "(" + ($left.score | tostring) + "): " + $left.reasoning +
          " | " +
          ($model_b_name | display_model_name) + "(" + ($right.score | tostring) + "): " + $right.reasoning
        ),
      split: true
    }
  else
    (
      if $left.score <= $right.score then
        {
          model: $model_a_name,
          score: $left.score,
          reasoning: $left.reasoning
        }
      else
        {
          model: $model_b_name,
          score: $right.score,
          reasoning: $right.reasoning
        }
      end
    ) as $lower |
    {
      name: $id,
      score: $lower.score,
      reasoning:
        (
          ($lower.model | display_model_name) + "(" + ($lower.score | tostring) + "): " + $lower.reasoning
        )
    }
  end;

$model_a[0] as $doc_a |
$model_b[0] as $doc_b |
if $doc_a == null or $doc_b == null then
  error("two input documents are required")
else
  ($doc_a.path // null) as $path_a |
  ($doc_b.path // null) as $path_b |
  ($doc_a.type // null) as $type_a |
  ($doc_b.type // null) as $type_b |
  ($doc_a.mode // null) as $mode_a |
  ($doc_b.mode // null) as $mode_b |
  if $path_a == null or $path_b == null then
    error("path missing in one or both inputs")
  elif $path_a != $path_b then
    error("path mismatch between inputs")
  elif $type_a == null and $type_b == null then
    error("type missing in one or both inputs")
  elif ($type_a != null and $type_b != null and $type_a != $type_b) then
    error("type mismatch between inputs")
  elif ($mode_a != null and $mode_b != null and $mode_a != $mode_b) then
    error("mode mismatch between inputs")
  else
    (ensure_unique($doc_a | normalized_criteria; "model_a")) as $criteria_a |
    (ensure_unique($doc_b | normalized_criteria; "model_b")) as $criteria_b |
    if ($criteria_a | length) == 0 or ($criteria_b | length) == 0 then
      error("criteria missing or unparseable")
    else
      ($criteria_a | map(.id) | ordered_ids) as $ids_a |
      ($criteria_b | map(.id) | ordered_ids) as $ids_b |
      if $ids_a != $ids_b then
        error("criteria mismatch between inputs")
      else
        ($boundary_csv | normalized_boundary_ids) as $cli_boundary_ids |
        ($doc_a.boundary_criteria | normalized_boundary_ids) as $boundary_ids_a |
        ($doc_b.boundary_criteria | normalized_boundary_ids) as $boundary_ids_b |
        (
          if ($cli_boundary_ids | length) > 0 then
            $cli_boundary_ids
          elif ($boundary_ids_a | length) > 0 and ($boundary_ids_b | length) > 0 and $boundary_ids_a != $boundary_ids_b then
            error("boundary criteria mismatch between inputs")
          elif ($boundary_ids_a | length) > 0 then
            $boundary_ids_a
          elif ($boundary_ids_b | length) > 0 then
            $boundary_ids_b
          else
            ["F3", "Q5", "E1", "E2", "E3"]
          end
        ) as $boundary_ids |
        ($doc_a.model // "model_a") as $model_a_name |
        ($doc_b.model // "model_b") as $model_b_name |
        (criteria_map($criteria_a)) as $map_a |
        (criteria_map($criteria_b)) as $map_b |
        ($ids_a | map(criterion_result(.; $model_a_name; $model_b_name; $map_a; $map_b; $boundary_ids))) as $criteria |
        (consensus_summary($criteria)) as $summary |
        ([$ids_a[] | select($map_a[.].score != $map_b[.].score)] | length) as $splits |
        {
          path: $path_a,
          type: ($type_a // $type_b),
          mode: ($mode_a // $mode_b // "static"),
          multi_model: true,
          models: [$model_a_name, $model_b_name],
          criteria: $criteria,
          level: $summary.level,
          f_score: $summary.f_score,
          q_score: $summary.q_score,
          e_score: $summary.e_score,
          splits: $splits,
          agreement_rate:
            (
              if ($ids_a | length) == 0 then
                0
              else
                ((($ids_a | length) - $splits) / ($ids_a | length) | round_rate)
              end
            )
        }
      end
    end
  end
end
JQ
)"

if [ -n "$OUTPUT_PATH" ]; then
  jq -n \
    --arg boundary_csv "$BOUNDARY_CSV" \
    --slurpfile model_a "$INPUT_A_PATH" \
    --slurpfile model_b "$INPUT_B_PATH" \
    "$JQ_FILTER" >"$OUTPUT_PATH"
else
  jq -n \
    --arg boundary_csv "$BOUNDARY_CSV" \
    --slurpfile model_a "$INPUT_A_PATH" \
    --slurpfile model_b "$INPUT_B_PATH" \
    "$JQ_FILTER"
fi
