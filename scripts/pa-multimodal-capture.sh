#!/usr/bin/env bash
# pa-multimodal-capture.sh - voice and screenshot capture helper for PA.
#
# Actions:
#   voice [--clipboard|--file <path>]
#   screenshot <path>
#   status
set -euo pipefail

MLX_WHISPER_MODEL="${PA_MLX_WHISPER_MODEL:-mlx-community/whisper-large-v3}"
TMP_DIR=""
TRANSCRIPT_PATH=""
usage() {
  cat <<'EOF'
pa-multimodal-capture.sh <action> [args]

Actions:
  voice [--clipboard]  - Read Whispree-corrected text from the macOS clipboard
  voice --file <path>  - Transcribe an audio file with mlx-whisper
  screenshot <path>    - Output a screenshot source packet for an existing image file
  status               - Output capture capability status as JSON
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
need_jq() { command -v jq >/dev/null 2>&1 || die_system "jq is required."; }
tool_available() { command -v "$1" >/dev/null 2>&1; }
mlx_whisper_available() { uvx --quiet mlx_whisper --help >/dev/null 2>&1; }

whispree_available() {
  tool_available whispree || tool_available Whispree || [[ -d "${WHISPREE_APP_PATH:-}" ]] || [[ -d "$HOME/Applications/Whispree.app" ]] || [[ -d "/Applications/Whispree.app" ]] || [[ -d "/Applications/Setapp/Whispree.app" ]]
}

iso_timestamp() {
  local ts=""

  ts="$(date '+%Y-%m-%dT%H:%M:%S%z')"
  printf '%s:%s\n' "${ts%??}" "${ts: -2}"
}

expand_home_path() {
  local path="${1:-}"

  case "$path" in
    \~) printf '%s\n' "$HOME" ;;
    \~/*) printf '%s/%s\n' "$HOME" "${path#\~/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
}

resolve_absolute_file() {
  local input_path="$1"
  local path=""

  path="$(expand_home_path "$input_path")"
  [[ -f "$path" ]] || die_user "file not found: $input_path"

  (
    cd "$(dirname "$path")" &&
      printf '%s/%s\n' "$(pwd -P)" "$(basename "$path")"
  ) || die_system "Failed to resolve file path: $input_path"
}

cleanup_tmp() {
  [[ -n "${TMP_DIR:-}" && -e "$TMP_DIR" ]] || return 0
  rm -rf "$TMP_DIR"
  TMP_DIR=""
}

find_whisper_text_path() {
  local output_dir="$1"
  local audio_path="$2"
  local audio_base=""
  local audio_stem=""
  local candidate=""
  local -a matches=()

  audio_base="$(basename "$audio_path")"
  audio_stem="${audio_base%.*}"

  for candidate in "$output_dir/$audio_stem.txt" "$output_dir/$audio_base.txt"; do
    [[ -f "$candidate" ]] || continue
    printf '%s\n' "$candidate"
    return 0
  done

  shopt -s nullglob
  matches=("$output_dir"/*.txt)
  shopt -u nullglob

  [[ "${#matches[@]}" -gt 0 ]] || return 1
  printf '%s\n' "${matches[0]}"
}

transcribe_audio_file() {
  local audio_path="$1"

  tool_available ffmpeg || die_system "ffmpeg is required for audio file transcription."
  mlx_whisper_available || die_system "mlx_whisper is required via uvx."

  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pa-multimodal-capture.XXXXXX")" || die_system "Failed to create transcription temp directory."
  trap cleanup_tmp EXIT

  (
    cd "$TMP_DIR" &&
      uvx mlx_whisper "$audio_path" --model "$MLX_WHISPER_MODEL" --output_format txt >/dev/null 2>&1
  ) || die_system "mlx_whisper transcription failed."

  TRANSCRIPT_PATH="$(find_whisper_text_path "$TMP_DIR" "$audio_path")" || die_system "Failed to locate mlx_whisper transcript output."
  [[ -s "$TRANSCRIPT_PATH" ]] || die_system "mlx_whisper produced an empty transcript."
}

emit_voice_packet() {
  jq -n --arg type "voice-transcript" --arg extractor "$1" --arg content "$2" --arg ts "$(iso_timestamp)" '{type: $type, extractor: $extractor, content: $content, ts: $ts}'
}

emit_screenshot_packet() {
  jq -n --arg type "screenshot" --arg path "$1" --arg ts "$(iso_timestamp)" '{type: $type, path: $path, ts: $ts}'
}

action_voice() {
  local mode=""
  local audio_path=""
  local content=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --clipboard)
        [[ -z "$mode" ]] || die_user "Use either --clipboard or --file, not both."
        mode="clipboard"
        shift
        ;;
      --file)
        [[ -z "$mode" ]] || die_user "Use either --clipboard or --file, not both."
        [[ -n "${2:-}" ]] || die_user "--file requires a path"
        mode="file"
        audio_path="$2"
        shift 2
        ;;
      *)
        die_user "Unknown argument for voice: $1"
        ;;
    esac
  done

  need_jq
  mode="${mode:-clipboard}"

  if [[ "$mode" == "clipboard" ]]; then
    tool_available pbpaste || die_system "pbpaste is required for clipboard capture on macOS."
    content="$(pbpaste)"
    [[ -n "$content" ]] || die_user "clipboard is empty; record with Whispree first or pass --file."
    emit_voice_packet "whispree" "$content"
    return 0
  fi

  audio_path="$(resolve_absolute_file "$audio_path")"
  transcribe_audio_file "$audio_path"
  content="$(cat "$TRANSCRIPT_PATH")"
  trap - EXIT
  cleanup_tmp
  [[ -n "$content" ]] || die_system "mlx_whisper produced an empty transcript."
  emit_voice_packet "mlx-whisper" "$content"
}

action_screenshot() {
  [[ $# -eq 1 ]] || die_user "Usage: pa-multimodal-capture.sh screenshot <path>"
  local resolved=""

  need_jq
  resolved="$(resolve_absolute_file "$1")" || exit 1
  emit_screenshot_packet "$resolved"
}

action_status() {
  local whispree_ready="false"
  local mlx_whisper_ready="false"
  local clipboard_ready="false"
  local ffmpeg_ready="false"

  [[ $# -eq 0 ]] || die_user "Usage: pa-multimodal-capture.sh status"
  need_jq

  whispree_available && whispree_ready="true"
  mlx_whisper_available && mlx_whisper_ready="true"
  tool_available pbpaste && clipboard_ready="true"
  tool_available ffmpeg && ffmpeg_ready="true"

  jq -n --argjson whispree "$whispree_ready" --argjson mlx_whisper "$mlx_whisper_ready" --argjson clipboard "$clipboard_ready" --argjson ffmpeg "$ffmpeg_ready" '{whispree: $whispree, mlx_whisper: $mlx_whisper, clipboard: $clipboard, ffmpeg: $ffmpeg}'
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  voice) action_voice "$@" ;;
  screenshot) action_screenshot "$@" ;;
  status) action_status "$@" ;;
  "" | -h | --help | help) usage ;;
  *) die_user "Unknown action: $ACTION" ;;
esac
