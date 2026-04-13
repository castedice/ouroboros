#!/usr/bin/env bash

set -euo pipefail

QUERY="${1:-}"
[[ -n "$QUERY" ]] || { echo "Usage: kb-similarity.sh <query-text> [--threshold 0.3] [--top 5] [--format json|text] [--corpus <path>]" >&2; exit 1; }
shift || true

THRESHOLD="0.3"
TOP="5"
FORMAT="json"
CORPUS="docs/specs/knowledge/"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="${2:?Missing value for --threshold}"; shift 2 ;;
    --top) TOP="${2:?Missing value for --top}"; shift 2 ;;
    --format) FORMAT="${2:?Missing value for --format}"; shift 2 ;;
    --corpus) CORPUS="${2:?Missing value for --corpus}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ "$FORMAT" == "json" || "$FORMAT" == "text" ]] || { echo "Format must be json or text." >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 2; }
[[ -e "$CORPUS" ]] || { echo "Corpus path not found: $CORPUS" >&2; exit 1; }

_frontmatter_field() {
  sed -n '/^---$/,/^---$/p' "$1" | sed -n "s/^$2: *//p" | head -1
}

_title() {
  local title
  title=$(_frontmatter_field "$1" "title")
  [[ -n "$title" ]] && printf '%s\n' "$title" && return
  sed -n 's/^# \+//p' "$1" | head -1
}

_tags() {
  _frontmatter_field "$1" "tags" | tr -d '[]' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' || true
}

_first_paragraph() {
  awk '
    BEGIN { fence=0; started=0; body=0; para="" }
    /^---$/ { fence++; next }
    fence < 2 { next }
    /^#/ { next }
    /^[[:space:]]*$/ { if (started) exit; next }
    {
      para = para (para ? " " : "") $0
      started = 1
    }
    END { print para }
  ' "$1"
}

_json_entries() {
  jq -c '
    def as_tags:
      if . == null then []
      elif type == "array" then [ .[] | tostring ]
      else [ tostring ]
      end;
    def text_value:
      if . == null then ""
      elif type == "string" then .
      elif type == "array" then [ .[] | text_value ] | join(" ")
      elif type == "object" then [ .[] | text_value ] | join(" ")
      else tostring
      end;
    def emit_entry($item):
      {
        path: ($item.path // $item.report_path // $item.source_path // $item.study_path // $item.file // $item.slug // $item.id // ""),
        title: ($item.title // $item.name // $item.slug // $item.id // ""),
        tags: (($item.tags // $item.tag_list // $item.suggested_tags // []) | as_tags),
        text: (($item.summary // $item.abstract // $item.description // $item.notes // $item.text // $item.key_findings // $item.query // $item.topic // "") | text_value),
        contradiction: ($item.contradiction // false)
      };
    if type == "array" then
      .[]
    elif type == "object" and (.entries? | type) == "array" then
      .entries[]
    elif type == "object" and (.items? | type) == "array" then
      .items[]
    elif type == "object" and (.studies? | type) == "array" then
      .studies[]
    else
      .
    end
    | emit_entry(.)
    | select(.path != "" or .title != "" or .text != "")
  ' "$1"
}

_corpus_files() {
  local corpus_path="$1"

  if [[ -f "$corpus_path" ]]; then
    printf '%s\n' "$corpus_path"
    return
  fi

  if [[ "$corpus_path" == "docs/specs/knowledge" || "$corpus_path" == "docs/specs/knowledge/" ]]; then
    find "$corpus_path" -maxdepth 1 -type f -name '*.md' | sort
    return
  fi

  find "$corpus_path" -type f \( -name '*.md' -o -name '*.json' \) | sort
}

_terms() {
  printf '%s\n' "$*" |
    tr '[:upper:]' '[:lower:]' |
    tr -cs '[:alnum:]' '\n' |
    awk 'length >= 3 && !/^(the|and|for|with|from|that|this|into|onto|about|your|what|when|where|will|would|should|could|their|there|have|has|had|are|was|were|but|not|you|use|used|using|via|over|under|than|then|them|they|our|out)$/ { print }' |
    sort -u
}

declare -A QUERY_TERMS=()
while IFS= read -r term; do
  [[ -n "$term" ]] && QUERY_TERMS["$term"]=1
done < <(_terms "$QUERY")
QUERY_COUNT=${#QUERY_TERMS[@]}
QUERY_DENOM=$QUERY_COUNT
[[ "$QUERY_DENOM" -lt 2 ]] && QUERY_DENOM=2

_overlap_count() {
  local text="$1"
  local count=0
  declare -A seen=()
  while IFS= read -r term; do
    [[ -z "$term" || -n "${seen[$term]:-}" ]] && continue
    seen["$term"]=1
    [[ -n "${QUERY_TERMS[$term]:-}" ]] && count=$((count + 1))
  done < <(_terms "$text")
  printf '%s\n' "$count"
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

_append_candidate() {
  local path="$1"
  local title="$2"
  local text="$3"
  local tag_text="$4"
  local contradiction="${5:-false}"
  tag_term_count=$(_terms "$tag_text" | wc -l | tr -d ' ')
  tag_denom=$QUERY_COUNT
  [[ "$tag_term_count" -lt "$tag_denom" ]] && tag_denom=$tag_term_count
  [[ "$tag_denom" -lt 2 ]] && tag_denom=2
  term_overlap=$(_overlap_count "$title $text")
  tag_overlap=$(_overlap_count "$tag_text")
  score=$(awk -v term="$term_overlap" -v term_denom="$QUERY_DENOM" -v tag="$tag_overlap" -v tag_denom="$tag_denom" 'BEGIN { s=(0.7*(term/term_denom))+(0.3*(tag/tag_denom)); if (s > 1) s = 1; printf "%.3f", s }')
  outcome="none"
  awk -v s="$score" 'BEGIN { exit !(s > 0.8) }' && outcome="duplicate"
  awk -v s="$score" 'BEGIN { exit !(s >= 0.3 && s <= 0.8) }' && outcome="related"
  [[ "$contradiction" == "true" ]] && outcome="contradiction"
  tags_json=$(printf '%s\n' "$tag_text" | jq -R . | jq -s 'map(select(length > 0))')
  jq -nc --arg path "$path" --arg title "$title" --arg outcome "$outcome" --argjson score "$score" --argjson tags "$tags_json" '{path:$path,title:$title,score:$score,outcome:$outcome,tags:$tags}' >>"$TMP"
}

while IFS= read -r file; do
  case "$file" in
    *.md)
      [[ "$(basename "$file")" == "INDEX.md" ]] && continue
      title=$(_title "$file")
      paragraph=$(_first_paragraph "$file")
      mapfile -t tags < <(_tags "$file")
      tag_text=$(printf '%s\n' "${tags[@]+"${tags[@]}"}")
      contradiction=$(_frontmatter_field "$file" "contradiction")
      _append_candidate "$file" "$title" "$paragraph" "$tag_text" "$contradiction"
      ;;
    *.json)
      while IFS= read -r entry; do
        path=$(jq -r '.path // empty' <<<"$entry")
        title=$(jq -r '.title // empty' <<<"$entry")
        text=$(jq -r '.text // empty' <<<"$entry")
        tag_text=$(jq -r '(.tags // [])[]?' <<<"$entry")
        contradiction=$(jq -r '.contradiction // false' <<<"$entry")
        [[ -z "$path" ]] && path="$file"
        _append_candidate "$path" "$title" "$text" "$tag_text" "$contradiction"
      done < <(_json_entries "$file")
      ;;
  esac
done < <(_corpus_files "$CORPUS")

RESULTS=$(jq -s --argjson threshold "$THRESHOLD" --argjson top "$TOP" '
  map(select(.outcome == "contradiction")) as $contradictions |
  (map(select(.outcome != "contradiction" and .score >= $threshold)) | sort_by(-.score, .title)[:$top]) as $scored |
  ($scored | map(.path)) as $paths |
  ($scored + ($contradictions | map(select(.path as $p | ($paths | index($p) | not))))) | sort_by(-.score, .title)
' "$TMP")

if [[ "$FORMAT" == "text" ]]; then
  jq -r '
    if length == 0 then
      "No similar entries found."
    else
      .[] | "\(.score)\t\(.outcome)\t\(.title)\t\(.path)\t[\(.tags | join(", "))]"
    end
  ' <<<"$RESULTS"
else
  printf '%s\n' "$RESULTS"
fi
