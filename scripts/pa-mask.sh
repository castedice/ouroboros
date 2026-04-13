#!/usr/bin/env bash
# Privacy masking utility — project-local .pa/mask-map.json
#
# Actions:
#   mask <text>                               — replace registered names with mask IDs
#   mask-entity <text>                        — replace registered names with mask_id(safe_name)
#   unmask <text>                             — replace mask IDs with real names
#   pii <text>                                — replace Tier 1 PII with sequential tokens
#   add <name> [options]                      — register a new privacy mapping
#   list [--reveal]                           — show current mappings
#   forget <mask_id>                          — cascade erase a privacy node
#   hash-index                                — regenerate .pa/hash-index.json
#
# Common flags for mask and mask-entity:
#   --strip-private                           — strip HTML comments
#   --pii                                     — replace Tier 1 PII with tokens
#   --generalize                              — generalize amounts, dates, and ages
#   --full                                    — apply strip-private -> pii -> mask-entity -> generalize
#
# Usage:
#   bash scripts/pa-mask.sh mask "Talk to Kim tomorrow"
#   bash scripts/pa-mask.sh mask-entity "삼성전자 AI팀"
#   bash scripts/pa-mask.sh pii "010-1234-5678 / user@example.com"
#   bash scripts/pa-mask.sh add "Kim" --aliases "김민준,MJ"
#   bash scripts/pa-mask.sh add "삼성전자" --kind org --safe-name "대기업 기술팀"
#   bash scripts/pa-mask.sh forget ORG_A

set -euo pipefail

MASK_MAP_PATH=""
FLAG_PII="false"
FLAG_STRIP_PRIVATE="false"
FLAG_GENERALIZE="false"
FLAG_FULL="false"
TRANSFORM_TEXT=""

usage() {
  cat <<'EOF'
pa-mask.sh <action> [args]

Actions:
  mask <text>                               — Replace registered names with mask IDs
  mask-entity <text>                        — Replace registered names with mask_id(safe_name)
  unmask <text>                             — Replace mask IDs with real names
  pii <text>                                — Replace Tier 1 PII with sequential tokens
  add <name> [--aliases "a,b"] [--kind <kind>] [--safe-name "<text>"]
                                           — Register a new privacy mapping
  list [--reveal]                           — Show current mappings
  forget <mask_id>                          — Cascade erase one privacy node
  hash-index                                — Regenerate .pa/hash-index.json

Kinds:
  person | org | place | edu | project

Flags for mask and mask-entity:
  --strip-private                           — Strip HTML comments
  --pii                                     — Replace phone/email/SSN/account with tokens
  --generalize                              — Generalize amounts, dates, and ages
  --full                                    — Apply strip-private -> pii -> mask-entity -> generalize
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

today_date() {
  date "+%Y-%m-%d"
}

timestamp_now() {
  date "+%Y-%m-%dT%H:%M:%S%z"
}

resolve_existing_mask_map() {
  if [[ -f ".pa/mask-map.json" ]]; then
    MASK_MAP_PATH=".pa/mask-map.json"
    return
  fi

  if [[ -n "${PA_VAULT_PATH:-}" ]] && [[ -f "$PA_VAULT_PATH/.pa/mask-map.json" ]]; then
    MASK_MAP_PATH="$PA_VAULT_PATH/.pa/mask-map.json"
    return
  fi

  die_user "mask-map.json not found in .pa/ or \$PA_VAULT_PATH/.pa/"
}

resolve_mask_map_for_add() {
  if [[ -f ".pa/mask-map.json" ]]; then
    MASK_MAP_PATH=".pa/mask-map.json"
    return
  fi

  if [[ -n "${PA_VAULT_PATH:-}" ]] && [[ -f "$PA_VAULT_PATH/.pa/mask-map.json" ]]; then
    MASK_MAP_PATH="$PA_VAULT_PATH/.pa/mask-map.json"
    return
  fi

  MASK_MAP_PATH=".pa/mask-map.json"
}

resolve_mask_map_if_present() {
  MASK_MAP_PATH=""

  if [[ -f ".pa/mask-map.json" ]]; then
    MASK_MAP_PATH=".pa/mask-map.json"
    return
  fi

  if [[ -n "${PA_VAULT_PATH:-}" ]] && [[ -f "$PA_VAULT_PATH/.pa/mask-map.json" ]]; then
    MASK_MAP_PATH="$PA_VAULT_PATH/.pa/mask-map.json"
  fi
}

ensure_mask_map_initialized() {
  local path="$1"

  if [[ -f "$path" ]]; then
    validate_json "$path"
    return
  fi

  mkdir -p "$(dirname "$path")"
  cat >"$path" <<'EOF'
{
  "version": 2,
  "next_ids": {
    "person": 1,
    "org": 1,
    "place": 1,
    "edu": 1,
    "project": 1
  },
  "entries": []
}
EOF
}

normalize_kind() {
  local kind="${1:-person}"

  case "$kind" in
    person | org | place | edu | project)
      printf '%s\n' "$kind"
      ;;
    *)
      die_user "invalid kind: $kind"
      ;;
  esac
}

kind_prefix() {
  local kind="$1"

  case "$kind" in
    person)
      printf 'Person_'
      ;;
    org)
      printf 'ORG_'
      ;;
    place)
      printf 'PLACE_'
      ;;
    edu)
      printf 'EDU_'
      ;;
    project)
      printf 'PROJ_'
      ;;
    *)
      die_system "unknown kind prefix: $kind"
      ;;
  esac
}

hash_name() {
  printf '%s' "$1" | shasum -a 256 | cut -c1-8
}

split_aliases_json() {
  local aliases_csv="$1"

  if [[ -z "$aliases_csv" ]]; then
    printf '[]'
    return
  fi

  printf '%s\n' "$aliases_csv" |
    tr ',' '\n' |
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//' |
    awk 'NF > 0' |
    jq -R . |
    jq -s .
}

build_name_hashes_json() {
  local real_name="$1"
  local aliases_json="$2"

  {
    printf '%s\n' "$real_name"
    jq -r '.[]' <<<"$aliases_json"
  } |
    awk 'NF > 0 && !seen[$0]++' |
    while IFS= read -r name; do
      hash_name "$name"
    done |
    jq -R . |
    jq -s .
}

ensure_mask_map_v2() {
  local path="$1"
  local tmp_file

  validate_json "$path"

  tmp_file=$(mktemp)
  jq '
    .version = 2
    | .next_ids = {
        person: (.next_ids.person // .next_id // 1),
        org: (.next_ids.org // 1),
        place: (.next_ids.place // 1),
        edu: (.next_ids.edu // 1),
        project: (.next_ids.project // 1)
      }
    | .entries = ((.entries // []) | map(. + {kind: (.kind // "person")}))
    | del(.next_id)
  ' "$path" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to normalize mask-map schema: $path"
  }
  mv "$tmp_file" "$path"

  local entry_count
  entry_count=$(jq '.entries | length' "$path") || die_system "Failed to count entries in $path"

  local index
  for ((index = 0; index < entry_count; index++)); do
    local has_hashes
    has_hashes=$(jq -r ".entries[$index].name_hashes | if type == \"array\" and length > 0 then \"true\" else \"false\" end" "$path") || die_system "Failed to inspect entry hashes in $path"

    if [[ "$has_hashes" == "true" ]]; then
      continue
    fi

    local real_name
    local aliases_json
    local hashes_json

    real_name=$(jq -r ".entries[$index].real_name" "$path") || die_system "Failed to read entry name from $path"
    aliases_json=$(jq -c ".entries[$index].aliases // []" "$path") || die_system "Failed to read entry aliases from $path"
    hashes_json=$(build_name_hashes_json "$real_name" "$aliases_json")

    tmp_file=$(mktemp)
    jq --argjson hashes "$hashes_json" ".entries[$index].name_hashes = \$hashes" "$path" >"$tmp_file" || {
      rm -f "$tmp_file"
      die_system "Failed to backfill entry hashes in $path"
    }
    mv "$tmp_file" "$path"
  done
}

mask_id_from_number() {
  local prefix="$1"
  local number="$2"
  local suffix=""

  while ((number > 0)); do
    local remainder=$(((number - 1) % 26))
    local letter
    printf -v letter "\\$(printf '%03o' $((65 + remainder)))"
    suffix="${letter}${suffix}"
    number=$(((number - 1) / 26))
  done

  printf "%s%s" "$prefix" "$suffix"
}

apply_boundary_replace() {
  local text="$1"
  local from="$2"
  local to="$3"

  TARGET="$from" REPLACEMENT="$to" perl -CSDA -MEncode=decode -0pe '
    BEGIN {
      $from = decode("UTF-8", $ENV{"TARGET"});
      $to = decode("UTF-8", $ENV{"REPLACEMENT"});
    }
    # ASCII-only boundaries intentionally preserve directly attached Korean particles.
    s/(?<![A-Za-z0-9_])\Q$from\E(?![A-Za-z0-9_])/$to/g;
  ' <<<"$text"
}

parse_text_flags() {
  FLAG_PII="false"
  FLAG_STRIP_PRIVATE="false"
  FLAG_GENERALIZE="false"
  FLAG_FULL="false"
  TRANSFORM_TEXT=""

  local text_parts=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pii)
        FLAG_PII="true"
        ;;
      --strip-private)
        FLAG_STRIP_PRIVATE="true"
        ;;
      --generalize)
        FLAG_GENERALIZE="true"
        ;;
      --full)
        FLAG_FULL="true"
        ;;
      --)
        shift
        text_parts+=("$@")
        break
        ;;
      *)
        text_parts+=("$1")
        ;;
    esac
    shift || true
  done

  TRANSFORM_TEXT="${text_parts[*]:-}"
}

read_text_or_stdin() {
  if [[ $# -gt 0 ]]; then
    printf '%s' "$*"
  else
    cat
  fi
}

transform_strip_private() {
  perl -0pe 's/<!--.*?-->//gs' <<<"$1"
}

transform_pii() {
  perl -CSDA -0pe '
    BEGIN {
      %counts = (
        EMAIL => 0,
        SSN => 0,
        PHONE => 0,
        ACCOUNT => 0
      );
    }

    s{
      (?<![A-Za-z0-9._%+-])
      [A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}
      (?![A-Za-z0-9._%+-])
    }{"[EMAIL_" . ++$counts{EMAIL} . "]"}gex;

    s{(?<!\d)\d{6}-\d{7}(?!\d)}{"[SSN_" . ++$counts{SSN} . "]"}gex;
    s{(?<!\d)(?:010-\d{4}-\d{4}|010\d{8}|02-\d{3,4}-\d{4})(?!\d)}{"[PHONE_" . ++$counts{PHONE} . "]"}gex;
    s{(?<!\d)\d{3}-\d{2,6}-\d{2,6}(?!\d)}{"[ACCOUNT_" . ++$counts{ACCOUNT} . "]"}gex;
  ' <<<"$1"
}

transform_generalize() {
  perl -CSDA -MEncode=decode -0pe '
    use utf8;

    sub has_batchim {
      my ($str) = @_;
      return 0 unless length($str);
      my $last = ord(substr($str, -1, 1));
      return 0 if $last < 0xAC00 || $last > 0xD7A3;
      return (($last - 0xAC00) % 28) != 0 ? 1 : 0;
    }

    sub fix_particle {
      my ($repl, $p) = @_;
      return "" unless defined $p && length($p);
      my $h = has_batchim($repl);
      my %m = ("을",$h?"을":"를", "를",$h?"을":"를", "이",$h?"이":"가", "가",$h?"이":"가", "은",$h?"은":"는", "는",$h?"은":"는", "과",$h?"과":"와", "와",$h?"과":"와", "으로",$h?"으로":"로", "로",$h?"으로":"로");
      return exists $m{$p} ? $m{$p} : $p;
    }

    sub amount_bucket {
      my ($won) = @_;
      return "소액" if $won < 10000000;
      return "중간" if $won < 50000000;
      return "중상위" if $won < 100000000;
      return "고액" if $won < 1000000000;
      return "초고액";
    }

    sub amount_to_won {
      my ($expr) = @_;
      my $total = 0;

      $expr =~ s/\s+//g;
      $expr =~ s/원$//;

      while (length $expr) {
        if ($expr =~ s/^(\d+)억//) {
          $total += $1 * 100000000;
          next;
        }
        if ($expr =~ s/^(\d+)천만//) {
          $total += $1 * 10000000;
          next;
        }
        if ($expr =~ s/^(\d+)백만//) {
          $total += $1 * 1000000;
          next;
        }
        if ($expr =~ s/^(\d+)만//) {
          $total += $1 * 10000;
          next;
        }
        if ($expr =~ s/^(\d+)천//) {
          $total += $1 * 1000;
          next;
        }
        if ($expr =~ s/^(\d+)원//) {
          $total += $1;
          next;
        }
        if ($expr =~ s/^(\d+)$//) {
          $total += $1;
          last;
        }
        return undef;
      }

      return $total;
    }

    s{(?<!\d)((?:\d+원|(?:\d+(?:억|천만|백만|만|천))+원?))(을|를|이|가|은|는|과|와|으로|로)?(?!\d)}{
      my $won = amount_to_won($1);
      my $particle = $2 // "";
      if (defined $won) {
        my $b = amount_bucket($won);
        $b . fix_particle($b, $particle);
      } else {
        $& ;
      }
    }gex;

    s{(?<!\d)(\d{4})-(\d{2})-\d{2}(?!\d)}{$1 . "-" . $2}gex;
    s{(?<!\d)(\d{1,3})(살|세)(을|를|이|가|은|는|과|와|으로|로)?}{
      my $decade = int($1 / 10) * 10 . "대";
      my $particle = $3 // "";
      $decade . fix_particle($decade, $particle);
    }gex;
  ' <<<"$1"
}

mask_text_core() {
  local text="$1"

  if [[ -z "$MASK_MAP_PATH" ]]; then
    resolve_mask_map_if_present
  fi

  if [[ -z "$MASK_MAP_PATH" ]]; then
    printf '%s\n' "$text"
    return
  fi

  validate_json "$MASK_MAP_PATH"

  while IFS=$'\t' read -r target mask_id; do
    [[ -n "$target" ]] || continue
    text=$(apply_boundary_replace "$text" "$target" "$mask_id")
  done < <(
    jq -r '
      [
        .entries[] as $entry
        | {target: $entry.real_name, replacement: $entry.mask_id},
          (($entry.aliases // [])[] | {target: ., replacement: $entry.mask_id})
      ]
      | sort_by(.target | length)
      | reverse[]
      | [.target, .replacement]
      | @tsv
    ' "$MASK_MAP_PATH"
  )

  printf '%s\n' "$text"
}

mask_entity_text_core() {
  local text="$1"

  if [[ -z "$MASK_MAP_PATH" ]]; then
    resolve_mask_map_if_present
  fi

  if [[ -z "$MASK_MAP_PATH" ]]; then
    printf '%s\n' "$text"
    return
  fi

  validate_json "$MASK_MAP_PATH"

  while IFS=$'\t' read -r target replacement; do
    [[ -n "$target" ]] || continue
    text=$(apply_boundary_replace "$text" "$target" "$replacement")
  done < <(
    jq -r '
      [
        .entries[] as $entry
        | ($entry.mask_id + (if ($entry.safe_name // "") != "" then "(" + $entry.safe_name + ")" else "" end)) as $replacement
        | {target: $entry.real_name, replacement: $replacement},
          (($entry.aliases // [])[] | {target: ., replacement: $replacement})
      ]
      | sort_by(.target | length)
      | reverse[]
      | [.target, .replacement]
      | @tsv
    ' "$MASK_MAP_PATH"
  )

  printf '%s\n' "$text"
}

unmask_text_core() {
  local text="$1"

  if [[ -z "$MASK_MAP_PATH" ]]; then
    resolve_mask_map_if_present
  fi

  [[ -n "$MASK_MAP_PATH" ]] || die_user "mask-map.json not found in .pa/ or \$PA_VAULT_PATH/.pa/"
  validate_json "$MASK_MAP_PATH"

  # Pass 1: Replace composite forms MASK_ID(safe_name) → real_name
  # Must run before bare mask_id replacement to avoid partial matches
  while IFS=$'\t' read -r mask_id safe_name real_name; do
    [[ -n "$mask_id" ]] || continue
    [[ -n "$safe_name" ]] || continue
    local composite="${mask_id}(${safe_name})"
    text=$(apply_boundary_replace "$text" "$composite" "$real_name")
  done < <(
    jq -r '
      .entries
      | map(select(.safe_name != null and .safe_name != ""))
      | sort_by(.mask_id | length)
      | reverse[]
      | [.mask_id, .safe_name, .real_name]
      | @tsv
    ' "$MASK_MAP_PATH"
  )

  # Pass 2: Replace bare mask_id → real_name (longest first)
  while IFS=$'\t' read -r mask_id real_name; do
    [[ -n "$mask_id" ]] || continue
    text=$(apply_boundary_replace "$text" "$mask_id" "$real_name")
  done < <(
    jq -r '
      .entries
      | sort_by(.mask_id | length)
      | reverse[]
      | [.mask_id, .real_name]
      | @tsv
    ' "$MASK_MAP_PATH"
  )

  printf '%s\n' "$text"
}

run_text_pipeline() {
  local base_mode="$1"
  local text="$2"

  if [[ "$FLAG_FULL" == "true" ]]; then
    text=$(transform_strip_private "$text")
    text=$(transform_pii "$text")
    text=$(mask_entity_text_core "$text")
    text=$(transform_generalize "$text")
    printf '%s\n' "$text"
    return
  fi

  if [[ "$FLAG_STRIP_PRIVATE" == "true" ]]; then
    text=$(transform_strip_private "$text")
  fi

  if [[ "$FLAG_PII" == "true" || "$base_mode" == "pii" ]]; then
    text=$(transform_pii "$text")
  fi

  case "$base_mode" in
    mask)
      text=$(mask_text_core "$text")
      ;;
    mask-entity)
      text=$(mask_entity_text_core "$text")
      ;;
    pii) ;;
    *)
      die_system "unknown pipeline base mode: $base_mode"
      ;;
  esac

  if [[ "$FLAG_GENERALIZE" == "true" ]]; then
    text=$(transform_generalize "$text")
  fi

  printf '%s\n' "$text"
}

regenerate_hash_index() {
  local pa_dir="$1"
  local hash_index_path="$pa_dir/hash-index.json"
  local tmp_file

  tmp_file=$(mktemp)
  jq '
    reduce .entries[]? as $entry (
      {};
      reduce ($entry.name_hashes // [])[] as $hash (
        .;
        .[$hash] = ((.[$hash] // []) + [$entry.mask_id] | unique)
      )
    )
  ' "$MASK_MAP_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to regenerate hash index from $MASK_MAP_PATH"
  }

  mv "$tmp_file" "$hash_index_path"
}

rewrite_json_file() {
  local path="$1"
  local filter="$2"
  local tmp_file
  shift 2

  tmp_file=$(mktemp)
  jq "$@" "$filter" "$path" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update JSON file: $path"
  }
  mv "$tmp_file" "$path"
}

# ─── Action: mask ───

action_mask() {
  ensure_jq
  resolve_existing_mask_map
  parse_text_flags "$@"
  [[ -n "$TRANSFORM_TEXT" ]] || die_user "text required. Usage: pa-mask.sh mask <text>"
  run_text_pipeline "mask" "$TRANSFORM_TEXT"
}

# ─── Action: mask-entity ───

action_mask_entity() {
  ensure_jq
  resolve_existing_mask_map
  parse_text_flags "$@"
  [[ -n "$TRANSFORM_TEXT" ]] || die_user "text required. Usage: pa-mask.sh mask-entity <text>"
  run_text_pipeline "mask-entity" "$TRANSFORM_TEXT"
}

# ─── Action: unmask ───

action_unmask() {
  ensure_jq
  resolve_existing_mask_map
  local text="${*:-}"

  [[ -n "$text" ]] || die_user "text required. Usage: pa-mask.sh unmask <text>"
  unmask_text_core "$text"
}

# ─── Action: pii ───

action_pii() {
  ensure_jq
  parse_text_flags "$@"
  [[ -n "$TRANSFORM_TEXT" ]] || die_user "text required. Usage: pa-mask.sh pii <text>"
  run_text_pipeline "pii" "$TRANSFORM_TEXT"
}

action_filter_strip_private() {
  local text

  text=$(read_text_or_stdin "$@")
  printf '%s\n' "$(transform_strip_private "$text")"
}

action_filter_pii() {
  local text

  text=$(read_text_or_stdin "$@")
  printf '%s\n' "$(transform_pii "$text")"
}

action_filter_generalize() {
  local text

  text=$(read_text_or_stdin "$@")
  printf '%s\n' "$(transform_generalize "$text")"
}

action_filter_full() {
  local text

  ensure_jq
  resolve_mask_map_if_present
  if [[ -n "$MASK_MAP_PATH" ]]; then
    validate_json "$MASK_MAP_PATH"
  fi

  FLAG_PII="false"
  FLAG_STRIP_PRIVATE="false"
  FLAG_GENERALIZE="false"
  FLAG_FULL="true"
  text=$(read_text_or_stdin "$@")
  run_text_pipeline "mask-entity" "$text"
}

# ─── Action: add ───

action_add() {
  ensure_jq

  local real_name="${1:-}"
  local aliases_csv=""
  local kind="person"
  local safe_name=""

  [[ -n "$real_name" ]] || die_user "name required. Usage: pa-mask.sh add <name> [--aliases \"a,b\"] [--kind <kind>] [--safe-name \"<text>\"]"
  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --aliases)
        shift
        aliases_csv="${1:-}"
        [[ -n "$aliases_csv" ]] || die_user "--aliases requires a comma-separated value"
        ;;
      --kind)
        shift
        kind=$(normalize_kind "${1:-}")
        ;;
      --safe-name)
        shift
        safe_name="${1:-}"
        [[ -n "$safe_name" ]] || die_user "--safe-name requires a value"
        ;;
      *)
        die_user "unknown argument for add: $1"
        ;;
    esac
    shift || true
  done

  resolve_mask_map_for_add
  ensure_mask_map_initialized "$MASK_MAP_PATH"
  ensure_mask_map_v2 "$MASK_MAP_PATH"

  local duplicate_count
  duplicate_count=$(jq -r --arg real_name "$real_name" '
    [.entries[] | select(.real_name == $real_name)] | length
  ' "$MASK_MAP_PATH")

  if [[ "$duplicate_count" != "0" ]]; then
    die_user "duplicate name: $real_name"
  fi

  local next_id
  next_id=$(jq -r --arg kind "$kind" '.next_ids[$kind]' "$MASK_MAP_PATH") || die_system "Failed to read next_id from $MASK_MAP_PATH"

  [[ "$next_id" =~ ^[0-9]+$ ]] || die_system "next_ids.$kind must be numeric in $MASK_MAP_PATH"

  local prefix
  local mask_id
  local aliases_json
  local hashes_json
  local tmp_file

  prefix=$(kind_prefix "$kind")
  mask_id=$(mask_id_from_number "$prefix" "$next_id")
  aliases_json=$(split_aliases_json "$aliases_csv")
  hashes_json=$(build_name_hashes_json "$real_name" "$aliases_json")
  tmp_file=$(mktemp)

  jq \
    --arg real_name "$real_name" \
    --arg mask_id "$mask_id" \
    --arg created "$(today_date)" \
    --arg kind "$kind" \
    --arg safe_name "$safe_name" \
    --argjson aliases "$aliases_json" \
    --argjson name_hashes "$hashes_json" \
    '
      .entries += [{
        real_name: $real_name,
        aliases: $aliases,
        mask_id: $mask_id,
        safe_name: (if $safe_name == "" then null else $safe_name end),
        kind: $kind,
        name_hashes: $name_hashes,
        created: $created
      }]
      | .next_ids[$kind] += 1
    ' "$MASK_MAP_PATH" >"$tmp_file" || {
    rm -f "$tmp_file"
    die_system "Failed to update $MASK_MAP_PATH"
  }

  mv "$tmp_file" "$MASK_MAP_PATH"

  local pa_dir
  pa_dir=$(dirname "$MASK_MAP_PATH")

  if [[ "$kind" == "person" ]]; then
    local profile_dir="$pa_dir/people/profiles"
    local profile_path="$profile_dir/$mask_id.json"

    mkdir -p "$profile_dir"

    jq -n \
      --arg mask_id "$mask_id" \
      --arg first_registered "$(today_date)" \
      '{
        mask_id: $mask_id,
        relationship_type: "other",
        trust_level: "standard",
        context: "",
        first_registered: $first_registered
      }' >"$profile_path" || die_system "Failed to create profile: $profile_path"
  fi

  regenerate_hash_index "$pa_dir"
  printf 'Registered: %s → %s\n' "$real_name" "$mask_id"
}

# ─── Action: list ───

action_list() {
  ensure_jq

  local reveal="false"

  if [[ "${1:-}" == "--reveal" ]]; then
    reveal="true"
  elif [[ $# -gt 0 ]]; then
    die_user "unknown argument for list: $1"
  fi

  resolve_existing_mask_map
  validate_json "$MASK_MAP_PATH"

  if [[ "$reveal" == "true" ]]; then
    echo "| mask_id | kind | safe_name | real_name | alias_count |"
    echo "|---------|------|-----------|-----------|-------------|"
    jq -r '
      .entries[]
      | "| \(.mask_id) | \(.kind // "person") | \(.safe_name // "-") | \(.real_name) | \((.aliases // []) | length) |"
    ' "$MASK_MAP_PATH"
  else
    echo "| mask_id | kind | safe_name | alias_count |"
    echo "|---------|------|-----------|-------------|"
    jq -r '
      .entries[]
      | "| \(.mask_id) | \(.kind // "person") | \(.safe_name // "-") | \((.aliases // []) | length) |"
    ' "$MASK_MAP_PATH"
  fi
}

# ─── Action: forget ───

action_forget() {
  ensure_jq

  local mask_id="${1:-}"
  [[ -n "$mask_id" ]] || die_user "mask_id required. Usage: pa-mask.sh forget <mask_id>"

  resolve_existing_mask_map
  ensure_mask_map_v2 "$MASK_MAP_PATH"

  jq -e --arg mask_id "$mask_id" '.entries[] | select(.mask_id == $mask_id)' "$MASK_MAP_PATH" >/dev/null 2>&1 || die_user "unknown mask_id: $mask_id"

  local pa_dir
  local entities_path
  local relations_path
  local dossiers_dir
  local profile_path
  local ledger_path

  pa_dir=$(dirname "$MASK_MAP_PATH")
  entities_path="$pa_dir/entities.json"
  relations_path="$pa_dir/relations.json"
  dossiers_dir="$pa_dir/dossiers"
  profile_path="$pa_dir/people/profiles/$mask_id.json"
  ledger_path="$pa_dir/transmission-ledger.jsonl"

  rewrite_json_file "$MASK_MAP_PATH" '.entries |= map(select(.mask_id != $mask_id))' --arg mask_id "$mask_id"

  if [[ -f "$entities_path" ]]; then
    validate_json "$entities_path"
    rewrite_json_file "$entities_path" '
      if type == "array" then
        map(select((.mask_id // "") != $mask_id))
      elif type == "object" and has("entities") and (.entities | type) == "array" then
        .entities |= map(select((.mask_id // "") != $mask_id))
      else
        .
      end
    ' --arg mask_id "$mask_id"
  fi

  if [[ -f "$relations_path" ]]; then
    validate_json "$relations_path"
    rewrite_json_file "$relations_path" '
      if type == "array" then
        map(select((tostring | contains($mask_id)) | not))
      elif type == "object" and has("relations") and (.relations | type) == "array" then
        .relations |= map(select((tostring | contains($mask_id)) | not))
      else
        .
      end
    ' --arg mask_id "$mask_id"
  fi

  if [[ -d "$dossiers_dir" ]]; then
    while IFS= read -r dossier_path; do
      [[ -n "$dossier_path" ]] || continue
      rm -f "$dossier_path"
    done < <(rg -l --fixed-strings "$mask_id" "$dossiers_dir" 2>/dev/null || true)
  fi

  if [[ -f "$profile_path" ]]; then
    rm -f "$profile_path"
  fi

  mkdir -p "$pa_dir"
  jq -nc \
    --arg ts "$(timestamp_now)" \
    --arg mask_id "$mask_id" \
    '{
      ts: $ts,
      action: "forget",
      mask_id: $mask_id,
      cascade: ["entities", "relations", "dossiers", "profiles", "mask-map"]
    }' >>"$ledger_path" || die_system "Failed to append tombstone to $ledger_path"

  regenerate_hash_index "$pa_dir"
  printf 'Forgot: %s\n' "$mask_id"
}

# ─── Action: hash-index ───

action_hash_index() {
  ensure_jq

  resolve_existing_mask_map
  ensure_mask_map_v2 "$MASK_MAP_PATH"
  regenerate_hash_index "$(dirname "$MASK_MAP_PATH")"
  printf 'Regenerated: %s\n' "$(dirname "$MASK_MAP_PATH")/hash-index.json"
}

# ─── Dispatch ───

ACTION="${1:-}"

case "$ACTION" in
  mask)
    shift
    action_mask "$@"
    ;;
  mask-entity)
    shift
    action_mask_entity "$@"
    ;;
  unmask)
    shift
    action_unmask "$@"
    ;;
  pii)
    shift
    action_pii "$@"
    ;;
  add)
    shift
    action_add "$@"
    ;;
  list)
    shift
    action_list "$@"
    ;;
  forget)
    shift
    action_forget "$@"
    ;;
  hash-index)
    shift
    action_hash_index "$@"
    ;;
  --strip-private)
    shift
    action_filter_strip_private "$@"
    ;;
  --pii)
    shift
    action_filter_pii "$@"
    ;;
  --generalize)
    shift
    action_filter_generalize "$@"
    ;;
  --full)
    shift
    action_filter_full "$@"
    ;;
  help | --help | -h)
    usage
    ;;
  "")
    usage >&2
    exit 1
    ;;
  *)
    die_user "unknown action: $ACTION"
    ;;
esac
