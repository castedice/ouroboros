#!/usr/bin/env bash
# pa-feedback-analysis.sh - analyze assistant ledger feedback patterns for PA.
#
# Actions:
#   analyze [vault-path]
#   summary [vault-path]
#   preferences [vault-path]
#   context [--generate] [vault-path]
#   energy [vault-path]

set -euo pipefail

MINIMUM_FOR_PREFERENCES=30
MINIMUM_FOR_CONTEXT_PROFILES=20
MINIMUM_FOR_ENERGY=10
SUMMARY_TAG_LIMIT=5

VAULT_PATH=""
PA_DIR=""
LEDGER_PATH=""
PREFERENCES_PATH=""
CONTEXT_PROFILES_PATH=""
OBSERVATIONS_PATH=""
INTELLIGENCE_DIR=""
ENERGY_PATTERNS_PATH=""

usage() {
  cat <<'EOF'
pa-feedback-analysis.sh <action> [vault-path]

Actions:
  analyze [vault-path]      - Output feedback analysis JSON from .pa/assistant-ledger.jsonl
  summary [vault-path]      - Print a human-readable feedback summary
  preferences [vault-path]  - Generate proposed learned preferences in .pa/preferences-learned.json
  context [--generate] [vault-path] - Analyze context telemetry or generate proposed context profiles
  energy [vault-path]       - Aggregate mood-energy observations into .pa/intelligence/energy-patterns.json
EOF
}

known_state_files_json() {
  cat <<'EOF'
["settings.json","vault-profile.json","work.jsonl","timeline.jsonl","entities.json","relations.json","derivation-state.json","soul.md","persona.json","specialists.json","specialist-insights.jsonl","retrieval-profiles.json","memory/observations.jsonl","memory/.pending-flush.jsonl","personal-profile.json","review-state.json","mask-map.json","preferences-learned.json","context-profiles.json","intelligence/energy-patterns.json"]
EOF
}

skippable_state_files_json() {
  cat <<'EOF'
["work.jsonl","timeline.jsonl","entities.json","relations.json","derivation-state.json","soul.md","persona.json","specialists.json","specialist-insights.jsonl","retrieval-profiles.json","memory/observations.jsonl","memory/.pending-flush.jsonl","personal-profile.json","review-state.json","mask-map.json","preferences-learned.json","intelligence/energy-patterns.json"]
EOF
}

die_user() {
  echo "Error: $1" >&2
  exit 1
}

die_system() {
  echo "Error: $1" >&2
  exit 2
}

ensure_jq() {
  command -v jq >/dev/null 2>&1 || die_system "jq is required."
}

validate_json() {
  local path="$1"
  jq empty "$path" >/dev/null 2>&1 || die_system "Failed to parse JSON: $path"
}

expand_home_path() {
  local path="${1:-}"

  case "$path" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${path#\~/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

resolve_absolute_dir() {
  local path="$1"

  [[ -n "$path" ]] || die_user "vault path is required"
  [[ -d "$path" ]] || die_user "vault path is not a directory: $path"

  (
    cd "$path" && pwd -P
  ) || die_system "Failed to resolve vault path: $path"
}

detect_default_vault_path() {
  local env_path=""
  local collections=""
  local coll=""
  local vault_path=""
  local settings_path=""
  local vault_root=""

  if [[ -n "${PA_VAULT_PATH:-}" ]]; then
    env_path="$(expand_home_path "$PA_VAULT_PATH")"
    if [[ -d "$env_path" ]] && [[ -d "$env_path/.pa" ]]; then
      resolve_absolute_dir "$env_path"
      return
    fi
  fi

  if command -v qmd >/dev/null 2>&1; then
    collections=$(qmd collection list 2>/dev/null | sed -n 's/^\([a-zA-Z0-9_-]*\) (qmd:.*/\1/p' || true)
    for coll in $collections; do
      vault_path=$(qmd collection show "$coll" 2>/dev/null | awk '/Path:/{print $2}' || true)
      [[ -n "$vault_path" ]] || continue
      settings_path="$vault_path/.pa/settings.json"
      [[ -f "$settings_path" ]] || continue
      vault_root=$(jq -r '.vault_root // empty' "$settings_path" 2>/dev/null || true)
      if [[ -n "$vault_root" ]] && [[ -d "$vault_root/.pa" ]]; then
        resolve_absolute_dir "$vault_root"
        return
      fi
      if [[ -d "$vault_path/.pa" ]]; then
        resolve_absolute_dir "$vault_path"
        return
      fi
    done
  fi

  if [[ -d ".pa" || -d ".obsidian" ]]; then
    pwd -P
    return
  fi

  printf '\n'
}

resolve_vault_path() {
  local explicit_path="${1:-}"
  local detected_path=""

  if [[ -n "$explicit_path" ]]; then
    resolve_absolute_dir "$explicit_path"
    return
  fi

  detected_path="$(detect_default_vault_path)"
  [[ -n "$detected_path" ]] || die_user "vault path required. Set PA_VAULT_PATH, rely on QMD collection discovery, or run from the vault root."
  printf '%s\n' "$detected_path"
}

set_vault_context() {
  VAULT_PATH="$1"
  PA_DIR="$VAULT_PATH/.pa"
  LEDGER_PATH="$PA_DIR/assistant-ledger.jsonl"
  PREFERENCES_PATH="$PA_DIR/preferences-learned.json"
  CONTEXT_PROFILES_PATH="$PA_DIR/context-profiles.json"
  OBSERVATIONS_PATH="$PA_DIR/memory/observations.jsonl"
  INTELLIGENCE_DIR="$PA_DIR/intelligence"
  ENERGY_PATTERNS_PATH="$INTELLIGENCE_DIR/energy-patterns.json"
}

ensure_pa_root() {
  [[ -d "$PA_DIR" ]] || die_user ".pa directory not found: $PA_DIR"
}

iso_timestamp() {
  local ts
  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

collect_feedback_runs_json() {
  if [[ ! -f "$LEDGER_PATH" ]] || [[ ! -s "$LEDGER_PATH" ]]; then
    printf '[]\n'
    return
  fi

  jq -Rn '
    def normalized_feedback:
      if . == "accepted" or . == "rejected" or . == "modified" then . else null end;

    [
      inputs
      | select(length > 0)
      | fromjson?
      | select(type == "object")
      | select((.run_id // "") != "")
    ]
    | sort_by(.run_id, (.ts // ""), (.action // ""))
    | group_by(.run_id)
    | map(
        . as $group
        | ($group | map(select(.action != "feedback"))) as $events
        | ($group | map(select(.action == "feedback" and (((.user_feedback // "") | normalized_feedback) != null))) | last) as $feedback
        | if (($events | length) > 0 and ($feedback != null or (($events | map(select((.status // "") == "proposed")) | length) > 0))) then
            {
              run_id: ($group[0].run_id),
              command: (($events | map(.command // "") | map(select(length > 0)) | first) // ($feedback.command // "unknown")),
              actions: ($events | map(.action // "") | map(select(length > 0)) | unique),
              feedback: (if $feedback == null then null else (($feedback.user_feedback // "") | normalized_feedback) end),
              feedback_tags: (
                if $feedback == null then
                  []
                else
                  (($feedback.feedback_tags // []) | if type == "array" then map(tostring) else [] end)
                end
              )
            }
          else
            empty
          end
      )
  ' <"$LEDGER_PATH"
}

collect_context_runs_json() {
  if [[ ! -f "$LEDGER_PATH" ]] || [[ ! -s "$LEDGER_PATH" ]]; then
    printf '[]\n'
    return
  fi

  jq -Rn '
    def normalized_string_array:
      if type == "array" then map(tostring) else [] end;

    def numeric_context_chars:
      if type == "number" then .
      elif type == "string" then (tonumber? // empty)
      else empty
      end;

    [
      inputs
      | select(length > 0)
      | fromjson?
      | select(type == "object")
      | select((.run_id // "") != "")
      | select(.state_files_loaded != null or .state_files_used != null or .estimated_context_chars != null)
    ]
    | sort_by(.run_id, (.ts // ""), (.action // ""))
    | group_by(.run_id)
    | map(
        . as $group
        | {
            run_id: ($group[0].run_id),
            command: (($group | map(.command // "") | map(select(length > 0)) | first) // "unknown"),
            state_files_loaded: (
              [
                $group[]
                | (.state_files_loaded // [])
                | normalized_string_array
                | .[]
              ]
              | unique
            ),
            state_files_used: (
              [
                $group[]
                | (.state_files_used // [])
                | normalized_string_array
                | .[]
              ]
              | unique
            ),
            estimated_context_chars: (
              [
                $group[]
                | .estimated_context_chars?
                | numeric_context_chars
              ]
              | last? // null
            )
          }
      )
  ' <"$LEDGER_PATH"
}

collect_mood_energy_observations_json() {
  if [[ ! -f "$OBSERVATIONS_PATH" ]] || [[ ! -s "$OBSERVATIONS_PATH" ]]; then
    printf '[]\n'
    return
  fi

  jq -Rn '
    [
      inputs
      | select(length > 0)
      | fromjson?
      | select(type == "object")
      | select((.kind // "") == "mood-energy")
      | select((.ts // "") != "")
      | {
          ts: (.ts | tostring),
          signal: ((.signal // "") | tostring)
        }
    ]
  ' <"$OBSERVATIONS_PATH"
}

normalize_iso_offset() {
  local ts="$1"

  if [[ "$ts" == *Z ]]; then
    printf '%s\n' "${ts%Z}+0000"
    return
  fi

  printf '%s\n' "$ts" | sed -E 's/([+-][0-9]{2}):([0-9]{2})$/\1\2/'
}

parse_energy_timestamp() {
  local ts="$1"
  local normalized_ts=""

  normalized_ts="$(normalize_iso_offset "$ts")"
  date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized_ts" '+%A	%H	%Y-%m' 2>/dev/null || return 1
}

estimate_energy_score() {
  local signal="$1"

  case "$signal" in
    *번아웃*)
      printf '0.2\n'
      ;;
    *무기력*)
      printf '0.25\n'
      ;;
    *피곤*)
      printf '0.3\n'
      ;;
    *지침*)
      printf '0.35\n'
      ;;
    *집중*)
      printf '0.9\n'
      ;;
    *활력*)
      printf '0.85\n'
      ;;
    *의욕*)
      printf '0.8\n'
      ;;
    *좋음*)
      printf '0.7\n'
      ;;
    *)
      printf '0.5\n'
      ;;
  esac
}

build_analysis_json() {
  local analyzed_at="$1"

  jq \
    --arg analyzed_at "$analyzed_at" \
    --argjson minimum "$MINIMUM_FOR_PREFERENCES" \
    '
      def rate($accepted; $rejected; $modified):
        if ($accepted + $rejected + $modified) > 0 then
          ($accepted / ($accepted + $rejected + $modified))
        else
          0
        end;

      . as $runs
      | ($runs | length) as $total_proposals
      | ($runs | map(select(.feedback != null)) | length) as $total_feedback
      | {
          version: 1,
          analyzed_at: $analyzed_at,
          total_proposals: $total_proposals,
          total_feedback: $total_feedback,
          feedback_rate: (
            if $total_proposals > 0 then
              ($total_feedback / $total_proposals)
            else
              0
            end
          ),
          by_command: (
            $runs
            | group_by(.command)
            | map({
                key: .[0].command,
                value: (
                  {
                    proposals: length,
                    accepted: (map(select(.feedback == "accepted")) | length),
                    rejected: (map(select(.feedback == "rejected")) | length),
                    modified: (map(select(.feedback == "modified")) | length),
                    no_feedback: (map(select(.feedback == null)) | length)
                  }
                  | .acceptance_rate = rate(.accepted; .rejected; .modified)
                )
              })
            | from_entries
          ),
          by_action: (
            $runs
            | map(. as $run | $run.actions[]? | {action: ., feedback: $run.feedback})
            | group_by(.action)
            | map({
                key: .[0].action,
                value: {
                  accepted: (map(select(.feedback == "accepted")) | length),
                  rejected: (map(select(.feedback == "rejected")) | length),
                  rate: rate(
                    (map(select(.feedback == "accepted")) | length);
                    (map(select(.feedback == "rejected")) | length);
                    (map(select(.feedback == "modified")) | length)
                  )
                }
              })
            | from_entries
          ),
          by_tags: (
            $runs
            | map(.feedback_tags[]?)
            | group_by(.)
            | map({key: .[0], value: length})
            | from_entries
          ),
          sample_size_sufficient: ($total_feedback >= $minimum),
          minimum_for_preferences: $minimum
        }
    '
}

build_context_analysis_json() {
  local analyzed_at="$1"
  local known_state_files=""

  known_state_files="$(known_state_files_json)"

  jq \
    --arg analyzed_at "$analyzed_at" \
    --argjson minimum "$MINIMUM_FOR_CONTEXT_PROFILES" \
    --argjson known_state_files "$known_state_files" \
    '
      def context_summary($command_runs; $known):
        {
          always_loaded: (
            $known
            | map(. as $file | select(($command_runs | length) > 0 and ($command_runs | all(.state_files_loaded | index($file) != null))))
          ),
          sometimes_loaded: (
            $known
            | map(. as $file | select(($command_runs | any(.state_files_loaded | index($file) != null)) and (($command_runs | all(.state_files_loaded | index($file) != null)) | not)))
          ),
          never_loaded: (
            $known
            | map(. as $file | select((($command_runs | any(.state_files_loaded | index($file) != null)) | not)))
          ),
          always_used: (
            $known
            | map(. as $file | select(($command_runs | length) > 0 and ($command_runs | all(.state_files_used | index($file) != null))))
          ),
          sometimes_used: (
            $known
            | map(. as $file | select(($command_runs | any(.state_files_used | index($file) != null)) and (($command_runs | all(.state_files_used | index($file) != null)) | not)))
          ),
          avg_context_chars: (
            ($command_runs | map(.estimated_context_chars) | map(select(. != null))) as $chars
            | if ($chars | length) > 0 then
                (($chars | add) / ($chars | length) | round)
              else
                0
              end
          )
        };

      . as $runs
      | {
          version: 1,
          analyzed_at: $analyzed_at,
          total_runs: ($runs | length),
          minimum_for_profiles: $minimum,
          sample_size_sufficient: (($runs | length) >= $minimum),
          by_command: (
            $runs
            | group_by(.command)
            | map({
                key: .[0].command,
                value: context_summary(.; $known_state_files)
              })
            | from_entries
          )
        }
    '
}

build_rejection_tags_json() {
  jq '
    map(select(.feedback == "rejected" or .feedback == "modified"))
    | map(.feedback_tags[]?)
    | group_by(.)
    | map({tag: .[0], count: length})
    | sort_by(-.count, .tag)
  '
}

build_preference_candidates_json() {
  jq '
    def rate($accepted; $rejected; $modified):
      if ($accepted + $rejected + $modified) > 0 then
        ($accepted / ($accepted + $rejected + $modified))
      else
        0
      end;

    def top_rejection_tags($group):
      $group
      | map(select(.feedback == "rejected" or .feedback == "modified"))
      | map(.feedback_tags[]?)
      | group_by(.)
      | map({tag: .[0], count: length})
      | sort_by(-.count, .tag);

    group_by(.command)
    | map(
        . as $group
        | {
            command: .[0].command,
            accepted: (map(select(.feedback == "accepted")) | length),
            rejected: (map(select(.feedback == "rejected")) | length),
            modified: (map(select(.feedback == "modified")) | length),
            sample_size: (map(select(.feedback != null)) | length),
            rejection_tags: top_rejection_tags($group)
          }
        | .acceptance_rate = rate(.accepted; .rejected; .modified)
      )
    | map(select(.sample_size >= 10 and .acceptance_rate < 0.5))
    | map({
        kind: "frequency",
        scope: {command: .command},
        recommendation: (
          if (.rejection_tags[0].tag // "") == "too-many" then
            "Reduce " + .command + " suggestion count from default to top-3"
          elif (.rejection_tags[0].tag // "") == "wrong-target" then
            "Reduce " + .command + " proposal volume and narrow targeting before suggesting"
          elif (.rejection_tags[0].tag // "") == "not-now" then
            "Reduce " + .command + " proposal frequency unless timing is explicit"
          else
            "Reduce " + .command + " proposal volume and present a smaller default set"
          end
        ),
        evidence: {
          acceptance_rate: .acceptance_rate,
          sample_size: .sample_size,
          pattern: "repeated-rejection",
          top_tags: (.rejection_tags | map(.tag) | .[:3])
        }
      })
  '
}

build_preferences_json() {
  local generated_at="$1"
  local existing_path="$2"

  jq -n \
    --arg generated_at "$generated_at" \
    --slurpfile existing "$existing_path" \
    '
      def pref_id($n):
        "pref-" + (("000" + ($n | tostring))[-3:]);

      ($existing[0] // {version: 1, rules: []}) as $existing_doc
      | ($existing_doc.rules // []) as $existing_rules
      | input as $candidate_specs
      | ($existing_rules | map(select((.status // "") != "proposed"))) as $preserved_rules
      | ($preserved_rules | map(.scope.command // empty) | unique) as $preserved_commands
      | ($candidate_specs | map(select((.scope.command // "") as $command | ($preserved_commands | index($command) | not)))) as $new_specs
      | (
          [
            $preserved_rules[]?.id // ""
            | capture("^pref-(?<num>[0-9]+)$")?.num
            | tonumber?
          ]
          | max // 0
        ) as $max_existing_id
      | {
          version: 1,
          generated_at: $generated_at,
          rules: (
            $preserved_rules
            + (
              $new_specs
              | to_entries
              | map(
                  .value
                  + {
                      id: pref_id($max_existing_id + .key + 1),
                      status: "proposed",
                      approved_at: null,
                      reverted_at: null
                    }
                )
            )
          )
        }
    '
}

build_context_profiles_json() {
  local generated_at="$1"
  local existing_path="$2"
  local skippable_state_files=""

  skippable_state_files="$(skippable_state_files_json)"

  jq -n \
    --arg generated_at "$generated_at" \
    --argjson skippable_state_files "$skippable_state_files" \
    --slurpfile existing "$existing_path" \
    '
      def comparable_profile($profile):
        if $profile == null then
          null
        else
          {
            required_state: ($profile.required_state // []),
            optional_state: ($profile.optional_state // []),
            skip_if_empty: ($profile.skip_if_empty // []),
            max_qmd_docs: ($profile.max_qmd_docs // null),
            cache_policy: ($profile.cache_policy // null)
          }
        end;

      def proposal_from_summary($summary; $generated_at):
        (
          (($summary.always_used // []) | if length > 0 then . else ($summary.always_loaded // []) end) as $required
          | ((($summary.sometimes_used // []) + ($summary.sometimes_loaded // [])) | unique) as $optional_candidates
          | ($optional_candidates | map(select($required | index(.) | not))) as $optional
          | {
              status: "proposed",
              proposed_at: $generated_at,
              approved_at: null,
              reverted_at: null,
              required_state: $required,
              optional_state: $optional,
              skip_if_empty: ($optional | map(select($skippable_state_files | index(.) != null))),
              max_qmd_docs: (
                if (($summary.avg_context_chars // 0) >= 12000) then 3 else 4 end
              ),
              cache_policy: "session"
            }
        );

      ($existing[0] // {version: 1, profiles: {}, proposals: {}}) as $existing_doc
      | ($existing_doc.profiles // {}) as $profiles
      | input as $analysis
      | {
          version: 1,
          updated_at: $generated_at,
          profiles: $profiles,
          proposals: (
            $analysis.by_command
            | to_entries
            | map(
                .key as $command
                | .value as $summary
                | proposal_from_summary($summary; $generated_at) as $proposal
                | ($profiles[$command] // null) as $approved
                | if comparable_profile($approved) == comparable_profile($proposal) then
                    empty
                  else
                    {key: $command, value: $proposal}
                  end
              )
            | from_entries
          )
        }
    '
}

build_energy_patterns_json() {
  local aggregated_at="$1"
  local enriched_path="$2"

  jq -s \
    --arg last_aggregated "$aggregated_at" \
    --argjson minimum "$MINIMUM_FOR_ENERGY" \
    '
      def round_energy:
        ((. * 1000) | round) / 1000;

      def avg_energy($items):
        if ($items | length) > 0 then
          (($items | map(.energy_level) | add) / ($items | length) | round_energy)
        else
          null
        end;

      def top_signals($items; $limit):
        $items
        | group_by(.signal)
        | map({signal: .[0].signal, count: length})
        | sort_by(-.count, .signal)
        | map(.signal)
        | .[:$limit];

      . as $items
      | {
          version: 1,
          last_aggregated: $last_aggregated,
          observation_count: ($items | length),
          patterns: {
            day_of_week: (
              $items
              | group_by(.day_of_week)
              | map({
                  key: .[0].day_of_week,
                  value: {
                    avg_energy: avg_energy(.),
                    count: length,
                    common_signals: top_signals(.; 3)
                  }
                })
              | from_entries
            ),
            time_of_day: (
              $items
              | group_by(.time_of_day)
              | map({
                  key: .[0].time_of_day,
                  value: {
                    avg_energy: avg_energy(.),
                    count: length
                  }
                })
              | from_entries
            )
          },
          trends: (
            $items
            | group_by(.month)
            | map({
                period: .[0].month,
                avg_energy: avg_energy(.),
                dominant_signal: ((top_signals(.; 1) | .[0]) // null)
              })
            | sort_by(.period)
          ),
          minimum_observations: $minimum,
          sufficient: (($items | length) >= $minimum)
        }
    ' "$enriched_path"
}

action_analyze() {
  local analyzed_at=""
  local runs_json=""

  [[ $# -le 1 ]] || die_user "Usage: pa-feedback-analysis.sh analyze [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root

  analyzed_at="$(iso_timestamp)"
  runs_json="$(collect_feedback_runs_json)"

  printf '%s\n' "$runs_json" | build_analysis_json "$analyzed_at"
}

action_summary() {
  local analyzed_at=""
  local runs_json=""
  local analysis_json=""
  local analyzed_date=""
  local total_proposals=""
  local total_feedback=""
  local feedback_percent=""
  local minimum=""
  local sufficient=""
  local command_width=""
  local summary_line=""
  local rejection_tags_json=""

  [[ $# -le 1 ]] || die_user "Usage: pa-feedback-analysis.sh summary [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root

  analyzed_at="$(iso_timestamp)"
  runs_json="$(collect_feedback_runs_json)"
  analysis_json="$(printf '%s\n' "$runs_json" | build_analysis_json "$analyzed_at")"
  rejection_tags_json="$(printf '%s\n' "$runs_json" | build_rejection_tags_json)"

  analyzed_date="$(printf '%s\n' "$analysis_json" | jq -r '.analyzed_at | split("T")[0]')"
  total_proposals="$(printf '%s\n' "$analysis_json" | jq -r '.total_proposals')"
  total_feedback="$(printf '%s\n' "$analysis_json" | jq -r '.total_feedback')"
  feedback_percent="$(printf '%s\n' "$analysis_json" | jq -r '(.feedback_rate * 100) | round')"
  minimum="$(printf '%s\n' "$analysis_json" | jq -r '.minimum_for_preferences')"
  sufficient="$(printf '%s\n' "$analysis_json" | jq -r '.sample_size_sufficient')"
  command_width="$(printf '%s\n' "$analysis_json" | jq -r '(.by_command | keys | map(length) | max) // 0')"

  printf 'PA Feedback Analysis\n'
  printf 'Analyzed: %s\n' "$analyzed_date"
  printf 'Total proposals: %s (%s with feedback, %s%%)\n' "$total_proposals" "$total_feedback" "$feedback_percent"
  printf '\n'
  printf 'By Command:\n'

  if [[ "$(printf '%s\n' "$analysis_json" | jq '.by_command | length')" -eq 0 ]]; then
    printf '  none\n'
  else
    while IFS=$'\t' read -r command percent accepted proposals rejected modified no_feedback; do
      summary_line="$(printf '  %-'$command_width's: %s%% acceptance (%s/%s' "$command" "$percent" "$accepted" "$proposals")"
      if [[ "$rejected" -gt 0 ]]; then
        summary_line+=", $rejected rejected"
      fi
      if [[ "$modified" -gt 0 ]]; then
        summary_line+=", $modified modified"
      fi
      if [[ "$no_feedback" -gt 0 ]]; then
        summary_line+=", $no_feedback no feedback"
      fi
      summary_line+=")"
      printf '%s\n' "$summary_line"
    done < <(
      printf '%s\n' "$analysis_json" | jq -r '
        .by_command
        | to_entries[]
        | [
            .key,
            ((.value.acceptance_rate * 100) | round),
            .value.accepted,
            .value.proposals,
            .value.rejected,
            .value.modified,
            .value.no_feedback
          ]
        | @tsv
      '
    )
  fi

  printf '\n'
  printf 'Common rejection reasons:\n'
  if [[ "$(printf '%s\n' "$rejection_tags_json" | jq 'length')" -eq 0 ]]; then
    printf '  none\n'
  else
    printf '%s\n' "$rejection_tags_json" | jq -r --argjson limit "$SUMMARY_TAG_LIMIT" '
      .[:$limit]
      | .[]
      | "  \(.tag): \(.count) times"
    '
  fi

  printf '\n'
  if [[ "$sufficient" == "true" ]]; then
    printf 'Sample size: sufficient (%s/%s minimum)\n' "$total_feedback" "$minimum"
  else
    printf 'Sample size: insufficient (%s/%s minimum)\n' "$total_feedback" "$minimum"
  fi
}

action_preferences() {
  local generated_at=""
  local runs_json=""
  local analysis_json=""
  local total_feedback=""
  local sufficient=""
  local minimum=""
  local existing_path=""
  local tmp_file=""
  local candidate_specs_json=""
  local preferences_json=""

  [[ $# -le 1 ]] || die_user "Usage: pa-feedback-analysis.sh preferences [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root

  generated_at="$(iso_timestamp)"
  runs_json="$(collect_feedback_runs_json)"
  analysis_json="$(printf '%s\n' "$runs_json" | build_analysis_json "$generated_at")"
  total_feedback="$(printf '%s\n' "$analysis_json" | jq -r '.total_feedback')"
  sufficient="$(printf '%s\n' "$analysis_json" | jq -r '.sample_size_sufficient')"
  minimum="$(printf '%s\n' "$analysis_json" | jq -r '.minimum_for_preferences')"

  [[ "$sufficient" == "true" ]] || die_user "insufficient feedback sample for learned preferences: $total_feedback/$minimum"

  candidate_specs_json="$(printf '%s\n' "$runs_json" | build_preference_candidates_json)"

  existing_path="$(mktemp)"
  tmp_file="$(mktemp)"

  if [[ -f "$PREFERENCES_PATH" ]]; then
    validate_json "$PREFERENCES_PATH"
    cp "$PREFERENCES_PATH" "$existing_path" || {
      rm -f "$existing_path" "$tmp_file"
      die_system "Failed to read existing preferences: $PREFERENCES_PATH"
    }
  else
    printf '{\"version\":1,\"generated_at\":null,\"rules\":[]}\n' >"$existing_path" || {
      rm -f "$existing_path" "$tmp_file"
      die_system "Failed to initialize temporary preferences state"
    }
  fi

  preferences_json="$(printf '%s\n' "$candidate_specs_json" | build_preferences_json "$generated_at" "$existing_path")"

  printf '%s\n' "$preferences_json" >"$tmp_file" || {
    rm -f "$existing_path" "$tmp_file"
    die_system "Failed to write temporary preferences output"
  }

  mv "$tmp_file" "$PREFERENCES_PATH" || {
    rm -f "$existing_path" "$tmp_file"
    die_system "Failed to write learned preferences: $PREFERENCES_PATH"
  }

  rm -f "$existing_path"
  printf '%s\n' "$preferences_json"
}

action_context() {
  local generate="false"
  local explicit_path=""
  local analyzed_at=""
  local runs_json=""
  local analysis_json=""
  local total_runs=""
  local sufficient=""
  local minimum=""
  local existing_path=""
  local tmp_file=""
  local context_profiles_json=""

  case $# in
    0)
      ;;
    1)
      if [[ "$1" == "--generate" ]]; then
        generate="true"
      else
        explicit_path="$1"
      fi
      ;;
    2)
      [[ "$1" == "--generate" ]] || die_user "Usage: pa-feedback-analysis.sh context [--generate] [vault-path]"
      generate="true"
      explicit_path="$2"
      ;;
    *)
      die_user "Usage: pa-feedback-analysis.sh context [--generate] [vault-path]"
      ;;
  esac

  ensure_jq
  set_vault_context "$(resolve_vault_path "$explicit_path")"
  ensure_pa_root

  analyzed_at="$(iso_timestamp)"
  runs_json="$(collect_context_runs_json)"
  analysis_json="$(printf '%s\n' "$runs_json" | build_context_analysis_json "$analyzed_at")"

  if [[ "$generate" != "true" ]]; then
    printf '%s\n' "$analysis_json"
    return
  fi

  total_runs="$(printf '%s\n' "$analysis_json" | jq -r '.total_runs')"
  sufficient="$(printf '%s\n' "$analysis_json" | jq -r '.sample_size_sufficient')"
  minimum="$(printf '%s\n' "$analysis_json" | jq -r '.minimum_for_profiles')"

  [[ "$sufficient" == "true" ]] || die_user "insufficient context telemetry sample for context profiles: $total_runs/$minimum"

  existing_path="$(mktemp)"
  tmp_file="$(mktemp)"

  if [[ -f "$CONTEXT_PROFILES_PATH" ]]; then
    validate_json "$CONTEXT_PROFILES_PATH"
    cp "$CONTEXT_PROFILES_PATH" "$existing_path" || {
      rm -f "$existing_path" "$tmp_file"
      die_system "Failed to read existing context profiles: $CONTEXT_PROFILES_PATH"
    }
  else
    printf '{\"version\":1,\"updated_at\":null,\"profiles\":{},\"proposals\":{}}\n' >"$existing_path" || {
      rm -f "$existing_path" "$tmp_file"
      die_system "Failed to initialize temporary context profile state"
    }
  fi

  context_profiles_json="$(printf '%s\n' "$analysis_json" | build_context_profiles_json "$analyzed_at" "$existing_path")"

  printf '%s\n' "$context_profiles_json" >"$tmp_file" || {
    rm -f "$existing_path" "$tmp_file"
    die_system "Failed to write temporary context profile output"
  }

  mv "$tmp_file" "$CONTEXT_PROFILES_PATH" || {
    rm -f "$existing_path" "$tmp_file"
    die_system "Failed to write context profiles: $CONTEXT_PROFILES_PATH"
  }

  rm -f "$existing_path"
  printf '%s\n' "$context_profiles_json"
}

action_energy() {
  local aggregated_at=""
  local observations_json=""
  local enriched_file=""
  local tmp_file=""
  local patterns_json=""
  local row=""
  local ts=""
  local signal=""
  local timestamp_parts=""
  local day_of_week=""
  local hour=""
  local month=""
  local time_of_day=""
  local energy_score=""

  [[ $# -le 1 ]] || die_user "Usage: pa-feedback-analysis.sh energy [vault-path]"

  ensure_jq
  set_vault_context "$(resolve_vault_path "${1:-}")"
  ensure_pa_root

  aggregated_at="$(iso_timestamp)"
  observations_json="$(collect_mood_energy_observations_json)"
  enriched_file="$(mktemp)"
  tmp_file="$(mktemp)"

  while IFS= read -r row; do
    ts="$(printf '%s\n' "$row" | jq -r '.ts')"
    signal="$(printf '%s\n' "$row" | jq -r '.signal')"
    timestamp_parts="$(parse_energy_timestamp "$ts" || true)"

    [[ -n "$timestamp_parts" ]] || continue

    IFS=$'\t' read -r day_of_week hour month <<<"$timestamp_parts"
    day_of_week="$(printf '%s\n' "$day_of_week" | tr '[:upper:]' '[:lower:]')"

    if (( 10#$hour >= 5 && 10#$hour < 12 )); then
      time_of_day="morning"
    elif (( 10#$hour >= 12 && 10#$hour < 18 )); then
      time_of_day="afternoon"
    else
      time_of_day="evening"
    fi

    energy_score="$(estimate_energy_score "$signal")"

    jq -cn \
      --arg ts "$ts" \
      --arg signal "$signal" \
      --arg day_of_week "$day_of_week" \
      --arg time_of_day "$time_of_day" \
      --arg month "$month" \
      --argjson energy_level "$energy_score" \
      '{
        ts: $ts,
        signal: $signal,
        day_of_week: $day_of_week,
        time_of_day: $time_of_day,
        month: $month,
        energy_level: $energy_level
      }' >>"$enriched_file" || {
      rm -f "$enriched_file" "$tmp_file"
      die_system "Failed to build energy observation records"
    }
    printf '\n' >>"$enriched_file"
  done < <(printf '%s\n' "$observations_json" | jq -c '.[]')

  patterns_json="$(build_energy_patterns_json "$aggregated_at" "$enriched_file")"

  mkdir -p "$INTELLIGENCE_DIR" || {
    rm -f "$enriched_file" "$tmp_file"
    die_system "Failed to create intelligence directory: $INTELLIGENCE_DIR"
  }

  printf '%s\n' "$patterns_json" >"$tmp_file" || {
    rm -f "$enriched_file" "$tmp_file"
    die_system "Failed to write temporary energy patterns output"
  }

  mv "$tmp_file" "$ENERGY_PATTERNS_PATH" || {
    rm -f "$enriched_file" "$tmp_file"
    die_system "Failed to write energy patterns: $ENERGY_PATTERNS_PATH"
  }

  rm -f "$enriched_file"
  printf '%s\n' "$patterns_json"
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  analyze)
    action_analyze "$@"
    ;;
  summary)
    action_summary "$@"
    ;;
  preferences)
    action_preferences "$@"
    ;;
  context)
    action_context "$@"
    ;;
  energy)
    action_energy "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die_user "Unknown action: $ACTION"
    ;;
esac
