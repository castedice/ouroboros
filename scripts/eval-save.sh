#!/usr/bin/env bash
# Persist normalized evaluation results through the canonical regression pipeline.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/learning-lib.sh"

REGRESSION_SCRIPT="$SCRIPT_DIR/regression.sh"
HOOK_SCRIPT="$SCRIPT_DIR/hook-eval-result.sh"
LEARNING_SCRIPT="$SCRIPT_DIR/learning-ingest-eval.sh"
PROJECT_ROOT="$(learning_project_root)"

usage() {
  cat >&2 <<'EOF'
Usage: eval-save.sh <module|auto> <normalized-json-file>... [--criteria-version <ver>] [--models <model-spec>...]
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

append_unique_model() {
  local candidate="${1:-}"
  local existing=""

  [ -n "$candidate" ] || return 0

  for existing in "${MODELS[@]:-}"; do
    if [ "$existing" = "$candidate" ]; then
      return 0
    fi
  done

  MODELS+=("$candidate")
}

append_unique_criteria_file() {
  local candidate="${1:-}"
  local existing=""

  [ -n "$candidate" ] || return 0

  for existing in "${CRITERIA_FILES[@]:-}"; do
    if [ "$existing" = "$candidate" ]; then
      return 0
    fi
  done

  CRITERIA_FILES+=("$candidate")
}

normalize_component_path() {
  local raw_path="${1:-}"
  local normalized_path=""

  [ -n "$raw_path" ] || return 1

  normalized_path="$(learning_normalize_component_path "$raw_path" 2>/dev/null || printf '%s' "$raw_path")"
  printf '%s\n' "$normalized_path"
}

resolve_component_file() {
  local component_path="${1:-}"

  [ -n "$component_path" ] || return 1

  if [ -f "$component_path" ]; then
    printf '%s\n' "$component_path"
    return 0
  fi

  if [ -f "$PROJECT_ROOT/$component_path" ]; then
    printf '%s\n' "$PROJECT_ROOT/$component_path"
    return 0
  fi

  return 1
}

infer_component_type() {
  local component_path="${1:-}"

  case "$component_path" in
    commands/*)
      printf 'command\n'
      ;;
    agents/*)
      printf 'agent\n'
      ;;
    skills/*)
      printf 'skill\n'
      ;;
    templates/*)
      printf 'template\n'
      ;;
    hooks/*)
      printf 'hook\n'
      ;;
    CLAUDE.md | AGENTS.md)
      printf 'claudemd\n'
      ;;
    *)
      return 1
      ;;
  esac
}

infer_module_from_path() {
  local component_path="${1:-}"

  case "$component_path" in
    commands/core/* | agents/core/* | skills/core/* | templates/core/* | CLAUDE.md | AGENTS.md | hooks/*)
      printf 'core\n'
      ;;
    commands/swe/* | agents/swe/* | skills/swe/* | templates/swe/*)
      printf 'swe\n'
      ;;
    commands/pa/* | agents/pa/* | skills/pa/* | templates/pa/*)
      printf 'pa\n'
      ;;
    commands/*/* | agents/*/* | skills/*/* | templates/*/*)
      printf '%s\n' "$component_path" | cut -d/ -f2
      ;;
    *)
      return 1
      ;;
  esac
}

infer_model_name() {
  local model_id="${1:-}"

  case "$model_id" in
    claude*)
      printf 'claude\n'
      ;;
    gpt-* | codex* | o1* | o3* | o4*)
      printf 'codex\n'
      ;;
    *)
      printf '%s\n' "$model_id"
      ;;
  esac
}

build_model_metadata_json() {
  local model_lines_file="$TMP_DIR/model-lines.jsonl"
  local model_spec=""
  local model_id=""
  local effort=""
  local model_name=""

  : >"$model_lines_file"

  for model_spec in "${MODELS[@]:-}"; do
    [ -n "$model_spec" ] || continue
    model_id="${model_spec%%:*}"
    effort=""
    if [ "$model_id" != "$model_spec" ]; then
      effort="${model_spec#*:}"
    fi
    model_name="$(infer_model_name "$model_id")"
    if [ -n "$effort" ]; then
      jq -cn --arg name "$model_name" --arg model_id "$model_id" --arg effort "$effort" '{name:$name,model_id:$model_id,effort:$effort}' >>"$model_lines_file"
    else
      jq -cn --arg name "$model_name" --arg model_id "$model_id" '{name:$name,model_id:$model_id}' >>"$model_lines_file"
    fi
  done

  if [ ! -s "$model_lines_file" ]; then
    printf 'null\n'
    return 0
  fi

  jq -s '{models:.}' "$model_lines_file"
}

criteria_map_json_path() {
  local criteria_file="${1:?Missing criteria file}"
  local map_name=""
  local map_path=""

  map_name="$(basename "$criteria_file" .md)"
  map_name="${map_name//[^A-Za-z0-9._-]/_}"
  map_path="$TMP_DIR/${map_name}.criteria-map.json"

  if [ -f "$map_path" ]; then
    printf '%s\n' "$map_path"
    return 0
  fi

  awk '
    BEGIN {
      printf "{"
      sep = ""
    }
    /^### [A-Z][0-9]+: / {
      line = $0
      sub(/^### /, "", line)
      id = line
      sub(/: .*/, "", id)
      name = line
      sub(/^[A-Z][0-9]+: /, "", name)
      gsub(/\\/, "\\\\", name)
      gsub(/"/, "\\\"", name)
      printf "%s\"%s\":\"%s\"", sep, id, name
      sep = ","
    }
    END {
      print "}"
    }
  ' "$criteria_file" >"$map_path"

  printf '%s\n' "$map_path"
}

criteria_scope_for_component() {
  local component_json="${1:?Missing component json path}"

  if jq -e '((.scores // {}) | keys_unsorted) == ["C"]' "$component_json" >/dev/null 2>&1; then
    printf 'output\n'
    return 0
  fi

  printf 'static\n'
}

criteria_file_for() {
  local component_type="${1:?Missing component type}"
  local scope="${2:?Missing criteria scope}"
  local criteria_file=""

  if [ "$scope" = "output" ]; then
    criteria_file="$PROJECT_ROOT/skills/core/evaluation/references/${component_type}-output-criteria.md"
  else
    criteria_file="$PROJECT_ROOT/skills/core/evaluation/references/${component_type}-criteria.md"
  fi

  [ -f "$criteria_file" ] || fail "criteria file not found: $criteria_file"
  printf '%s\n' "$criteria_file"
}

file_epoch_mtime() {
  local target_file="${1:?Missing file path}"

  if stat -f %m "$target_file" >/dev/null 2>&1; then
    stat -f %m "$target_file"
    return 0
  fi

  if stat -c %Y "$target_file" >/dev/null 2>&1; then
    stat -c %Y "$target_file"
    return 0
  fi

  return 1
}

epoch_to_utc_date() {
  local epoch="${1:?Missing epoch}"

  if date -u -r "$epoch" +%Y-%m-%d >/dev/null 2>&1; then
    date -u -r "$epoch" +%Y-%m-%d
    return 0
  fi

  if date -u -d "@$epoch" +%Y-%m-%d >/dev/null 2>&1; then
    date -u -d "@$epoch" +%Y-%m-%d
    return 0
  fi

  return 1
}

derive_criteria_version() {
  local signature_file="$TMP_DIR/criteria-signature.txt"
  local criteria_file=""
  local epoch=""
  local date_token=""
  local latest_epoch=0
  local latest_date=""
  local signature_hash=""

  if [ ${#CRITERIA_FILES[@]} -eq 0 ]; then
    printf 'criteria-manual-v1\n'
    return 0
  fi

  : >"$signature_file"

  for criteria_file in "${CRITERIA_FILES[@]}"; do
    epoch="$(file_epoch_mtime "$criteria_file")" || continue
    date_token="$(epoch_to_utc_date "$epoch")" || continue
    if [ "$epoch" -gt "$latest_epoch" ]; then
      latest_epoch="$epoch"
      latest_date="$date_token"
    fi
    printf '%s|%s\n' "$(basename "$criteria_file" .md)" "$date_token" >>"$signature_file"
  done

  if [ ! -s "$signature_file" ]; then
    printf 'criteria-manual-v1\n'
    return 0
  fi

  if [ "$(wc -l <"$signature_file" | tr -d ' ')" = "1" ]; then
    awk -F'|' '{printf "%s-%s\n", $1, $2}' "$signature_file"
    return 0
  fi

  signature_hash="$(sort "$signature_file" | shasum -a 256 | awk '{print substr($1, 1, 12)}')"
  printf 'criteria-bundle-%s-%s\n' "${latest_date:-unknown}" "$signature_hash"
}

extract_input_criteria_version() {
  local component_file=""
  local value=""

  for component_file in "$RAW_COMPONENT_DIR"/*.json; do
    [ -f "$component_file" ] || continue
    value="$(jq -r '.criteria_version // empty' "$component_file")"
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return 0
    fi
  done

  return 1
}

collect_models_from_component() {
  local component_file="${1:?Missing component file}"
  local model_spec=""

  while IFS= read -r model_spec; do
    append_unique_model "$model_spec"
  done < <(
    jq -r '
      def to_model_spec:
        if type == "string" then
          .
        elif type == "object" then
          (.model_id // .id // .name // empty) as $model_id |
          if $model_id == "" then
            empty
          elif (.effort // empty) != empty then
            "\($model_id):\(.effort)"
          else
            $model_id
          end
        else
          empty
        end;
      [
        .models[]?,
        .multi_model.models[]?
      ]
      | .[]
      | to_model_spec
    ' "$component_file"
  )
}

collect_criteria_files_from_component() {
  local component_file="${1:?Missing component file}"
  local component_path=""
  local component_type=""
  local criteria_scope=""
  local criteria_file=""

  component_path="$(jq -r '.path // empty' "$component_file")"
  [ -n "$component_path" ] || return 1
  component_path="$(normalize_component_path "$component_path")"

  component_type="$(jq -r '.type // empty' "$component_file")"
  if [ -z "$component_type" ]; then
    component_type="$(infer_component_type "$component_path" || true)"
  fi
  [ -n "$component_type" ] || return 1

  if jq -e '.criteria? | type == "array" and length > 0' "$component_file" >/dev/null 2>&1; then
    criteria_scope="$(criteria_scope_for_component "$component_file")"
    criteria_file="$(criteria_file_for "$component_type" "$criteria_scope")"
    append_unique_criteria_file "$criteria_file"
  fi

  if jq -e '.output_evaluation?.criteria? | type == "array" and length > 0' "$component_file" >/dev/null 2>&1; then
    criteria_file="$(criteria_file_for "$component_type" "output")"
    append_unique_criteria_file "$criteria_file"
  fi
}

enrich_component() {
  local input_component="${1:?Missing input component file}"
  local output_component="${2:?Missing output component file}"
  local meta_file="${3:?Missing meta file}"
  local component_path=""
  local resolved_path=""
  local component_type=""
  local content_hash=""
  local eval_hash=""
  local criteria_file=""
  local output_criteria_file=""
  local criteria_scope=""
  local top_names_file="$EMPTY_JSON_FILE"
  local output_names_file="$EMPTY_JSON_FILE"

  component_path="$(jq -r '.path // empty' "$input_component")"
  [ -n "$component_path" ] || fail "component path missing in $input_component"
  component_path="$(normalize_component_path "$component_path")"

  resolved_path="$(resolve_component_file "$component_path" || true)"
  [ -n "$resolved_path" ] || fail "component file not found: $component_path"

  component_type="$(jq -r '.type // empty' "$input_component")"
  if [ -z "$component_type" ]; then
    component_type="$(infer_component_type "$component_path" || true)"
  fi
  [ -n "$component_type" ] || fail "component type missing or uninferrable for $component_path"

  content_hash="$(bash "$REGRESSION_SCRIPT" hash "$resolved_path")"
  eval_hash="$(bash "$REGRESSION_SCRIPT" eval-hash "$resolved_path" "${MODELS[@]}")"

  if jq -e '.criteria? | type == "array" and length > 0' "$input_component" >/dev/null 2>&1; then
    criteria_scope="$(criteria_scope_for_component "$input_component")"
    criteria_file="$(criteria_file_for "$component_type" "$criteria_scope")"
    top_names_file="$(criteria_map_json_path "$criteria_file")"
  fi

  if jq -e '.output_evaluation?.criteria? | type == "array" and length > 0' "$input_component" >/dev/null 2>&1; then
    output_criteria_file="$(criteria_file_for "$component_type" "output")"
    output_names_file="$(criteria_map_json_path "$output_criteria_file")"
  fi

  jq \
    --arg path "$component_path" \
    --arg type "$component_type" \
    --arg content_hash "$content_hash" \
    --arg eval_hash "$eval_hash" \
    --argjson run_multi_model "$RUN_MULTI_MODEL_JSON" \
    --slurpfile top_names "$top_names_file" \
    --slurpfile output_names "$output_names_file" \
    '
      def with_names($names):
        map(
          if (.name // "") == "" then
            . + {name: ($names[.id] // .id)}
          else
            .
          end
        );

      def normalize_improvements:
        map(
          {
            priority: (.priority // "MED"),
            criterion: (.criterion // .criterion_id // empty),
            description: (.description // "")
          }
          | with_entries(
              select(
                .value != null and
                .value != ""
              )
            )
        );

      def cleanup_output_evaluation:
        {
          output_hash: (.output_hash // empty),
          output_source: (.output_source // .output_path // empty),
          score: (.score // .scores.C // empty),
          criteria: ((.criteria // []) | with_names($output_names[0])),
          strengths: (.strengths // []),
          improvements: ((.improvements // []) | normalize_improvements)
        }
        | with_entries(
            select(
              .value != null and
              .value != "" and
              ((.value | type) != "array" or (.value | length) > 0) and
              ((.value | type) != "object" or (.value | length) > 0)
            )
          );

      {
        path: $path,
        type: $type,
        content_hash: $content_hash,
        eval_hash: $eval_hash,
        level: .level,
        scores: (.scores // {}),
        criteria: ((.criteria // []) | with_names($top_names[0])),
        strengths: (.strengths // []),
        improvements: ((.improvements // []) | normalize_improvements)
      }
      + (if (.name // "") != "" then {name: .name} else {} end)
      + (
          if .consensus != null then
            {consensus: .consensus}
          else
            {}
          end
        )
      + (
          if .multi_model != null then
            {multi_model: .multi_model}
          elif $run_multi_model != null then
            {multi_model: $run_multi_model}
          else
            {}
          end
        )
      + (
          if .output_evaluation != null then
            {output_evaluation: (.output_evaluation | cleanup_output_evaluation)}
          else
            {}
          end
        )
    ' "$input_component" >"$output_component"

  jq -cn \
    --arg path "$component_path" \
    --arg level "$(jq -r '.level' "$output_component")" \
    --arg mode "$(jq -r '.mode // empty' "$input_component")" \
    '{path:$path,level:$level,mode:$mode}' >"$meta_file"
}

build_summary_json() {
  local summary_path="${1:?Missing summary output path}"

  jq -s '
    def level_count($n):
      map(select((.level // 0) == $n)) | length;

    def output_score_pair:
      (.output_evaluation.score // empty);

    (
      [ .[] | select(.output_evaluation? != null and (.output_evaluation.score? | type) == "array" and (.output_evaluation.score | length) == 2) ]
    ) as $output_components
    |
    {
      total: length,
      level_distribution: {
        "1": level_count(1),
        "2": level_count(2),
        "3": level_count(3),
        "4": level_count(4)
      }
    }
    + (
        if ($output_components | length) > 0 then
          {
            output_evaluated: ($output_components | length),
            output_avg_score: [
              (($output_components | map(.output_evaluation.score[0]) | add) / ($output_components | length)),
              ($output_components[0].output_evaluation.score[1])
            ]
          }
        else
          {}
        end
      )
  ' "$ENRICHED_COMPONENT_DIR"/*.json >"$summary_path"
}

MODULE="${1:-}"
[ -n "$MODULE" ] || usage
shift

FILES=()
MODELS=()
CRITERIA_FILES=()
CRITERIA_VERSION="${EVAL_CRITERIA_VERSION:-}"

while [ $# -gt 0 ]; do
  case "$1" in
    --criteria-version)
      shift
      [ $# -gt 0 ] || usage
      CRITERIA_VERSION="$1"
      ;;
    --models)
      shift
      [ $# -gt 0 ] || usage
      while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do
        append_unique_model "$1"
        shift
      done
      continue
      ;;
    --*)
      fail "unknown flag: $1"
      ;;
    *)
      FILES+=("$1")
      ;;
  esac
  shift
done

[ ${#FILES[@]} -gt 0 ] || usage
require_tool jq

TMP_DIR="$(mktemp -d "${PROJECT_ROOT}/.tmp/eval-save.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

RAW_COMPONENT_DIR="$TMP_DIR/raw"
ENRICHED_COMPONENT_DIR="$TMP_DIR/enriched"
META_DIR="$TMP_DIR/meta"
mkdir -p "$RAW_COMPONENT_DIR" "$ENRICHED_COMPONENT_DIR" "$META_DIR"

EMPTY_JSON_FILE="$TMP_DIR/empty-object.json"
printf '{}\n' >"$EMPTY_JSON_FILE"

COMPONENT_FILTER="$(cat <<'JQ'
def top_meta:
  {
    __top_mode: (.mode // .evaluation_mode // .report_mode // ""),
    __top_multi_model: (.multi_model // null),
    __top_consensus: (.consensus // null),
    __top_models: (.models // null),
    __top_criteria_version: (.criteria_version // null)
  };

def merge_eval:
  if (.component? | type) == "object" and (.evaluation? | type) == "object" then
    (.component + .evaluation)
  elif (.evaluation? | type) == "object" then
    (. + .evaluation)
  elif (.component? | type) == "object" then
    .component
  else
    .
  end;

def apply_top($meta):
  .
  | if .path == null and (.component_path? != null) then . + {path: .component_path} else . end
  | if .type == null and (.component_type? != null) then . + {type: .component_type} else . end
  | if (.mode // "") == "" and ($meta.__top_mode // "") != "" then . + {mode: $meta.__top_mode} else . end
  | if .multi_model == null and $meta.__top_multi_model != null then . + {multi_model: $meta.__top_multi_model} else . end
  | if .consensus == null and $meta.__top_consensus != null then . + {consensus: $meta.__top_consensus} else . end
  | if .models == null and $meta.__top_models != null then . + {models: $meta.__top_models} else . end
  | if .criteria_version == null and $meta.__top_criteria_version != null then . + {criteria_version: $meta.__top_criteria_version} else . end;

if type == "array" then
  .[]
elif (.components? | type) == "array" then
  . as $top | .components[] | (merge_eval | apply_top($top | top_meta))
else
  . as $top | (merge_eval | apply_top($top | top_meta))
end
| select(type == "object")
JQ
)"

component_index=0
for input_file in "${FILES[@]}"; do
  [ -f "$input_file" ] || fail "input file not found: $input_file"
  while IFS= read -r component_json; do
    [ -n "$component_json" ] || continue
    component_index=$((component_index + 1))
    printf '%s\n' "$component_json" >"$RAW_COMPONENT_DIR/$(printf '%04d' "$component_index").json"
  done < <(jq -c "$COMPONENT_FILTER" "$input_file")
done

[ "$component_index" -gt 0 ] || fail "no component results found in input"

for raw_component in "$RAW_COMPONENT_DIR"/*.json; do
  collect_models_from_component "$raw_component"
  collect_criteria_files_from_component "$raw_component" || true
done

if [ ${#MODELS[@]} -eq 0 ]; then
  append_unique_model "claude-opus-4-6"
fi

if [ "$MODULE" = "auto" ]; then
  first_component_path="$(jq -r '.path // empty' "$RAW_COMPONENT_DIR/0001.json")"
  [ -n "$first_component_path" ] || fail "cannot infer module without a component path"
  first_component_path="$(normalize_component_path "$first_component_path")"
  MODULE="$(infer_module_from_path "$first_component_path" || true)"
  [ -n "$MODULE" ] || fail "could not infer module from path: $first_component_path"
fi

if [ -z "$CRITERIA_VERSION" ]; then
  CRITERIA_VERSION="$(extract_input_criteria_version || true)"
fi

if [ -z "$CRITERIA_VERSION" ]; then
  CRITERIA_VERSION="$(derive_criteria_version)"
fi

RUN_MULTI_MODEL_JSON="$(build_model_metadata_json)"
if [ "${#MODELS[@]}" -lt 2 ]; then
  RUN_MULTI_MODEL_JSON='null'
fi

for raw_component in "$RAW_COMPONENT_DIR"/*.json; do
  component_name="$(basename "$raw_component" .json)"
  enrich_component \
    "$raw_component" \
    "$ENRICHED_COMPONENT_DIR/${component_name}.json" \
    "$META_DIR/${component_name}.json"
done

SUMMARY_FILE="$TMP_DIR/summary.json"
build_summary_json "$SUMMARY_FILE"

timestamp="$(learning_timestamp_utc)"
git_sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

PAYLOAD_FILE="$TMP_DIR/payload.json"
jq -s \
  --arg version "1" \
  --arg timestamp "$timestamp" \
  --arg git_sha "$git_sha" \
  --arg module "$MODULE" \
  --arg criteria_version "$CRITERIA_VERSION" \
  --argjson multi_model "$RUN_MULTI_MODEL_JSON" \
  --slurpfile summary "$SUMMARY_FILE" \
  '
    {
      version: $version,
      timestamp: $timestamp,
      git_sha: $git_sha,
      module: $module,
      criteria_version: $criteria_version,
      multi_model: $multi_model,
      components: .,
      summary: $summary[0]
    }
  ' "$ENRICHED_COMPONENT_DIR"/*.json >"$PAYLOAD_FILE"

saved_path="$(bash "$REGRESSION_SCRIPT" save "$MODULE" <"$PAYLOAD_FILE")"

for meta_file in "$META_DIR"/*.json; do
  [ -f "$meta_file" ] || continue
  bash "$HOOK_SCRIPT" \
    saved \
    "$(jq -r '.path' "$meta_file")" \
    "$(jq -r '.level' "$meta_file")" \
    "$(jq -r '.mode // empty' "$meta_file")" >/dev/null 2>&1 || true
done

bash "$LEARNING_SCRIPT" "$saved_path" >/dev/null 2>&1 || true

printf '%s\n' "$saved_path"
