#!/usr/bin/env bash
# Spiral Monitor — Real-time team spiral dashboard
#
# Polls .swe/active/spiral-state.json every second and renders a live
# terminal dashboard. Catppuccin Frappe theme, box-drawing layout.
#
# Usage:
#   spiral-monitor.sh              # default 1s interval
#   spiral-monitor.sh --interval 2 # custom interval (seconds)
#   spiral-monitor.sh --once       # single render, no loop
#
# Requires: jq

set -uo pipefail

STATE_FILE=".swe/active/spiral-state.json"
INTERVAL=1
ONCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --interval)
      INTERVAL="${2:?Missing interval value}"
      shift 2
      ;;
    --once)
      ONCE=true
      shift
      ;;
    -h | --help)
      echo "Usage: spiral-monitor.sh [--interval N] [--once]"
      exit 0
      ;;
    *)
      echo "Unknown flag: $1" >&2
      exit 1
      ;;
  esac
done

# ─── Catppuccin Frappe ───

RST="\033[0m"
BLD="\033[1m"
DIM="\033[2m"
BLUE="\033[38;2;140;170;238m"
GREEN="\033[38;2;166;209;137m"
YELLOW="\033[38;2;229;200;144m"
RED="\033[38;2;231;130;132m"
PEACH="\033[38;2;239;159;118m"
MAUVE="\033[38;2;202;158;230m"
TEAL="\033[38;2;129;200;190m"
TEXT="\033[38;2;198;208;245m"
SUB="\033[38;2;165;173;206m"
OVR="\033[38;2;115;121;148m"
SRF="\033[38;2;81;87;109m"

# ─── Helpers ───

_jq() { jq -r "$@" "$STATE_FILE" 2>/dev/null; }

_elapsed() {
  local started
  started=$(_jq '.started_at')
  [[ -z "$started" || "$started" == "null" ]] && echo "00:00:00" && return
  local start_epoch now_epoch diff
  start_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" +%s 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  diff=$((now_epoch - start_epoch))
  printf "%02d:%02d:%02d" $((diff / 3600)) $(((diff % 3600) / 60)) $((diff % 60))
}

_depth_short() {
  case "$1" in
    Standard) echo "Std" ;; Light) echo "Lt" ;; Deep) echo "Dp" ;;
    Skip) echo "—" ;; *) echo "$1" ;;
  esac
}

_strip_ansi() {
  echo -ne "$1" | sed $'s/\033\[[0-9;]*m//g'
}

_visible_len() {
  local stripped
  stripped=$(_strip_ansi "$1")
  echo ${#stripped}
}

# ─── Box drawing ───

W=0

_box_top() {
  echo -ne "${SRF}╭"
  printf '─%.0s' $(seq 1 $((W - 2)))
  echo -e "╮${RST}"
}

_box_bottom() {
  echo -ne "${SRF}╰"
  printf '─%.0s' $(seq 1 $((W - 2)))
  echo -e "╯${RST}"
}

_box_sep() {
  local label="$1"
  local label_len=${#label}
  local rest=$((W - 5 - label_len))
  [[ $rest -lt 1 ]] && rest=1
  echo -ne "${SRF}├─ ${RST}${BLD}${SUB}${label}${RST}${SRF} "
  printf '─%.0s' $(seq 1 $rest)
  echo -e "┤${RST}"
}

_box_line() {
  local content="$1"
  local vlen
  vlen=$(_visible_len "$content")
  local inner=$((W - 4))
  local pad=$((inner - vlen))
  [[ $pad -lt 1 ]] && pad=1
  echo -ne "${SRF}│${RST} "
  echo -ne "$content"
  printf '%*s' "$pad" ""
  echo -e " ${SRF}│${RST}"
}

# ─── Pipeline ───

_render_pipeline() {
  local composites=("spec_composite" "dev_composite" "ship_composite" "tune_composite")
  local gates=("spec_dev_gate" "dev_ship_gate" "ship_tune_gate")
  local labels=("SPEC" "DEV" "SHIP" "TUNE")

  local out=""
  for i in "${!composites[@]}"; do
    local st
    st=$(_jq ".stages.${composites[$i]}")
    local color="$SRF" icon="○"
    case "$st" in
      running)
        color="$BLUE"
        icon="◉"
        ;;
      completed)
        color="$GREEN"
        icon="●"
        ;;
      invalidated)
        color="$RED"
        icon="✗"
        ;;
      stale)
        color="$YELLOW"
        icon="◎"
        ;;
    esac
    out+="${color}${icon} ${BLD}${labels[$i]}${RST}"

    if [[ $i -lt ${#gates[@]} ]]; then
      local gst
      gst=$(_jq ".stages.${gates[$i]}")
      if [[ "$gst" == "completed" ]]; then
        out+="${GREEN} ━━━ ${RST}"
      elif [[ "$gst" == "running" ]]; then
        out+="${BLUE} ━━━ ${RST}"
      else
        out+="${SRF} ─── ${RST}"
      fi
    fi
  done
  echo -ne "$out"
}

# ─── Stage progress bar ───

_stage_bar() {
  local specialist="$1"
  local primitives=("understand" "constrain" "design" "interface" "test" "implement" "verify" "optimize")
  local current_stage current_status
  current_stage=$(_jq ".team.specialists.${specialist}.current_stage // \"\"")
  current_status=$(_jq ".team.specialists.${specialist}.stage_status // \"\"")

  if [[ -z "$current_stage" || "$current_stage" == "null" ]]; then
    echo -ne "${SRF}░░░░░░░░${RST}"
    return
  fi

  for i in "${!primitives[@]}"; do
    if [[ "${primitives[$i]}" == "$current_stage" ]]; then
      local j
      for ((j = 0; j < i; j++)); do echo -ne "${GREEN}█${RST}"; done
      if [[ "$current_status" == "running" ]]; then
        echo -ne "${BLUE}▓${RST}"
      else
        echo -ne "${GREEN}█${RST}"
      fi
      for ((j = i + 1; j < 8; j++)); do echo -ne "${SRF}░${RST}"; done
      return
    fi
  done
  echo -ne "${SRF}░░░░░░░░${RST}"
}

# ─── Specialist row ───

_specialist_row() {
  local sp="$1"
  local sp_status sp_task sp_stage sp_stage_st icon sc

  sp_status=$(_jq ".team.specialists.${sp}.status")
  sp_task=$(_jq ".team.specialists.${sp}.current_task // \"\"")
  sp_stage=$(_jq ".team.specialists.${sp}.current_stage // \"\"")
  sp_stage_st=$(_jq ".team.specialists.${sp}.stage_status // \"\"")

  case "$sp" in
    shaper) icon="◆" ;; builder) icon="■" ;; critic) icon="●" ;; bridge) icon="◇" ;; *) icon="○" ;;
  esac
  case "$sp_status" in
    active) sc="$BLUE" ;; reviewing) sc="$MAUVE" ;; idle) sc="$DIM" ;; *) sc="$TEXT" ;;
  esac

  local row=""
  row+="${sc}${icon}${RST} ${sc}$(printf '%-8s' "$sp")${RST} "
  row+="$(_stage_bar "$sp") "

  # Current stage label — the key info
  if [[ -n "$sp_stage" && "$sp_stage" != "null" ]]; then
    if [[ "$sp_stage_st" == "running" ]]; then
      row+="${BLUE}${BLD}▸ ${sp_stage}${RST}"
    else
      row+="${GREEN}✓ ${sp_stage}${RST}"
    fi
  else
    case "$sp_status" in
      idle) row+="${DIM}  idle${RST}" ;;
      *) row+="${sc}  ${sp_status}${RST}" ;;
    esac
  fi

  # Task description
  if [[ -n "$sp_task" && "$sp_task" != "null" ]]; then
    row+="  ${SUB}${sp_task:0:22}${RST}"
  fi

  echo -ne "$row"
}

# ─── Main render ───

render() {
  W=$(tput cols 2>/dev/null || echo 80)
  [[ $W -gt 80 ]] && W=80
  [[ $W -lt 40 ]] && W=40

  if [[ ! -f "$STATE_FILE" ]]; then
    _box_top
    _box_line "${DIM}Waiting for spiral-state.json...${RST}"
    _box_bottom
    return
  fi

  local task policy regressions max_reg elapsed
  task=$(_jq '.task' | head -c $((W - 20)))
  policy=$(_jq '.policy')
  regressions=$(_jq '.regression_count')
  max_reg=$(_jq '.max_regressions')
  elapsed=$(_elapsed)

  local d_spec d_dev d_ship d_tune
  d_spec=$(_depth_short "$(_jq '.depths.spec')")
  d_dev=$(_depth_short "$(_jq '.depths.dev')")
  d_ship=$(_depth_short "$(_jq '.depths.ship')")
  d_tune=$(_depth_short "$(_jq '.depths.tune')")

  # ── Header (no title, just task + metadata) ──
  _box_top
  _box_line "${TEXT}${task}${RST}"
  _box_line "${TEAL}${policy}${RST}  ${PEACH}${d_spec}/${d_dev}/${d_ship}/${d_tune}${RST}  ${SUB}reg${RST} ${TEXT}${regressions}/${max_reg}${RST}  ${SUB}⏱${RST} ${TEXT}${elapsed}${RST}"

  # ── Pipeline ──
  _box_sep "PIPELINE"
  _box_line "  $(_render_pipeline)"

  # ── Team ──
  if [[ "$policy" == "team" || "$policy" == "team+probe" ]]; then
    _box_sep "TEAM"
    for sp in shaper builder critic bridge; do
      local sp_exists
      sp_exists=$(_jq ".team.specialists.${sp} // empty")
      [[ -z "$sp_exists" ]] && continue
      _box_line "$(_specialist_row "$sp")"
    done

    local cr_count
    cr_count=$(_jq '.team.cross_reviews | length')
    if [[ "$cr_count" -gt 0 ]]; then
      _box_sep "REVIEW"
      _jq '.team.cross_reviews[] | "\(.reviewer) \(.target) \(.status)"' | while IFS= read -r line; do
        local reviewer target cr_status cr_color cr_icon
        reviewer=$(echo "$line" | awk '{print $1}')
        target=$(echo "$line" | awk '{print $2}')
        cr_status=$(echo "$line" | awk '{print $3}')
        case "$cr_status" in
          completed)
            cr_color="$GREEN"
            cr_icon="●"
            ;;
          running)
            cr_color="$BLUE"
            cr_icon="◉"
            ;;
          *)
            cr_color="$DIM"
            cr_icon="○"
            ;;
        esac
        _box_line "${cr_color}${cr_icon} ${reviewer} → ${target}  ${cr_status}${RST}"
      done
    fi
  fi

  # ── Events ──
  local tr_count
  tr_count=$(_jq '.transitions | length')
  if [[ "$tr_count" -gt 0 ]]; then
    _box_sep "EVENTS"
    _jq '.transitions | .[-5:] | reverse | .[] | "\(.type) \(.from) \(.to) \(.timestamp)"' | while IFS= read -r line; do
      local type from to ts arrow ac
      type=$(echo "$line" | awk '{print $1}')
      from=$(echo "$line" | awk '{print $2}')
      to=$(echo "$line" | awk '{print $3}')
      ts=$(echo "$line" | awk '{print $4}')
      local time_part="${ts:11:5}"
      case "$type" in
        forward)
          arrow="→"
          ac="$GREEN"
          ;;
        regression)
          arrow="←"
          ac="$RED"
          ;;
        escalate)
          arrow="↑"
          ac="$YELLOW"
          ;;
        *)
          arrow="·"
          ac="$TEXT"
          ;;
      esac
      _box_line "${SUB}${time_part}${RST} ${ac}${arrow}${RST} ${TEXT}${from} → ${to}${RST}"
    done
  fi

  # ── Learning delta ──
  local delta_file=".swe/active/learning-delta.json"
  if [[ -f "$delta_file" ]]; then
    _box_sep "LEARNING"
    local spec dev ship tune dl=""
    spec=$(jq -r '.depth_calibration.spec // "-"' "$delta_file" 2>/dev/null)
    dev=$(jq -r '.depth_calibration.dev // "-"' "$delta_file" 2>/dev/null)
    ship=$(jq -r '.depth_calibration.ship // "-"' "$delta_file" 2>/dev/null)
    tune=$(jq -r '.depth_calibration.tune // "-"' "$delta_file" 2>/dev/null)
    for pair in "spec:$spec" "dev:$dev" "ship:$ship" "tune:$tune"; do
      local key="${pair%%:*}" val="${pair#*:}"
      case "$val" in
        ok) dl+="${GREEN}${key}:ok${RST}  " ;;
        over) dl+="${YELLOW}${key}:over${RST}  " ;;
        under) dl+="${RED}${key}:under${RST}  " ;;
        *) dl+="${DIM}${key}:-${RST}  " ;;
      esac
    done
    _box_line "$dl"
  fi

  _box_bottom
  echo -ne "${OVR} $(date +%H:%M:%S) │ ${INTERVAL}s${RST}"
}

# ─── TUI lifecycle ───

_tui_enter() {
  tput smcup
  tput civis
  tput clear
}
_tui_exit() {
  tput cnorm
  tput rmcup
}
_tui_frame() { tput home; }
_tui_flush() { tput ed; }

# ─── Loop ───

FILE_SEEN=false

if [[ "$ONCE" == true ]]; then
  render
else
  trap '_tui_exit; exit 0' INT TERM EXIT
  _tui_enter
  while true; do
    if [[ -f "$STATE_FILE" ]]; then
      FILE_SEEN=true
    elif [[ "$FILE_SEEN" == true ]]; then
      _tui_frame
      W=$(tput cols 2>/dev/null || echo 80)
      [[ $W -gt 80 ]] && W=80
      _box_top
      _box_line "${BLD}${GREEN}SPIRAL COMPLETE${RST}"
      _box_line "${SUB}State file archived. Closing in 3s...${RST}"
      _box_bottom
      _tui_flush
      sleep 3
      exit 0
    fi
    frame=$(render)
    _tui_frame
    while IFS= read -r line; do
      printf '%s\033[K\n' "$line"
    done <<<"$frame"
    _tui_flush
    sleep "$INTERVAL"
  done
fi
