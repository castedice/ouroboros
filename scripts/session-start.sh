#!/usr/bin/env bash
# SessionStart hook: inject project status into session context
# Fires on: startup, resume, compact, clear
# Priority: STATUS.md (project root) > dev/STATUS.md (ouroboros internal)
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-.}"
PROJECT_ROOT="$(pwd)"

format_pattern_suggestion() {
  local pattern_json="${1:?Missing pattern json}"
  local pattern_id=""
  local pattern_type=""
  local occurrences="0"
  local day_count="0"
  local summary=""
  local kinds=""
  local tool=""
  local block_count="0"
  local files=""

  pattern_id="$(printf '%s' "$pattern_json" | jq -r '.pattern_id // "PAT-unknown"' 2>/dev/null || true)"
  pattern_type="$(printf '%s' "$pattern_json" | jq -r '.pattern_type // empty' 2>/dev/null || true)"
  occurrences="$(printf '%s' "$pattern_json" | jq -r '(.occurrences // 0) | tostring' 2>/dev/null || printf '0')"
  day_count="$(printf '%s' "$pattern_json" | jq -r '(.day_count // 0) | tostring' 2>/dev/null || printf '0')"

  case "$pattern_type" in
    verification_bundle)
      kinds="$(printf '%s' "$pattern_json" | jq -r '
        if (.detail.kinds // [] | length) > 0 then
          .detail.kinds | join(", ")
        elif (.detail.commands // [] | length) > 0 then
          .detail.commands | join(", ")
        else
          "Recurring checks"
        end
      ' 2>/dev/null || true)"
      summary="Verification bundle: $kinds after edits"
      ;;
    permission_friction)
      tool="$(printf '%s' "$pattern_json" | jq -r '.detail.tool // "Unknown tool"' 2>/dev/null || true)"
      block_count="$(printf '%s' "$pattern_json" | jq -r '(.detail.count // .occurrences // 0) | tostring' 2>/dev/null || printf '0')"
      summary="Permission friction: $tool blocked $block_count times. Consider adding to allow list."
      ;;
    companion_file_bundle)
      files="$(printf '%s' "$pattern_json" | jq -r '
        if (.detail.files // [] | length) > 0 then
          .detail.files[:4] | join(", ")
        else
          "Recurring file set"
        end
      ' 2>/dev/null || true)"
      summary="Companion file bundle: $files"
      ;;
    *)
      summary="$(printf '%s' "$pattern_json" | jq -r '.detail.description // .detail.summary // .pattern_key // "Recurring pattern"' 2>/dev/null || true)"
      ;;
  esac

  printf -- '- [%s] %s (seen %sx, %s days)\n' "$pattern_id" "$summary" "$occurrences" "$day_count"
}

format_pattern_instruction() {
  local pattern_json="${1:?Missing pattern json}"
  local pattern_id=""
  local pattern_type=""
  local instruction=""
  local kinds=""
  local tool=""
  local files=""

  pattern_id="$(printf '%s' "$pattern_json" | jq -r '.pattern_id // "PAT-unknown"' 2>/dev/null || true)"
  instruction="$(printf '%s' "$pattern_json" | jq -r '.instruction // .detail.instruction // empty' 2>/dev/null || true)"

  if [[ -z "$instruction" ]]; then
    pattern_type="$(printf '%s' "$pattern_json" | jq -r '.pattern_type // empty' 2>/dev/null || true)"

    case "$pattern_type" in
      verification_bundle)
        kinds="$(printf '%s' "$pattern_json" | jq -r '
          if (.detail.kinds // [] | length) > 0 then
            .detail.kinds | join(", ")
          elif (.detail.commands // [] | length) > 0 then
            .detail.commands | join(", ")
          else
            "the recurring verification bundle"
          end
        ' 2>/dev/null || true)"
        instruction="Always run $kinds after editing relevant files"
        ;;
      permission_friction)
        tool="$(printf '%s' "$pattern_json" | jq -r '.detail.tool // "this tool"' 2>/dev/null || true)"
        instruction="Expect recurring permission friction around $tool; prefer the allow-list path when appropriate"
        ;;
      companion_file_bundle)
        files="$(printf '%s' "$pattern_json" | jq -r '
          if (.detail.files // [] | length) > 0 then
            .detail.files[:4] | join(", ")
          else
            "this recurring file set"
          end
        ' 2>/dev/null || true)"
        instruction="Treat this file set as a recurring companion bundle: $files"
        ;;
      *)
        instruction="$(printf '%s' "$pattern_json" | jq -r '.detail.description // "Active pattern"' 2>/dev/null || true)"
        ;;
    esac
  fi

  printf -- '- [%s] %s\n' "$pattern_id" "$instruction"
}

emit_suggestions() {
  local patterns_dir="${CLAUDE_PLUGIN_DATA:-$PLUGIN_ROOT/.tmp}/patterns"
  local catalog_path="$patterns_dir/catalog.json"
  local suggestions_json=""
  local suggestion_lines=""
  local approved_lines=""
  local pattern_json=""

  [[ -d "$patterns_dir" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0

  suggestions_json="$(bash "$PLUGIN_ROOT/scripts/session-patterns.sh" materialize --max-suggestions 2 2>/dev/null || true)"
  if [[ -n "$suggestions_json" ]]; then
    while IFS= read -r pattern_json; do
      [[ -n "$pattern_json" ]] || continue
      suggestion_lines="${suggestion_lines}$(format_pattern_suggestion "$pattern_json")"$'\n'
    done < <(printf '%s' "$suggestions_json" | jq -c '.[]?' 2>/dev/null || true)
  fi

  if [[ -n "$suggestion_lines" ]]; then
    echo ""
    echo "=== Session Suggestions ==="
    echo "Recent sessions show recurring patterns:"
    printf '%s' "$suggestion_lines"
    echo 'Reply "approve PAT-xxx" or "dismiss PAT-xxx" to act.'
    echo "============================="
  fi

  if [[ -f "$catalog_path" ]]; then
    while IFS= read -r pattern_json; do
      [[ -n "$pattern_json" ]] || continue
      approved_lines="${approved_lines}$(format_pattern_instruction "$pattern_json")"$'\n'
    done < <(jq -c '.entries[]? | select(.status == "approved")' "$catalog_path" 2>/dev/null || true)
  fi

  if [[ -n "$approved_lines" ]]; then
    echo ""
    echo "=== Active Pattern Instructions ==="
    printf '%s' "$approved_lines"
    echo "===================================="
  fi
}

# Priority 1: Project-level STATUS.md (universal pattern for any project)
if [[ -f "$PROJECT_ROOT/STATUS.md" ]]; then
  echo "=== Project Status ==="
  cat "$PROJECT_ROOT/STATUS.md"
  echo "======================"
# Priority 2: Ouroboros dev status (only within ouroboros project itself)
elif [[ -f "$PLUGIN_ROOT/dev/STATUS.md" ]] && [[ "$PROJECT_ROOT" == "$PLUGIN_ROOT" ]]; then
  echo "=== Ouroboros Dev Status ==="
  # Extract State + Immediate Next sections (skip Backlog for brevity)
  awk '/^## State:/{found=1} found{print} /^## Backlog/{exit}' "$PLUGIN_ROOT/dev/STATUS.md"
  echo "============================="
fi

# Recent activity (git-based session history)
if [[ -f "$PLUGIN_ROOT/scripts/session-history.sh" ]]; then
  ACTIVITY=$(bash "$PLUGIN_ROOT/scripts/session-history.sh" list --limit 5 2>/dev/null || true)
  if [[ -n "$ACTIVITY" ]]; then
    echo ""
    echo "=== Recent Activity ==="
    echo "$ACTIVITY"
    echo "======================="
  fi
fi

if [[ -f "$PLUGIN_ROOT/scripts/learning-lib.sh" ]] && command -v jq &>/dev/null; then
  # shellcheck source=/dev/null
  source "$PLUGIN_ROOT/scripts/learning-lib.sh"
  PROMISE_DIR="$(learning_promises_dir)"
  if [[ -d "$PROMISE_DIR" ]]; then
    PROMISE_SUMMARY="$(
      while IFS= read -r promise_file; do
        [[ -n "$promise_file" ]] || continue
        jq -r '
          select((.status // "") == "active" or (.status // "") == "interrupted") |
          [
            (.updated_at // .started_at // ""),
            (.promise_id // ""),
            (.target // ""),
            (.status // ""),
            ((.current_iteration // 0) | tostring),
            ((.max_iterations // 0) | tostring)
          ] | @tsv
        ' "$promise_file" 2>/dev/null || true
      done < <(find "$PROMISE_DIR" -maxdepth 1 -type f -name '*.json' | sort 2>/dev/null)
    )"

    if [[ -n "$PROMISE_SUMMARY" ]]; then
      echo ""
      echo "=== Ralph Promises ==="
      while IFS=$'\t' read -r updated_at promise_id target_name promise_status current_iteration max_iterations; do
        [[ -n "$promise_id" ]] || continue
        echo "- $promise_id [$promise_status]"
        echo "  target: $target_name"
        echo "  iterations: $current_iteration/$max_iterations (updated $updated_at)"
      done < <(printf '%s\n' "$PROMISE_SUMMARY" | sort -r)
      echo "======================"
    fi
  fi
fi

emit_suggestions

# Inject compact context if available (one-shot: read then delete)
COMPACT_CTX="$PROJECT_ROOT/.compact-context.md"
if [[ -f "$COMPACT_CTX" ]]; then
  echo ""
  echo "=== Conversation Context (restored) ==="
  cat "$COMPACT_CTX"
  echo "========================================"
  rm -f "$COMPACT_CTX"
fi

# --- PA Memory digest injection ---
# Inject the latest daily memory digest if a PA vault is configured.
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
  if [[ -n "$VAULT_ROOT" ]]; then
    MEMORY_DIR="$VAULT_ROOT/.pa/memory"
    DAILY_DIR="$MEMORY_DIR/daily"

    if [[ -d "$DAILY_DIR" ]]; then
      # Find the most recent daily digest
      LATEST_DIGEST=$(ls -1 "$DAILY_DIR"/*.md 2>/dev/null | sort -r | head -1 || true)
      if [[ -n "$LATEST_DIGEST" ]] && [[ -f "$LATEST_DIGEST" ]]; then
        echo ""
        echo "=== PA Memory ==="
        cat "$LATEST_DIGEST"

        # Also show recent long-term unactioned observations (max 3)
        OBS_FILE="$MEMORY_DIR/observations.jsonl"
        if [[ -f "$OBS_FILE" ]]; then
          RECENT=$(tail -50 "$OBS_FILE" | jq -r '
            select(.actioned == false and .kind != "mood-energy") |
            "- \(.signal) (\(.kind), \(.ts | split("T")[0]))"
          ' 2>/dev/null | tail -3 || true)
          if [[ -n "$RECENT" ]]; then
            echo ""
            echo "### Long-term Signals"
            echo "$RECENT"
          fi

          # Show unexpired mood-energy observations
          TODAY=$(date +%Y-%m-%d)
          MOOD=$(tail -20 "$OBS_FILE" | jq -r --arg today "$TODAY" '
            select(.kind == "mood-energy" and .actioned == false and (.expires == null or .expires >= $today)) |
            "- \(.signal) (expires \(.expires // "n/a"))"
          ' 2>/dev/null || true)
          if [[ -n "$MOOD" ]]; then
            echo ""
            echo "### Current Mood/Energy"
            echo "$MOOD"
          fi
        fi

        echo "=================="
      fi
    fi
  fi
fi

write_session_context() {
  local target_root=""
  local branch=""
  local uncommitted=""
  local subject=""
  local -a commit_subjects=()

  target_root="${PROJECT_ROOT:-}"
  if [[ -z "$target_root" ]]; then
    target_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  [[ -n "$target_root" ]] || return 0

  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [[ -n "$branch" ]] || return 0

  while IFS= read -r subject; do
    commit_subjects+=("${subject:0:80}")
  done < <(git log --oneline -3 --format='%s' 2>/dev/null || true)

  uncommitted="$(git status --porcelain 2>/dev/null | wc -l | tr -d '[:space:]' || printf '0')"

  {
    printf 'Branch: %s\n' "$branch"
    printf 'Commits:\n'
    for subject in "${commit_subjects[@]}"; do
      printf -- '- %s\n' "$subject"
    done
    printf 'Uncommitted: %s\n' "${uncommitted:-0}"
  } > "$target_root/.session-context.md" 2>/dev/null || return 0
}

write_session_context
exit 0
