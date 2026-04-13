#!/usr/bin/env bash
# pa-youtube.sh - YouTube transcript and metadata helper for PA.
#
# Actions:
#   transcript <url> [--lang ko,en]
#   metadata <url>
#   status

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
SAFE_RM_SCRIPT="$SCRIPT_DIR/safe-rm.sh"

DEFAULT_SUBTITLE_LANGS="ko,en,en.*"
MLX_WHISPER_MODEL="mlx-community/whisper-large-v3"
YT_DLP_JS_RUNTIME="${PA_YT_DLP_JS_RUNTIME:-bun}"
YT_DLP_COOKIES_BROWSER="${PA_YT_DLP_COOKIES_BROWSER:-}"

TEMP_CLEANUP_PATHS=()

usage() {
  cat <<'EOF'
pa-youtube.sh <action> [args]

Actions:
  transcript <url> [--lang ko,en]  - Extract transcript from YouTube subtitles or local transcription fallback
  metadata <url>                   - Output video metadata as JSON
  status                           - Output tool availability as JSON
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

ensure_yt_dlp() {
  command -v yt-dlp >/dev/null 2>&1 || die_system "yt-dlp is required."
}

ensure_ffmpeg() {
  command -v ffmpeg >/dev/null 2>&1 || die_system "ffmpeg is required for captionless transcription."
}

ensure_safe_rm() {
  [[ -f "$SAFE_RM_SCRIPT" ]] || die_system "safe-rm.sh not found: $SAFE_RM_SCRIPT"
}

mlx_whisper_available() {
  uvx --quiet mlx_whisper --help >/dev/null 2>&1
}

ensure_mlx_whisper() {
  mlx_whisper_available || die_system "mlx_whisper is required via uvx."
}

register_cleanup_path() {
  local path="${1:-}"

  [[ -n "$path" ]] || return 0
  TEMP_CLEANUP_PATHS+=("$path")
}

cleanup_temp_paths() {
  local path=""

  [[ "${#TEMP_CLEANUP_PATHS[@]}" -gt 0 ]] || return 0

  for path in "${TEMP_CLEANUP_PATHS[@]}"; do
    [[ -e "$path" ]] || continue
    (
      cd "$REPO_ROOT" &&
        bash "$SAFE_RM_SCRIPT" delete "$path"
    ) >/dev/null 2>&1 || true
  done

  TEMP_CLEANUP_PATHS=()
}

validate_youtube_url() {
  local url="${1:-}"

  [[ -n "$url" ]] || die_user "YouTube URL is required."
  [[ "$url" =~ ^https?://([A-Za-z0-9-]+\.)?(youtube\.com/watch\?[^[:space:]]*v=|youtube\.com/shorts/|youtube\.com/live/|youtu\.be/) ]] || die_user "Invalid YouTube URL: $url"
}

yt_dlp_global_args() {
  local args=()
  [[ -n "$YT_DLP_JS_RUNTIME" ]] && args+=(--js-runtimes "$YT_DLP_JS_RUNTIME")
  [[ -n "$YT_DLP_COOKIES_BROWSER" ]] && args+=(--cookies-from-browser "$YT_DLP_COOKIES_BROWSER")
  printf '%s\n' "${args[@]}"
}

fetch_video_json() {
  local url="$1"
  local info_json=""
  local -a global_args=()

  while IFS= read -r arg; do
    [[ -n "$arg" ]] && global_args+=("$arg")
  done < <(yt_dlp_global_args)

  info_json="$(yt-dlp "${global_args[@]}" --print-json --skip-download "$url" 2>/dev/null)" || die_user "Failed to fetch video metadata for URL: $url"
  [[ -n "$info_json" ]] || die_user "No video metadata returned for URL: $url"
  printf '%s\n' "$info_json"
}

split_lang_csv() {
  printf '%s\n' "$1" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | awk 'NF'
}

available_subtitle_langs() {
  local info_json="$1"

  printf '%s\n' "$info_json" |
    jq -r '[.subtitles // {}, .automatic_captions // {}] | map(keys) | add | unique[]?' 2>/dev/null
}

choose_subtitle_lang() {
  local info_json="$1"
  local lang_csv="${2:-$DEFAULT_SUBTITLE_LANGS}"
  local available_langs=""
  local preferred_lang=""
  local available_lang=""
  local prefix=""
  local fallback_lang=""

  available_langs="$(available_subtitle_langs "$info_json")"
  [[ -n "$available_langs" ]] || return 1

  fallback_lang="$(printf '%s\n' "$available_langs" | head -1)"

  while IFS= read -r preferred_lang; do
    [[ -n "$preferred_lang" ]] || continue

    if [[ "$preferred_lang" == *".*" ]]; then
      prefix="${preferred_lang%.*}"
      while IFS= read -r available_lang; do
        [[ "$available_lang" == "$prefix"* ]] || continue
        printf '%s\n' "$available_lang"
        return 0
      done <<<"$available_langs"
      continue
    fi

    while IFS= read -r available_lang; do
      [[ "$available_lang" == "$preferred_lang" ]] || continue
      printf '%s\n' "$available_lang"
      return 0
    done <<<"$available_langs"
  done < <(split_lang_csv "$lang_csv")

  printf '%s\n' "$fallback_lang"
}

format_duration_human() {
  local seconds="${1:-0}"
  local hours=0
  local minutes=0
  local remaining_seconds=0

  [[ "$seconds" =~ ^[0-9]+$ ]] || seconds=0

  hours=$((seconds / 3600))
  minutes=$(((seconds % 3600) / 60))
  remaining_seconds=$((seconds % 60))

  if ((hours > 0)); then
    printf '%02d:%02d:%02d\n' "$hours" "$minutes" "$remaining_seconds"
  else
    printf '%02d:%02d\n' "$minutes" "$remaining_seconds"
  fi
}

format_publish_date() {
  local raw="${1:-}"

  if [[ "$raw" =~ ^[0-9]{8}$ ]]; then
    printf '%s-%s-%s\n' "${raw:0:4}" "${raw:4:2}" "${raw:6:2}"
  else
    printf '\n'
  fi
}

pick_subtitle_file() {
  local dir="$1"
  local video_id="$2"
  local lang_csv="${3:-$DEFAULT_SUBTITLE_LANGS}"
  local preferred_lang=""
  local prefix=""
  local -a matches=()

  shopt -s nullglob

  while IFS= read -r preferred_lang; do
    [[ -n "$preferred_lang" ]] || continue

    if [[ "$preferred_lang" == *".*" ]]; then
      prefix="${preferred_lang%.*}"
      matches=("$dir/$video_id.$prefix"*.vtt)
    else
      matches=("$dir/$video_id.$preferred_lang.vtt")
    fi

    if [[ "${#matches[@]}" -gt 0 ]] && [[ -f "${matches[0]}" ]]; then
      printf '%s\n' "${matches[0]}"
      shopt -u nullglob
      return 0
    fi
  done < <(split_lang_csv "$lang_csv")

  matches=("$dir/$video_id"*.vtt)
  if [[ "${#matches[@]}" -gt 0 ]] && [[ -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
    shopt -u nullglob
    return 0
  fi

  shopt -u nullglob
  return 1
}

extract_vtt_text() {
  local subtitle_path="$1"

  sed -E \
    -e '/^WEBVTT$/d' \
    -e '/^[[:space:]]*$/d' \
    -e '/^[[:space:]]*[0-9]+[[:space:]]*$/d' \
    -e '/^[[:space:]]*[0-9]{2}:[0-9]{2}\.[0-9]{3}[[:space:]]-->[[:space:]][0-9]{2}:[0-9]{2}\.[0-9]{3}.*$/d' \
    -e '/^[[:space:]]*[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}[[:space:]]-->[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}.*$/d' \
    -e '/^(NOTE|Kind:|Language:)/d' \
    -e 's/<[^>]+>//g' \
    -e 's/[[:space:]]+/ /g' \
    -e 's/^ //; s/ $//' \
    "$subtitle_path" |
    awk '
      NF {
        if ($0 != prev) {
          lines[++count] = $0
          prev = $0
        }
      }
      END {
        for (i = 1; i <= count; i++) {
          printf "%s", lines[i]
          if (i < count) {
            printf " "
          }
        }
        printf "\n"
      }
    '
}

find_audio_path() {
  local video_id="$1"
  local expected="/tmp/pa-youtube-${video_id}.wav"
  local -a matches=()

  if [[ -f "$expected" ]]; then
    printf '%s\n' "$expected"
    return 0
  fi

  shopt -s nullglob
  matches=("/tmp/pa-youtube-${video_id}"*.wav)
  shopt -u nullglob

  if [[ "${#matches[@]}" -gt 0 ]] && [[ -f "${matches[0]}" ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  return 1
}

find_whisper_text_path() {
  local video_id="$1"
  local -a candidates=(
    "/tmp/pa-youtube-${video_id}.txt"
    "/tmp/pa-youtube-${video_id}.wav.txt"
  )
  local candidate=""

  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

download_subtitles() {
  local url="$1"
  local lang_csv="$2"
  local temp_dir="$3"
  local -a global_args=()

  while IFS= read -r arg; do
    [[ -n "$arg" ]] && global_args+=("$arg")
  done < <(yt_dlp_global_args)

  yt-dlp \
    "${global_args[@]}" \
    --write-auto-subs \
    --sub-langs "$lang_csv" \
    --sub-format vtt \
    --skip-download \
    --print-json \
    -P "home:$temp_dir" \
    -o '%(id)s.%(ext)s' \
    "$url" >/dev/null 2>&1 || true
}

transcribe_without_subtitles() {
  local url="$1"
  local video_id="$2"
  local audio_path=""
  local transcript_path=""

  ensure_ffmpeg
  ensure_mlx_whisper

  local -a global_args=()
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && global_args+=("$arg")
  done < <(yt_dlp_global_args)

  yt-dlp "${global_args[@]}" -x --audio-format wav --audio-quality 0 -o "/tmp/pa-youtube-%(id)s.wav" "$url" >/dev/null 2>&1 || die_system "Failed to download audio for transcription."

  audio_path="$(find_audio_path "$video_id")" || die_system "Failed to locate downloaded audio file."
  register_cleanup_path "$audio_path"

  (
    cd /tmp &&
      uvx mlx_whisper "$audio_path" --model "$MLX_WHISPER_MODEL" --output_format txt >/dev/null 2>&1
  ) || die_system "mlx_whisper transcription failed."

  transcript_path="$(find_whisper_text_path "$video_id")" || die_system "Failed to locate mlx_whisper transcript output."
  register_cleanup_path "$transcript_path"

  [[ -s "$transcript_path" ]] || die_system "mlx_whisper produced an empty transcript."
  cat "$transcript_path"
}

action_transcript() {
  local url="${1:-}"
  local lang_csv="$DEFAULT_SUBTITLE_LANGS"
  local info_json=""
  local video_id=""
  local subtitle_dir=""
  local subtitle_path=""
  local transcript_text=""

  [[ $# -ge 1 ]] || die_user "Usage: pa-youtube.sh transcript <url> [--lang ko,en]"

  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lang)
        [[ -n "${2:-}" ]] || die_user "--lang requires a value"
        lang_csv="$2"
        shift 2
        ;;
      *)
        die_user "Unknown argument for transcript: $1"
        ;;
    esac
  done

  ensure_safe_rm
  ensure_jq
  ensure_yt_dlp
  validate_youtube_url "$url"

  TEMP_CLEANUP_PATHS=()
  trap cleanup_temp_paths EXIT

  info_json="$(fetch_video_json "$url")"
  video_id="$(printf '%s\n' "$info_json" | jq -r '.id // empty')"
  [[ -n "$video_id" ]] || die_system "Failed to read video ID."

  subtitle_dir="$(mktemp -d "${TMPDIR:-/tmp}/pa-youtube-subs.XXXXXX")" || die_system "Failed to create subtitle temp directory."
  register_cleanup_path "$subtitle_dir"

  download_subtitles "$url" "$lang_csv" "$subtitle_dir"

  if subtitle_path="$(pick_subtitle_file "$subtitle_dir" "$video_id" "$lang_csv")"; then
    transcript_text="$(extract_vtt_text "$subtitle_path")"
    if [[ -n "$transcript_text" ]]; then
      echo "transcription_method=auto-subs" >&2
      printf '%s\n' "$transcript_text"
      trap - EXIT
      cleanup_temp_paths
      return 0
    fi
  fi

  echo "transcription_method=mlx-whisper" >&2
  transcribe_without_subtitles "$url" "$video_id"
  trap - EXIT
  cleanup_temp_paths
}

action_metadata() {
  local url="${1:-}"
  local info_json=""
  local duration_seconds=0
  local duration_human=""
  local publish_date=""
  local subtitle_lang=""
  local has_subtitles_json="false"
  local title=""
  local channel=""
  local view_count_json="null"
  local description=""
  local video_id=""
  local canonical_url=""

  [[ $# -eq 1 ]] || die_user "Usage: pa-youtube.sh metadata <url>"

  ensure_jq
  ensure_yt_dlp
  validate_youtube_url "$url"

  info_json="$(fetch_video_json "$url")"

  title="$(printf '%s\n' "$info_json" | jq -r '.title // ""')"
  channel="$(printf '%s\n' "$info_json" | jq -r '.channel // .uploader // ""')"
  duration_seconds="$(printf '%s\n' "$info_json" | jq -r '.duration // 0')"
  duration_human="$(format_duration_human "$duration_seconds")"
  publish_date="$(format_publish_date "$(printf '%s\n' "$info_json" | jq -r '.upload_date // ""')")"
  view_count_json="$(printf '%s\n' "$info_json" | jq '.view_count // null')"
  description="$(printf '%s\n' "$info_json" | jq -r '(.description // "") | if length > 500 then .[:500] + "..." else . end')"
  video_id="$(printf '%s\n' "$info_json" | jq -r '.id // ""')"
  canonical_url="$(printf '%s\n' "$info_json" | jq -r '.webpage_url // .original_url // ""')"

  if subtitle_lang="$(choose_subtitle_lang "$info_json" "$DEFAULT_SUBTITLE_LANGS" 2>/dev/null)"; then
    has_subtitles_json="true"
  else
    subtitle_lang=""
  fi

  jq -n \
    --arg title "$title" \
    --arg channel "$channel" \
    --argjson duration "$duration_seconds" \
    --arg duration_human "$duration_human" \
    --arg publish_date "$publish_date" \
    --argjson view_count "$view_count_json" \
    --arg description "$description" \
    --arg video_id "$video_id" \
    --arg url "$canonical_url" \
    --argjson has_subtitles "$has_subtitles_json" \
    --arg subtitle_lang "$subtitle_lang" \
    '{
      title: $title,
      channel: $channel,
      duration: $duration,
      duration_human: $duration_human,
      publish_date: (if $publish_date == "" then null else $publish_date end),
      view_count: $view_count,
      description: $description,
      video_id: $video_id,
      url: $url,
      has_subtitles: $has_subtitles,
      subtitle_lang: (if $subtitle_lang == "" then null else $subtitle_lang end)
    }'
}

action_status() {
  local yt_dlp_available="false"
  local ffmpeg_available="false"
  local mlx_whisper_ready="false"
  local can_transcript="false"
  local can_transcribe_captionless="false"

  [[ $# -eq 0 ]] || die_user "Usage: pa-youtube.sh status"

  ensure_jq

  if command -v yt-dlp >/dev/null 2>&1; then
    yt_dlp_available="true"
    can_transcript="true"
  fi

  if command -v ffmpeg >/dev/null 2>&1; then
    ffmpeg_available="true"
  fi

  if mlx_whisper_available; then
    mlx_whisper_ready="true"
  fi

  if [[ "$yt_dlp_available" == "true" ]] && [[ "$ffmpeg_available" == "true" ]] && [[ "$mlx_whisper_ready" == "true" ]]; then
    can_transcribe_captionless="true"
  fi

  jq -n \
    --argjson yt_dlp "$yt_dlp_available" \
    --argjson ffmpeg "$ffmpeg_available" \
    --argjson mlx_whisper "$mlx_whisper_ready" \
    --argjson can_transcript "$can_transcript" \
    --argjson can_transcribe_captionless "$can_transcribe_captionless" \
    '{
      yt_dlp: $yt_dlp,
      ffmpeg: $ffmpeg,
      mlx_whisper: $mlx_whisper,
      can_transcript: $can_transcript,
      can_transcribe_captionless: $can_transcribe_captionless
    }'
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  transcript)
    action_transcript "$@"
    ;;
  metadata)
    action_metadata "$@"
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
