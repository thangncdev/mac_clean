#!/usr/bin/env bash
# lib/ui.sh - Interactive TUI: menu, colors, progress bar, confirm dialog

# Colors (ANSI)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Optional header function name to call inside draw_menu (used for disk info on main menu)
MENU_HEADER_FN=""

# Draw disk usage bar (called via MENU_HEADER_FN)
draw_disk_info() {
  # On macOS APFS, '/' is the sealed system volume (small Used).
  # '/System/Volumes/Data' holds user data. Available is shared across both.
  # Used = Total - Available gives the real picture regardless of volume split.
  local info
  info=$(df -k /System/Volumes/Data 2>/dev/null | awk 'NR==2 {printf "%d %d %d", $2*1024, ($2-$4)*1024, $4*1024}')
  if [[ -z "$info" ]]; then
    info=$(df -k / 2>/dev/null | awk 'NR==2 {printf "%d %d %d", $2*1024, ($2-$4)*1024, $4*1024}')
  fi
  [[ -z "$info" ]] && return
  local total used avail pct color i
  read -r total used avail <<< "$info"
  [[ $total -eq 0 ]] && return
  pct=$(( used * 100 / total ))
  local total_h used_h avail_h
  total_h=$(format_bytes "$total")
  used_h=$(format_bytes "$used")
  avail_h=$(format_bytes "$avail")

  color="$GREEN"
  (( pct >= 80 )) && color="$YELLOW"
  (( pct >= 90 )) && color="$RED"

  local bar_width=36 filled=$(( 36 * pct / 100 )) empty
  empty=$(( bar_width - filled ))
  local bar=""
  for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
  for (( i=0; i<empty; i++ )); do bar="${bar}░"; done

  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  printf "  ${BOLD}Macintosh HD${NC}  ${DIM}(/)${NC}  ${BOLD}%s${NC} total\n" "$total_h"
  echo -e "  ${color}${bar}${NC}  ${BOLD}${pct}%%${NC}"
  printf "  Used: ${BOLD}%-10s${NC}  Free: ${color}${BOLD}%s${NC}\n" "$used_h" "$avail_h"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
}

# Draw interactive menu with arrow key navigation
# Usage: draw_menu "Title" "opt1" "opt2" ...
# Sets MENU_CHOICE (1-based, 0=quit) and MENU_INDEX (0-based, -1=quit)
draw_menu() {
  local title="$1"
  shift
  local options=("$@")
  local selected=0
  local key=""

  while true; do
    clear_screen
    tput civis 2>/dev/null
    echo ""
    echo -e "  ${BOLD}${BLUE}${title}${NC}"
    [[ -n "${MENU_HEADER_FN:-}" ]] && "$MENU_HEADER_FN"
    echo ""
    for i in "${!options[@]}"; do
      if [[ $i -eq $selected ]]; then
        echo -e "  ${GREEN}▶${NC} ${BOLD}${options[$i]}${NC}"
      else
        echo -e "    ${DIM}${options[$i]}${NC}"
      fi
    done
    echo ""
    echo -e "  ${DIM}[↑↓] Navigate  [Enter] Select  [q] Back/Quit${NC}"

    read -rsn1 key
    case "$key" in
      $'\x1b')
        read -rsn2 key
        case "$key" in
          '[A') (( selected > 0 )) && (( selected-- )) ;;
          '[B') (( selected < ${#options[@]} - 1 )) && (( selected++ )) ;;
        esac
        ;;
      '')
        tput cnorm 2>/dev/null
        MENU_CHOICE=$(( selected + 1 ))
        MENU_INDEX=$selected
        return 0
        ;;
      'q'|'Q')
        tput cnorm 2>/dev/null
        MENU_CHOICE=0
        MENU_INDEX=-1
        return 0
        ;;
    esac
  done
}

# Spinner for long background operations
# Usage: start_spinner "message"; ...; stop_spinner
_SPINNER_PID=""
start_spinner() {
  local msg="${1:-Working...}"
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  (
    while true; do
      for frame in "${frames[@]}"; do
        printf "\r  ${CYAN}%s${NC}  %s " "$frame" "$msg"
        sleep 0.1
      done
    done
  ) &
  _SPINNER_PID=$!
}

stop_spinner() {
  if [[ -n "${_SPINNER_PID:-}" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null
    wait "$_SPINNER_PID" 2>/dev/null
    _SPINNER_PID=""
    printf "\r%60s\r" ""
  fi
}

# Show live scanning line (update in place)
show_scan_line() {
  local current_file="$1"
  local found="${2:-0}"
  printf "\r  ${DIM}[%d found]${NC} ${CYAN}▸${NC} %-65.65s" "$found" "$current_file"
}

# Confirm dialog: confirm_dialog "Question?"  Returns 0=Yes, 1=No
confirm_dialog() {
  local prompt="$1"
  local default="${2:-n}"
  tput cnorm 2>/dev/null
  echo ""
  if [[ "$default" == "y" ]]; then
    read -rp "  $prompt [Y/n]: " ans
    case "${ans:-y}" in
      [nN]) return 1 ;;
      *) return 0 ;;
    esac
  else
    read -rp "  $prompt [y/N]: " ans
    case "${ans:-n}" in
      [yY]) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

# Print a styled section header
print_section() {
  local title="$1"
  echo ""
  echo -e "  ${BOLD}${CYAN}▸ ${title}${NC}"
  echo -e "  ${DIM}$(printf '─%.0s' {1..50})${NC}"
}

# Print table from stdin: lines are "SIZE\tPATH"
print_table() {
  local header1="${1:-Size}"
  local header2="${2:-Path}"
  echo ""
  printf "  ${BOLD}%-12s %s${NC}\n" "$header1" "$header2"
  echo -e "  ${DIM}$(printf '─%.0s' {1..70})${NC}"
  while IFS= read -r line; do
    local size path
    size="${line%%	*}"
    path="${line#*	}"
    printf "  %-12s %s\n" "$size" "$path"
  done
}

# Clear screen
clear_screen() {
  clear 2>/dev/null || printf '\033[2J\033[H'
}

# Pause and wait for key
pause() {
  echo ""
  tput cnorm 2>/dev/null
  read -rp "  Press Enter to continue..."
}
