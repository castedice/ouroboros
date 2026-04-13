#!/usr/bin/env bash
# Tier 1 static checker for ouroboros skills.
# Usage: check-skills.sh [--fix] [skill-path].
# The optional --fix rewrites same-skill Reference Map paths to ${CLAUDE_SKILL_DIR}/references/... when it is safe.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIX=0
TARGET_PATH=""
STATUS=0

usage() {
  echo "Usage: check-skills.sh [--fix] [skill-path]"
}

line_count() {
  wc -l <"$1" | tr -d ' '
}

frontmatter_value() {
  awk -v key="$2" '
    NR == 1 && /^---$/ { in_frontmatter = 1; next }
    in_frontmatter && /^---$/ { exit }
    in_frontmatter && $0 ~ "^" key ":[[:space:]]*" {
      sub("^[^:]*:[[:space:]]*", "", $0)
      print
      exit
    }
  ' "$1"
}

extract_reference_paths() {
  awk '
    /^## Reference Map$/ { in_section = 1; next }
    /^## / && in_section { exit }
    in_section { print }
  ' "$1" |
    perl -ne '
      my $line = $_;
      while ($line =~ /\]\(([^)]+\.md)\)/g) { print "$1\n"; }
      $line =~ s/\[[^][]*\]\([^)]+\)//g;
      while ($line =~ /`([^`]+\.md)`/g) { print "$1\n"; }
    ' |
    sed '/^$/d' |
    sort -u
}

resolve_path() {
  case "$1" in
    "\${CLAUDE_SKILL_DIR}/"*)
      printf '%s/%s\n' "$2" "${1#\$\{CLAUDE_SKILL_DIR\}/}"
      ;;
    references/* | ./references/* | ../* | ./*)
      (
        cd "$2" 2>/dev/null || exit 1
        cd "$(dirname "$1")" 2>/dev/null || exit 1
        printf '%s/%s\n' "$(pwd)" "$(basename "$1")"
      )
      ;;
    skills/* | commands/* | agents/* | hooks/* | templates/* | docs/* | dev/* | scripts/* | .agents/*)
      printf '%s/%s\n' "$PROJECT_ROOT" "$1"
      ;;
    /*)
      printf '%s\n' "$1"
      ;;
  esac
}

fix_local_refs() {
  perl -0pi -e 's{(?<=\(|`)(?:\./)?references/([A-Za-z0-9._-]+\.md)(?=\)|`)}{\$\{CLAUDE_SKILL_DIR\}/references/$1}g' "$1"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --fix) FIX=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      [ -z "$TARGET_PATH" ] || {
        usage
        exit 1
      }
      TARGET_PATH="$1"
      ;;
  esac
  shift
done

LIST_FILE="$(mktemp)"
if [ -z "$TARGET_PATH" ]; then
  find "$PROJECT_ROOT/skills" -name SKILL.md | sort >"$LIST_FILE"
elif [ -d "$TARGET_PATH" ] && [ -f "$TARGET_PATH/SKILL.md" ]; then
  printf '%s\n' "$TARGET_PATH/SKILL.md" >"$LIST_FILE"
elif [ -f "$TARGET_PATH" ] && [ "$(basename "$TARGET_PATH")" = "SKILL.md" ]; then
  printf '%s\n' "$TARGET_PATH" >"$LIST_FILE"
else
  rm -f "$LIST_FILE"
  usage
  exit 1
fi

while IFS= read -r skill_file; do
  [ -n "$skill_file" ] || continue
  skill_dir="$(cd "$(dirname "$skill_file")" && pwd)"
  rel_skill="${skill_file#$PROJECT_ROOT/}"
  skill_fail=0
  details=""
  if [ "$FIX" -eq 1 ]; then
    before="$(cksum <"$skill_file")"
    fix_local_refs "$skill_file"
    after="$(cksum <"$skill_file")"
    [ "$before" = "$after" ] || details="${details}\n  - fixed same-skill Reference Map paths"
  fi
  name_value="$(frontmatter_value "$skill_file" name)"
  description_value="$(frontmatter_value "$skill_file" description)"
  preamble_tier="$(frontmatter_value "$skill_file" preamble_tier)"
  summary_value="$(frontmatter_value "$skill_file" summary)"
  version_value="$(frontmatter_value "$skill_file" version)"
  tags_value="$(frontmatter_value "$skill_file" tags)"
  [ -n "$name_value" ] || {
    skill_fail=1
    details="${details}\n  - missing frontmatter field: name"
  }
  [ -n "$description_value" ] || {
    skill_fail=1
    details="${details}\n  - missing frontmatter field: description"
  }
  [ -n "$summary_value" ] || {
    skill_fail=1
    details="${details}\n  - missing frontmatter field: summary"
  }
  [ -n "$version_value" ] || {
    skill_fail=1
    details="${details}\n  - missing frontmatter field: version"
  }
  [ -n "$tags_value" ] || {
    skill_fail=1
    details="${details}\n  - missing frontmatter field: tags"
  }
  case "$preamble_tier" in
    1 | 2 | 3 | 4) ;;
    *)
      skill_fail=1
      details="${details}\n  - invalid preamble_tier: ${preamble_tier:-missing}"
      ;;
  esac
  skill_lines="$(line_count "$skill_file")"
  [ "$skill_lines" -le 180 ] || {
    skill_fail=1
    details="${details}\n  - SKILL.md exceeds 180 lines: $skill_lines"
  }
  for heading in "Core Rule" "Gotchas" "Workflow" "Decision Rules" "Reference Map" "See Also"; do
    grep -q "^## $heading$" "$skill_file" || {
      skill_fail=1
      details="${details}\n  - missing section: $heading"
    }
  done
  if [ "$preamble_tier" = "4" ]; then
    grep -q 'skip loading this skill\.' "$skill_file" && grep -q 'Commands already embed the relevant methodology inline\.' "$skill_file" || {
      skill_fail=1
      details="${details}\n  - missing tier 4 SUBAGENT-STOP guard text"
    }
  fi
  if [ -d "$skill_dir/references" ]; then
    while IFS= read -r ref_file; do
      [ -n "$ref_file" ] || continue
      ref_lines="$(line_count "$ref_file")"
      [ "$ref_lines" -le 250 ] || {
        skill_fail=1
        details="${details}\n  - reference exceeds 250 lines: ${ref_file#$PROJECT_ROOT/} ($ref_lines)"
      }
    done <<EOF
$(find "$skill_dir/references" -type f -name '*.md' | sort)
EOF
    while IFS= read -r token_hit; do
      [ -n "$token_hit" ] || continue
      skill_fail=1
      details="${details}\n  - unresolved token in reference: ${token_hit#$PROJECT_ROOT/}"
    done <<EOF
$(rg -l '\$\{CLAUDE_[^}]+\}' "$skill_dir/references" 2>/dev/null || true)
EOF
  fi
  while IFS= read -r raw_ref; do
    [ -n "$raw_ref" ] || continue
    case "$raw_ref" in
      references/* | ./references/*)
        skill_fail=1
        details="${details}\n  - same-skill reference should use \${CLAUDE_SKILL_DIR}: $raw_ref"
        ;;
    esac
    resolved="$(resolve_path "$raw_ref" "$skill_dir")"
    [ -n "$resolved" ] && [ -e "$resolved" ] || {
      skill_fail=1
      details="${details}\n  - dead Reference Map path: $raw_ref"
    }
  done <<EOF
$(extract_reference_paths "$skill_file")
EOF
  if [ "$skill_fail" -eq 0 ]; then
    printf '[PASS] %s\n' "$rel_skill"
  else
    STATUS=1
    printf '[FAIL] %s\n%b\n' "$rel_skill" "$details"
  fi
done <"$LIST_FILE"

rm -f "$LIST_FILE"
exit "$STATUS"
