#!/usr/bin/env bash
# Minimal proposition KB helper for research spikes.

set -euo pipefail

PROP_FILE="propositions.jsonl"
INTEGRITY_FILE="integrity.lp"
ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  ACTION="status"
else
  shift || true
fi

log_error() {
  echo "[proposition-kb] $*" >&2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  proposition-kb.sh init <kb-path>
  proposition-kb.sh add <kb-path> <claim> <source-ref> [--confidence high|medium|low] [--kind direct|derived] [--depends-on id1,id2]
  proposition-kb.sh check <kb-path>
  proposition-kb.sh list <kb-path> [--status active|invalidated|all]
  proposition-kb.sh invalidate <kb-path> <proposition-id> --reason "<text>"
  proposition-kb.sh status <kb-path>
EOF
}

die_usage() {
  log_error "${1:?Missing error message}"
  usage
  exit 2
}

require_jq() {
  command -v jq >/dev/null 2>&1 || {
    log_error "jq is required."
    exit 1
  }
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

propositions_path() {
  printf '%s/%s\n' "${1:?Missing KB path}" "$PROP_FILE"
}

integrity_path() {
  printf '%s/%s\n' "${1:?Missing KB path}" "$INTEGRITY_FILE"
}

write_default_integrity() {
  cat >"${1:?Missing integrity path}" <<'EOF'
% Research-spike proposition integrity rules.
% Add domain-specific contradicts/2 facts here as the study evolves.
active(P) :- proposition(P), status(P, active).
has_dependency(P) :- depends(P, _).
missing_dependency(P, D) :- active(P), depends(P, D), not proposition(D).
invalid_dependency(P, D) :- active(P), depends(P, D), status(D, invalidated).
unsupported_claim(P) :- active(P), kind(P, derived), not has_dependency(P).
duplicate_claim(P1, P2, C) :- active(P1), active(P2), fact(P1, C), fact(P2, C), P1 < P2.
contradiction(P1, P2) :- active(P1), active(P2), contradicts(P1, P2).
contradiction(P1, P2) :- active(P1), active(P2), contradicts(P2, P1).
:- missing_dependency(P, D).
:- invalid_dependency(P, D).
:- contradiction(P1, P2).
#show missing_dependency/2.
#show invalid_dependency/2.
#show unsupported_claim/1.
#show duplicate_claim/3.
#show contradiction/2.
EOF
}

ensure_layout() {
  local kb_path="${1:?Missing KB path}"
  mkdir -p "$kb_path"
  touch "$(propositions_path "$kb_path")"
  [[ -f "$(integrity_path "$kb_path")" ]] || write_default_integrity "$(integrity_path "$kb_path")"
}

require_layout() {
  local kb_path="${1:?Missing KB path}"
  [[ -d "$kb_path" && -f "$(propositions_path "$kb_path")" && -f "$(integrity_path "$kb_path")" ]] ||
    die_usage "KB is not initialized: $kb_path"
}

validate_enum() {
  local value="${1:?Missing value}"
  local label="${2:?Missing label}"
  shift 2
  local allowed=""
  for allowed in "$@"; do
    [[ "$value" == "$allowed" ]] && return 0
  done
  die_usage "Invalid $label: $value"
}

validate_asp_id() {
  [[ "${1:?Missing proposition id}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
    die_usage "Proposition ids must be ASP-safe atoms: $1"
}

sha256_text() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "${1-}" | sha256sum | awk '{print $1}'
  else
    printf '%s' "${1-}" | shasum -a 256 | awk '{print $1}'
  fi
}

source_hash_for_ref() {
  local source_ref="${1:?Missing source ref}"
  if [[ -f "$source_ref" ]]; then
    if command -v sha256sum >/dev/null 2>&1; then
      printf 'sha256:%s\n' "$(sha256sum "$source_ref" | awk '{print $1}')"
    else
      printf 'sha256:%s\n' "$(shasum -a 256 "$source_ref" | awk '{print $1}')"
    fi
  else
    printf 'sha256:%s\n' "$(sha256_text "$source_ref")"
  fi
}

asp_escape_string() {
  printf '%s' "${1-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

next_proposition_id() {
  local kb_path="${1:?Missing KB path}"
  local count=""
  count="$(jq -s 'map(select(type == "object")) | length' "$(propositions_path "$kb_path")")"
  printf 'prop_%s_%04d\n' "$(date -u +%Y%m%d%H%M%S)" "$((count + 1))"
}

depends_json_from_csv() {
  jq -cn --arg raw "${1-}" 'if $raw == "" then [] else $raw | split(",") | map(gsub("^[[:space:]]+|[[:space:]]+$"; "")) | map(select(length > 0)) end'
}

fallback_checks_json() {
  jq -s '
    map(select(type == "object")) as $rows
    | ($rows | map(.proposition_id)) as $ids
    | ($rows | map({key: .proposition_id, value: (.status // "active")}) | from_entries) as $status_by_id
    | ($rows | map(select((.status // "active") == "active"))) as $active
    | {
        duplicate_claims: ($active | sort_by(.claim_text) | group_by(.claim_text) | map(select(length > 1)) | map({claim_text: .[0].claim_text, proposition_ids: map(.proposition_id)})),
        missing_dependencies: [$active[] as $p | ($p.depends_on // [])[]? as $dep | select(($ids | index($dep)) | not) | {proposition_id: $p.proposition_id, depends_on: $dep}],
        invalid_dependencies: [$active[] as $p | ($p.depends_on // [])[]? as $dep | select(($status_by_id[$dep] // "") == "invalidated") | {proposition_id: $p.proposition_id, depends_on: $dep}],
        unsupported_claims: [$active[] | select((.kind // "") == "derived") | select(((.depends_on // []) | length) == 0) | {proposition_id: .proposition_id, reason: "derived proposition has no dependencies"}]
      }
  ' "$(propositions_path "${1:?Missing KB path}")"
}

generate_asp_facts() {
  jq -r '
    def aspstr: tostring | gsub("\\\\"; "\\\\\\\\") | gsub("\""; "\\\"");
    . as $p
    | "proposition(\($p.proposition_id)).",
      "fact(\($p.proposition_id), \"\($p.claim_text | aspstr)\").",
      "source(\($p.proposition_id), \"\($p.source_hash | aspstr)\").",
      "source_ref(\($p.proposition_id), \"\($p.source_ref | aspstr)\").",
      "confidence(\($p.proposition_id), \($p.confidence)).",
      "kind(\($p.proposition_id), \($p.kind)).",
      "status(\($p.proposition_id), \($p.status)).",
      (($p.depends_on // [])[]? | "depends(\($p.proposition_id), \(.)).")
  ' "$(propositions_path "${1:?Missing KB path}")" >"${2:?Missing facts path}"
}

clingo_check_json() {
  local kb_path="${1:?Missing KB path}"
  local facts_file=""
  local output=""
  local exit_code="0"
  local output_json=""
  local result=""

  if ! command -v clingo >/dev/null 2>&1; then
    jq -cn '{available: false, result: null, exit_code: null, output: null}'
    return 0
  fi

  facts_file="$(mktemp "${TMPDIR:-/tmp}/proposition-kb.XXXXXX.lp")"
  generate_asp_facts "$kb_path" "$facts_file"
  output="$(clingo "$(integrity_path "$kb_path")" "$facts_file" 0 --outf=2 2>&1)" || exit_code="$?"
  rm -f "$facts_file"
  output_json="$(printf '%s' "$output" | jq -c . 2>/dev/null || jq -cn --arg output "$output" '{raw_output: $output}')"
  result="$(printf '%s' "$output_json" | jq -r '.Result // empty' 2>/dev/null || true)"
  jq -cn --argjson output "$output_json" --arg result "$result" --argjson exit_code "$exit_code" \
    '{available: true, result: (if $result == "" then null else $result end), exit_code: $exit_code, output: $output}'
}

action_init() {
  [[ $# -eq 1 ]] || die_usage "init requires <kb-path>."
  require_jq
  ensure_layout "$1"
  action_status "$1"
}

action_add() {
  [[ $# -ge 3 ]] || die_usage "add requires <kb-path> <claim> <source-ref>."
  require_jq
  local kb_path="$1"
  local claim="$2"
  local source_ref="$3"
  local confidence="medium"
  local kind="direct"
  local depends_on=""
  local proposition_id=""
  local source_hash=""
  local depends_json=""
  local record=""
  shift 3

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --confidence) [[ $# -ge 2 ]] || die_usage "Missing value for --confidence."; confidence="$2"; shift 2 ;;
      --kind) [[ $# -ge 2 ]] || die_usage "Missing value for --kind."; kind="$2"; shift 2 ;;
      --depends-on) [[ $# -ge 2 ]] || die_usage "Missing value for --depends-on."; depends_on="$2"; shift 2 ;;
      *) die_usage "Unknown add option: $1" ;;
    esac
  done

  validate_enum "$confidence" "confidence" high medium low
  validate_enum "$kind" "kind" direct derived
  ensure_layout "$kb_path"
  proposition_id="$(next_proposition_id "$kb_path")"
  source_hash="$(source_hash_for_ref "$source_ref")"
  depends_json="$(depends_json_from_csv "$depends_on")"
  while IFS= read -r dep_id; do
    [[ -z "$dep_id" ]] || validate_asp_id "$dep_id"
  done < <(printf '%s\n' "$depends_json" | jq -r '.[]?')

  record="$(jq -cn --arg proposition_id "$proposition_id" --arg claim_text "$claim" \
    --arg asp_encoding "fact($proposition_id, \"$(asp_escape_string "$claim")\")." \
    --arg source_hash "$source_hash" --arg source_ref "$source_ref" --arg confidence "$confidence" \
    --arg kind "$kind" --argjson depends_on "$depends_json" --arg created_at "$(timestamp_utc)" \
    '{proposition_id:$proposition_id,claim_text:$claim_text,asp_encoding:$asp_encoding,source_hash:$source_hash,source_ref:$source_ref,confidence:$confidence,kind:$kind,depends_on:$depends_on,status:"active",created_at:$created_at,invalidated_at:null,invalidation_reason:null}')"
  printf '%s\n' "$record" >>"$(propositions_path "$kb_path")"
  jq -cn --argjson proposition "$record" '{added: $proposition}'
}

action_check() {
  [[ $# -eq 1 ]] || die_usage "check requires <kb-path>."
  require_jq
  local kb_path="$1"
  local fallback_json=""
  local clingo_json=""
  require_layout "$kb_path"
  fallback_json="$(fallback_checks_json "$kb_path")"
  clingo_json="$(clingo_check_json "$kb_path")"
  jq -cn --arg kb_path "$kb_path" --argjson fallback "$fallback_json" --argjson clingo "$clingo_json" \
    '{kb_path:$kb_path,clingo_available:$clingo.available,clingo:$clingo,fallback_checks:$fallback,healthy:((($clingo.available|not) or ($clingo.result!="UNSATISFIABLE")) and (($fallback.duplicate_claims|length)==0) and (($fallback.missing_dependencies|length)==0) and (($fallback.invalid_dependencies|length)==0) and (($fallback.unsupported_claims|length)==0))}'
}

action_list() {
  [[ $# -ge 1 ]] || die_usage "list requires <kb-path>."
  require_jq
  local kb_path="$1"
  local status_filter="active"
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status) [[ $# -ge 2 ]] || die_usage "Missing value for --status."; status_filter="$2"; shift 2 ;;
      *) die_usage "Unknown list option: $1" ;;
    esac
  done
  validate_enum "$status_filter" "status" active invalidated all
  require_layout "$kb_path"
  jq -s --arg kb_path "$kb_path" --arg status_filter "$status_filter" \
    'map(select(type=="object")) as $rows | {kb_path:$kb_path,status_filter:$status_filter,propositions:(if $status_filter=="all" then $rows else $rows | map(select((.status // "active") == $status_filter)) end)}' \
    "$(propositions_path "$kb_path")"
}

action_invalidate() {
  [[ $# -ge 2 ]] || die_usage "invalidate requires <kb-path> <proposition-id> --reason <text>."
  require_jq
  local kb_path="$1"
  local proposition_id="$2"
  local reason=""
  local result_json=""
  local tmp_file=""
  shift 2
  validate_asp_id "$proposition_id"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason) [[ $# -ge 2 ]] || die_usage "Missing value for --reason."; reason="$2"; shift 2 ;;
      *) die_usage "Unknown invalidate option: $1" ;;
    esac
  done
  [[ -n "$reason" ]] || die_usage "invalidate requires --reason."
  require_layout "$kb_path"
  result_json="$(jq -s --arg target "$proposition_id" --arg reason "$reason" --arg invalidated_at "$(timestamp_utc)" '
    def deps($ids; $rows): [$rows[] as $p | select((($p.status // "active") == "active") or ($p.proposition_id == $target)) | select(any(($p.depends_on // [])[]; . as $dep | ($ids | index($dep)))) | $p.proposition_id];
    def closure($ids; $rows): reduce range(0; (($rows | length) + 1)) as $i ($ids; (. + deps(.; $rows)) | unique);
    map(select(type=="object")) as $rows
    | ($rows | any(.proposition_id == $target)) as $found
    | closure([$target]; $rows) as $targets
    | {found:$found,invalidated:$targets,rows:($rows | map(if (.proposition_id as $id | $targets | index($id)) then .status="invalidated" | .invalidated_at=$invalidated_at | .invalidation_reason=$reason else . end))}
  ' "$(propositions_path "$kb_path")")"
  [[ "$(printf '%s\n' "$result_json" | jq -r '.found')" == "true" ]] || {
    log_error "Proposition not found: $proposition_id"
    exit 1
  }
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/propositions.XXXXXX.jsonl")"
  printf '%s\n' "$result_json" | jq -c '.rows[]' >"$tmp_file"
  mv "$tmp_file" "$(propositions_path "$kb_path")"
  printf '%s\n' "$result_json" | jq '{invalidated:.invalidated}'
}

action_status() {
  [[ $# -eq 1 ]] || die_usage "status requires <kb-path>."
  require_jq
  local kb_path="$1"
  local initialized="false"
  local stats='{"total":0,"active":0,"invalidated":0,"superseded":0,"dependencies":0}'
  [[ -d "$kb_path" && -f "$(propositions_path "$kb_path")" && -f "$(integrity_path "$kb_path")" ]] && {
    initialized="true"
    stats="$(jq -s 'map(select(type=="object")) as $rows | {total:($rows|length),active:($rows|map(select((.status // "active")=="active"))|length),invalidated:($rows|map(select(.status=="invalidated"))|length),superseded:($rows|map(select(.status=="superseded"))|length),dependencies:($rows|map((.depends_on // [])|length)|add // 0)}' "$(propositions_path "$kb_path")")"
  }
  jq -cn --arg kb_path "$kb_path" --argjson initialized "$initialized" --argjson stats "$stats" \
    --argjson clingo_available "$(if command -v clingo >/dev/null 2>&1; then printf 'true'; else printf 'false'; fi)" \
    '{kb_path:$kb_path,initialized:$initialized,total:$stats.total,active:$stats.active,invalidated:$stats.invalidated,superseded:$stats.superseded,dependencies:$stats.dependencies,clingo_available:$clingo_available}'
}

case "$ACTION" in
  init) action_init "$@" ;;
  add) action_add "$@" ;;
  check) action_check "$@" ;;
  list) action_list "$@" ;;
  invalidate) action_invalidate "$@" ;;
  status) action_status "$@" ;;
  *) die_usage "Unknown action: $ACTION" ;;
esac
