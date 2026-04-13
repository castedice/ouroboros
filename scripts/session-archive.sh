#!/usr/bin/env bash
# Session archive lifecycle manager for Claude Code transcripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/learning-lib.sh"

SCHEMA_VERSION=1
DEFAULT_PLUGIN_DATA_ROOT="${HOME}/.claude/plugins/data/ouroboros-inline"
ARCHIVE_DATA_ROOT="${CLAUDE_PLUGIN_DATA:-$DEFAULT_PLUGIN_DATA_ROOT}"
ARCHIVE_ROOT="$ARCHIVE_DATA_ROOT/session-archive"
INDEX_FILE="$ARCHIVE_ROOT/index.sqlite"
QUEUE_FILE="$ARCHIVE_ROOT/queue.jsonl"
STATE_FILE="$ARCHIVE_ROOT/state.json"
SETTINGS_FILE="$ARCHIVE_ROOT/settings.json"
PROPOSALS_DIR="$ARCHIVE_ROOT/proposals"
WIKI_DIR="$ARCHIVE_ROOT/wiki"
WIKI_LEDGER_FILE="$ARCHIVE_ROOT/wiki-ledger.jsonl"
PROPOSALS_INDEX_FILE="$PROPOSALS_DIR/proposals.jsonl"
TRANSCRIPT_ROOT="${HOME}/.claude/projects"

DEFAULT_REBUILD_SINCE="30d"
DEFAULT_PRUNE_OLDER_THAN="365d"
DEFAULT_SEARCH_TOP=5
DEFAULT_SESSION_WIKI_MIN_SEGMENTS=5
DEFAULT_SESSION_WIKI_MIN_SESSIONS=2
DEFAULT_SESSION_WIKI_MIN_SPAN_DAYS=1
DEFAULT_SESSION_WIKI_STALE_DAYS=90
DEFAULT_SESSION_WIKI_MAX_PAGES_PER_PROPOSAL=3
DEFAULT_SESSION_WIKI_HARD_CAP_PAGES=5
TOOL_RESULT_STDOUT_CAP=2048
DEFAULT_RESULT_CAP=1024
RESULT_SEPARATOR=$'\x1f'
IMPORT_FIELD_SEPARATOR=$'\x1f'
IMPORT_RECORD_SEPARATOR=$'\n'

ACTION="${1:-}"
if [[ -z "$ACTION" ]]; then
  ACTION="status"
else
  shift || true
fi

log_error() {
  echo "[session-archive] $*" >&2
}

usage() {
  cat >&2 <<'EOF'
Usage:
  session-archive.sh init
  session-archive.sh sync [--budget-seconds N]
  session-archive.sh search <query> [--since <date-or-nd>] [--project current|all|<slug>] [--agent all|main|subagent] [--component <path-or-command>] [--top N] [--format json|text] [--include-meta]
  session-archive.sh select <query> [--top N] [--project current|all|<slug>] [--agent all|main|subagent] [--since <date-or-nd>] [--format json|text]
  session-archive.sh get <segment-id|session-id> [--before N] [--after N] [--format json|text]
  session-archive.sh propose [--task-key <k>] [--component <c>] [--session <id>] [--query <text>] [--since <date-or-nd>] [--project current|all|<slug>] [--min-segments N] [--min-sessions N] [--min-span-days N] [--dry-run] [--format json|text]
  session-archive.sh status
  session-archive.sh wiki-status [--format json|text]
  session-archive.sh wiki-lint [--stale-days N] [--format json|text]
  session-archive.sh proposal-list [--status pending|applied|rejected|all] [--format json|text]
  session-archive.sh proposal-show <proposal-id> [--format json|text]
  session-archive.sh proposal-apply <proposal-id> [--force] [--format json|text]
  session-archive.sh proposal-reject <proposal-id> --reason "<text>" [--format json|text]
  session-archive.sh rebuild [--since <date-or-nd>]
  session-archive.sh prune [--older-than <date-or-nd>]
EOF
}

die_usage() {
  local message="${1:?Missing error message}"
  log_error "$message"
  usage
  exit 2
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required."
    exit 1
  fi
}

require_sqlite3() {
  if ! command -v sqlite3 >/dev/null 2>&1; then
    log_error "sqlite3 is required."
    exit 1
  fi
}

require_nonnegative_int() {
  local value="${1:?Missing value}"
  local label="${2:?Missing label}"

  if [[ ! "$value" =~ ^[0-9]+$ ]]; then
    die_usage "$label must be a non-negative integer."
  fi
}

require_positive_int() {
  local value="${1:?Missing value}"
  local label="${2:?Missing label}"

  require_nonnegative_int "$value" "$label"
  if ((value < 1)); then
    die_usage "$label must be a positive integer."
  fi
}

timestamp_utc() {
  learning_timestamp_utc
}

normalize_text() {
  printf '%s' "${1-}" |
    tr '\r\n\t' '   ' |
    sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'
}

sanitize_import_field() {
  local value="${1-}"
  value="${value//$'\x1f'/ }"
  value="${value//$'\x1e'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

append_import_row() {
  local output_path="${1:?Missing output path}"
  local first=1
  local field=""
  shift || true

  {
    for field in "$@"; do
      if [[ "$first" -eq 0 ]]; then
        printf '%s' "$IMPORT_FIELD_SEPARATOR"
      fi
      sanitize_import_field "$field"
      first=0
    done
    printf '%s' "$IMPORT_RECORD_SEPARATOR"
  } >>"$output_path"
}

cap_text() {
  local raw_text="${1-}"
  local max_chars="${2:-$DEFAULT_RESULT_CAP}"
  local normalized_text=""

  normalized_text="$(normalize_text "$raw_text")"
  if ((${#normalized_text} <= max_chars)); then
    printf '%s\n' "$normalized_text"
    return 0
  fi

  printf '%s…\n' "${normalized_text:0:max_chars}"
}

sql_quote() {
  local value="${1-}"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

sql_nullable() {
  local value="${1-}"
  if [[ -z "$value" ]]; then
    printf 'NULL'
    return 0
  fi
  sql_quote "$value"
}

stat_mtime() {
  local path="${1:?Missing path}"
  if stat -f '%m' "$path" >/dev/null 2>&1; then
    stat -f '%m' "$path"
  else
    stat -c '%Y' "$path"
  fi
}

stat_size() {
  local path="${1:?Missing path}"
  if stat -f '%z' "$path" >/dev/null 2>&1; then
    stat -f '%z' "$path"
  else
    stat -c '%s' "$path"
  fi
}

sha256_file() {
  local path="${1:?Missing path}"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
    return 0
  fi
  shasum -a 256 "$path" | awk '{print $1}'
}

iso_to_epoch() {
  local iso_ts="${1:?Missing timestamp}"

  if date -u -d "$iso_ts" +%s >/dev/null 2>&1; then
    date -u -d "$iso_ts" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso_ts" +%s
    return 0
  fi

  if date -j -u -f "%Y-%m-%d" "$iso_ts" +%s >/dev/null 2>&1; then
    date -j -u -f "%Y-%m-%d" "$iso_ts" +%s
    return 0
  fi

  return 1
}

epoch_from_spec() {
  local spec="${1:?Missing time spec}"
  local now_epoch=""
  local days=""

  now_epoch="$(date -u +%s)"

  if [[ "$spec" =~ ^([0-9]+)d$ ]]; then
    days="${BASH_REMATCH[1]}"
    printf '%s\n' "$((now_epoch - (days * 86400)))"
    return 0
  fi

  if [[ "$spec" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    iso_to_epoch "$spec"
    return 0
  fi

  if [[ "$spec" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]; then
    iso_to_epoch "$spec"
    return 0
  fi

  return 1
}

home_relative_path() {
  local raw_path="${1-}"
  if [[ "$raw_path" == "$HOME/"* ]]; then
    printf '%s/%s\n' '~' "${raw_path#"$HOME"/}"
    return 0
  fi
  printf '%s\n' "$raw_path"
}

current_project_slug() {
  local cwd_path=""
  cwd_path="$(pwd)"
  printf '%s' "$cwd_path" |
    sed -E 's#[^[:alnum:]]+#-#g; s/--+/-/g'
  printf '\n'
}

project_slug_from_source() {
  local source_path="${1:?Missing source path}"
  local slug=""

  slug="$(printf '%s' "$source_path" | sed -E "s#^.*/\\.claude/projects/([^/]+)/.*#\\1#")"
  if [[ -n "$slug" && "$slug" != "$source_path" ]]; then
    printf '%s\n' "$slug"
    return 0
  fi

  current_project_slug
}

agent_kind_from_source() {
  local source_path="${1:?Missing source path}"
  if [[ "$source_path" == *"/subagents/"* ]]; then
    printf 'subagent\n'
  else
    printf 'main\n'
  fi
}

fallback_session_id_from_source() {
  local source_path="${1:?Missing source path}"
  if [[ "$source_path" == *"/subagents/"* ]]; then
    basename "$(dirname "$(dirname "$source_path")")"
    return 0
  fi
  basename "$source_path" .jsonl
}

parent_session_id_from_source() {
  local source_path="${1:?Missing source path}"
  if [[ "$source_path" == *"/subagents/"* ]]; then
    basename "$(dirname "$(dirname "$source_path")")"
  fi
}

source_session_id() {
  local source_path="${1:?Missing source path}"
  local fallback_session_id="${2:?Missing fallback session id}"
  local detected_session_id=""

  detected_session_id="$(jq -r '.sessionId // .session_id // .session // empty' "$source_path" 2>/dev/null | awk 'NF { print; exit }')"
  if [[ -n "$detected_session_id" ]]; then
    printf '%s\n' "$detected_session_id"
    return 0
  fi

  printf '%s\n' "$fallback_session_id"
}

source_project_cwd() {
  local source_path="${1:?Missing source path}"
  jq -r '.cwd // empty' "$source_path" 2>/dev/null | awk 'NF { print; exit }'
}

ensure_archive_layout() {
  mkdir -p "$ARCHIVE_ROOT"
  mkdir -p "$PROPOSALS_DIR"
  mkdir -p "$WIKI_DIR"
  touch "$QUEUE_FILE"
}

fts5_available() {
  sqlite3 :memory: "CREATE VIRTUAL TABLE t USING fts5(a);" >/dev/null 2>&1
}

write_default_settings() {
  local settings_tmp=""

  if [[ -f "$SETTINGS_FILE" ]]; then
    settings_tmp="$(mktemp /tmp/session-archive-settings.XXXXXX)"
    jq \
      --arg qmd_wiki_collection_name "session-wiki" \
      --argjson session_wiki_min_segments "$DEFAULT_SESSION_WIKI_MIN_SEGMENTS" \
      --argjson session_wiki_min_sessions "$DEFAULT_SESSION_WIKI_MIN_SESSIONS" \
      --argjson session_wiki_min_span_days "$DEFAULT_SESSION_WIKI_MIN_SPAN_DAYS" \
      --argjson session_wiki_stale_days "$DEFAULT_SESSION_WIKI_STALE_DAYS" \
      --argjson session_wiki_max_pages_per_proposal "$DEFAULT_SESSION_WIKI_MAX_PAGES_PER_PROPOSAL" \
      --argjson session_wiki_hard_cap_pages "$DEFAULT_SESSION_WIKI_HARD_CAP_PAGES" \
      '
        .qmd_wiki_collection_name = (.qmd_wiki_collection_name // $qmd_wiki_collection_name)
        | .session_wiki = ({
            enabled: true,
            collection_name: $qmd_wiki_collection_name,
            min_segments: $session_wiki_min_segments,
            min_sessions: $session_wiki_min_sessions,
            min_span_days: $session_wiki_min_span_days,
            stale_days: $session_wiki_stale_days,
            max_pages_per_proposal: $session_wiki_max_pages_per_proposal,
            hard_cap_pages: $session_wiki_hard_cap_pages,
            grouping: ["task_key", "component_hint", "topic"],
            include_subagents: true,
            min_agent_text_segments: 1
          } + (.session_wiki // {}))
        | .session_wiki.collection_name = $qmd_wiki_collection_name
      ' "$SETTINGS_FILE" >"$settings_tmp"
    mv "$settings_tmp" "$SETTINGS_FILE"
    return 0
  fi

  jq -cn \
    --argjson schema_version "$SCHEMA_VERSION" \
    --arg rebuild_since "$DEFAULT_REBUILD_SINCE" \
    --arg prune_older_than "$DEFAULT_PRUNE_OLDER_THAN" \
    --arg qmd_wiki_collection_name "session-wiki" \
    --argjson session_wiki_min_segments "$DEFAULT_SESSION_WIKI_MIN_SEGMENTS" \
    --argjson session_wiki_min_sessions "$DEFAULT_SESSION_WIKI_MIN_SESSIONS" \
    --argjson session_wiki_min_span_days "$DEFAULT_SESSION_WIKI_MIN_SPAN_DAYS" \
    --argjson session_wiki_stale_days "$DEFAULT_SESSION_WIKI_STALE_DAYS" \
    --argjson session_wiki_max_pages_per_proposal "$DEFAULT_SESSION_WIKI_MAX_PAGES_PER_PROPOSAL" \
    --argjson session_wiki_hard_cap_pages "$DEFAULT_SESSION_WIKI_HARD_CAP_PAGES" \
    --argjson tool_result_stdout_cap "$TOOL_RESULT_STDOUT_CAP" \
    --argjson search_top "$DEFAULT_SEARCH_TOP" \
    '{
      schema_version: $schema_version,
      qmd_wiki_collection_name: $qmd_wiki_collection_name,
      session_wiki: {
        enabled: true,
        collection_name: $qmd_wiki_collection_name,
        min_segments: $session_wiki_min_segments,
        min_sessions: $session_wiki_min_sessions,
        min_span_days: $session_wiki_min_span_days,
        stale_days: $session_wiki_stale_days,
        max_pages_per_proposal: $session_wiki_max_pages_per_proposal,
        hard_cap_pages: $session_wiki_hard_cap_pages,
        grouping: ["task_key", "component_hint", "topic"],
        include_subagents: true,
        min_agent_text_segments: 1
      },
      defaults: {
        rebuild_since: $rebuild_since,
        prune_older_than: $prune_older_than,
        search_top: $search_top,
        include_meta: false,
        project: "current",
        agent: "all",
        tool_result_stdout_cap_bytes: $tool_result_stdout_cap
      }
    }' >"$SETTINGS_FILE"
}

create_schema() {
  sqlite3 "$INDEX_FILE" <<'SQL'
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS sources (
  source_path TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  parent_session_id TEXT,
  project_slug TEXT NOT NULL,
  project_cwd TEXT,
  agent_kind TEXT NOT NULL,
  source_mtime INTEGER NOT NULL,
  source_size INTEGER NOT NULL,
  source_hash TEXT,
  indexed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS segments (
  segment_id TEXT PRIMARY KEY,
  source_path TEXT NOT NULL REFERENCES sources(source_path) ON DELETE CASCADE,
  session_id TEXT NOT NULL,
  parent_session_id TEXT,
  project_slug TEXT NOT NULL,
  agent_kind TEXT NOT NULL,
  speaker TEXT NOT NULL,
  segment_kind TEXT NOT NULL,
  ts TEXT,
  line_no INTEGER NOT NULL,
  item_no INTEGER NOT NULL,
  turn_no INTEGER,
  tool_name TEXT,
  tool_use_id TEXT,
  is_error INTEGER NOT NULL DEFAULT 0,
  is_meta INTEGER NOT NULL DEFAULT 0,
  command_hint TEXT,
  component_hint TEXT,
  task_key TEXT,
  raw_uuid TEXT,
  content TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_segments_filters ON segments(project_slug, agent_kind, component_hint, ts);
CREATE INDEX IF NOT EXISTS idx_segments_tool_use ON segments(tool_use_id);

CREATE VIRTUAL TABLE IF NOT EXISTS segments_fts USING fts5(
  content,
  command_hint,
  component_hint,
  tool_name,
  content='segments',
  content_rowid='rowid',
  tokenize='unicode61'
);

DROP TRIGGER IF EXISTS segments_ai;
DROP TRIGGER IF EXISTS segments_ad;
DROP TRIGGER IF EXISTS segments_au;
SQL
}

queue_pending_count() {
  if [[ ! -f "$QUEUE_FILE" ]]; then
    printf '0\n'
    return 0
  fi

  awk 'NF { count += 1 } END { print count + 0 }' "$QUEUE_FILE"
}

update_state_file() {
  local last_sync_at="${1-}"
  local pending_count="0"
  local indexed_sources="0"
  local segment_count="0"

  pending_count="$(queue_pending_count)"

  if [[ -f "$INDEX_FILE" ]]; then
    indexed_sources="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM sources;" 2>/dev/null || printf '0')"
    segment_count="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM segments;" 2>/dev/null || printf '0')"
  fi

  if [[ -z "$last_sync_at" && -f "$STATE_FILE" ]]; then
    last_sync_at="$(jq -r '.last_sync_at // empty' "$STATE_FILE" 2>/dev/null || true)"
  fi

  sqlite3 :memory: >/dev/null 2>&1 || true

  jq -cn \
    --argjson schema_version "$SCHEMA_VERSION" \
    --arg last_sync_at "${last_sync_at-}" \
    --argjson pending_count "$pending_count" \
    --argjson indexed_sources "$indexed_sources" \
    --argjson segment_count "$segment_count" \
    '{
      schema_version: $schema_version,
      last_sync_at: (if ($last_sync_at | length) > 0 then $last_sync_at else null end),
      pending_count: $pending_count,
      indexed_sources: $indexed_sources,
      segment_count: $segment_count
    }' >"$STATE_FILE"
}

ensure_initialized() {
  if [[ -f "$INDEX_FILE" && -f "$SETTINGS_FILE" && -f "$STATE_FILE" && -f "$QUEUE_FILE" ]]; then
    return 0
  fi
  action_init >/dev/null
}

action_init() {
  require_jq
  require_sqlite3

  if ! fts5_available; then
    log_error "SQLite FTS5 is required for session archive init."
    log_error "Tried: sqlite3 :memory: \"CREATE VIRTUAL TABLE t USING fts5(a);\""
    log_error "Install an sqlite3 build with FTS5 support and retry."
    exit 1
  fi

  ensure_archive_layout
  write_default_settings
  create_schema
  update_state_file ""
  action_status
}

queue_line_path() {
  local raw_line="${1-}"
  local trimmed_line=""

  trimmed_line="$(printf '%s' "$raw_line" | tr -d '\r')"
  if [[ -z "$trimmed_line" ]]; then
    return 1
  fi

  if [[ "$trimmed_line" == \{* ]]; then
    printf '%s' "$trimmed_line" | jq -r '.source_path // .transcript_path // .path // empty' 2>/dev/null | awk 'NF { print; exit }'
    return 0
  fi

  printf '%s\n' "$trimmed_line"
}

append_queue_path() {
  local source_path="${1:?Missing source path}"
  ensure_archive_layout
  printf '%s\n' "$source_path" >>"$QUEUE_FILE"
}

extract_queue_paths() {
  local queue_snapshot="${1:?Missing queue snapshot}"
  local raw_line=""
  local source_path=""

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    source_path="$(queue_line_path "$raw_line" 2>/dev/null || true)"
    if [[ -n "$source_path" ]]; then
      printf '%s\n' "$source_path"
    elif [[ -n "$(normalize_text "$raw_line")" ]]; then
      log_error "Dropping malformed queue line."
    fi
  done <"$queue_snapshot"
}

emit_source_items_json() {
  local source_path="${1:?Missing source path}"

  jq -cRn '
    def meta_wrapped($text):
      ($text | type == "string") and ($text | test("^<(local-command-[^>]+|command-[A-Za-z0-9_-]+)>"));
    def emit($speaker; $kind; $content; $line_no; $item_no; $tool_name; $tool_use_id; $is_error; $is_meta; $raw_uuid; $payload):
      {
        speaker: $speaker,
        segment_kind: $kind,
        content: ($content // ""),
        line_no: $line_no,
        item_no: $item_no,
        tool_name: ($tool_name // ""),
        tool_use_id: ($tool_use_id // ""),
        is_error: (if $is_error then 1 else 0 end),
        is_meta: (if $is_meta then 1 else 0 end),
        raw_uuid: ($raw_uuid // ""),
        ts: (.timestamp // ""),
        payload_json: $payload
      };
    inputs as $raw
    | (input_line_number) as $line_no
    | ($raw | fromjson?) as $rec
    | if $rec == null then
        empty
      elif ($rec.type // "") == "assistant" then
        ($rec.message.content // empty) as $content
        | if ($content | type) == "array" then
            $content
            | to_entries[]
            | .key as $item_no
            | .value as $block
            | if ($block.type // "") == "text" then
                ($rec | emit("assistant"; "text"; ($block.text // ""); $line_no; $item_no; ""; ""; false; false; ($rec.uuid // ""); null))
              elif ($block.type // "") == "tool_use" then
                ($rec | emit("assistant"; "tool_use"; ""; $line_no; $item_no; ($block.name // ""); ($block.id // ""); false; false; ($rec.uuid // ""); {input: ($block.input // {}), caller: ($block.caller // null)}))
              else
                empty
              end
          elif ($content | type) == "string" then
            ($rec | emit("assistant"; "text"; $content; $line_no; 0; ""; ""; false; false; ($rec.uuid // ""); null))
          else
            empty
          end
      elif ($rec.type // "") == "user" then
        ($rec.message.content // empty) as $content
        | if ($content | type) == "string" then
            ($rec | emit("user"; (if meta_wrapped($content) then "meta" else "text" end); $content; $line_no; 0; ""; ""; false; meta_wrapped($content); ($rec.uuid // ""); null))
          elif ($content | type) == "array" then
            $content
            | to_entries[]
            | .key as $item_no
            | .value as $block
            | if ($block.type // "") == "tool_result" then
                ($rec | emit("tool"; "tool_result"; ""; $line_no; $item_no; ""; ($block.tool_use_id // ""); false; false; ($rec.uuid // ""); {
                  tool_result_block: $block,
                  tool_use_result: ($rec.toolUseResult // null),
                  mcp_meta: ($rec.mcpMeta // null),
                  source_tool_assistant_uuid: ($rec.sourceToolAssistantUUID // null)
                }))
              elif ($block.type // "") == "text" then
                ($rec | emit("user"; "text"; ($block.text // $block.content // ""); $line_no; $item_no; ""; ""; false; false; ($rec.uuid // ""); null))
              else
                empty
              end
          else
            empty
          end
      elif ($rec.type // "") == "system" and ($rec.subtype // "") == "local_command" then
        ($rec | emit("tool"; "meta"; ($rec.content // ""); $line_no; 0; ""; ""; false; true; ($rec.uuid // ""); null))
      else
        empty
      end
    | .
  ' "$source_path"
}

sanitize_tool_input_json() {
  local raw_json="${1:-null}"

  printf '%s' "$raw_json" | jq -c '
    def scrub:
      if type == "object" then
        with_entries(
          select(.key | test("(?i)(blob|base64|bytes|binary|image|images|data|content)$") | not)
          | .value |= scrub
        )
      elif type == "array" then
        map(scrub)
      else
        .
      end;
    (try .input catch .) // {}
    | scrub
  ' 2>/dev/null || printf '{}'
}

json_path_hint() {
  local raw_json="${1:-null}"
  printf '%s' "$raw_json" | jq -r '
    [
      .file_path?,
      .path?,
      .cwd?,
      .input.file_path?,
      .input.path?
    ]
    | .[]
    | select(type == "string" and length > 0)
    | .
  ' 2>/dev/null | awk 'NF { print; exit }'
}

json_command_hint() {
  local raw_json="${1:-null}"
  printf '%s' "$raw_json" | jq -r '
    [
      .command?,
      .input.command?,
      .prompt?,
      .input.prompt?,
      .pattern?,
      .input.pattern?
    ]
    | .[]
    | select(type == "string" and length > 0)
    | .
  ' 2>/dev/null | awk 'NF { print; exit }'
}

summarize_tool_use() {
  local tool_name="${1-}"
  local raw_payload_json="${2:-null}"
  local sanitized_json=""
  local path_hint=""
  local command_hint=""
  local detail=""

  sanitized_json="$(sanitize_tool_input_json "$raw_payload_json")"
  path_hint="$(json_path_hint "$sanitized_json")"
  command_hint="$(json_command_hint "$sanitized_json")"

  case "$tool_name" in
    Read | Write | Edit)
      detail="${path_hint:+path=$path_hint}"
      ;;
    Glob)
      detail="${command_hint:+pattern=$command_hint}"
      if [[ -n "$path_hint" ]]; then
        detail="$(normalize_text "$detail path=$path_hint")"
      fi
      ;;
    Grep)
      detail="${command_hint:+pattern=$command_hint}"
      if [[ -n "$path_hint" ]]; then
        detail="$(normalize_text "$detail path=$path_hint")"
      fi
      ;;
    Bash)
      detail="${command_hint:+command=$command_hint}"
      ;;
    Agent | Task*)
      detail="${command_hint:+prompt=$command_hint}"
      ;;
    *)
      detail="$(printf '%s' "$sanitized_json" | jq -c '.' 2>/dev/null || printf '{}')"
      ;;
  esac

  cap_text "$(normalize_text "$tool_name $detail")" 512
}

tool_result_display_text() {
  local raw_payload_json="${1:-null}"

  printf '%s' "$raw_payload_json" | jq -r '
    def flatten:
      if . == null then
        empty
      elif type == "string" then
        if (startswith("{") or startswith("[")) then
          (try (fromjson | flatten) catch .)
        else
          .
        end
      elif type == "array" then
        map(flatten)
        | map(select(type == "string" and length > 0))
        | join(" ")
      elif type == "object" then
        if has("stdout") or has("stderr") then
          [(.stdout // null), (.stderr // null)] | flatten
        elif has("text") then
          .text
        elif has("content") then
          .content | flatten
        elif has("tool_name") then
          .tool_name
        elif has("path") then
          .path
        else
          tostring
        end
      else
        tostring
      end;
    [
      (.tool_result_block.content // null | flatten),
      (.tool_use_result // null | flatten),
      (.mcp_meta.structuredContent // null | flatten)
    ]
    | map(select(type == "string" and length > 0))
    | join(" ")
  ' 2>/dev/null
}

summarize_tool_result() {
  local tool_name="${1-}"
  local raw_payload_json="${2:-null}"
  local tool_input_json="${3:-null}"
  local result_text=""
  local path_hint=""
  local size_hint="0"

  result_text="$(tool_result_display_text "$raw_payload_json")"
  result_text="$(normalize_text "$result_text")"
  path_hint="$(json_path_hint "$tool_input_json")"
  size_hint="$(printf '%s' "$result_text" | wc -c | awk '{print $1}')"

  case "$tool_name" in
    Bash | Grep | Agent | Task*)
      cap_text "$result_text" "$TOOL_RESULT_STDOUT_CAP"
      ;;
    Read | Write | Edit | Glob)
      cap_text "$(normalize_text "$tool_name path=${path_hint:-unknown} size=$size_hint")" 256
      ;;
    *)
      cap_text "$(normalize_text "${tool_name:-tool} $result_text")" "$DEFAULT_RESULT_CAP"
      ;;
  esac
}

build_route_hint_json() {
  local raw_text="${1-}"
  local structured_json="${2-}"
  local fallback_session_id="${3-}"
  local hint_json=""

  hint_json="$(learning_extract_route_hint "$raw_text" "$structured_json" "$fallback_session_id" 2>/dev/null || true)"
  if [[ -z "$hint_json" ]]; then
    printf '\n'
    return 0
  fi

  printf '%s\n' "$hint_json"
}

segment_id_for() {
  local source_path="${1:?Missing source path}"
  local agent_kind="${2:?Missing agent kind}"
  local session_id="${3:?Missing session id}"
  local line_no="${4:?Missing line number}"
  local item_no="${5:?Missing item number}"
  local source_stem=""

  if [[ "$agent_kind" == "main" ]]; then
    printf 'main:%s:%s:%s\n' "$session_id" "$line_no" "$item_no"
    return 0
  fi

  source_stem="$(basename "$source_path" .jsonl)"
  printf 'subagent:%s:%s:%s:%s\n' "$session_id" "$source_stem" "$line_no" "$item_no"
}

parse_source_to_tsv() {
  local source_path="${1:?Missing source path}"
  local segments_tsv="${2:?Missing segment output path}"
  local agent_kind=""
  local project_slug=""
  local fallback_session_id=""
  local session_id=""
  local parent_session_id=""
  local project_cwd=""
  local speaker=""
  local segment_kind=""
  local ts=""
  local line_no=""
  local item_no=""
  local tool_name=""
  local tool_use_id=""
  local is_error=""
  local is_meta=""
  local raw_uuid=""
  local raw_content=""
  local payload_json=""
  local final_content=""
  local route_hint_json=""
  local component_hint=""
  local command_hint=""
  local task_key=""
  local segment_id=""
  local turn_no=0
  local last_line_no=""
  local item_json=""
  local -a item_fields=()
  local -a route_fields=()
  local session_anchor_assigned=0

  declare -A TOOL_NAME_MAP=()
  declare -A TOOL_INPUT_MAP=()
  declare -A TOOL_HINT_MAP=()

  agent_kind="$(agent_kind_from_source "$source_path")"
  project_slug="$(project_slug_from_source "$source_path")"
  fallback_session_id="$(fallback_session_id_from_source "$source_path")"
  session_id="$(source_session_id "$source_path" "$fallback_session_id")"
  parent_session_id="$(parent_session_id_from_source "$source_path")"
  project_cwd="$(source_project_cwd "$source_path")"

  : >"$segments_tsv"

  while IFS= read -r item_json; do
    [[ -n "$item_json" ]] || continue
    mapfile -t item_fields < <(
      printf '%s' "$item_json" |
        jq -r '
          .speaker,
          .segment_kind,
          (.ts // ""),
          (.line_no | tostring),
          (.item_no | tostring),
          (.tool_name // ""),
          (.tool_use_id // ""),
          (.is_error | tostring),
          (.is_meta | tostring),
          (.raw_uuid // ""),
          (.content // ""),
          ((.payload_json // null) | tojson)
        '
    )
    speaker="${item_fields[0]-}"
    segment_kind="${item_fields[1]-}"
    ts="${item_fields[2]-}"
    line_no="${item_fields[3]-}"
    item_no="${item_fields[4]-}"
    tool_name="${item_fields[5]-}"
    tool_use_id="${item_fields[6]-}"
    is_error="${item_fields[7]-0}"
    is_meta="${item_fields[8]-0}"
    raw_uuid="${item_fields[9]-}"
    raw_content="${item_fields[10]-}"
    payload_json="${item_fields[11]-null}"

    final_content=""
    component_hint=""
    command_hint=""
    task_key=""
    route_hint_json=""

    case "$segment_kind" in
      tool_use)
        final_content="$(summarize_tool_use "$tool_name" "$payload_json")"
        route_hint_json="$(build_route_hint_json "$final_content" "$payload_json" "$session_id")"
        TOOL_NAME_MAP["$tool_use_id"]="$tool_name"
        TOOL_INPUT_MAP["$tool_use_id"]="$(sanitize_tool_input_json "$payload_json")"
        TOOL_HINT_MAP["$tool_use_id"]="$route_hint_json"
        ;;
      tool_result)
        if [[ -n "${TOOL_NAME_MAP[$tool_use_id]-}" ]]; then
          tool_name="${TOOL_NAME_MAP[$tool_use_id]}"
        fi
        final_content="$(summarize_tool_result "$tool_name" "$payload_json" "${TOOL_INPUT_MAP[$tool_use_id]-null}")"
        route_hint_json="$(build_route_hint_json "$final_content" "${TOOL_INPUT_MAP[$tool_use_id]-null}" "$session_id")"
        if [[ -z "$route_hint_json" ]]; then
          route_hint_json="${TOOL_HINT_MAP[$tool_use_id]-}"
        fi
        ;;
      *)
        final_content="$(cap_text "$raw_content" 4096)"
        route_hint_json="$(build_route_hint_json "$final_content" "" "$session_id")"
        ;;
    esac

    final_content="$(normalize_text "$final_content")"
    if [[ -z "$final_content" ]]; then
      continue
    fi

    if [[ -n "$route_hint_json" ]]; then
      mapfile -t route_fields < <(
        printf '%s' "$route_hint_json" |
          jq -r '
            .component // "",
            .command // "",
            .task_key // ""
          '
      )
      component_hint="${route_fields[0]-}"
      command_hint="${route_fields[1]-}"
      task_key="${route_fields[2]-}"
    fi

    if [[ "$is_meta" != "1" && "$session_anchor_assigned" -eq 0 ]]; then
      if [[ -z "$component_hint" && -z "$command_hint" ]]; then
        command_hint="session"
      fi
      if [[ -z "$task_key" ]]; then
        task_key="session:$session_id"
      fi
      session_anchor_assigned=1
    fi

    if [[ "$line_no" != "$last_line_no" ]]; then
      turn_no=$((turn_no + 1))
      last_line_no="$line_no"
    fi

    segment_id="$(segment_id_for "$source_path" "$agent_kind" "$session_id" "$line_no" "$item_no")"

    append_import_row "$segments_tsv" \
      "$segment_id" \
      "$source_path" \
      "$session_id" \
      "${parent_session_id-}" \
      "$project_slug" \
      "$agent_kind" \
      "$speaker" \
      "$segment_kind" \
      "${ts-}" \
      "$line_no" \
      "$item_no" \
      "$turn_no" \
      "${tool_name-}" \
      "${tool_use_id-}" \
      "$is_error" \
      "$is_meta" \
      "${command_hint-}" \
      "${component_hint-}" \
      "${task_key-}" \
      "${raw_uuid-}" \
      "$final_content"
  done < <(emit_source_items_json "$source_path")

  PARSED_SOURCE_AGENT_KIND="$agent_kind"
  PARSED_SOURCE_PROJECT_SLUG="$project_slug"
  PARSED_SOURCE_SESSION_ID="$session_id"
  PARSED_SOURCE_PARENT_SESSION_ID="${parent_session_id-}"
  PARSED_SOURCE_PROJECT_CWD="${project_cwd-}"
}

import_segments_for_source() {
  local source_path="${1:?Missing source path}"
  local source_mtime="${2:?Missing source mtime}"
  local source_size="${3:?Missing source size}"
  local source_hash="${4:?Missing source hash}"
  local segments_tsv="${5:?Missing segments tsv}"
  local indexed_at="${6:?Missing indexed timestamp}"
  local sqlite_script=""
  local separator_cmd=""

  sqlite_script="$(mktemp /tmp/session-archive-sql.XXXXXX)"
  separator_cmd="$(printf '.separator "%s" "%s"' "$IMPORT_FIELD_SEPARATOR" "$IMPORT_RECORD_SEPARATOR")"
  cat >"$sqlite_script" <<EOF
PRAGMA foreign_keys = ON;
BEGIN IMMEDIATE;
DELETE FROM sources WHERE source_path = $(sql_quote "$source_path");
CREATE TEMP TABLE temp_segments (
  segment_id TEXT,
  source_path TEXT,
  session_id TEXT,
  parent_session_id TEXT,
  project_slug TEXT,
  agent_kind TEXT,
  speaker TEXT,
  segment_kind TEXT,
  ts TEXT,
  line_no TEXT,
  item_no TEXT,
  turn_no TEXT,
  tool_name TEXT,
  tool_use_id TEXT,
  is_error TEXT,
  is_meta TEXT,
  command_hint TEXT,
  component_hint TEXT,
  task_key TEXT,
  raw_uuid TEXT,
  content TEXT
);
.import "$segments_tsv" temp_segments
INSERT INTO sources (
  source_path,
  session_id,
  parent_session_id,
  project_slug,
  project_cwd,
  agent_kind,
  source_mtime,
  source_size,
  source_hash,
  indexed_at
) VALUES (
  $(sql_quote "$source_path"),
  $(sql_quote "$PARSED_SOURCE_SESSION_ID"),
  $(sql_nullable "${PARSED_SOURCE_PARENT_SESSION_ID-}"),
  $(sql_quote "$PARSED_SOURCE_PROJECT_SLUG"),
  $(sql_nullable "${PARSED_SOURCE_PROJECT_CWD-}"),
  $(sql_quote "$PARSED_SOURCE_AGENT_KIND"),
  $source_mtime,
  $source_size,
  $(sql_quote "$source_hash"),
  $(sql_quote "$indexed_at")
);
INSERT INTO segments (
  segment_id,
  source_path,
  session_id,
  parent_session_id,
  project_slug,
  agent_kind,
  speaker,
  segment_kind,
  ts,
  line_no,
  item_no,
  turn_no,
  tool_name,
  tool_use_id,
  is_error,
  is_meta,
  command_hint,
  component_hint,
  task_key,
  raw_uuid,
  content
)
SELECT
  segment_id,
  source_path,
  session_id,
  NULLIF(parent_session_id, ''),
  project_slug,
  agent_kind,
  speaker,
  segment_kind,
  NULLIF(ts, ''),
  CAST(line_no AS INTEGER),
  CAST(item_no AS INTEGER),
  NULLIF(turn_no, ''),
  NULLIF(tool_name, ''),
  NULLIF(tool_use_id, ''),
  CAST(COALESCE(NULLIF(is_error, ''), '0') AS INTEGER),
  CAST(COALESCE(NULLIF(is_meta, ''), '0') AS INTEGER),
  NULLIF(command_hint, ''),
  NULLIF(component_hint, ''),
  NULLIF(task_key, ''),
  NULLIF(raw_uuid, ''),
  content
FROM temp_segments;
INSERT INTO segments_fts(segments_fts) VALUES ('rebuild');
DROP TABLE temp_segments;
COMMIT;
EOF

  sqlite3 -cmd '.mode ascii' -cmd "$separator_cmd" "$INDEX_FILE" <"$sqlite_script"
  rm -f "$sqlite_script"
}

PROCESS_SOURCE_STATUS=""

process_source() {
  local source_path="${1:?Missing source path}"
  local source_mtime=""
  local source_size=""
  local source_hash=""
  local existing_row=""
  local segments_tsv=""
  local indexed_at=""

  PROCESS_SOURCE_STATUS="failed"

  if [[ ! -f "$source_path" ]]; then
    log_error "Skipping missing source: $source_path"
    PROCESS_SOURCE_STATUS="dropped"
    return 0
  fi

  source_mtime="$(stat_mtime "$source_path")"
  source_size="$(stat_size "$source_path")"
  source_hash="$(sha256_file "$source_path")"

  existing_row="$(sqlite3 -separator $'\t' "$INDEX_FILE" "SELECT source_mtime, source_size, COALESCE(source_hash, '') FROM sources WHERE source_path = $(sql_quote "$source_path");" 2>/dev/null || true)"
  if [[ -n "$existing_row" ]]; then
    IFS=$'\t' read -r existing_mtime existing_size existing_hash <<<"$existing_row"
    if [[ "$existing_mtime" == "$source_mtime" && "$existing_size" == "$source_size" && "$existing_hash" == "$source_hash" ]]; then
      PROCESS_SOURCE_STATUS="skipped"
      return 0
    fi
  fi

  segments_tsv="$(mktemp /tmp/session-archive-segments.XXXXXX)"
  if ! parse_source_to_tsv "$source_path" "$segments_tsv"; then
    rm -f "$segments_tsv"
    log_error "Failed to parse source: $source_path"
    return 1
  fi

  indexed_at="$(timestamp_utc)"
  if ! import_segments_for_source "$source_path" "$source_mtime" "$source_size" "$source_hash" "$segments_tsv" "$indexed_at"; then
    rm -f "$segments_tsv"
    log_error "Failed to index source: $source_path"
    return 1
  fi

  rm -f "$segments_tsv"
  PROCESS_SOURCE_STATUS="updated"
  return 0
}

rewrite_queue_excluding_paths() {
  local queue_snapshot="${1:?Missing queue snapshot}"
  local drop_paths_file="${2:?Missing drop paths file}"
  local rewritten_queue=""
  local raw_line=""
  local source_path=""

  rewritten_queue="$(mktemp /tmp/session-archive-queue.XXXXXX)"

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    source_path="$(queue_line_path "$raw_line" 2>/dev/null || true)"
    if [[ -z "$source_path" ]]; then
      if [[ -n "$(normalize_text "$raw_line")" ]]; then
        log_error "Dropping malformed queue line during rewrite."
      fi
      continue
    fi

    if grep -Fqx "$source_path" "$drop_paths_file" 2>/dev/null; then
      continue
    fi

    printf '%s\n' "$raw_line" >>"$rewritten_queue"
  done <"$queue_snapshot"

  mv "$rewritten_queue" "$QUEUE_FILE"
}

action_sync() {
  require_jq
  require_sqlite3
  ensure_initialized

  local budget_seconds=""
  local queue_snapshot=""
  local unique_paths_file=""
  local drop_paths_file=""
  local source_path=""
  local start_epoch=""
  local now_epoch=""
  local processed=0
  local updated=0
  local skipped=0
  local dropped=0
  local failed=0
  local last_sync_at=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --budget-seconds)
        [[ $# -ge 2 ]] || die_usage "Missing value for --budget-seconds."
        budget_seconds="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown sync option: $1"
        ;;
    esac
  done

  ensure_archive_layout
  queue_snapshot="$(mktemp /tmp/session-archive-queue.XXXXXX)"
  cp "$QUEUE_FILE" "$queue_snapshot"

  unique_paths_file="$(mktemp /tmp/session-archive-paths.XXXXXX)"
  drop_paths_file="$(mktemp /tmp/session-archive-drop.XXXXXX)"

  extract_queue_paths "$queue_snapshot" | awk '!seen[$0]++' >"$unique_paths_file"
  start_epoch="$(date -u +%s)"

  while IFS= read -r source_path; do
    [[ -n "$source_path" ]] || continue

    if [[ -n "$budget_seconds" ]]; then
      now_epoch="$(date -u +%s)"
      if ((now_epoch - start_epoch >= budget_seconds)) && ((processed > 0)); then
        break
      fi
    fi

    if process_source "$source_path"; then
      processed=$((processed + 1))
      case "$PROCESS_SOURCE_STATUS" in
        updated)
          updated=$((updated + 1))
          printf '%s\n' "$source_path" >>"$drop_paths_file"
          ;;
        skipped)
          skipped=$((skipped + 1))
          printf '%s\n' "$source_path" >>"$drop_paths_file"
          ;;
        dropped)
          dropped=$((dropped + 1))
          printf '%s\n' "$source_path" >>"$drop_paths_file"
          ;;
      esac
    else
      failed=$((failed + 1))
    fi
  done <"$unique_paths_file"

  rewrite_queue_excluding_paths "$queue_snapshot" "$drop_paths_file"
  last_sync_at="$(timestamp_utc)"
  update_state_file "$last_sync_at"

  rm -f "$queue_snapshot" "$unique_paths_file" "$drop_paths_file"

  jq -cn \
    --arg last_sync_at "$last_sync_at" \
    --argjson processed "$processed" \
    --argjson updated "$updated" \
    --argjson skipped "$skipped" \
    --argjson dropped "$dropped" \
    --argjson failed "$failed" \
    --argjson pending_remaining "$(queue_pending_count)" \
    '{
      last_sync_at: $last_sync_at,
      processed: $processed,
      updated: $updated,
      skipped: $skipped,
      dropped: $dropped,
      failed: $failed,
      pending_remaining: $pending_remaining
    }'
}

build_fts_query() {
  local raw_query="${1:?Missing query}"
  local normalized_query=""
  local token=""
  local fts_query=""

  normalized_query="$(printf '%s' "$raw_query" | tr -cs '[:alnum:]' ' ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  if [[ -z "$normalized_query" ]]; then
    normalized_query="$(normalize_text "$raw_query")"
  fi
  [[ -n "$normalized_query" ]] || return 1

  for token in $normalized_query; do
    token="${token//\"/}"
    token="${token//\'/}"
    [[ -n "$token" ]] || continue
    if [[ -n "$fts_query" ]]; then
      fts_query="$fts_query AND "
    fi
    fts_query="${fts_query}\"$token\""
  done

  printf '%s\n' "$fts_query"
}

search_rows_to_json() {
  local query="${1:?Missing query}"
  local pending_ingest="${2:?Missing pending count}"
  local rows_file="${3:?Missing rows file}"

  jq -Rn \
    --arg query "$query" \
    --argjson pending_ingest "$pending_ingest" \
    '
      [inputs | split("\u001f")] as $rows
      | {
          query: $query,
          pending_ingest: $pending_ingest,
          count: ($rows | length),
          hits: (
            $rows
            | map({
                segment_id: .[0],
                score: (.[1] | tonumber),
                session_id: .[2],
                project_slug: .[3],
                agent_kind: .[4],
                speaker: .[5],
                segment_kind: .[6],
                component_hint: (if .[7] == "" then null else .[7] end),
                tool_name: (if .[8] == "" then null else .[8] end),
                ts: (if .[9] == "" then null else .[9] end),
                snippet: .[10],
                source_ref: .[11]
              })
          )
        }
    ' "$rows_file"
}

search_rows_to_text() {
  local rows_file="${1:?Missing rows file}"
  local segment_id=""
  local score=""
  local session_id=""
  local project_slug=""
  local agent_kind=""
  local speaker=""
  local segment_kind=""
  local component_hint=""
  local tool_name=""
  local ts=""
  local snippet=""
  local source_ref=""

  while IFS="$RESULT_SEPARATOR" read -r segment_id score session_id project_slug agent_kind speaker segment_kind component_hint tool_name ts snippet source_ref; do
    printf '%s [%s] %s/%s %s\n' "$segment_id" "$score" "$speaker" "$segment_kind" "${ts:-no-ts}"
    printf '  project=%s agent=%s session=%s\n' "$project_slug" "$agent_kind" "$session_id"
    if [[ -n "$component_hint" ]]; then
      printf '  component=%s\n' "$component_hint"
    fi
    if [[ -n "$tool_name" ]]; then
      printf '  tool=%s\n' "$tool_name"
    fi
    printf '  %s\n' "$snippet"
    printf '  %s\n' "$source_ref"
  done <"$rows_file"
}

action_search() {
  require_jq
  require_sqlite3
  ensure_initialized

  local query="${1-}"
  local since_spec=""
  local project_filter="current"
  local agent_filter="all"
  local component_filter=""
  local top_n="$DEFAULT_SEARCH_TOP"
  local format="text"
  local include_meta=0
  local fts_query=""
  local sql_where=""
  local rows_file=""
  local pending_ingest=""
  local since_epoch=""
  local project_slug=""

  [[ -n "$query" ]] || die_usage "search requires a query."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        [[ $# -ge 2 ]] || die_usage "Missing value for --since."
        since_spec="$2"
        shift 2
        ;;
      --project)
        [[ $# -ge 2 ]] || die_usage "Missing value for --project."
        project_filter="$2"
        shift 2
        ;;
      --agent)
        [[ $# -ge 2 ]] || die_usage "Missing value for --agent."
        agent_filter="$2"
        shift 2
        ;;
      --component)
        [[ $# -ge 2 ]] || die_usage "Missing value for --component."
        component_filter="$2"
        shift 2
        ;;
      --top)
        [[ $# -ge 2 ]] || die_usage "Missing value for --top."
        top_n="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      --include-meta)
        include_meta=1
        shift
        ;;
      *)
        die_usage "Unknown search option: $1"
        ;;
    esac
  done

  fts_query="$(build_fts_query "$query")" || die_usage "search query must not be empty."
  sql_where="1=1"

  if [[ "$include_meta" -eq 0 ]]; then
    sql_where="$sql_where AND s.is_meta = 0"
  fi

  case "$project_filter" in
    current)
      project_slug="$(current_project_slug)"
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_slug")"
      ;;
    all)
      ;;
    *)
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_filter")"
      ;;
  esac

  case "$agent_filter" in
    all)
      ;;
    main | subagent)
      sql_where="$sql_where AND s.agent_kind = $(sql_quote "$agent_filter")"
      ;;
    *)
      die_usage "Unknown agent filter: $agent_filter"
      ;;
  esac

  if [[ -n "$component_filter" ]]; then
    sql_where="$sql_where AND (s.component_hint = $(sql_quote "$component_filter") OR s.command_hint = $(sql_quote "$component_filter"))"
  fi

  if [[ -n "$since_spec" ]]; then
    since_epoch="$(epoch_from_spec "$since_spec" 2>/dev/null || true)"
    if [[ -z "$since_epoch" ]]; then
      die_usage "Unsupported --since value: $since_spec"
    fi
    sql_where="$sql_where AND src.source_mtime >= $since_epoch"
  fi

  rows_file="$(mktemp /tmp/session-archive-search.XXXXXX)"
  sqlite3 -separator "$RESULT_SEPARATOR" "$INDEX_FILE" "
    SELECT
      s.segment_id,
      printf('%.4f', -bm25(segments_fts)),
      s.session_id,
      s.project_slug,
      s.agent_kind,
      s.speaker,
      s.segment_kind,
      COALESCE(s.component_hint, ''),
      COALESCE(s.tool_name, ''),
      COALESCE(s.ts, ''),
      REPLACE(REPLACE(REPLACE(snippet(segments_fts, 0, '[', ']', '...', 12), char(9), ' '), char(10), ' '), char(13), ' '),
      REPLACE(s.source_path, $(sql_quote "$HOME"), '~') || ':' || s.line_no
    FROM segments_fts
    JOIN segments s ON s.rowid = segments_fts.rowid
    JOIN sources src ON src.source_path = s.source_path
    WHERE segments_fts MATCH $(sql_quote "$fts_query")
      AND $sql_where
    ORDER BY bm25(segments_fts), COALESCE(s.ts, '') DESC, s.segment_id
    LIMIT $top_n;
  " >"$rows_file"

  pending_ingest="$(queue_pending_count)"
  case "$format" in
    json)
      search_rows_to_json "$query" "$pending_ingest" "$rows_file"
      ;;
    text)
      search_rows_to_text "$rows_file"
      ;;
    *)
      rm -f "$rows_file"
      die_usage "Unknown search format: $format"
      ;;
  esac

  rm -f "$rows_file"
}

segments_rows_to_json() {
  local identifier="${1:?Missing identifier}"
  local rows_file="${2:?Missing rows file}"

  jq -Rn \
    --arg identifier "$identifier" \
    '
      [inputs | split("\u001f")] as $rows
      | {
          target: $identifier,
          count: ($rows | length),
          segments: (
            $rows
            | map({
                segment_id: .[0],
                session_id: .[1],
                project_slug: .[2],
                agent_kind: .[3],
                speaker: .[4],
                segment_kind: .[5],
                ts: (if .[6] == "" then null else .[6] end),
                tool_name: (if .[7] == "" then null else .[7] end),
                component_hint: (if .[8] == "" then null else .[8] end),
                content: .[9],
                source_ref: .[10]
              })
          )
        }
    ' "$rows_file"
}

segments_rows_to_text() {
  local rows_file="${1:?Missing rows file}"
  local segment_id=""
  local session_id=""
  local project_slug=""
  local agent_kind=""
  local speaker=""
  local segment_kind=""
  local ts=""
  local tool_name=""
  local component_hint=""
  local content=""
  local source_ref=""

  while IFS="$RESULT_SEPARATOR" read -r segment_id session_id project_slug agent_kind speaker segment_kind ts tool_name component_hint content source_ref; do
    printf '%s %s/%s %s\n' "$segment_id" "$speaker" "$segment_kind" "${ts:-no-ts}"
    if [[ -n "$tool_name" ]]; then
      printf '  tool=%s\n' "$tool_name"
    fi
    if [[ -n "$component_hint" ]]; then
      printf '  component=%s\n' "$component_hint"
    fi
    printf '  %s\n' "$content"
    printf '  %s\n' "$source_ref"
  done <"$rows_file"
}

action_get() {
  require_jq
  require_sqlite3
  ensure_initialized

  local identifier="${1-}"
  local before_count=2
  local after_count=2
  local format="text"
  local rows_file=""
  local target_exists=0

  [[ -n "$identifier" ]] || die_usage "get requires a segment-id or session-id."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --before)
        [[ $# -ge 2 ]] || die_usage "Missing value for --before."
        before_count="$2"
        shift 2
        ;;
      --after)
        [[ $# -ge 2 ]] || die_usage "Missing value for --after."
        after_count="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown get option: $1"
        ;;
    esac
  done

  rows_file="$(mktemp /tmp/session-archive-get.XXXXXX)"
  target_exists="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM segments WHERE segment_id = $(sql_quote "$identifier");" 2>/dev/null || printf '0')"

  if [[ "$target_exists" != "0" ]]; then
    sqlite3 -separator "$RESULT_SEPARATOR" "$INDEX_FILE" "
      WITH target AS (
        SELECT source_path, line_no, item_no
        FROM segments
        WHERE segment_id = $(sql_quote "$identifier")
      ),
      ordered AS (
        SELECT
          s.segment_id,
          s.session_id,
          s.project_slug,
          s.agent_kind,
          s.speaker,
          s.segment_kind,
          COALESCE(s.ts, '') AS ts,
          COALESCE(s.tool_name, '') AS tool_name,
          COALESCE(s.component_hint, '') AS component_hint,
          s.content AS content,
          REPLACE(s.source_path, $(sql_quote "$HOME"), '~') || ':' || s.line_no AS source_ref,
          ROW_NUMBER() OVER (ORDER BY s.line_no, s.item_no) AS seq
        FROM segments s
        JOIN target t ON t.source_path = s.source_path
      ),
      anchor AS (
        SELECT seq
        FROM ordered
        WHERE segment_id = $(sql_quote "$identifier")
      )
      SELECT segment_id, session_id, project_slug, agent_kind, speaker, segment_kind, ts, tool_name, component_hint, content, source_ref
      FROM ordered
      WHERE seq BETWEEN ((SELECT seq FROM anchor) - $before_count) AND ((SELECT seq FROM anchor) + $after_count)
      ORDER BY seq;
    " >"$rows_file"
  else
    sqlite3 -separator "$RESULT_SEPARATOR" "$INDEX_FILE" "
      SELECT
        s.segment_id,
        s.session_id,
        s.project_slug,
        s.agent_kind,
        s.speaker,
        s.segment_kind,
        COALESCE(s.ts, ''),
        COALESCE(s.tool_name, ''),
        COALESCE(s.component_hint, ''),
        s.content,
        REPLACE(s.source_path, $(sql_quote "$HOME"), '~') || ':' || s.line_no AS source_ref
      FROM segments s
      WHERE s.session_id = $(sql_quote "$identifier")
         OR s.parent_session_id = $(sql_quote "$identifier")
      ORDER BY COALESCE(s.ts, ''), s.source_path, s.line_no, s.item_no;
    " >"$rows_file"
  fi

  case "$format" in
    json)
      segments_rows_to_json "$identifier" "$rows_file"
      ;;
    text)
      segments_rows_to_text "$rows_file"
      ;;
    *)
      rm -f "$rows_file"
      die_usage "Unknown get format: $format"
      ;;
  esac

  rm -f "$rows_file"
}

select_rows_to_json() {
  local query="${1:?Missing query}"
  local rows_file="${2:?Missing rows file}"

  jq -Rn \
    --arg query "$query" \
    '
      [inputs | split("\u001f")] as $rows
      | ($rows | sort_by(.[0] | tonumber) | group_by(.[0])) as $groups
      | {
          query: $query,
          count: ($groups | length),
          hits: (
            $groups
            | map({
                segment_id: .[0][1],
                score: (.[0][2] | tonumber),
                session_id: .[0][3],
                project_slug: .[0][4],
                agent_kind: .[0][5],
                component_hint: (if .[0][6] == "" then null else .[0][6] end),
                task_key: (if .[0][7] == "" then null else .[0][7] end),
                snippet: .[0][8],
                ts: (if .[0][9] == "" then null else .[0][9] end),
                neighbors: (
                  map({
                    segment_id: .[10],
                    speaker: .[11],
                    segment_kind: .[12],
                    content: .[13],
                    ts: (if .[14] == "" then null else .[14] end)
                  })
                )
              })
          )
        }
    ' "$rows_file"
}

select_json_to_text() {
  local select_json="${1:?Missing select json}"

  printf '%s\n' "$select_json" |
    jq -r '
      if .count == 0 then
        "No matching segments found."
      else
        "Select results for: " + .query,
        (
          .hits[]
          | "\n" + .segment_id + " [" + (.score | tostring) + "] " + (.ts // "no-ts"),
            "  project=" + .project_slug + " agent=" + .agent_kind + " session=" + .session_id,
            (if .component_hint then "  component=" + .component_hint else empty end),
            (if .task_key then "  task_key=" + .task_key else empty end),
            "  " + .snippet,
            "  neighbors:",
            (
              .neighbors[]
              | "    - " + .segment_id + " " + .speaker + "/" + .segment_kind + " " + (.ts // "no-ts") + ": " + .content
            )
        )
      end
    '
}

action_select() {
  require_jq
  require_sqlite3
  ensure_initialized

  local query="${1-}"
  local since_spec=""
  local project_filter="current"
  local agent_filter="all"
  local top_n="$DEFAULT_SEARCH_TOP"
  local format="text"
  local fts_query=""
  local sql_where=""
  local rows_file=""
  local since_epoch=""
  local project_slug=""
  local select_json=""
  local before_count=2
  local after_count=2

  [[ -n "$query" ]] || die_usage "select requires a query."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        [[ $# -ge 2 ]] || die_usage "Missing value for --since."
        since_spec="$2"
        shift 2
        ;;
      --project)
        [[ $# -ge 2 ]] || die_usage "Missing value for --project."
        project_filter="$2"
        shift 2
        ;;
      --agent)
        [[ $# -ge 2 ]] || die_usage "Missing value for --agent."
        agent_filter="$2"
        shift 2
        ;;
      --top)
        [[ $# -ge 2 ]] || die_usage "Missing value for --top."
        top_n="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown select option: $1"
        ;;
    esac
  done

  require_positive_int "$top_n" "--top"

  fts_query="$(build_fts_query "$query")" || die_usage "select query must not be empty."
  sql_where="s.is_meta = 0"

  case "$project_filter" in
    current)
      project_slug="$(current_project_slug)"
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_slug")"
      ;;
    all)
      ;;
    *)
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_filter")"
      ;;
  esac

  case "$agent_filter" in
    all)
      ;;
    main | subagent)
      sql_where="$sql_where AND s.agent_kind = $(sql_quote "$agent_filter")"
      ;;
    *)
      die_usage "Unknown agent filter: $agent_filter"
      ;;
  esac

  if [[ -n "$since_spec" ]]; then
    since_epoch="$(epoch_from_spec "$since_spec" 2>/dev/null || true)"
    if [[ -z "$since_epoch" ]]; then
      die_usage "Unsupported --since value: $since_spec"
    fi
    sql_where="$sql_where AND COALESCE(src.source_mtime, CAST(strftime('%s', src.indexed_at) AS INTEGER), 0) >= $since_epoch"
  fi

  rows_file="$(mktemp /tmp/session-archive-select.XXXXXX)"
  sqlite3 -separator "$RESULT_SEPARATOR" "$INDEX_FILE" "
    WITH hit_base AS (
      SELECT
        s.segment_id,
        bm25(segments_fts) AS rank_score,
        printf('%.4f', -bm25(segments_fts)) AS score,
        s.session_id,
        s.project_slug,
        s.agent_kind,
        COALESCE(s.component_hint, '') AS component_hint,
        COALESCE(s.task_key, '') AS task_key,
        REPLACE(REPLACE(REPLACE(snippet(segments_fts, 0, '[', ']', '...', 12), char(9), ' '), char(10), ' '), char(13), ' ') AS snippet,
        COALESCE(s.ts, '') AS ts
      FROM segments_fts
      JOIN segments s ON s.rowid = segments_fts.rowid
      JOIN sources src ON src.source_path = s.source_path
      WHERE segments_fts MATCH $(sql_quote "$fts_query")
        AND $sql_where
      ORDER BY bm25(segments_fts), COALESCE(s.ts, '') DESC, s.segment_id
      LIMIT $top_n
    ),
    ranked_hits AS (
      SELECT
        ROW_NUMBER() OVER (ORDER BY rank_score, ts DESC, segment_id) AS hit_rank,
        segment_id,
        score,
        session_id,
        project_slug,
        agent_kind,
        component_hint,
        task_key,
        snippet,
        ts
      FROM hit_base
    ),
    ordered AS (
      SELECT
        s.source_path,
        s.segment_id,
        s.speaker,
        s.segment_kind,
        s.content,
        COALESCE(s.ts, '') AS ts,
        ROW_NUMBER() OVER (PARTITION BY s.source_path ORDER BY s.line_no, s.item_no) AS seq
      FROM segments s
    ),
    hit_seq AS (
      SELECT h.*, o.source_path, o.seq
      FROM ranked_hits h
      JOIN ordered o ON o.segment_id = h.segment_id
    )
    SELECT
      h.hit_rank,
      h.segment_id,
      h.score,
      h.session_id,
      h.project_slug,
      h.agent_kind,
      h.component_hint,
      h.task_key,
      h.snippet,
      h.ts,
      n.segment_id,
      n.speaker,
      n.segment_kind,
      n.content,
      n.ts
    FROM hit_seq h
    JOIN ordered n
      ON n.source_path = h.source_path
     AND n.seq BETWEEN (h.seq - $before_count) AND (h.seq + $after_count)
    ORDER BY h.hit_rank, n.seq;
  " >"$rows_file"

  select_json="$(select_rows_to_json "$query" "$rows_file")"
  rm -f "$rows_file"

  case "$format" in
    json)
      printf '%s\n' "$select_json"
      ;;
    text)
      select_json_to_text "$select_json"
      ;;
    *)
      die_usage "Unknown select format: $format"
      ;;
  esac
}

proposal_id_timestamp() {
  local created_at="${1:?Missing created_at}"
  local proposal_stamp=""

  proposal_stamp="$(printf '%s' "$created_at" | sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z$/\1\2\3-\4\5\6/')"
  if [[ "$proposal_stamp" == "$created_at" ]]; then
    date -u '+%Y%m%d-%H%M%S'
    return 0
  fi

  printf '%s\n' "$proposal_stamp"
}

proposal_analysis_json() {
  local candidates_json="${1:?Missing candidates json file}"
  local min_segments="${2:?Missing min segments}"
  local min_sessions="${3:?Missing min sessions}"
  local min_span_days="${4:?Missing min span days}"
  local min_agent_text_segments="${5:?Missing min agent text segments}"
  local max_pages_per_proposal="${6:?Missing max pages}"
  local hard_cap_pages="${7:?Missing hard cap}"
  local page_limit="${8:?Missing page limit}"

  jq \
    --argjson min_segments "$min_segments" \
    --argjson min_sessions "$min_sessions" \
    --argjson min_span_days "$min_span_days" \
    --argjson min_agent_text_segments "$min_agent_text_segments" \
    --argjson max_pages_per_proposal "$max_pages_per_proposal" \
    --argjson hard_cap_pages "$hard_cap_pages" \
    --argjson page_limit "$page_limit" \
    '
      def blank($v): (($v // "") | tostring | length) == 0;
      def slugify_task:
        ascii_downcase
        | gsub("[^A-Za-z0-9]+"; "-")
        | gsub("^-+"; "")
        | gsub("-+$"; "")
        | if length == 0 then "untitled" else . end;
      def slugify_component:
        gsub("\\.[A-Za-z0-9]+$"; "")
        | ascii_downcase
        | gsub("[^A-Za-z0-9]+"; "-")
        | gsub("^-+"; "")
        | gsub("-+$"; "")
        | if length == 0 then "untitled" else . end;
      def day_num($day):
        try (($day | strptime("%Y-%m-%d") | mktime) / 86400 | floor) catch null;
      def span_days_for($segments):
        ($segments | map(.source_day // "") | map(select(length > 0)) | unique | sort | map(day_num(.)) | map(select(. != null))) as $days
        | if ($days | length) > 1 then (($days | max) - ($days | min)) else 0 end;
      def agent_mix($segments):
        reduce $segments[] as $segment ({main: 0, subagent: 0};
          if $segment.agent_kind == "main" then
            .main += 1
          elif $segment.agent_kind == "subagent" then
            .subagent += 1
          else
            .
          end
        );
      def segment_metrics($segments):
        {
          segment_count: ($segments | length),
          session_count: ($segments | map(.session_id) | unique | length),
          span_days: span_days_for($segments),
          agent_kind_mix: agent_mix($segments),
          has_text_segment: any($segments[]; .segment_kind == "text"),
          text_segment_count: ($segments | map(select(.segment_kind == "text")) | length),
          source_segments: ($segments | map(.segment_id) | unique | sort),
          source_session_ids: ($segments | map(.session_id) | unique | sort)
        };
      def page_fields($rule; $key; $project_slug):
        if $rule == "task_key" then
          {
            page_type: "topic",
            page_type_dir: "topics",
            slug: ($key | slugify_task)
          }
        else
          {
            page_type: "component",
            page_type_dir: "components",
            slug: ($key | slugify_component)
          }
        end
        | .wiki_key = (.page_type_dir + "/" + .slug)
        | .target_wiki_path = ("wiki/" + $project_slug + "/" + .page_type_dir + "/" + .slug + ".md");
      def group_object($rule; $key; $segments):
        ($segments[0].project_slug // "unknown-project") as $project_slug
        | segment_metrics($segments) + page_fields($rule; $key; $project_slug) + {
            grouping_rule: $rule,
            grouping_key: $key,
            project_slug: $project_slug,
            segments: $segments
          };
      def summarize_group:
        .source_segment_count = (.source_segments | length)
        | .source_segment_sample = (.source_segments[0:10])
        | del(.segments, .source_segments);
      def threshold_reasons($group):
        [
          if $group.segment_count < $min_segments then "segment_count < min_segments" else empty end,
          if $group.session_count < $min_sessions then "session_count < min_sessions" else empty end,
          if $group.span_days < $min_span_days then "span_days < min_span_days" else empty end,
          if ($min_agent_text_segments >= 1 and $group.text_segment_count < $min_agent_text_segments) then "text_segment_count < min_agent_text_segments" else empty end
        ];
      def chunks($size):
        [range(0; length; $size) as $offset | .[$offset:($offset + $size)]];
      def proposal_chunk($groups):
        ($groups | map(.segments) | add // []) as $segments
        | segment_metrics($segments) as $metrics
        | {
            target_pages: ($groups | map({
              wiki_path: .target_wiki_path,
              wiki_key: .wiki_key,
              page_type: .page_type,
              preimage_hash: null,
              after_hash: null
            })),
            groups: $groups,
            grouping_rule: (
              ($groups | map(.grouping_rule) | unique) as $rules
              | if ($rules | length) == 1 then $rules[0] else "mixed" end
            )
          } + $metrics;

      . as $rows
      | ($rows | map(select((blank(.task_key) | not))) | sort_by(.project_slug, .task_key) | group_by([.project_slug, .task_key]) | map(group_object("task_key"; .[0].task_key; .))) as $task_groups
      | ($rows | map(select(blank(.task_key) and (blank(.component_hint) | not))) | sort_by(.project_slug, .component_hint) | group_by([.project_slug, .component_hint]) | map(group_object("component_hint"; .[0].component_hint; .))) as $component_groups
      | ($rows | map(select(blank(.task_key) and blank(.component_hint))) | sort_by(.project_slug) | group_by(.project_slug) | map(segment_metrics(.) + {
          grouping_rule: "ungrouped",
          grouping_key: null,
          project_slug: (.[0].project_slug // "unknown-project"),
          reasons: ["ungrouped"]
        } | summarize_group)) as $ungrouped_drops
      | ($task_groups + $component_groups) as $all_groups
      | ($all_groups | map(select(.segment_count < 2) | . + {reasons: ["single_element_group"]} | summarize_group)) as $single_drops
      | ($all_groups | map(select(.segment_count >= 2))) as $multi_groups
      | ($multi_groups | map(. + {reasons: threshold_reasons(.)})) as $thresholded_groups
      | ($thresholded_groups | map(select((.reasons | length) == 0)) | sort_by([(-.span_days), (-.segment_count), .wiki_key])) as $accepted_groups
      | ($thresholded_groups | map(select((.reasons | length) > 0) | summarize_group)) as $threshold_drops
      | ($accepted_groups | chunks($page_limit) | map(proposal_chunk(.))) as $proposal_chunks
      | {
          candidate_count: ($rows | length),
          accepted_group_count: ($accepted_groups | length),
          max_pages_per_proposal: $max_pages_per_proposal,
          hard_cap_pages: $hard_cap_pages,
          page_limit: $page_limit,
          proposal_chunks: $proposal_chunks,
          dropped_groups: ($ungrouped_drops + $single_drops + $threshold_drops)
        }
    ' "$candidates_json"
}

proposal_json_to_text() {
  local proposal_json="${1:?Missing proposal json}"

  printf '%s\n' "$proposal_json" |
    jq -r '
      if .dry_run then
        "Dry run: " + (.count | tostring) + " proposal(s) would be created."
      else
        "Created " + (.count | tostring) + " proposal(s)."
      end,
      (if (.message // "") != "" then .message else empty end),
      (
        .proposals[]
        | "- " + ((.proposal_id // "(dry-run)") | tostring)
          + ": " + ((.target_pages | length) | tostring) + " page(s), "
          + (.segment_count | tostring) + " segment(s), "
          + (.session_count | tostring) + " session(s), span_days="
          + (.span_days | tostring)
      ),
      (
        if (.dropped_groups | length) == 0 then
          "Dropped groups: none"
        else
          "Dropped groups:",
          (
            .dropped_groups[]
            | "- " + ((.grouping_rule // "unknown") | tostring)
              + ":" + ((.grouping_key // .project_slug // "unknown") | tostring)
              + " "
              + (((.reasons // [(.reason // "dropped")]) | join(", ")))
              + " (" + ((.segment_count // 0) | tostring) + " segment(s))"
          )
        end
      )
    '
}

action_propose() {
  require_jq
  require_sqlite3
  ensure_initialized

  local task_key_selector=""
  local component_selector=""
  local session_selector=""
  local query_selector=""
  local since_spec=""
  local project_filter="current"
  local min_segments=""
  local min_sessions=""
  local min_span_days=""
  local min_agent_text_segments=""
  local max_pages_per_proposal=""
  local hard_cap_pages=""
  local page_limit=""
  local include_subagents=""
  local dry_run="false"
  local format="text"
  local since_epoch=""
  local project_slug=""
  local sql_where=""
  local fts_query=""
  local with_clause=""
  local query_filter=""
  local rows_file=""
  local candidates_json=""
  local analysis_file=""
  local created_proposals_file=""
  local output_json=""
  local message=""

  min_segments="$(jq -r ".session_wiki.min_segments // $DEFAULT_SESSION_WIKI_MIN_SEGMENTS" "$SETTINGS_FILE")"
  min_sessions="$(jq -r ".session_wiki.min_sessions // $DEFAULT_SESSION_WIKI_MIN_SESSIONS" "$SETTINGS_FILE")"
  min_span_days="$(jq -r ".session_wiki.min_span_days // $DEFAULT_SESSION_WIKI_MIN_SPAN_DAYS" "$SETTINGS_FILE")"
  min_agent_text_segments="$(jq -r '.session_wiki.min_agent_text_segments // 1' "$SETTINGS_FILE")"
  max_pages_per_proposal="$(jq -r ".session_wiki.max_pages_per_proposal // $DEFAULT_SESSION_WIKI_MAX_PAGES_PER_PROPOSAL" "$SETTINGS_FILE")"
  hard_cap_pages="$(jq -r ".session_wiki.hard_cap_pages // $DEFAULT_SESSION_WIKI_HARD_CAP_PAGES" "$SETTINGS_FILE")"
  include_subagents="$(jq -r '.session_wiki.include_subagents // true' "$SETTINGS_FILE")"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task-key)
        [[ $# -ge 2 ]] || die_usage "Missing value for --task-key."
        task_key_selector="$2"
        shift 2
        ;;
      --component)
        [[ $# -ge 2 ]] || die_usage "Missing value for --component."
        component_selector="$2"
        shift 2
        ;;
      --session)
        [[ $# -ge 2 ]] || die_usage "Missing value for --session."
        session_selector="$2"
        shift 2
        ;;
      --query)
        [[ $# -ge 2 ]] || die_usage "Missing value for --query."
        query_selector="$2"
        shift 2
        ;;
      --since)
        [[ $# -ge 2 ]] || die_usage "Missing value for --since."
        since_spec="$2"
        shift 2
        ;;
      --project)
        [[ $# -ge 2 ]] || die_usage "Missing value for --project."
        project_filter="$2"
        shift 2
        ;;
      --min-segments)
        [[ $# -ge 2 ]] || die_usage "Missing value for --min-segments."
        min_segments="$2"
        shift 2
        ;;
      --min-sessions)
        [[ $# -ge 2 ]] || die_usage "Missing value for --min-sessions."
        min_sessions="$2"
        shift 2
        ;;
      --min-span-days)
        [[ $# -ge 2 ]] || die_usage "Missing value for --min-span-days."
        min_span_days="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
        shift
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown propose option: $1"
        ;;
    esac
  done

  require_nonnegative_int "$min_segments" "--min-segments"
  require_nonnegative_int "$min_sessions" "--min-sessions"
  require_nonnegative_int "$min_span_days" "--min-span-days"
  require_nonnegative_int "$min_agent_text_segments" "min_agent_text_segments"
  require_positive_int "$max_pages_per_proposal" "max_pages_per_proposal"
  require_positive_int "$hard_cap_pages" "hard_cap_pages"

  page_limit="$max_pages_per_proposal"
  if ((page_limit > hard_cap_pages)); then
    page_limit="$hard_cap_pages"
  fi

  sql_where="s.is_meta = 0 AND (s.command_hint IS NULL OR s.command_hint <> 'session')"

  case "$project_filter" in
    current)
      project_slug="$(current_project_slug)"
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_slug")"
      ;;
    all)
      ;;
    *)
      sql_where="$sql_where AND s.project_slug = $(sql_quote "$project_filter")"
      ;;
  esac

  case "$include_subagents" in
    true | 1)
      ;;
    false | 0)
      sql_where="$sql_where AND s.agent_kind = 'main'"
      ;;
    *)
      die_usage "session_wiki.include_subagents must be true or false."
      ;;
  esac

  if [[ -n "$since_spec" ]]; then
    since_epoch="$(epoch_from_spec "$since_spec" 2>/dev/null || true)"
    if [[ -z "$since_epoch" ]]; then
      die_usage "Unsupported --since value: $since_spec"
    fi
    sql_where="$sql_where AND COALESCE(src.source_mtime, CAST(strftime('%s', src.indexed_at) AS INTEGER), 0) >= $since_epoch"
  fi

  if [[ -n "$task_key_selector" ]]; then
    sql_where="$sql_where AND s.task_key = $(sql_quote "$task_key_selector")"
  fi

  if [[ -n "$component_selector" ]]; then
    sql_where="$sql_where AND (s.component_hint = $(sql_quote "$component_selector") OR s.command_hint = $(sql_quote "$component_selector"))"
  fi

  if [[ -n "$session_selector" ]]; then
    sql_where="$sql_where AND (s.session_id = $(sql_quote "$session_selector") OR s.parent_session_id = $(sql_quote "$session_selector"))"
  fi

  if [[ -n "$query_selector" ]]; then
    fts_query="$(build_fts_query "$query_selector")" || die_usage "--query must not be empty."
    with_clause="WITH query_hits AS (
      SELECT s.segment_id
      FROM segments_fts
      JOIN segments s ON s.rowid = segments_fts.rowid
      WHERE segments_fts MATCH $(sql_quote "$fts_query")
    )"
    query_filter="AND s.segment_id IN (SELECT segment_id FROM query_hits)"
  fi

  rows_file="$(mktemp /tmp/session-archive-propose-rows.XXXXXX)"
  candidates_json="$(mktemp /tmp/session-archive-propose-candidates.XXXXXX)"
  analysis_file="$(mktemp /tmp/session-archive-propose-analysis.XXXXXX)"

  sqlite3 -separator "$RESULT_SEPARATOR" "$INDEX_FILE" "
    $with_clause
    SELECT
      s.segment_id,
      COALESCE(s.ts, '') AS ts,
      s.session_id,
      s.project_slug,
      s.agent_kind,
      s.speaker,
      s.segment_kind,
      COALESCE(s.tool_name, '') AS tool_name,
      COALESCE(s.component_hint, '') AS component_hint,
      COALESCE(s.task_key, '') AS task_key,
      COALESCE(s.command_hint, '') AS command_hint,
      s.content,
      COALESCE(
        date(src.source_mtime, 'unixepoch'),
        date(s.ts),
        date(src.indexed_at),
        ''
      ) AS source_day,
      COALESCE(
        src.source_mtime,
        CAST(strftime('%s', s.ts) AS INTEGER),
        CAST(strftime('%s', src.indexed_at) AS INTEGER),
        0
      ) AS source_epoch
    FROM segments s
    JOIN sources src ON src.source_path = s.source_path
    WHERE $sql_where
      $query_filter
    ORDER BY s.project_slug, COALESCE(s.task_key, ''), COALESCE(s.component_hint, ''), source_epoch, s.source_path, s.line_no, s.item_no;
  " >"$rows_file"

  jq -Rn '
    [inputs | split("\u001f")]
    | map(select(length >= 14) | {
        segment_id: .[0],
        ts: (if .[1] == "" then null else .[1] end),
        session_id: .[2],
        project_slug: .[3],
        agent_kind: .[4],
        speaker: .[5],
        segment_kind: .[6],
        tool_name: (if .[7] == "" then null else .[7] end),
        component_hint: (if .[8] == "" then null else .[8] end),
        task_key: (if .[9] == "" then null else .[9] end),
        command_hint: (if .[10] == "" then null else .[10] end),
        content: .[11],
        source_day: .[12],
        source_epoch: (.[13] | tonumber? // 0)
      })
  ' "$rows_file" >"$candidates_json"

  # DC-08: dedupe acompact subagent copies — keep one per (session_id, content, ts), prefer main
  jq '[group_by([.session_id, .content, .ts]) | .[] | sort_by(if .agent_kind == "main" then "0" else "1" end) | .[0]]' \
    "$candidates_json" >"${candidates_json}.dedup" && mv "${candidates_json}.dedup" "$candidates_json"

  proposal_analysis_json \
    "$candidates_json" \
    "$min_segments" \
    "$min_sessions" \
    "$min_span_days" \
    "$min_agent_text_segments" \
    "$max_pages_per_proposal" \
    "$hard_cap_pages" \
    "$page_limit" >"$analysis_file"

  if [[ "$(jq -r '.candidate_count' "$analysis_file")" == "0" ]]; then
    message="No candidate segments matched the selectors."
  elif [[ "$(jq -r '.accepted_group_count' "$analysis_file")" == "0" ]]; then
    message="Candidate segments were found, but no groups passed grouping and threshold rules."
  fi

  if [[ "$dry_run" == "true" ]]; then
    output_json="$(jq \
      --arg message "$message" \
      '{
        proposals: (.proposal_chunks | map(. + {
          proposal_id: null,
          proposal_dir: null,
          groups: (.groups | map(
            .source_segment_count = (.source_segments | length)
            | .source_segment_sample = (.source_segments[0:10])
            | del(.segments, .source_segments)
          ))
        })),
        count: (.proposal_chunks | length),
        dropped_groups: .dropped_groups,
        dry_run: true,
        message: (if ($message | length) > 0 then $message else null end)
      }' "$analysis_file")"
    rm -f "$rows_file" "$candidates_json" "$analysis_file"
    case "$format" in
      json)
        printf '%s\n' "$output_json"
        ;;
      text)
        proposal_json_to_text "$output_json"
        ;;
      *)
        die_usage "Unknown propose format: $format"
        ;;
    esac
    return 0
  fi

  ensure_archive_layout
  created_proposals_file="$(mktemp /tmp/session-archive-created-proposals.XXXXXX)"
  local dropped_groups_file=""
  dropped_groups_file="$(mktemp /tmp/session-archive-dropped-groups.XXXXXX)"

  while IFS= read -r chunk_json || [[ -n "$chunk_json" ]]; do
    local created_at=""
    local proposal_stamp=""
    local first_slug=""
    local base_proposal_id=""
    local proposal_id=""
    local proposal_dir=""
    local suffix=2
    local target_pages_file=""
    local updated_target_pages_file=""
    local target_pages_json=""
    local target_paths_json=""
    local bundle_json=""
    local source_segments_json=""
    local source_session_ids_json=""
    local agent_kind_mix_json=""
    local segment_count=""
    local session_count=""
    local span_days=""
    local grouping_rule=""
    local trigger_json=""
    local proposal_json=""
    local target_page_json=""

    [[ -n "$chunk_json" ]] || continue

    created_at="$(timestamp_utc)"
    proposal_stamp="$(proposal_id_timestamp "$created_at")"
    first_slug="$(printf '%s\n' "$chunk_json" | jq -r '.groups[0].slug')"
    base_proposal_id="PROMO-$proposal_stamp-$first_slug"
    proposal_id="$base_proposal_id"
    while [[ -e "$PROPOSALS_DIR/$proposal_id" ]]; do
      proposal_id="$base_proposal_id-$suffix"
      suffix=$((suffix + 1))
    done
    proposal_dir="$PROPOSALS_DIR/$proposal_id"
    mkdir -p "$proposal_dir"

    target_pages_file="$(mktemp /tmp/session-archive-target-pages.XXXXXX)"
    updated_target_pages_file="$(mktemp /tmp/session-archive-target-pages-updated.XXXXXX)"
    printf '%s\n' "$chunk_json" | jq -c '.target_pages[]' >"$target_pages_file"

    while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
      local target_wiki_path=""
      local target_wiki_full_path=""
      local preimage_hash=""
      local preimage_path=""

      [[ -n "$target_page_json" ]] || continue
      target_wiki_path="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_path')"
      target_wiki_full_path="$ARCHIVE_ROOT/$target_wiki_path"
      preimage_hash=""

      if [[ -f "$target_wiki_full_path" ]]; then
        preimage_hash="sha256:$(sha256_file "$target_wiki_full_path")"
        preimage_path="$proposal_dir/preimage/$target_wiki_path"
        mkdir -p "$(dirname "$preimage_path")"
        cp "$target_wiki_full_path" "$preimage_path"
      fi

      if [[ -n "$preimage_hash" ]]; then
        printf '%s\n' "$target_page_json" |
          jq --arg preimage_hash "$preimage_hash" '.preimage_hash = $preimage_hash | .after_hash = null' >>"$updated_target_pages_file"
      else
        printf '%s\n' "$target_page_json" |
          jq '.preimage_hash = null | .after_hash = null' >>"$updated_target_pages_file"
      fi
    done <"$target_pages_file"

    target_pages_json="$(jq -s '.' "$updated_target_pages_file")"
    target_paths_json="$(printf '%s\n' "$target_pages_json" | jq '[.[].wiki_path]')"
    bundle_json="$(printf '%s\n' "$chunk_json" | jq '[.groups[].segments[] | {
      segment_id,
      ts,
      session_id,
      speaker,
      segment_kind,
      tool_name,
      component_hint,
      content
    }]')"
    source_segments_json="$(printf '%s\n' "$chunk_json" | jq '.source_segments')"
    source_session_ids_json="$(printf '%s\n' "$chunk_json" | jq '.source_session_ids')"
    agent_kind_mix_json="$(printf '%s\n' "$chunk_json" | jq '.agent_kind_mix')"
    segment_count="$(printf '%s\n' "$chunk_json" | jq -r '.segment_count')"
    session_count="$(printf '%s\n' "$chunk_json" | jq -r '.session_count')"
    span_days="$(printf '%s\n' "$chunk_json" | jq -r '.span_days')"
    grouping_rule="$(printf '%s\n' "$chunk_json" | jq -r '.grouping_rule')"
    trigger_json="$(jq -cn \
      --arg task_key "$task_key_selector" \
      --arg component "$component_selector" \
      --arg session "$session_selector" \
      --arg query "$query_selector" \
      --arg since "$since_spec" \
      --arg project "$project_filter" \
      --argjson min_segments "$min_segments" \
      --argjson min_sessions "$min_sessions" \
      --argjson min_span_days "$min_span_days" \
      '{
        action: "propose",
        selectors: {
          task_key: (if ($task_key | length) > 0 then $task_key else null end),
          component: (if ($component | length) > 0 then $component else null end),
          session: (if ($session | length) > 0 then $session else null end),
          query: (if ($query | length) > 0 then $query else null end),
          since: (if ($since | length) > 0 then $since else null end),
          project: $project,
          min_segments: $min_segments,
          min_sessions: $min_sessions,
          min_span_days: $min_span_days
        }
      }')"

    printf '%s\n' "$bundle_json" >"$proposal_dir/bundle.json"
    jq -n \
      --arg proposal_id "$proposal_id" \
      --arg created_at "$created_at" \
      --argjson trigger "$trigger_json" \
      --argjson target_pages "$target_pages_json" \
      --argjson source_segments "$source_segments_json" \
      --argjson source_session_ids "$source_session_ids_json" \
      --argjson segment_count "$segment_count" \
      --argjson session_count "$session_count" \
      --argjson span_days "$span_days" \
      --argjson agent_kind_mix "$agent_kind_mix_json" \
      --arg grouping_rule "$grouping_rule" \
      '{
        proposal_id: $proposal_id,
        kind: "session-wiki-promotion",
        status: "pending",
        created_at: $created_at,
        trigger: $trigger,
        target_pages: $target_pages,
        source_segments: $source_segments,
        source_session_ids: $source_session_ids,
        segment_count: $segment_count,
        session_count: $session_count,
        span_days: $span_days,
        agent_kind_mix: $agent_kind_mix,
        synthesis_confidence: null,
        synthesis_agent: "core/session-synthesizer",
        grouping_rule: $grouping_rule,
        reversal_hint: null
      }' >"$proposal_dir/manifest.json"

    jq -cn \
      --arg proposal_id "$proposal_id" \
      --arg created_at "$created_at" \
      --argjson target_pages "$target_paths_json" \
      --argjson segment_count "$segment_count" \
      --argjson session_count "$session_count" \
      --argjson span_days "$span_days" \
      '{
        proposal_id: $proposal_id,
        status: "pending",
        created_at: $created_at,
        updated_at: $created_at,
        target_pages: $target_pages,
        segment_count: $segment_count,
        session_count: $session_count,
        span_days: $span_days
      }' >>"$PROPOSALS_INDEX_FILE"

    proposal_json="$(jq -n \
      --arg proposal_id "$proposal_id" \
      --arg proposal_dir "$(home_relative_path "$proposal_dir")" \
      --argjson target_pages "$target_pages_json" \
      --argjson source_segments "$source_segments_json" \
      --argjson source_session_ids "$source_session_ids_json" \
      --argjson segment_count "$segment_count" \
      --argjson session_count "$session_count" \
      --argjson span_days "$span_days" \
      --argjson agent_kind_mix "$agent_kind_mix_json" \
      --arg grouping_rule "$grouping_rule" \
      '{
        proposal_id: $proposal_id,
        proposal_dir: $proposal_dir,
        target_pages: $target_pages,
        source_segments: $source_segments,
        source_session_ids: $source_session_ids,
        segment_count: $segment_count,
        session_count: $session_count,
        span_days: $span_days,
        agent_kind_mix: $agent_kind_mix,
        grouping_rule: $grouping_rule
      }')"
    printf '%s\n' "$proposal_json" >>"$created_proposals_file"
    rm -f "$target_pages_file" "$updated_target_pages_file"
  done < <(jq -c '.proposal_chunks[]' "$analysis_file")

  jq '.dropped_groups' "$analysis_file" >"$dropped_groups_file"
  output_json="$(jq -s \
    --arg message "$message" \
    --slurpfile dropped_groups "$dropped_groups_file" \
    '{
      proposals: .,
      count: length,
      dropped_groups: $dropped_groups[0],
      dry_run: false,
      message: (if ($message | length) > 0 then $message else null end)
    }' "$created_proposals_file")"

  rm -f "$rows_file" "$candidates_json" "$analysis_file" "$created_proposals_file" "$dropped_groups_file"

  case "$format" in
    json)
      printf '%s\n' "$output_json"
      ;;
    text)
      proposal_json_to_text "$output_json"
      ;;
    *)
      die_usage "Unknown propose format: $format"
      ;;
  esac
}

action_status() {
  local pending_count="0"
  local indexed_sources="0"
  local segment_count="0"
  local last_sync_at=""
  local initialized="false"

  pending_count="$(queue_pending_count 2>/dev/null || printf '0')"

  if [[ -f "$INDEX_FILE" ]]; then
    initialized="true"
    indexed_sources="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM sources;" 2>/dev/null || printf '0')"
    segment_count="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM segments;" 2>/dev/null || printf '0')"
  fi

  if [[ -f "$STATE_FILE" ]]; then
    last_sync_at="$(jq -r '.last_sync_at // empty' "$STATE_FILE" 2>/dev/null || true)"
  fi

  jq -cn \
    --arg archive_root "$(home_relative_path "$ARCHIVE_ROOT")" \
    --argjson initialized "$initialized" \
    --argjson schema_version "$SCHEMA_VERSION" \
    --arg last_sync_at "${last_sync_at-}" \
    --argjson pending_count "$pending_count" \
    --argjson indexed_sources "$indexed_sources" \
    --argjson segment_count "$segment_count" \
    '{
      archive_root: $archive_root,
      initialized: $initialized,
      schema_version: $schema_version,
      last_sync_at: (if ($last_sync_at | length) > 0 then $last_sync_at else null end),
      pending_count: $pending_count,
      indexed_sources: $indexed_sources,
      segment_count: $segment_count
    }'
}

count_wiki_pages() {
  if [[ ! -d "$WIKI_DIR" ]]; then
    printf '0\n'
    return 0
  fi

  find "$WIKI_DIR" -type f -name '*.md' ! -name '.index.md' ! -name '.log.md' 2>/dev/null | awk 'END { print NR + 0 }'
}

qmd_session_wiki_registered() {
  if command -v qmd >/dev/null 2>&1 && qmd collection show session-wiki >/dev/null 2>&1; then
    printf 'true\n'
    return 0
  fi

  printf 'false\n'
}

pending_proposal_count() {
  if [[ ! -f "$PROPOSALS_INDEX_FILE" ]]; then
    printf '0\n'
    return 0
  fi

  jq -s 'map(select(type == "object" and (.proposal_id // "") != "")) | reduce .[] as $row ({}; .[$row.proposal_id] = $row) | [.[]] | map(select((.status // "") == "pending")) | length' "$PROPOSALS_INDEX_FILE" 2>/dev/null || printf '0\n'
}

last_wiki_lint_at() {
  if [[ ! -f "$WIKI_LEDGER_FILE" ]]; then
    printf '\n'
    return 0
  fi

  jq -r '
    select(((.event // .action // "") | tostring | test("lint")))
    | .ts // .timestamp // .created_at // .at // empty
  ' "$WIKI_LEDGER_FILE" 2>/dev/null | tail -n 1 || true
}

action_wiki_status() {
  require_jq

  local format="text"
  local wiki_page_count="0"
  local qmd_registered="false"
  local pending_proposals="0"
  local last_lint_at=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown wiki-status option: $1"
        ;;
    esac
  done

  wiki_page_count="$(count_wiki_pages)"
  qmd_registered="$(qmd_session_wiki_registered)"
  pending_proposals="$(pending_proposal_count)"
  last_lint_at="$(last_wiki_lint_at)"

  case "$format" in
    json)
      jq -cn \
        --arg archive_root "$(home_relative_path "$ARCHIVE_ROOT")" \
        --arg wiki_dir "$(home_relative_path "$WIKI_DIR")" \
        --arg collection_name "session-wiki" \
        --argjson wiki_page_count "$wiki_page_count" \
        --argjson qmd_registered "$qmd_registered" \
        --argjson pending_proposals "$pending_proposals" \
        --arg last_lint_at "${last_lint_at-}" \
        '{
          archive_root: $archive_root,
          wiki_dir: $wiki_dir,
          collection_name: $collection_name,
          wiki_page_count: $wiki_page_count,
          qmd_registered: $qmd_registered,
          pending_proposals: $pending_proposals,
          last_lint_at: (if ($last_lint_at | length) > 0 then $last_lint_at else null end)
        }'
      ;;
    text)
      printf 'Session wiki status\n'
      printf '  archive_root=%s\n' "$(home_relative_path "$ARCHIVE_ROOT")"
      printf '  wiki_dir=%s\n' "$(home_relative_path "$WIKI_DIR")"
      printf '  collection_name=session-wiki\n'
      printf '  wiki_page_count=%s\n' "$wiki_page_count"
      printf '  qmd_registered=%s\n' "$qmd_registered"
      printf '  pending_proposals=%s\n' "$pending_proposals"
      printf '  last_lint_at=%s\n' "${last_lint_at:-null}"
      if [[ "$qmd_registered" == "false" ]]; then
        printf '\nManual QMD registration:\n'
        cat <<'EOF'
qmd collection add session-wiki "$CLAUDE_PLUGIN_DATA/session-archive/wiki" --pattern '**/*.md'
qmd update && qmd embed
EOF
      fi
      ;;
    *)
      die_usage "Unknown wiki-status format: $format"
      ;;
  esac
}

wiki_markdown_files() {
  if [[ ! -d "$WIKI_DIR" ]]; then
    return 0
  fi

  find "$WIKI_DIR" -type d -name '.*' -prune -o -type f -name '*.md' ! -name '.*' -print 2>/dev/null | sort
}

extract_wiki_frontmatter() {
  local page_path="${1:?Missing wiki page path}"

  awk '
    NR == 1 && $0 == "---" {
      in_frontmatter = 1
      next
    }
    NR == 1 {
      exit
    }
    in_frontmatter && $0 == "---" {
      exit
    }
    in_frontmatter {
      print
    }
  ' "$page_path"
}

wiki_frontmatter_scalar() {
  local frontmatter_path="${1:?Missing frontmatter path}"
  local key="${2:?Missing frontmatter key}"

  awk -v key="$key" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if ((s ~ /^".*"$/) || (s ~ /^\047.*\047$/)) {
        s = substr(s, 2, length(s) - 2)
      }
      gsub(/\\"/, "\"", s)
      return s
    }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      value = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", value)
      value = trim(value)
      if (value == "" || value == "null" || value == "~") {
        exit
      }
      print unquote(value)
      exit
    }
  ' "$frontmatter_path"
}

wiki_frontmatter_array_values() {
  local frontmatter_path="${1:?Missing frontmatter path}"
  local key="${2:?Missing frontmatter key}"

  awk -v key="$key" '
    function trim(s) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if ((s ~ /^".*"$/) || (s ~ /^\047.*\047$/)) {
        s = substr(s, 2, length(s) - 2)
      }
      gsub(/\\"/, "\"", s)
      return s
    }
    function emit_inline_array(raw, parts, part_count, i, item) {
      raw = trim(raw)
      if (raw == "" || raw == "[]") {
        return
      }
      if (raw ~ /^\[/) {
        sub(/^\[/, "", raw)
        sub(/\][[:space:]]*$/, "", raw)
        part_count = split(raw, parts, ",")
        for (i = 1; i <= part_count; i += 1) {
          item = unquote(parts[i])
          if (item != "") {
            print item
          }
        }
        return
      }
      print unquote(raw)
    }
    $0 ~ "^[[:space:]]*" key ":[[:space:]]*" {
      active = 1
      value = $0
      sub("^[[:space:]]*" key ":[[:space:]]*", "", value)
      value = trim(value)
      if (value != "") {
        emit_inline_array(value)
        exit
      }
      next
    }
    active && /^[[:space:]]*-[[:space:]]*/ {
      value = $0
      sub(/^[[:space:]]*-[[:space:]]*/, "", value)
      value = unquote(value)
      if (value != "") {
        print value
      }
      next
    }
    active && /^[^[:space:]][A-Za-z0-9_-]*:/ {
      exit
    }
  ' "$frontmatter_path"
}

wiki_related_mentions_key() {
  local page_path="${1:?Missing wiki page path}"
  local wiki_key="${2:?Missing wiki key}"

  awk -v wiki_key="$wiki_key" '
    /^##[[:space:]]+Related Pages[[:space:]]*$/ {
      in_related = 1
      next
    }
    in_related && /^##[[:space:]]+/ {
      exit
    }
    in_related && index($0, wiki_key) > 0 {
      found = 1
      exit
    }
    END {
      exit(found ? 0 : 1)
    }
  ' "$page_path"
}

wiki_lint_unavailable() {
  local stale_days="${1:?Missing stale days}"
  local format="${2:?Missing output format}"
  local reason="${3:?Missing unavailable reason}"

  case "$format" in
    json)
      jq -cn \
        --argjson stale_days "$stale_days" \
        --arg reason "$reason" \
        '{stale_days: $stale_days, scanned: 0, flagged: 0, findings: [], unavailable: true, reason: $reason}'
      ;;
    text)
      printf 'Session wiki lint unavailable: %s\n' "$reason"
      printf 'scanned=0 flagged=0\n'
      ;;
    *)
      die_usage "Unknown wiki-lint format: $format"
      ;;
  esac
}

action_wiki_lint() {
  require_jq

  local stale_days_override=""
  local stale_days="$DEFAULT_SESSION_WIKI_STALE_DAYS"
  local format="text"
  local pages_file=""
  local findings_file=""
  local page_path=""
  local scanned="0"
  local output_json=""
  local lint_ts=""
  local now_epoch=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stale-days)
        [[ $# -ge 2 ]] || die_usage "Missing value for --stale-days."
        require_nonnegative_int "$2" "stale-days"
        stale_days_override="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown wiki-lint option: $1"
        ;;
    esac
  done

  if ! command -v sqlite3 >/dev/null 2>&1; then
    if [[ -n "$stale_days_override" ]]; then
      stale_days="$stale_days_override"
    fi
    wiki_lint_unavailable "$stale_days" "$format" "sqlite3 unavailable"
    return 0
  fi

  ensure_initialized

  if [[ -n "$stale_days_override" ]]; then
    stale_days="$stale_days_override"
  else
    stale_days="$(jq -r ".session_wiki.stale_days // $DEFAULT_SESSION_WIKI_STALE_DAYS" "$SETTINGS_FILE" 2>/dev/null || printf '%s\n' "$DEFAULT_SESSION_WIKI_STALE_DAYS")"
  fi
  require_nonnegative_int "$stale_days" "stale-days"

  if [[ ! -f "$INDEX_FILE" ]]; then
    wiki_lint_unavailable "$stale_days" "$format" "sqlite index unavailable"
    return 0
  fi

  if ! sqlite3 "$INDEX_FILE" "SELECT segment_id FROM segments LIMIT 1;" >/dev/null 2>&1; then
    wiki_lint_unavailable "$stale_days" "$format" "sqlite segments table unavailable"
    return 0
  fi

  pages_file="$(mktemp /tmp/session-archive-wiki-lint-pages.XXXXXX)"
  findings_file="$(mktemp /tmp/session-archive-wiki-lint-findings.XXXXXX)"
  wiki_markdown_files >"$pages_file"
  scanned="$(awk 'END { print NR + 0 }' "$pages_file")"
  lint_ts="$(timestamp_utc)"
  now_epoch="$(date -u +%s)"

  while IFS= read -r page_path || [[ -n "$page_path" ]]; do
    local frontmatter_file=""
    local source_segments_file=""
    local missing_segments_file=""
    local flags_file=""
    local wiki_relative=""
    local wiki_path=""
    local wiki_key=""
    local project_slug=""
    local proposal_id=""
    local last_verified=""
    local last_verified_epoch=""
    local age_days=""
    local age_days_json="null"
    local segment_id=""
    local segment_exists=""
    local missing_count="0"
    local flag_stale="false"
    local flag_orphan="false"
    local flag_dangling="false"
    local other_page=""
    local reason=""
    local flags_json="[]"
    local missing_segments_json="[]"
    local primary_event="lint-stale"

    [[ -n "$page_path" ]] || continue
    frontmatter_file="$(mktemp /tmp/session-archive-wiki-fm.XXXXXX)"
    source_segments_file="$(mktemp /tmp/session-archive-wiki-segments.XXXXXX)"
    missing_segments_file="$(mktemp /tmp/session-archive-wiki-missing.XXXXXX)"
    flags_file="$(mktemp /tmp/session-archive-wiki-flags.XXXXXX)"

    extract_wiki_frontmatter "$page_path" >"$frontmatter_file"
    wiki_relative="${page_path#"$WIKI_DIR"/}"
    wiki_path="wiki/$wiki_relative"
    wiki_key="$(wiki_frontmatter_scalar "$frontmatter_file" "wiki_key")"
    if [[ -z "$wiki_key" ]]; then
      wiki_key="${wiki_relative#*/}"
      wiki_key="${wiki_key%.md}"
    fi
    project_slug="$(wiki_frontmatter_scalar "$frontmatter_file" "project_slug")"
    if [[ -z "$project_slug" ]]; then
      project_slug="${wiki_relative%%/*}"
    fi
    proposal_id="$(wiki_frontmatter_scalar "$frontmatter_file" "proposal_id")"
    last_verified="$(wiki_frontmatter_scalar "$frontmatter_file" "last_verified")"
    wiki_frontmatter_array_values "$frontmatter_file" "source_segments" >"$source_segments_file"

    if [[ -n "$last_verified" ]]; then
      last_verified_epoch="$(iso_to_epoch "$last_verified" 2>/dev/null || true)"
      if [[ -n "$last_verified_epoch" ]]; then
        age_days="$(((now_epoch - last_verified_epoch) / 86400))"
        if ((age_days < 0)); then
          age_days="0"
        fi
        age_days_json="$age_days"
        if ((age_days > stale_days)); then
          flag_stale="true"
        fi
      fi
    fi

    while IFS= read -r segment_id || [[ -n "$segment_id" ]]; do
      [[ -n "$segment_id" ]] || continue
      segment_exists="$(sqlite3 "$INDEX_FILE" "SELECT 1 FROM segments WHERE segment_id = $(sql_quote "$segment_id") LIMIT 1;" 2>/dev/null || true)"
      if [[ "$segment_exists" != "1" ]]; then
        printf '%s\n' "$segment_id" >>"$missing_segments_file"
      fi
    done <"$source_segments_file"

    missing_count="$(awk 'END { print NR + 0 }' "$missing_segments_file")"
    if ((missing_count > 0)); then
      flag_dangling="true"
      flag_stale="true"
    fi

    flag_orphan="true"
    while IFS= read -r other_page || [[ -n "$other_page" ]]; do
      [[ -n "$other_page" && "$other_page" != "$page_path" ]] || continue
      if wiki_related_mentions_key "$other_page" "$wiki_key"; then
        flag_orphan="false"
        break
      fi
    done <"$pages_file"

    if [[ "$flag_stale" == "true" ]]; then
      printf 'stale\n' >>"$flags_file"
    fi
    if [[ "$flag_orphan" == "true" ]]; then
      printf 'orphan\n' >>"$flags_file"
    fi
    if [[ "$flag_dangling" == "true" ]]; then
      printf 'dangling_citation\n' >>"$flags_file"
    fi

    if [[ -s "$flags_file" ]]; then
      if ((missing_count > 0)); then
        reason="$(normalize_text "$reason missing_segments=$missing_count")"
      fi
      if [[ -n "$age_days" && "$age_days" -gt "$stale_days" ]]; then
        reason="$(normalize_text "$reason age_days=$age_days exceeds stale_days=$stale_days")"
      fi
      if [[ "$flag_orphan" == "true" ]]; then
        reason="$(normalize_text "$reason no inbound Related Pages reference")"
      fi
      if [[ -z "$reason" ]]; then
        reason="session wiki lint finding"
      fi

      flags_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' "$flags_file")"
      missing_segments_json="$(jq -Rsc 'split("\n") | map(select(length > 0))' "$missing_segments_file")"
      if [[ "$flag_dangling" == "true" ]]; then
        primary_event="lint-dangling"
      elif [[ "$flag_stale" == "true" ]]; then
        primary_event="lint-stale"
      else
        primary_event="lint-orphan"
      fi

      jq -cn \
        --arg wiki_key "$wiki_key" \
        --arg wiki_path "$wiki_path" \
        --arg project_slug "$project_slug" \
        --arg proposal_id "$proposal_id" \
        --argjson flags "$flags_json" \
        --argjson missing_segment_ids "$missing_segments_json" \
        --argjson age_days "$age_days_json" \
        --arg reason "$reason" \
        '{
          wiki_key: $wiki_key,
          wiki_path: $wiki_path,
          project_slug: $project_slug,
          proposal_id: (if ($proposal_id | length) > 0 then $proposal_id else null end),
          flags: $flags,
          missing_segment_ids: $missing_segment_ids,
          age_days: $age_days,
          reason: $reason
        }' >>"$findings_file"

      wiki_ledger_append "$(jq -cn \
        --arg ts "$lint_ts" \
        --arg event "$primary_event" \
        --arg wiki_key "$wiki_key" \
        --arg wiki_path "$wiki_path" \
        --arg proposal_id "$proposal_id" \
        --argjson flags "$flags_json" \
        --argjson missing_segments_count "$missing_count" \
        --argjson age_days "$age_days_json" \
        --arg reason "$reason" \
        '{
          ts: $ts,
          event: $event,
          wiki_key: $wiki_key,
          wiki_path: $wiki_path,
          proposal_id: (if ($proposal_id | length) > 0 then $proposal_id else null end),
          flags: $flags,
          missing_segments_count: $missing_segments_count,
          age_days: $age_days,
          reason: $reason
        }')"
    fi

    rm -f "$frontmatter_file" "$source_segments_file" "$missing_segments_file" "$flags_file"
  done <"$pages_file"

  output_json="$(jq -s \
    --argjson stale_days "$stale_days" \
    --argjson scanned "$scanned" \
    '{stale_days: $stale_days, scanned: $scanned, flagged: length, findings: .}' "$findings_file")"

  rm -f "$pages_file" "$findings_file"

  case "$format" in
    json)
      printf '%s\n' "$output_json"
      ;;
    text)
      printf '%s\n' "$output_json" |
        jq -r '
          if .flagged == 0 then
            "Session wiki is clean (scanned \(.scanned) pages, stale_days=\(.stale_days))."
          else
            "Session wiki lint findings: \(.flagged) flagged / \(.scanned) scanned",
            (
              .findings[]
              | "- " + .wiki_key
                + " flags=" + (.flags | join(","))
                + " missing_count=" + ((.missing_segment_ids | length) | tostring)
                + " age_days=" + ((.age_days // "unknown") | tostring)
                + " reason=" + .reason
                + "\n  remediation: run `/session-wiki propose --task-key <k>` to refresh"
            )
          end
        '
      ;;
    *)
      die_usage "Unknown wiki-lint format: $format"
      ;;
  esac
}

proposal_list_latest_json() {
  local status_filter="${1:?Missing status filter}"

  if [[ ! -f "$PROPOSALS_INDEX_FILE" ]]; then
    jq -cn \
      --arg status_filter "$status_filter" \
      '{
        status_filter: $status_filter,
        count: 0,
        proposals: []
      }'
    return 0
  fi

  jq -s \
    --arg status_filter "$status_filter" \
    '
      map(select(type == "object" and (.proposal_id // "") != ""))
      | reduce .[] as $row ({}; .[$row.proposal_id] = $row)
      | [.[]]
      | if $status_filter == "all" then . else map(select((.status // "") == $status_filter)) end
      | sort_by(.updated_at // .created_at // .ts // "")
      | reverse
      | {
          status_filter: $status_filter,
          count: length,
          proposals: .
        }
    ' "$PROPOSALS_INDEX_FILE"
}

action_proposal_list() {
  require_jq

  local status_filter="pending"
  local format="text"
  local proposals_json=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)
        [[ $# -ge 2 ]] || die_usage "Missing value for --status."
        status_filter="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown proposal-list option: $1"
        ;;
    esac
  done

  case "$status_filter" in
    pending | applied | rejected | all)
      ;;
    *)
      die_usage "Unknown proposal status: $status_filter"
      ;;
  esac

  proposals_json="$(proposal_list_latest_json "$status_filter")"

  case "$format" in
    json)
      printf '%s\n' "$proposals_json"
      ;;
    text)
      printf '%s\n' "$proposals_json" |
        jq -r '
          if .count == 0 then
            "No proposals found."
          else
            "Proposal ID\tStatus\tUpdated\tTarget Pages",
            (
              .proposals[]
              | [
                  .proposal_id,
                  (.status // "unknown"),
                  (.updated_at // .created_at // .ts // ""),
                  ((.target_pages // []) | length | tostring)
                ]
              | @tsv
            )
          end
        '
      ;;
    *)
      die_usage "Unknown proposal-list format: $format"
      ;;
  esac
}

wiki_ledger_append() {
  local row_json="${1:?Missing ledger row json}"
  ensure_archive_layout
  printf '%s\n' "$row_json" >>"$WIKI_LEDGER_FILE"
}

proposals_index_append() {
  local row_json="${1:?Missing proposals index row json}"
  ensure_archive_layout
  printf '%s\n' "$row_json" >>"$PROPOSALS_INDEX_FILE"
}

proposal_dir_for_id() {
  local proposal_id="${1:?Missing proposal id}"

  if [[ "$proposal_id" == *"/"* || "$proposal_id" == *".."* ]]; then
    log_error "Invalid proposal id: $proposal_id"
    exit 2
  fi

  printf '%s/%s\n' "$PROPOSALS_DIR" "$proposal_id"
}

proposal_manifest_path_for_id() {
  local proposal_id="${1:?Missing proposal id}"
  printf '%s/manifest.json\n' "$(proposal_dir_for_id "$proposal_id")"
}

require_proposal_manifest_path() {
  local proposal_id="${1:?Missing proposal id}"
  local manifest_path=""

  manifest_path="$(proposal_manifest_path_for_id "$proposal_id")"
  if [[ ! -f "$manifest_path" ]]; then
    log_error "proposal not found: $proposal_id"
    exit 1
  fi

  printf '%s\n' "$manifest_path"
}

validate_wiki_target_path() {
  local relative_path="${1:?Missing wiki target path}"

  if [[ "$relative_path" != wiki/* || "$relative_path" == *".."* || "$relative_path" == /* ]]; then
    log_error "Invalid wiki target path: $relative_path"
    exit 1
  fi
}

proposal_latest_status() {
  local proposal_id="${1:?Missing proposal id}"

  if [[ ! -f "$PROPOSALS_INDEX_FILE" ]]; then
    printf '\n'
    return 0
  fi

  jq -r --arg proposal_id "$proposal_id" '
    select((.proposal_id // "") == $proposal_id)
    | .status // empty
  ' "$PROPOSALS_INDEX_FILE" 2>/dev/null | tail -n 1 || true
}

diff_preimage_draft() {
  local proposal_dir="${1:?Missing proposal dir}"
  local relative_path="${2:?Missing relative path}"
  local preimage_path="$proposal_dir/preimage/$relative_path"
  local draft_path="$proposal_dir/pages/$relative_path"

  if [[ ! -f "$preimage_path" || ! -f "$draft_path" ]]; then
    return 0
  fi

  diff -u "$preimage_path" "$draft_path" || true
}

regenerate_wiki_catalogs() {
  local project_slug="${1:?Missing project slug}"
  local project_dir="$WIKI_DIR/$project_slug"
  local index_path="$project_dir/.index.md"
  local log_path="$project_dir/.log.md"
  local generated_at=""
  local page_path=""
  local relative_path=""
  local title=""
  local pages_file=""

  mkdir -p "$project_dir"
  generated_at="$(timestamp_utc)"
  pages_file="$(mktemp /tmp/session-archive-wiki-pages.XXXXXX)"
  find "$project_dir" -type f -name '*.md' ! -name '.index.md' ! -name '.log.md' 2>/dev/null | sort >"$pages_file"

  {
    printf '# Session Wiki Index - %s\n\n' "$project_slug"
    printf 'Generated: %s\n\n' "$generated_at"
    printf '## Pages\n\n'
    if [[ -s "$pages_file" ]]; then
      while IFS= read -r page_path; do
        relative_path="${page_path#"$WIKI_DIR"/}"
        title="$(awk '
          /^title:[[:space:]]*/ {
            sub(/^title:[[:space:]]*/, "", $0)
            gsub(/^"|"$/, "", $0)
            print
            exit
          }
        ' "$page_path")"
        if [[ -z "$title" ]]; then
          title="$(basename "$page_path" .md)"
        fi
        printf -- '- [%s](%s)\n' "$title" "$relative_path"
      done <"$pages_file"
    else
      printf 'No pages yet.\n'
    fi
  } >"$index_path"

  {
    printf '# Session Wiki Log - %s\n\n' "$project_slug"
    printf 'Generated: %s\n\n' "$generated_at"
    if [[ -f "$WIKI_LEDGER_FILE" ]]; then
      jq -r --arg prefix "wiki/$project_slug/" '
        select((.target_wiki_path // "") | startswith($prefix))
        | "- " + (.ts // "") + " " + (.event // "event") + " " + (.proposal_id // "") + " " + (.target_wiki_path // "")
      ' "$WIKI_LEDGER_FILE" 2>/dev/null || true
    fi
  } >"$log_path"

  rm -f "$pages_file"
}

update_manifest_status() {
  local proposal_id="${1:?Missing proposal id}"
  local status="${2:?Missing status}"
  local after_hash_map_json="${3:-}"
  local manifest_path=""
  local manifest_tmp=""
  local decided_at=""

  if [[ -z "$after_hash_map_json" ]]; then
    after_hash_map_json="{}"
  fi

  manifest_path="$(require_proposal_manifest_path "$proposal_id")"
  manifest_tmp="$(mktemp /tmp/session-archive-manifest.XXXXXX)"
  decided_at="$(timestamp_utc)"

  jq \
    --arg status "$status" \
    --arg decided_at "$decided_at" \
    --argjson after_hash_map "$after_hash_map_json" \
    '
      .status = $status
      | .decided_at = $decided_at
      | .updated_at = $decided_at
      | .target_pages = ((.target_pages // []) | map(
          if ($after_hash_map[.wiki_path] // null) then
            .after_hash = $after_hash_map[.wiki_path]
          else
            .
          end
        ))
    ' "$manifest_path" >"$manifest_tmp"
  mv "$manifest_tmp" "$manifest_path"
}

action_proposal_show() {
  require_jq

  local proposal_id="${1-}"
  local format="text"
  local manifest_path=""
  local proposal_dir=""
  local review_path=""
  local draft_pages_file=""
  local preimage_diffs_file=""
  local target_page_json=""
  local output_json=""

  [[ -n "$proposal_id" ]] || die_usage "proposal-show requires a proposal id."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown proposal-show option: $1"
        ;;
    esac
  done

  manifest_path="$(require_proposal_manifest_path "$proposal_id")"
  proposal_dir="$(proposal_dir_for_id "$proposal_id")"
  review_path="$proposal_dir/review.md"
  draft_pages_file="$(mktemp /tmp/session-archive-draft-pages.XXXXXX)"
  preimage_diffs_file="$(mktemp /tmp/session-archive-preimage-diffs.XXXXXX)"

  while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
    local relative_path=""
    local draft_path=""
    local preimage_path=""
    local diff_text=""
    local additions="0"
    local deletions="0"

    [[ -n "$target_page_json" ]] || continue
    relative_path="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_path')"
    validate_wiki_target_path "$relative_path"
    draft_path="$proposal_dir/pages/$relative_path"
    preimage_path="$proposal_dir/preimage/$relative_path"

    if [[ -f "$draft_path" ]]; then
      jq -n \
        --arg wiki_path "$relative_path" \
        --arg draft_path "$(home_relative_path "$draft_path")" \
        --argjson exists true \
        --argjson size "$(stat_size "$draft_path")" \
        --rawfile content "$draft_path" \
        '{wiki_path: $wiki_path, draft_path: $draft_path, exists: $exists, size: $size, content: $content}' >>"$draft_pages_file"
    else
      jq -n \
        --arg wiki_path "$relative_path" \
        --arg draft_path "$(home_relative_path "$draft_path")" \
        --argjson exists false \
        '{wiki_path: $wiki_path, draft_path: $draft_path, exists: $exists, size: null, content: null}' >>"$draft_pages_file"
    fi

    if [[ -f "$preimage_path" ]]; then
      diff_text="$(diff_preimage_draft "$proposal_dir" "$relative_path")"
      additions="$(printf '%s\n' "$diff_text" | awk '/^\+[^+]/ { count += 1 } END { print count + 0 }')"
      deletions="$(printf '%s\n' "$diff_text" | awk '/^-[^-]/ { count += 1 } END { print count + 0 }')"
      jq -n \
        --arg wiki_path "$relative_path" \
        --arg preimage_path "$(home_relative_path "$preimage_path")" \
        --argjson draft_exists "$([[ -f "$draft_path" ]] && printf true || printf false)" \
        --arg diff "$diff_text" \
        --argjson additions "$additions" \
        --argjson deletions "$deletions" \
        '{wiki_path: $wiki_path, preimage_path: $preimage_path, draft_exists: $draft_exists, diff: $diff, additions: $additions, deletions: $deletions}' >>"$preimage_diffs_file"
    fi
  done < <(jq -c '.target_pages[]?' "$manifest_path")

  if [[ -f "$review_path" ]]; then
    output_json="$(jq -n \
      --slurpfile manifest "$manifest_path" \
      --slurpfile draft_pages "$draft_pages_file" \
      --slurpfile preimage_diffs "$preimage_diffs_file" \
      --rawfile review_md "$review_path" \
      '{manifest: $manifest[0], draft_pages: $draft_pages, preimage_diffs: $preimage_diffs, review_md: $review_md}')"
  else
    output_json="$(jq -n \
      --slurpfile manifest "$manifest_path" \
      --slurpfile draft_pages "$draft_pages_file" \
      --slurpfile preimage_diffs "$preimage_diffs_file" \
      '{manifest: $manifest[0], draft_pages: $draft_pages, preimage_diffs: $preimage_diffs, review_md: null}')"
  fi

  rm -f "$draft_pages_file" "$preimage_diffs_file"

  case "$format" in
    json)
      printf '%s\n' "$output_json"
      ;;
    text)
      if [[ -f "$review_path" ]]; then
        sed -n '1,240p' "$review_path"
        printf '\n'
      fi
      printf 'Manifest summary\n'
      printf '%s\n' "$output_json" |
        jq -r '
          .manifest
          | "  proposal_id=" + (.proposal_id // ""),
            "  status=" + (.status // "unknown"),
            "  created_at=" + (.created_at // ""),
            "  updated_at=" + (.updated_at // .decided_at // ""),
            "  target_pages=" + ((.target_pages // []) | length | tostring),
            "  segment_count=" + ((.segment_count // 0) | tostring),
            "  synthesis_confidence=" + ((.synthesis_confidence // "null") | tostring),
            "  reversal_hint=" + ((.reversal_hint // "null") | tostring)
        '
      printf '%s\n' "$output_json" |
        jq -c '.draft_pages[]' |
        while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
          local relative_path=""
          local draft_path=""
          local exists=""
          local size=""
          local diff_summary=""

          [[ -n "$target_page_json" ]] || continue
          relative_path="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_path')"
          draft_path="$proposal_dir/pages/$relative_path"
          exists="$(printf '%s\n' "$target_page_json" | jq -r '.exists')"
          size="$(printf '%s\n' "$target_page_json" | jq -r '.size // "missing"')"
          printf '\nTarget: %s\n' "$relative_path"
          printf 'Draft: %s\n' "$(home_relative_path "$draft_path")"
          printf 'Size: %s\n' "$size"
          if [[ "$exists" == "true" ]]; then
            printf 'First 10 lines:\n'
            sed -n '1,10p' "$draft_path"
          else
            printf 'Draft missing.\n'
          fi
          diff_summary="$(printf '%s\n' "$output_json" | jq -r --arg wiki_path "$relative_path" '
            .preimage_diffs[]
            | select(.wiki_path == $wiki_path)
            | "Preimage diff: +" + (.additions | tostring) + " -" + (.deletions | tostring)
          ' | tail -n 1)"
          if [[ -n "$diff_summary" ]]; then
            printf '%s\n' "$diff_summary"
          fi
        done
      ;;
    *)
      die_usage "Unknown proposal-show format: $format"
      ;;
  esac
}

action_proposal_apply() {
  require_jq

  local proposal_id="${1-}"
  local force="false"
  local format="text"
  local manifest_path=""
  local proposal_dir=""
  local latest_status=""
  local targets_file=""
  local applied_targets_file=""
  local after_hash_rows_file=""
  local target_page_json=""
  local after_hash_map_json=""
  local decided_at=""
  local target_paths_json=""
  local segment_count="0"
  local session_count="0"
  local span_days="0"
  local agent_kind_mix_json="{}"
  local reversal_hint=""
  local output_json=""

  [[ -n "$proposal_id" ]] || die_usage "proposal-apply requires a proposal id."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)
        force="true"
        shift
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown proposal-apply option: $1"
        ;;
    esac
  done

  manifest_path="$(require_proposal_manifest_path "$proposal_id")"
  proposal_dir="$(proposal_dir_for_id "$proposal_id")"
  latest_status="$(proposal_latest_status "$proposal_id")"
  if [[ -z "$latest_status" ]]; then
    latest_status="$(jq -r '.status // empty' "$manifest_path")"
  fi

  if [[ "$force" != "true" && "$latest_status" != "pending" ]]; then
    log_error "proposal not pending: $proposal_id (status=${latest_status:-unknown})"
    exit 1
  fi

  targets_file="$(mktemp /tmp/session-archive-apply-targets.XXXXXX)"
  applied_targets_file="$(mktemp /tmp/session-archive-applied-targets.XXXXXX)"
  after_hash_rows_file="$(mktemp /tmp/session-archive-after-hashes.XXXXXX)"
  jq -c '.target_pages[]?' "$manifest_path" >"$targets_file"

  if [[ ! -s "$targets_file" ]]; then
    rm -f "$targets_file" "$applied_targets_file" "$after_hash_rows_file"
    log_error "proposal has no target pages: $proposal_id"
    exit 1
  fi

  while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
    local relative_path=""
    local preimage_hash=""
    local draft_path=""
    local target_wiki_full_path=""
    local current_hash=""

    [[ -n "$target_page_json" ]] || continue
    relative_path="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_path')"
    preimage_hash="$(printf '%s\n' "$target_page_json" | jq -r '.preimage_hash // empty')"
    validate_wiki_target_path "$relative_path"
    draft_path="$proposal_dir/pages/$relative_path"
    target_wiki_full_path="$ARCHIVE_ROOT/$relative_path"

    if [[ ! -f "$draft_path" ]]; then
      log_error "draft page missing: $draft_path"
      exit 1
    fi

    if [[ -n "$preimage_hash" ]]; then
      if [[ ! -f "$target_wiki_full_path" ]]; then
        log_error "preimage expected but target gone: $relative_path"
        exit 1
      fi
      current_hash="sha256:$(sha256_file "$target_wiki_full_path")"
      if [[ "$current_hash" != "$preimage_hash" ]]; then
        log_error "manual drift detected: preimage hash mismatch for $relative_path"
        exit 1
      fi
    elif [[ -e "$target_wiki_full_path" ]]; then
      log_error "unexpected existing file: $relative_path -- propose again; --force does not bypass target existence checks"
      exit 1
    fi
  done <"$targets_file"

  while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
    local relative_path=""
    local wiki_key=""
    local draft_path=""
    local target_wiki_full_path=""
    local after_hash=""

    [[ -n "$target_page_json" ]] || continue
    relative_path="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_path')"
    wiki_key="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_key // ""')"
    validate_wiki_target_path "$relative_path"
    draft_path="$proposal_dir/pages/$relative_path"
    target_wiki_full_path="$ARCHIVE_ROOT/$relative_path"

    mkdir -p "$(dirname "$target_wiki_full_path")"
    cp "$draft_path" "$target_wiki_full_path"
    after_hash="sha256:$(sha256_file "$target_wiki_full_path")"

    jq -cn \
      --arg target_wiki_path "$relative_path" \
      --arg target_wiki_full_path "$(home_relative_path "$target_wiki_full_path")" \
      --arg wiki_key "$wiki_key" \
      --arg after_hash "$after_hash" \
      '{target_wiki_path: $target_wiki_path, target_wiki_full_path: $target_wiki_full_path, wiki_key: $wiki_key, after_hash: $after_hash}' >>"$applied_targets_file"
    jq -cn \
      --arg wiki_path "$relative_path" \
      --arg after_hash "$after_hash" \
      '{wiki_path: $wiki_path, after_hash: $after_hash}' >>"$after_hash_rows_file"
  done <"$targets_file"

  after_hash_map_json="$(jq -s 'reduce .[] as $row ({}; .[$row.wiki_path] = $row.after_hash)' "$after_hash_rows_file")"
  update_manifest_status "$proposal_id" "applied" "$after_hash_map_json"
  decided_at="$(jq -r '.decided_at // empty' "$manifest_path")"
  target_paths_json="$(jq '[.target_pages[]?.wiki_path]' "$manifest_path")"
  segment_count="$(jq -r '.segment_count // 0' "$manifest_path")"
  session_count="$(jq -r '.session_count // 0' "$manifest_path")"
  span_days="$(jq -r '.span_days // 0' "$manifest_path")"
  agent_kind_mix_json="$(jq '.agent_kind_mix // {}' "$manifest_path")"
  reversal_hint="$(jq -r '.reversal_hint // empty' "$manifest_path")"

  proposals_index_append "$(jq -cn \
    --arg proposal_id "$proposal_id" \
    --arg decided_at "$decided_at" \
    --argjson target_pages "$target_paths_json" \
    --argjson segment_count "$segment_count" \
    --argjson session_count "$session_count" \
    --argjson span_days "$span_days" \
    '{
      proposal_id: $proposal_id,
      status: "applied",
      decided_at: $decided_at,
      updated_at: $decided_at,
      target_pages: $target_pages,
      segment_count: $segment_count,
      session_count: $session_count,
      span_days: $span_days
    }')"

  while IFS= read -r target_page_json || [[ -n "$target_page_json" ]]; do
    local target_wiki_path=""
    local content_hash=""
    local wiki_key=""

    [[ -n "$target_page_json" ]] || continue
    target_wiki_path="$(printf '%s\n' "$target_page_json" | jq -r '.target_wiki_path')"
    content_hash="$(printf '%s\n' "$target_page_json" | jq -r '.after_hash')"
    wiki_key="$(printf '%s\n' "$target_page_json" | jq -r '.wiki_key')"
    wiki_ledger_append "$(jq -cn \
      --arg ts "$decided_at" \
      --arg proposal_id "$proposal_id" \
      --arg target_wiki_path "$target_wiki_path" \
      --arg content_hash "$content_hash" \
      --arg wiki_key "$wiki_key" \
      --argjson agent_kind_mix "$agent_kind_mix_json" \
      '{
        ts: $ts,
        event: "applied",
        proposal_id: $proposal_id,
        target_wiki_path: $target_wiki_path,
        content_hash: $content_hash,
        agent_kind_mix: $agent_kind_mix,
        wiki_key: $wiki_key
      }')"
  done <"$applied_targets_file"

  jq -r '.target_wiki_path | split("/")[1] // empty' "$applied_targets_file" | sort -u |
    while IFS= read -r project_slug || [[ -n "$project_slug" ]]; do
      [[ -n "$project_slug" ]] || continue
      regenerate_wiki_catalogs "$project_slug"
    done

  output_json="$(jq -n \
    --arg proposal_id "$proposal_id" \
    --arg decided_at "$decided_at" \
    --slurpfile applied_targets "$applied_targets_file" \
    --arg reversal_hint "$reversal_hint" \
    '{
      proposal_id: $proposal_id,
      status: "applied",
      decided_at: $decided_at,
      applied_targets: $applied_targets,
      reversal_hint: (if ($reversal_hint | length) > 0 then $reversal_hint else null end)
    }')"

  rm -f "$targets_file" "$applied_targets_file" "$after_hash_rows_file"

  case "$format" in
    json)
      printf '%s\n' "$output_json"
      ;;
    text)
      printf '%s\n' "$output_json" |
        jq -r '
          "Applied proposal: " + .proposal_id,
          "decided_at=" + .decided_at,
          "Targets:",
          (.applied_targets[] | "- " + .target_wiki_path + " " + .after_hash),
          "Reversal hint: " + ((.reversal_hint // "not recorded") | tostring)
        '
      ;;
    *)
      die_usage "Unknown proposal-apply format: $format"
      ;;
  esac
}

action_proposal_reject() {
  require_jq

  local proposal_id="${1-}"
  local reason=""
  local format="text"
  local manifest_path=""
  local decided_at=""
  local target_paths_json="[]"
  local segment_count="0"
  local session_count="0"
  local span_days="0"
  local manifest_tmp=""
  local output_json=""

  [[ -n "$proposal_id" ]] || die_usage "proposal-reject requires a proposal id."
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason)
        [[ $# -ge 2 ]] || die_usage "Missing value for --reason."
        reason="$2"
        shift 2
        ;;
      --format)
        [[ $# -ge 2 ]] || die_usage "Missing value for --format."
        format="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown proposal-reject option: $1"
        ;;
    esac
  done

  [[ -n "$(normalize_text "$reason")" ]] || die_usage "proposal-reject requires --reason."

  manifest_path="$(require_proposal_manifest_path "$proposal_id")"
  update_manifest_status "$proposal_id" "rejected" "{}"
  decided_at="$(jq -r '.decided_at // empty' "$manifest_path")"
  manifest_tmp="$(mktemp /tmp/session-archive-manifest.XXXXXX)"
  jq --arg reason "$reason" '.rejection_reason = $reason' "$manifest_path" >"$manifest_tmp"
  mv "$manifest_tmp" "$manifest_path"

  target_paths_json="$(jq '[.target_pages[]?.wiki_path]' "$manifest_path")"
  segment_count="$(jq -r '.segment_count // 0' "$manifest_path")"
  session_count="$(jq -r '.session_count // 0' "$manifest_path")"
  span_days="$(jq -r '.span_days // 0' "$manifest_path")"

  proposals_index_append "$(jq -cn \
    --arg proposal_id "$proposal_id" \
    --arg decided_at "$decided_at" \
    --arg reason "$reason" \
    --argjson target_pages "$target_paths_json" \
    --argjson segment_count "$segment_count" \
    --argjson session_count "$session_count" \
    --argjson span_days "$span_days" \
    '{
      proposal_id: $proposal_id,
      status: "rejected",
      decided_at: $decided_at,
      updated_at: $decided_at,
      reason: $reason,
      target_pages: $target_pages,
      segment_count: $segment_count,
      session_count: $session_count,
      span_days: $span_days
    }')"

  wiki_ledger_append "$(jq -cn \
    --arg ts "$decided_at" \
    --arg proposal_id "$proposal_id" \
    --arg reason "$reason" \
    '{ts: $ts, event: "rejected", proposal_id: $proposal_id, reason: $reason}')"

  output_json="$(jq -cn \
    --arg proposal_id "$proposal_id" \
    --arg decided_at "$decided_at" \
    --arg reason "$reason" \
    --arg proposal_dir "$(home_relative_path "$(proposal_dir_for_id "$proposal_id")")" \
    '{
      proposal_id: $proposal_id,
      status: "rejected",
      decided_at: $decided_at,
      reason: $reason,
      proposal_dir: $proposal_dir
    }')"

  case "$format" in
    json)
      printf '%s\n' "$output_json"
      ;;
    text)
      printf '%s\n' "$output_json" |
        jq -r '"Rejected proposal: " + .proposal_id, "decided_at=" + .decided_at, "reason=" + .reason, "proposal_dir=" + .proposal_dir'
      ;;
    *)
      die_usage "Unknown proposal-reject format: $format"
      ;;
  esac
}

action_rebuild() {
  require_jq
  require_sqlite3
  ensure_initialized

  local since_spec="$DEFAULT_REBUILD_SINCE"
  local cutoff_epoch=""
  local source_path=""
  local enqueued=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --since)
        [[ $# -ge 2 ]] || die_usage "Missing value for --since."
        since_spec="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown rebuild option: $1"
        ;;
    esac
  done

  cutoff_epoch="$(epoch_from_spec "$since_spec" 2>/dev/null || true)"
  if [[ -z "$cutoff_epoch" ]]; then
    die_usage "Unsupported --since value: $since_spec"
  fi

  if [[ ! -d "$TRANSCRIPT_ROOT" ]]; then
    log_error "Transcript root not found: $TRANSCRIPT_ROOT"
    action_sync
    return 0
  fi

  while IFS= read -r source_path; do
    [[ -n "$source_path" ]] || continue
    append_queue_path "$source_path"
    enqueued=$((enqueued + 1))
  done < <(
    find "$TRANSCRIPT_ROOT" -type f -name '*.jsonl' 2>/dev/null |
      while IFS= read -r candidate; do
        [[ -n "$candidate" ]] || continue
        if (($(stat_mtime "$candidate") >= cutoff_epoch)); then
          printf '%s\n' "$candidate"
        fi
      done
  )

  action_sync
}

action_prune() {
  require_jq
  require_sqlite3
  ensure_initialized

  local older_than_spec="$DEFAULT_PRUNE_OLDER_THAN"
  local cutoff_epoch=""
  local deleted_sources="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --older-than)
        [[ $# -ge 2 ]] || die_usage "Missing value for --older-than."
        older_than_spec="$2"
        shift 2
        ;;
      *)
        die_usage "Unknown prune option: $1"
        ;;
    esac
  done

  cutoff_epoch="$(epoch_from_spec "$older_than_spec" 2>/dev/null || true)"
  if [[ -z "$cutoff_epoch" ]]; then
    die_usage "Unsupported --older-than value: $older_than_spec"
  fi

  deleted_sources="$(sqlite3 "$INDEX_FILE" "SELECT COUNT(*) FROM sources WHERE source_mtime < $cutoff_epoch;" 2>/dev/null || printf '0')"
  sqlite3 "$INDEX_FILE" "DELETE FROM sources WHERE source_mtime < $cutoff_epoch;"
  update_state_file "$(timestamp_utc)"

  jq -cn \
    --arg older_than "$older_than_spec" \
    --argjson cutoff_epoch "$cutoff_epoch" \
    --argjson deleted_sources "$deleted_sources" \
    '{
      older_than: $older_than,
      cutoff_epoch: $cutoff_epoch,
      deleted_sources: $deleted_sources
    }'
}

case "$ACTION" in
  init)
    action_init "$@"
    ;;
  sync)
    action_sync "$@"
    ;;
  search)
    action_search "$@"
    ;;
  select)
    action_select "$@"
    ;;
  get)
    action_get "$@"
    ;;
  propose)
    action_propose "$@"
    ;;
  status)
    action_status "$@"
    ;;
  wiki-status)
    action_wiki_status "$@"
    ;;
  wiki-lint)
    action_wiki_lint "$@"
    ;;
  proposal-list)
    action_proposal_list "$@"
    ;;
  proposal-show)
    action_proposal_show "$@"
    ;;
  proposal-apply)
    action_proposal_apply "$@"
    ;;
  proposal-reject)
    action_proposal_reject "$@"
    ;;
  rebuild)
    action_rebuild "$@"
    ;;
  prune)
    action_prune "$@"
    ;;
  *)
    die_usage "Unknown action: $ACTION"
    ;;
esac
