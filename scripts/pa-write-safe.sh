#!/usr/bin/env bash
# pa-write-safe.sh — Write declassification gate
#
# Inspects scribe output for mask residuals, declassifies reversible masks,
# and blocks writes containing irreversible tokens.
#
# Usage:
#   pa-write-safe.sh inspect <text>    Check for mask residuals, return JSON verdict
#   pa-write-safe.sh declassify <text> Unmask Layer 4 entities + verify clean
#   pa-write-safe.sh hash <file>       Content hash (SHA-256 first 8 chars)
#
# Exit codes:
#   0 — success
#   1 — irreversible residuals detected (proposal-only recommended)
#   2 — usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

die_user() {
  echo "ERROR: $*" >&2
  exit 2
}

# --- Residual detection patterns ---

# Layer 3: PII regex tokens
PII_PATTERN='\[(PHONE|EMAIL|SSN|ACCOUNT)_[0-9]+\]'

# Layer 2: Private note stubs
PRIVATE_PATTERN='\[PRIVATE NOTE\]'

# Layer 5: Tagged irreversible markers (if adopted)
GENERALIZED_PATTERN='\[(AMOUNT|DATE|AGE)_[A-Z0-9_]+\]'

# Unknown mask_ids: PREFIX_LETTER pattern not in mask-map
# Detected dynamically against mask-map entries

detect_pii_residuals() {
  local text="$1"
  echo "$text" | grep -oE "$PII_PATTERN" 2>/dev/null | sort -u || true
}

detect_private_residuals() {
  local text="$1"
  echo "$text" | grep -oE "$PRIVATE_PATTERN" 2>/dev/null | sort -u || true
}

detect_generalized_residuals() {
  local text="$1"
  echo "$text" | grep -oE "$GENERALIZED_PATTERN" 2>/dev/null | sort -u || true
}

# Detect mask_ids that exist in text but NOT in mask-map (unknown masks)
detect_unknown_masks() {
  local text="$1"

  # Extract all MASK_ID-like tokens from text (Person_X, ORG_X, PLACE_X, EDU_X, PROJ_X)
  local found
  found=$(echo "$text" | grep -oE '\b(Person|ORG|PLACE|EDU|PROJ)_[A-Z]+\b' 2>/dev/null | sort -u || true)
  [[ -z "$found" ]] && return

  # Get known mask_ids from mask-map
  local known=""
  if [[ -n "${MASK_MAP_PATH:-}" ]] && [[ -f "$MASK_MAP_PATH" ]]; then
    known=$(jq -r '.entries[].mask_id' "$MASK_MAP_PATH" 2>/dev/null | sort -u || true)
  fi

  # Filter: tokens in text but not in mask-map
  if [[ -n "$known" ]]; then
    comm -23 <(echo "$found") <(echo "$known") 2>/dev/null || true
  else
    echo "$found"
  fi
}

# Strip code fences and inline code before inspection
# (mask tokens inside code are intentional and should not block writes)
strip_code_blocks() {
  local text="$1"
  # Remove fenced code blocks
  echo "$text" | perl -0pe 's/```.*?```//gs; s/`[^`]+`//g'
}

# --- Actions ---

action_inspect() {
  local text="${*:-}"
  [[ -n "$text" ]] || die_user "text required. Usage: pa-write-safe.sh inspect <text>"

  # Resolve mask-map for unknown mask detection
  if [[ -z "${MASK_MAP_PATH:-}" ]]; then
    local vault_path="${PA_VAULT_PATH:-}"
    for candidate in "$vault_path/.pa/mask-map.json" ".pa/mask-map.json"; do
      if [[ -f "$candidate" ]]; then
        MASK_MAP_PATH="$candidate"
        break
      fi
    done
  fi

  # Strip code blocks for inspection (tokens in code are OK)
  local inspectable
  inspectable=$(strip_code_blocks "$text")

  local pii private generalized unknown
  pii=$(detect_pii_residuals "$inspectable")
  private=$(detect_private_residuals "$inspectable")
  generalized=$(detect_generalized_residuals "$inspectable")
  unknown=$(detect_unknown_masks "$inspectable")

  # Build JSON arrays
  local irr_json="[]"
  local items=""
  while IFS= read -r token; do
    [[ -n "$token" ]] && items="${items:+$items,}{\"kind\":\"pii\",\"token\":\"$token\"}"
  done <<<"$pii"
  while IFS= read -r token; do
    [[ -n "$token" ]] && items="${items:+$items,}{\"kind\":\"private\",\"token\":\"$token\"}"
  done <<<"$private"
  while IFS= read -r token; do
    [[ -n "$token" ]] && items="${items:+$items,}{\"kind\":\"generalized\",\"token\":\"$token\"}"
  done <<<"$generalized"
  [[ -n "$items" ]] && irr_json="[$items]"

  local unk_json="[]"
  local unk_items=""
  while IFS= read -r token; do
    [[ -n "$token" ]] && unk_items="${unk_items:+$unk_items,}\"$token\""
  done <<<"$unknown"
  [[ -n "$unk_items" ]] && unk_json="[$unk_items]"

  # Determine reversible masks (known mask_ids present in text)
  local rev_json="[]"
  if [[ -n "${MASK_MAP_PATH:-}" ]] && [[ -f "$MASK_MAP_PATH" ]]; then
    local known_in_text
    known_in_text=$(jq -r '.entries[].mask_id' "$MASK_MAP_PATH" 2>/dev/null | while read -r mid; do
      echo "$inspectable" | grep -qw "$mid" 2>/dev/null && echo "$mid"
    done || true)
    if [[ -n "$known_in_text" ]]; then
      local rev_items=""
      while IFS= read -r mid; do
        [[ -n "$mid" ]] && rev_items="${rev_items:+$rev_items,}\"$mid\""
      done <<<"$known_in_text"
      [[ -n "$rev_items" ]] && rev_json="[$rev_items]"
    fi
  fi

  local write_safe="true"
  if [[ "$irr_json" != "[]" ]] || [[ "$unk_json" != "[]" ]]; then
    write_safe="false"
  fi

  cat <<ENDJSON
{
  "write_safe": $write_safe,
  "reversible_masks": $rev_json,
  "irreversible_tokens": $irr_json,
  "unknown_masks": $unk_json
}
ENDJSON

  [[ "$write_safe" == "true" ]] && return 0 || return 1
}

action_declassify() {
  local text="${*:-}"
  [[ -n "$text" ]] || die_user "text required. Usage: pa-write-safe.sh declassify <text>"

  # Resolve mask-map
  if [[ -z "${MASK_MAP_PATH:-}" ]]; then
    local vault_path="${PA_VAULT_PATH:-}"
    for candidate in "$vault_path/.pa/mask-map.json" ".pa/mask-map.json"; do
      if [[ -f "$candidate" ]]; then
        export MASK_MAP_PATH="$candidate"
        break
      fi
    done
  fi

  # Step 1: Unmask Layer 4 entities (composite + bare) via pa-mask.sh
  local unmasked="$text"
  if [[ -n "${MASK_MAP_PATH:-}" ]] && [[ -f "$MASK_MAP_PATH" ]]; then
    unmasked=$(bash "$SCRIPT_DIR/pa-mask.sh" unmask "$text")
  fi

  # Step 2: Verify no irreversible residuals remain
  local inspectable
  inspectable=$(strip_code_blocks "$unmasked")

  local pii private generalized unknown
  pii=$(detect_pii_residuals "$inspectable")
  private=$(detect_private_residuals "$inspectable")
  generalized=$(detect_generalized_residuals "$inspectable")
  unknown=$(detect_unknown_masks "$inspectable")

  if [[ -n "$pii" ]] || [[ -n "$private" ]] || [[ -n "$generalized" ]] || [[ -n "$unknown" ]]; then
    echo "BLOCKED: irreversible residuals remain after declassification" >&2
    echo "$unmasked"
    return 1
  fi

  echo "$unmasked"
  return 0
}

action_hash() {
  local file="${1:-}"
  [[ -n "$file" ]] || die_user "file required. Usage: pa-write-safe.sh hash <file>"
  [[ -f "$file" ]] || die_user "file not found: $file"
  shasum -a 256 "$file" | cut -c1-8
}

# --- Source-only mode for function reuse ---
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

# --- Main ---
ACTION="${1:-}"
shift || true

case "$ACTION" in
  inspect) action_inspect "$@" ;;
  declassify) action_declassify "$@" ;;
  hash) action_hash "$@" ;;
  *) die_user "Unknown action: $ACTION. Use inspect, declassify, or hash" ;;
esac
