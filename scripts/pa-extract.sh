#!/usr/bin/env bash
# pa-extract.sh - document text extraction helper.
#
# Actions:
#   detect <file>
#   extract <file> [--format auto|pdf|docx|pptx|epub]
#   status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

usage() {
  cat <<'EOF'
pa-extract.sh <action> [args]

Actions:
  detect <file>                              - Detect file format by extension
  extract <file> [--format auto|pdf|docx|pptx|epub]
                                            - Extract text and output markdown
  status                                     - Show installed extraction tools as JSON
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

tool_available() {
  command -v "$1" >/dev/null 2>&1
}

normalize_value() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

detect_format() {
  local file="$1"
  local lower_name=""

  [[ -f "$file" ]] || die_user "file not found: $file"

  lower_name="$(normalize_value "${file##*/}")"

  case "$lower_name" in
    *.pdf)
      printf 'pdf\n'
      ;;
    *.docx)
      printf 'docx\n'
      ;;
    *.pptx)
      printf 'pptx\n'
      ;;
    *.epub)
      printf 'epub\n'
      ;;
    *.png | *.jpg | *.jpeg | *.gif | *.webp | *.bmp | *.tiff | *.tif)
      printf 'image\n'
      ;;
    *)
      printf 'unknown\n'
      ;;
  esac
}

resolve_extract_format() {
  local file="$1"
  local requested_format="${2:-auto}"
  local normalized_format=""

  normalized_format="$(normalize_value "$requested_format")"

  case "$normalized_format" in
    auto)
      action_detect "$file"
      ;;
    pdf | docx | pptx | epub)
      printf '%s\n' "$normalized_format"
      ;;
    *)
      die_user "unsupported format: $requested_format"
      ;;
  esac
}

try_markitdown() {
  local file="$1"

  tool_available markitdown || return 1
  markitdown "$file" 2>/dev/null
}

try_pandoc() {
  local format="$1"
  local file="$2"

  tool_available pandoc || return 1

  case "$format" in
    pdf)
      return 1
      ;;
    docx | pptx | epub)
      pandoc -f "$format" -t markdown "$file" 2>/dev/null
      ;;
    *)
      return 1
      ;;
  esac
}

try_pdftotext() {
  local file="$1"

  tool_available pdftotext || return 1
  pdftotext -layout "$file" - 2>/dev/null
}

has_extractor_for_format() {
  local format="$1"

  case "$format" in
    pdf)
      tool_available markitdown || tool_available pdftotext
      ;;
    docx | pptx)
      tool_available markitdown || tool_available pandoc
      ;;
    epub)
      tool_available pandoc || tool_available markitdown
      ;;
    image)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

append_format() {
  local format="$1"
  local existing=""

  for existing in "${SUPPORTED_FORMATS[@]:-}"; do
    [[ "$existing" == "$format" ]] && return 0
  done

  SUPPORTED_FORMATS+=("$format")
}

action_detect() {
  [[ $# -eq 1 ]] || die_user "Usage: pa-extract.sh detect <file>"
  detect_format "$1"
}

action_extract() {
  local file=""
  local format="auto"
  local resolved_format=""

  [[ $# -ge 1 ]] || die_user "Usage: pa-extract.sh extract <file> [--format auto|pdf|docx|pptx|epub]"

  file="$1"
  shift

  [[ -f "$file" ]] || die_user "file not found: $file"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        [[ $# -ge 2 ]] || die_user "--format requires a value"
        format="$2"
        shift 2
        ;;
      *)
        die_user "Unknown option: $1"
        ;;
    esac
  done

  resolved_format="$(resolve_extract_format "$file" "$format")"

  case "$resolved_format" in
    unknown)
      die_user "unsupported file format: $file"
      ;;
    image)
      printf '%s\n' "Image files require Claude vision. Use Read tool on the image file."
      return 0
      ;;
    pdf | docx | pptx)
      if try_markitdown "$file"; then
        echo "extractor=markitdown" >&2
        return 0
      fi

      if try_pandoc "$resolved_format" "$file"; then
        echo "extractor=pandoc" >&2
        return 0
      fi

      if [[ "$resolved_format" == "pdf" ]] && try_pdftotext "$file"; then
        echo "extractor=pdftotext" >&2
        return 0
      fi
      ;;
    epub)
      if try_pandoc "$resolved_format" "$file"; then
        echo "extractor=pandoc" >&2
        return 0
      fi

      if try_markitdown "$file"; then
        echo "extractor=markitdown" >&2
        return 0
      fi
      ;;
    *)
      die_system "Unknown extract format: $resolved_format"
      ;;
  esac

  if has_extractor_for_format "$resolved_format"; then
    die_system "failed to extract $resolved_format file: $file"
  fi

  die_system "no extraction tool available for format: $resolved_format"
}

action_status() {
  local markitdown_available="false"
  local pandoc_available="false"
  local pdftotext_available="false"
  local index=0

  [[ $# -eq 0 ]] || die_user "Usage: pa-extract.sh status"

  if tool_available markitdown; then
    markitdown_available="true"
  fi

  if tool_available pandoc; then
    pandoc_available="true"
  fi

  if tool_available pdftotext; then
    pdftotext_available="true"
  fi

  SUPPORTED_FORMATS=()

  if [[ "$markitdown_available" == "true" ]] || [[ "$pdftotext_available" == "true" ]]; then
    append_format "pdf"
  fi

  if [[ "$markitdown_available" == "true" ]] || [[ "$pandoc_available" == "true" ]]; then
    append_format "docx"
    append_format "pptx"
    append_format "epub"
  fi

  append_format "image"

  printf '{\n'
  printf '  "markitdown": %s,\n' "$markitdown_available"
  printf '  "pandoc": %s,\n' "$pandoc_available"
  printf '  "pdftotext": %s,\n' "$pdftotext_available"
  printf '  "supported_formats": ['

  for index in "${!SUPPORTED_FORMATS[@]}"; do
    if [[ "$index" -gt 0 ]]; then
      printf ', '
    fi
    printf '"%s"' "${SUPPORTED_FORMATS[$index]}"
  done

  printf ']\n'
  printf '}\n'
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  detect)
    action_detect "$@"
    ;;
  extract)
    action_extract "$@"
    ;;
  status)
    action_status "$@"
    ;;
  "" | -h | --help | help)
    usage
    ;;
  *)
    die_user "Unknown action: $ACTION"
    ;;
esac
