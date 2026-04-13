#!/usr/bin/env bash
# eval-normalize.sh — Normalize evaluation JSON into the canonical internal shape.

set -euo pipefail

usage() {
  printf 'Usage: eval-normalize.sh [json-file|-]\n' >&2
  exit 1
}

if ! command -v jq >/dev/null 2>&1; then
  printf 'Error: jq is required.\n' >&2
  exit 1
fi

if [ "$#" -gt 1 ]; then
  usage
fi

INPUT_PATH="${1:-}"

if [ -n "$INPUT_PATH" ] && [ "$INPUT_PATH" != "-" ] && [ ! -f "$INPUT_PATH" ]; then
  printf 'Error: input file not found: %s\n' "$INPUT_PATH" >&2
  exit 1
fi

read_input() {
  if [ -n "$INPUT_PATH" ] && [ "$INPUT_PATH" != "-" ]; then
    cat "$INPUT_PATH"
    return
  fi

  cat
}

JQ_FILTER="$(
  cat <<'JQ'
def trim_text:
  if . == null then ""
  elif type == "string" then gsub("^\\s+|\\s+$"; "")
  elif type == "array" then
    (
      [
        .[] |
        select(. != null) |
        if type == "string" then
          gsub("^\\s+|\\s+$"; "")
        else
          tostring
        end |
        select(length > 0)
      ] |
      join("\n")
    )
  else
    tostring
  end;

def normalized_score:
  if . == null then null
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
      ascii_downcase | gsub("^\\s+|\\s+$"; "") as $raw |
      if $raw == "-1" then
        -1
      elif ($raw | test("^(1|1\\.0+)$")) then
        1
      elif ($raw | test("^(0|0\\.0+)$")) then
        0
      elif (["pass", "passed", "true", "yes", "met", "meets", "satisfied", "present"] | index($raw)) != null then
        1
      elif (["fail", "failed", "false", "no", "missing", "not met", "unmet", "absent"] | index($raw)) != null then
        0
      else
        null
      end
    )
  elif type == "object" then
    (.score // .value // .result // .passed // .rating // .judgment) | normalized_score
  else
    null
  end;

def normalized_id($fallback):
  (. // $fallback) as $raw |
  if $raw == null then
    null
  else
    (
      $raw |
      tostring |
      ascii_upcase as $text |
      if ($text | test("[A-Z][A-Z0-9]*[0-9]+")) then
        ($text | capture("(?<id>[A-Z][A-Z0-9]*[0-9]+)").id)
      else
        null
      end
    )
  end;

def normalized_boundary_criteria:
  if . == null then
    []
  elif type == "array" then
    [.[]? | normalized_id(.) | select(. != null)] | unique
  elif type == "string" then
    [split(",")[]? | normalized_id(.) | select(. != null)] | unique
  else
    []
  end;

def normalized_evidence:
  if . == null then
    []
  elif type == "array" then
    [
      .[] |
      select(. != null) |
      if type == "string" then
        gsub("^\\s+|\\s+$"; "")
      elif type == "object" then
        (.quote // .text // .content // .evidence // .excerpt // tostring | gsub("^\\s+|\\s+$"; ""))
      else
        (tostring | gsub("^\\s+|\\s+$"; ""))
      end |
      select(length > 0)
    ]
  elif type == "object" then
    (.evidence // .quotes // .items // .support // .supporting_evidence) | normalized_evidence
  elif type == "string" then
    [gsub("^\\s+|\\s+$"; "") | select(length > 0)]
  else
    [tostring]
  end;

def normalized_string_array:
  if . == null then
    []
  elif type == "array" then
    [
      .[] |
      select(. != null) |
      trim_text |
      select(length > 0)
    ]
  else
    [trim_text | select(length > 0)]
  end;

def normalized_priority:
  if . == null then
    "MED"
  else
    (
      if type == "string" then
        ascii_upcase | gsub("^\\s+|\\s+$"; "")
      else
        tostring | ascii_upcase
      end as $raw |
      if ($raw | startswith("HIGH")) then
        "HIGH"
      elif ($raw | startswith("LOW")) then
        "LOW"
      else
        "MED"
      end
    )
  end;

def criteria_source:
  .criteria // .criterion_results // .results // .judgments // .evaluation?.criteria // .scorecard?.criteria;

def criteria_items:
  (criteria_source) as $source |
  if $source == null then
    []
  elif ($source | type) == "array" then
    $source
  elif ($source | type) == "object" and (($source.items? // null) | type) == "array" then
    $source.items
  elif ($source | type) == "object" and ($source.by_id? != null) then
    (
      $source.by_id |
      if type == "array" then
        .
      elif type == "object" then
        to_entries |
        map(
          if (.value | type) == "object" then
            (.value + {__fallback_id: .key})
          else
            {id: .key, score: .value}
          end
        )
      else
        []
      end
    )
  elif ($source | type) == "object" then
    (
      $source |
      to_entries |
      map(
        if (.value | type) == "object" then
          (.value + {__fallback_id: .key})
        else
          {id: .key, score: .value}
        end
      )
    )
  else
    []
  end;

def normalized_criteria:
  [
    criteria_items[]? |
    . as $item |
    {
      id: normalized_id($item.id // $item.criterion_id // $item.criterion // $item.name // $item.__fallback_id),
      score: (($item.score // $item.value // $item.result // $item.passed // $item.judgment // $item.rating) | normalized_score),
      evidence: (($item.evidence // $item.evidences // $item.citations // $item.quotes // $item.quote // $item.support // $item.supporting_evidence // $item.observations) | normalized_evidence),
      reasoning: (($item.reasoning // $item.rationale // $item.reason // $item.analysis // $item.explanation // $item.summary) | trim_text)
    } |
    select(.id != null and .score != null)
  ];

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

def priority_rank($priority):
  if $priority == "HIGH" then
    0
  elif $priority == "MED" then
    1
  else
    2
  end;

def tier_items($criteria; $prefix):
  [$criteria[] | select(criterion_prefix(.id) == $prefix)];

def tier_pair($criteria; $prefix):
  (tier_items($criteria; $prefix)) as $items |
  if ($items | length) == 0 then
    null
  else
    [
      ($items | map(select(.score == 1)) | length),
      ($items | map(.id | criterion_number(.)) | max)
    ]
  end;

def static_thresholds($qmax; $emax):
  if $qmax >= 7 or $emax >= 4 then
    {q_low: 3, q_high: 6, e_high: 3}
  elif $qmax == 6 then
    {q_low: 2, q_high: 5, e_high: 2}
  elif $qmax == 5 then
    {q_low: 2, q_high: 4, e_high: 2}
  else
    {q_low: 0, q_high: 0, e_high: 0}
  end;

def level_label($level):
  if $level == 4 then
    "Excellent"
  elif $level == 3 then
    "Good"
  elif $level == 2 then
    "Needs Work"
  else
    "Poor"
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

def grouped_scores($criteria):
  reduce (
    $criteria |
    map(criterion_prefix(.id)) |
    unique |
    sort_by([criterion_order(.), .])[]
  ) as $prefix (
    {};
    .[$prefix] = (tier_pair($criteria; $prefix) // [0, 0])
  );

def normalized_improvements:
  (
    .improvements //
    .recommendations //
    .actions //
    .next_steps //
    []
  ) as $source |
  if ($source | type) == "array" then
    $source
  elif ($source | type) == "object" then
    ($source | to_entries | map(.value))
  else
    []
  end |
  [
    .[]? |
    . as $item |
    {
      priority: (($item.priority // $item.severity // $item.importance) | normalized_priority),
      criterion_id: normalized_id($item.criterion_id // $item.criterion // $item.id // $item.target),
      description: (($item.description // $item.reasoning // $item.summary // $item.text // $item.recommendation) | trim_text)
    } |
    select(.description != "")
  ] |
  sort_by([priority_rank(.priority), (.criterion_id // "ZZZ"), .description]);

normalized_criteria as $criteria |
if ($criteria | length) == 0 then
  error("criteria missing or unparseable")
else
  ($criteria | sort_by([criterion_order(.id), criterion_number(.id)])) as $sorted_criteria |
  ((.boundary_criteria // .evaluation?.boundary_criteria // .scorecard?.boundary_criteria) | normalized_boundary_criteria) as $boundary_criteria |
  ($sorted_criteria | map(select(.id | startswith("F"))) | length) as $f_count |
  ($sorted_criteria | map(select(.id | startswith("Q"))) | length) as $q_count |
  ($sorted_criteria | map(select(.id | startswith("E"))) | length) as $e_count |
  if ($f_count + $q_count + $e_count) > 0 then
    (tier_pair($sorted_criteria; "F") // [0, 0]) as $foundation |
    (tier_pair($sorted_criteria; "Q")) as $craft |
    (tier_pair($sorted_criteria; "E")) as $excellence |
    ($foundation[0]) as $foundation_score |
    ($foundation[1]) as $foundation_max |
    (($craft // [0, 0])[0]) as $craft_score |
    (($craft // [0, 0])[1]) as $craft_max |
    (($excellence // [0, 0])[0]) as $excellence_score |
    (($excellence // [0, 0])[1]) as $excellence_max |
    (static_thresholds($craft_max; $excellence_max)) as $thresholds |
    (
      if $foundation_score <= 3 then
        {
          level: 1,
          gated: true,
          gate_reason: "Foundation score " + ($foundation_score | tostring) + "/" + ($foundation_max | tostring) + " failed the minimum gate (<=3)."
        }
      elif $foundation_score < $foundation_max then
        {
          level: 2,
          gated: true,
          gate_reason: "Foundation score " + ($foundation_score | tostring) + "/" + ($foundation_max | tostring) + " is incomplete, so the result is capped at Level 2."
        }
      elif $craft_max == 0 then
        {
          level: 3,
          gated: false,
          gate_reason: null
        }
      elif $craft_score <= $thresholds.q_low then
        {
          level: 2,
          gated: true,
          gate_reason: "Craft score " + ($craft_score | tostring) + "/" + ($craft_max | tostring) + " did not clear the Level 3 threshold (> " + ($thresholds.q_low | tostring) + ")."
        }
      elif $craft_score < $thresholds.q_high then
        {
          level: 3,
          gated: true,
          gate_reason: "Craft score " + ($craft_score | tostring) + "/" + ($craft_max | tostring) + " did not clear the Excellence gate (>= " + ($thresholds.q_high | tostring) + ")."
        }
      elif $excellence_max == 0 then
        {
          level: 4,
          gated: false,
          gate_reason: null
        }
      elif $excellence_score < $thresholds.e_high then
        {
          level: 3,
          gated: true,
          gate_reason: "Excellence score " + ($excellence_score | tostring) + "/" + ($excellence_max | tostring) + " did not clear the Level 4 threshold (>= " + ($thresholds.e_high | tostring) + ")."
        }
      else
        {
          level: 4,
          gated: false,
          gate_reason: null
        }
      end
    ) as $gate |
    {
      path: (.path // .component // .component_path // null),
      type: (.type // .component_type // null),
      mode: (.mode // null),
      multi_model: (.multi_model // null),
      schema_version: "eval-normalized-result.v1",
      criteria: $sorted_criteria,
      scores: (
        {F: $foundation} +
        (if $craft_max > 0 then {Q: [$craft_score, $craft_max]} else {} end) +
        (if $excellence_max > 0 then {E: [$excellence_score, $excellence_max]} else {} end)
      ),
      level: $gate.level,
      level_label: level_label($gate.level),
      gated: $gate.gated,
      gate_reason: $gate.gate_reason,
      strengths: (.strengths // .highlights // .wins) | normalized_string_array,
      improvements: normalized_improvements
    }
    + (
        if ($boundary_criteria | length) > 0 then
          {boundary_criteria: $boundary_criteria}
        else
          {}
        end
      )
  else
    (grouped_scores($sorted_criteria)) as $scores |
    ($scores | to_entries | map(.value[0]) | add) as $earned |
    ($scores | to_entries | map(.value[1]) | add) as $maximum |
    (flat_level($earned; $maximum)) as $flat_level |
    {
      path: (.path // .component // .component_path // null),
      type: (.type // .component_type // null),
      mode: (.mode // null),
      multi_model: (.multi_model // null),
      schema_version: "eval-normalized-result.v1",
      criteria: $sorted_criteria,
      scores: $scores,
      level: $flat_level,
      level_label: level_label($flat_level),
      gated: false,
      gate_reason: null,
      strengths: (.strengths // .highlights // .wins) | normalized_string_array,
      improvements: normalized_improvements
    }
    + (
        if ($boundary_criteria | length) > 0 then
          {boundary_criteria: $boundary_criteria}
        else
          {}
        end
      )
  end
end
JQ
)"

if ! read_input | jq -e "$JQ_FILTER"; then
  printf 'Error: criteria missing or unparseable.\n' >&2
  exit 1
fi
