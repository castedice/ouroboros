#!/usr/bin/env bash
# Gate checker for ported skills in .agents/skills.
# Usage: check-port-skills.sh.
# The stale-copy check uses source and port-script mtimes and optionally honors a numeric .port-skills.stamp.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PORT_ROOT="$PROJECT_ROOT/.agents/skills"
PORT_SCRIPT="$PROJECT_ROOT/scripts/port-skills.sh"
STAMP_FILE="$PORT_ROOT/.port-skills.stamp"
STATUS=0
STAMP_EPOCH=""

line_count() {
  wc -l <"$1" | tr -d ' '
}

mtime() {
  if stat -f %m "$1" >/dev/null 2>&1; then
    stat -f %m "$1"
  else
    stat -c %Y "$1"
  fi
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

resolve_port_path() {
  case "$1" in
    references/* | ./references/* | ../* | ./*)
      (
        cd "$2" 2>/dev/null || exit 1
        cd "$(dirname "$1")" 2>/dev/null || exit 1
        printf '%s/%s\n' "$(pwd)" "$(basename "$1")"
      )
      ;;
    .agents/skills/*)
      printf '%s/%s\n' "$PROJECT_ROOT" "$1"
      ;;
    skills/*/SKILL.md)
      mapped_name="$(source_to_target "${1%/SKILL.md}")"
      [ -n "$mapped_name" ] && printf '%s/%s/SKILL.md\n' "$PORT_ROOT" "$mapped_name"
      ;;
    skills/*/references/*)
      mapped_name="$(source_to_target "${1%/references/*}")"
      [ -n "$mapped_name" ] && printf '%s/%s/references/%s\n' "$PORT_ROOT" "$mapped_name" "${1##*/}"
      ;;
    /*)
      printf '%s\n' "$1"
      ;;
  esac
}

source_to_target() {
  awk -F: -v source_dir="$1" '$2 == source_dir { print $1; exit }' "$MAP_FILE"
}

if [ -f "$STAMP_FILE" ]; then
  maybe_stamp="$(tr -d '[:space:]' <"$STAMP_FILE" 2>/dev/null)"
  case "$maybe_stamp" in
    '' | *[!0-9]*) ;;
    *) STAMP_EPOCH="$maybe_stamp" ;;
  esac
fi

[ -d "$PORT_ROOT" ] || {
  echo "No ported skills found in .agents/skills"
  exit 1
}

MAP_FILE="$(mktemp)"
awk '
  /^PORTABLE_SKILLS=\(/ { in_list = 1; next }
  in_list && /^\)/ { exit }
  in_list && /"/ {
    gsub(/^[[:space:]]*"/, "", $0)
    gsub(/".*$/, "", $0)
    print
  }
' "$PORT_SCRIPT" >"$MAP_FILE"

while IFS=: read -r target_name source_rel; do
  [ -n "$target_name" ] || continue
  port_dir="$PORT_ROOT/$target_name"
  port_skill="$port_dir/SKILL.md"
  source_skill="$PROJECT_ROOT/$source_rel/SKILL.md"
  skill_fail=0
  details=""
  [ -f "$source_skill" ] || {
    STATUS=1
    printf '[FAIL] .agents/skills/%s/SKILL.md\n  - missing source skill mapping\n' "$target_name"
    continue
  }
  [ -f "$port_skill" ] || {
    STATUS=1
    printf '[FAIL] .agents/skills/%s/SKILL.md\n  - missing ported skill\n' "$target_name"
    continue
  }
  skill_lines="$(line_count "$port_skill")"
  [ "$skill_lines" -le 180 ] || { skill_fail=1; details="${details}\n  - SKILL.md exceeds 180 lines: $skill_lines"; }
  while IFS= read -r ref_file; do
    [ -n "$ref_file" ] || continue
    ref_lines="$(line_count "$ref_file")"
    [ "$ref_lines" -le 250 ] || { skill_fail=1; details="${details}\n  - reference exceeds 250 lines: ${ref_file#$PROJECT_ROOT/} ($ref_lines)"; }
  done <<EOF
$(find "$port_dir/references" -type f -name '*.md' 2>/dev/null | sort)
EOF
  while IFS= read -r token_hit; do
    [ -n "$token_hit" ] || continue
    skill_fail=1
    details="${details}\n  - unresolved token: ${token_hit#$PROJECT_ROOT/}"
  done <<EOF
$(rg -l '\$\{CLAUDE_[^}]+\}' "$port_dir" 2>/dev/null || true)
EOF
  source_mtime="$(mtime "$source_skill")"
  script_mtime="$(mtime "$PORT_SCRIPT")"
  port_mtime="$(mtime "$port_skill")"
  [ "$port_mtime" -ge "$source_mtime" ] || { skill_fail=1; details="${details}\n  - stale ported copy: older than source skill"; }
  [ "$port_mtime" -ge "$script_mtime" ] || { skill_fail=1; details="${details}\n  - stale ported copy: older than port-skills.sh"; }
  if [ -n "$STAMP_EPOCH" ] && [ "$port_mtime" -lt "$STAMP_EPOCH" ]; then
    skill_fail=1
    details="${details}\n  - stale ported copy: older than .port-skills.stamp"
  fi
  while IFS= read -r raw_ref; do
    [ -n "$raw_ref" ] || continue
    resolved="$(resolve_port_path "$raw_ref" "$port_dir")"
    [ -n "$resolved" ] && [ -e "$resolved" ] || {
      skill_fail=1
      details="${details}\n  - dead Reference Map path: $raw_ref"
      continue
    }
    case "$raw_ref" in
      ../* | .agents/skills/* | skills/*)
        [ -e "$resolved" ] || {
          skill_fail=1
          details="${details}\n  - cross-skill reference is not ported: $raw_ref"
        }
        ;;
    esac
  done <<EOF
$(extract_reference_paths "$port_skill")
EOF
  if [ "$skill_fail" -eq 0 ]; then
    printf '[PASS] .agents/skills/%s/SKILL.md\n' "$target_name"
  else
    STATUS=1
    printf '[FAIL] .agents/skills/%s/SKILL.md\n%b\n' "$target_name" "$details"
  fi
done <"$MAP_FILE"

rm -f "$MAP_FILE"
exit "$STATUS"
