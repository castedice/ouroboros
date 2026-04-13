#!/usr/bin/env bash
# PreCompact hook: output compact change summary + extract conversation context
# Fires before auto-compact or manual /compact.
# Output is included in the context that gets summarized, helping preserve
# recent change awareness through compaction.
# Also generates .compact-context.md for session-start injection after compaction.
# NOTE: STATUS.md injection is handled by SessionStart (no duplication).
set -euo pipefail

# Read stdin (hook provides JSON with transcript_path)
STDIN_DATA=""
if ! [ -t 0 ]; then
  STDIN_DATA=$(cat)
fi

echo "=== Pre-Compaction: Recent Changes ==="

# Compact git summary: commit messages + file count
if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  LOG=$(git log --oneline -3 2>/dev/null || true)
  if [[ -n "$LOG" ]]; then
    echo "$LOG"
    # One-line summary: "15 files changed, 410 insertions(+), 38 deletions(-)"
    SUMMARY=$(git diff --stat HEAD~3 2>/dev/null | tail -1 || true)
    [[ -n "$SUMMARY" ]] && echo "$SUMMARY"
  fi
fi

# Session name suggestion based on recent commits
if [[ -n "${LOG:-}" ]]; then
  FIRST_COMMIT=$(echo "$LOG" | head -1 | sed 's/^[a-f0-9]* //')
  echo "Session name suggestion: $FIRST_COMMIT"
fi

echo "=== End ==="

run_with_timeout() {
  local timeout_seconds="${1:?Missing timeout}"
  local pid=0
  local elapsed=0

  shift || true
  [ "$#" -gt 0 ] || return 0

  (
    "$@"
  ) &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    if [ "$elapsed" -ge "$timeout_seconds" ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "$pid" 2>/dev/null
}

compact_hash() {
  local raw_text="${1-}"
  local hash_value=""

  if command -v sha256sum >/dev/null 2>&1; then
    hash_value="$(printf '%s' "$raw_text" | sha256sum 2>/dev/null | awk '{print $1}')" || hash_value=""
  elif command -v shasum >/dev/null 2>&1; then
    hash_value="$(printf '%s' "$raw_text" | shasum -a 256 2>/dev/null | awk '{print $1}')" || hash_value=""
  fi

  if [[ -z "$hash_value" ]]; then
    hash_value="$(date -u +%s)-$$"
  fi

  printf '%s\n' "$hash_value"
}

emit_session_pattern() {
  local pattern_type="${1:?Missing pattern type}"
  local pattern_key="${2:?Missing pattern key}"
  local detail_json="${3:?Missing detail json}"
  local confidence="${4:-0.65}"
  local script_dir=""
  local script_path=""
  local cmd=()

  script_dir="$(cd "$(dirname "$0")" && pwd)"
  script_path="$script_dir/session-patterns.sh"
  [[ -f "$script_path" ]] || return 0

  cmd=(bash "$script_path" extract "$pattern_type" "$pattern_key" "$detail_json" --confidence "$confidence")
  if [[ -n "${SESSION_ID:-}" ]]; then
    cmd+=(--session-id "$SESSION_ID")
  fi

  run_with_timeout 10 "${cmd[@]}" >/dev/null 2>&1 || true
}

extract_session_patterns() {
  local companion_json=""
  local verification_json=""
  local permission_json=""
  local detail_json=""
  local pattern_key=""
  local pattern_key_seed=""
  local tool_name=""
  local normalized_tool=""

  [[ -n "${TRANSCRIPT_PATH:-}" ]] || return 0
  [[ -f "$TRANSCRIPT_PATH" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  while IFS= read -r companion_json; do
    [[ -n "$companion_json" ]] || continue
    pattern_key_seed="$(printf '%s' "$companion_json" | jq -r '.files | join("|")' 2>/dev/null || true)"
    [[ -n "$pattern_key_seed" ]] || continue
    pattern_key="bundle-$(compact_hash "$pattern_key_seed" | cut -c1-12)"
    detail_json="$(printf '%s' "$companion_json" | jq -c '.' 2>/dev/null || true)"
    [[ -n "$detail_json" ]] || continue
    emit_session_pattern "companion_file_bundle" "$pattern_key" "$detail_json" "0.72"
  done < <(
    tail -500 "$TRANSCRIPT_PATH" | jq -c --arg root "$PROJECT_ROOT" '
      select(.type == "assistant") |
      [
        .message.content[]? |
        select(.type == "tool_use" and (.name == "Edit" or .name == "Write")) |
        (.input.file_path // empty) |
        ltrimstr($root + "/")
      ] |
      map(select(type == "string" and length > 0)) |
      unique |
      select(length >= 3) |
      {
        files: .,
        count: length
      }
    ' 2>/dev/null || true
  )

  verification_json="$(
    tail -500 "$TRANSCRIPT_PATH" | jq -cs '
      [
        .[] |
        select(.type == "assistant") |
        .message.content[]? |
        select(.type == "tool_use" and .name == "Bash") |
        (.input.command // .input.cmd // "") as $cmd |
        if ($cmd | test("(^|[[:space:]])bash[[:space:]]+-n([[:space:]]|$)")) then
          { kind: "bash -n", command: $cmd }
        elif ($cmd | test("git[[:space:]].*diff[[:space:]]+--check")) then
          { kind: "git diff --check", command: $cmd }
        elif ($cmd | test("(^|[[:space:]])jq[[:space:]]+empty([[:space:]]|$)")) then
          { kind: "jq empty", command: $cmd }
        elif ($cmd | test("(^|[[:space:]])shellcheck([[:space:]]|$)")) then
          { kind: "shellcheck", command: $cmd }
        else
          empty
        end
      ] as $matches |
      if ($matches | length) >= 3 then
        {
          kinds: ($matches | map(.kind) | unique | sort),
          command_count: ($matches | length),
          commands: ($matches | map(.command) | unique | .[:8])
        }
      else
        empty
      end
    ' 2>/dev/null || true
  )"

  if [[ -n "$verification_json" ]]; then
    pattern_key_seed="$(printf '%s' "$verification_json" | jq -r '.kinds | join("|")' 2>/dev/null || true)"
    if [[ -n "$pattern_key_seed" ]]; then
      pattern_key="verify-$(compact_hash "$pattern_key_seed" | cut -c1-12)"
      detail_json="$(printf '%s' "$verification_json" | jq -c '.' 2>/dev/null || true)"
      [[ -n "$detail_json" ]] && emit_session_pattern "verification_bundle" "$pattern_key" "$detail_json" "0.70"
    fi
  fi

  while IFS= read -r permission_json; do
    [[ -n "$permission_json" ]] || continue
    tool_name="$(printf '%s' "$permission_json" | jq -r '.tool // empty' 2>/dev/null || true)"
    [[ -n "$tool_name" ]] || continue
    normalized_tool="$(printf '%s' "$tool_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
    [[ -n "$normalized_tool" ]] || continue
    detail_json="$(printf '%s' "$permission_json" | jq -c '.' 2>/dev/null || true)"
    [[ -n "$detail_json" ]] || continue
    emit_session_pattern "permission_friction" "tool-$normalized_tool" "$detail_json" "0.80"
  done < <(
    tail -500 "$TRANSCRIPT_PATH" | jq -cs '
      . as $rows |
      (
        reduce $rows[] as $row ({};
          . + (
            reduce ($row.message.content[]? | select(type == "object" and .type == "tool_use")) as $item ({};
              if (($item.id // $item.tool_use_id // "") | length) > 0 and (($item.name // "") | length) > 0 then
                . + { (($item.id // $item.tool_use_id)): ($item.name // "") }
              else
                .
              end
            )
          )
        )
      ) as $tool_map |
      [
        $rows[] |
        .message.content[]? |
        select(type == "object" and .type == "tool_result") |
        {
          tool: ($tool_map[.tool_use_id] // ""),
          text: (
            if (.content | type) == "string" then
              .content
            elif (.content | type) == "array" then
              (
                [
                  .content[]? |
                  if type == "string" then
                    .
                  elif (type == "object" and .type == "text") then
                    .text
                  else
                    empty
                  end
                ] | join(" ")
              )
            else
              ""
            end
          )
        } |
        select((.tool | length) > 0) |
        select(.text | test("permission denied|not allowed|requires approval|approval policy|sandbox|forbidden|denied|rejected"; "i"))
      ] |
      group_by(.tool) |
      map(
        select(length >= 3) |
        {
          tool: (.[0].tool),
          count: length,
          examples: (
            map(.text | gsub("[\r\n]+"; " ")) |
            unique |
            map(if length > 160 then .[0:160] + "..." else . end) |
            .[:3]
          )
        }
      ) |
      .[]
    ' 2>/dev/null || true
  )
}

# --- Conversation context extraction ---
# Parse transcript JSONL to preserve discussion context through compaction.
# Output: .compact-context.md (consumed once by session-start.sh)

TRANSCRIPT_PATH=""
SESSION_ID=""
if [[ -n "$STDIN_DATA" ]] && command -v jq &>/dev/null; then
  TRANSCRIPT_PATH=$(echo "$STDIN_DATA" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  SESSION_ID=$(echo "$STDIN_DATA" | jq -r '.session_id // .session // empty' 2>/dev/null || true)
fi

# Skip if no transcript available
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

PROJECT_ROOT="$(pwd)"
CONTEXT_FILE="$PROJECT_ROOT/.compact-context.md"

{
  echo "## Conversation Context (pre-compaction)"
  echo ""

  # 1. Recent conversation (last ~5 user+assistant pairs, 150 char truncate)
  echo "### Recent Discussion"
  echo ""
  tail -500 "$TRANSCRIPT_PATH" | jq -r '
    if .type == "user" and .userType == "external" then
      (.message.content |
        if type == "string" then .
        elif type == "array" then
          ([.[] | select(type == "object" and .type == "text") | .text] | join(" "))
        else ""
        end
      | gsub("\n"; " ") | gsub("  +"; " ")) as $text |
      if ($text | length) > 0 then
        "- **User**: " + (if ($text | length) > 150 then ($text[0:150] + "...") else $text end)
      else empty
      end
    elif .type == "assistant" then
      ([.message.content[]? | select(.type == "text") | .text] | join(" ")
      | gsub("\n"; " ") | gsub("  +"; " ")) as $text |
      if ($text | length) > 0 then
        "- **Assistant**: " + (if ($text | length) > 150 then ($text[0:150] + "...") else $text end)
      else empty
      end
    else empty
    end
  ' 2>/dev/null | tail -10 || true

  echo ""

  # 2. Modified files (from Edit/Write tool_use, deduplicated)
  echo "### Modified Files"
  echo ""
  MODIFIED=$(tail -500 "$TRANSCRIPT_PATH" | jq -r '
    select(.type == "assistant") | .message.content[]? |
    select(.type == "tool_use" and (.name == "Edit" or .name == "Write")) |
    .input.file_path // empty
  ' 2>/dev/null | sort -u || true)

  if [[ -n "$MODIFIED" ]]; then
    echo "$MODIFIED" | while IFS= read -r fpath; do
      # Convert to relative path
      echo "- ${fpath#$PROJECT_ROOT/}"
    done
  else
    echo "(none detected)"
  fi

  echo ""

  # 3. Uncommitted changes
  echo "### Uncommitted Changes"
  echo ""
  if command -v git &>/dev/null && git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    STATUS=$(git status --short 2>/dev/null || true)
    if [[ -n "$STATUS" ]]; then
      echo "$STATUS"
    else
      echo "(working tree clean)"
    fi
  else
    echo "(not a git repo)"
  fi

} >"$CONTEXT_FILE" 2>/dev/null || true

extract_session_patterns || true

# --- PA Memory flush (Layer 1) ---
# Extract recent user messages for memory distillation by next PA command.
# Only runs if a PA vault is configured (settings.json has vault_root).

# Discover PA vault settings: env override → project root → plugin-adjacent vaults
PA_SETTINGS=""
for candidate in \
  "${PA_VAULT_ROOT:+$PA_VAULT_ROOT/.pa/settings.json}" \
  "$PROJECT_ROOT/.pa/settings.json"; do
  [[ -n "$candidate" ]] && [[ -f "$candidate" ]] && PA_SETTINGS="$candidate" && break
done

# If not found yet, scan QMD collections for vault paths with .pa/
if [[ -z "$PA_SETTINGS" ]] && command -v qmd &>/dev/null; then
  COLLECTIONS=$(qmd collection list 2>/dev/null | sed -n 's/^\([a-zA-Z0-9_-]*\) (qmd:.*/\1/p' || true)
  for coll in $COLLECTIONS; do
    VAULT_PATH=$(qmd collection show "$coll" 2>/dev/null | awk '/Path:/{print $2}' || true)
    if [[ -n "$VAULT_PATH" ]] && [[ -f "$VAULT_PATH/.pa/settings.json" ]]; then
      PA_SETTINGS="$VAULT_PATH/.pa/settings.json"
      break
    fi
  done
fi

if [[ -n "$PA_SETTINGS" ]] && command -v jq &>/dev/null; then
  VAULT_ROOT=$(jq -r '.vault_root // empty' "$PA_SETTINGS" 2>/dev/null || true)
  if [[ -n "$VAULT_ROOT" ]] && [[ -d "$VAULT_ROOT/.pa" ]]; then
    MEMORY_DIR="$VAULT_ROOT/.pa/memory"
    PENDING="$MEMORY_DIR/.pending-flush.jsonl"
    STATE_FILE="$MEMORY_DIR/state.json"

    # Ensure memory directory exists
    mkdir -p "$MEMORY_DIR/daily"

    # Extract last ~20 user messages from transcript
    if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
      tail -500 "$TRANSCRIPT_PATH" | jq -c '
        select(.type == "user" and .userType == "external") |
        {
          ts: (now | strftime("%Y-%m-%dT%H:%M:%S+09:00")),
          text: (
            .message.content |
            if type == "string" then .
            elif type == "array" then
              ([.[] | select(type == "object" and .type == "text") | .text] | join(" "))
            else ""
            end
          )
        } | select(.text | length > 10)
      ' 2>/dev/null | tail -20 >>"$PENDING" 2>/dev/null || true

      # Update state.json
      if [[ -f "$STATE_FILE" ]]; then
        # Set flush_requested to true
        TMP_STATE=$(mktemp)
        jq '.flush_requested = true' "$STATE_FILE" >"$TMP_STATE" 2>/dev/null && mv "$TMP_STATE" "$STATE_FILE"
      else
        echo '{"version":1,"flush_requested":true,"transcript_cursor":0,"last_digest_date":null,"next_id":1}' >"$STATE_FILE"
      fi
    fi
  fi
fi

exit 0
