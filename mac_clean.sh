#!/usr/bin/env bash
# mac_clean.sh - Mac Clean CLI - Interactive TUI
# Usage: ./mac_clean.sh

set +e
MAC_CLEAN_VERSION="1.0"

# Resolve symlinks to find the real script directory
_resolve_script_dir() {
  local src="${BASH_SOURCE[0]}"
  local dir
  while [[ -L "$src" ]]; do
    dir="$(cd "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="$dir/$src"
  done
  cd "$(dirname "$src")" && pwd
}
SCRIPT_DIR="$(_resolve_script_dir)"

source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/scanner.sh"
source "$SCRIPT_DIR/lib/cleaner.sh"

main() {
  local main_options=(
    "  Scan Large Files"
    "  Scan Large Directories"
    "  Clean Common Caches"
    "  iOS / Xcode Development Clean"
    "  View Last Report"
    "  Settings"
    "  Quit"
  )

  while true; do
    MENU_HEADER_FN="draw_disk_info"
    draw_menu "  MAC CLEAN  v${MAC_CLEAN_VERSION}" "${main_options[@]}"
    MENU_HEADER_FN=""

    case "$MENU_INDEX" in
      0) run_scan_files_interactive "${SCAN_PATH:-$HOME}" "${MIN_SIZE:-100M}" ;;
      1) run_scan_dirs_interactive "${SCAN_PATH:-$HOME}" ;;
      2) run_clean_caches_interactive ;;
      3) run_clean_ios_interactive ;;
      4) view_last_report ;;
      5) run_settings ;;
      6|-1) exit 0 ;;
    esac
  done
}

view_last_report() {
  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}Last Report${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  if [[ -f "$MAC_CLEAN_LOG" ]]; then
    echo ""
    tail -60 "$MAC_CLEAN_LOG" | while IFS= read -r line; do
      echo "  $line"
    done
  else
    echo ""
    echo -e "  ${DIM}No actions logged yet. Deleted items will appear here.${NC}"
  fi
  pause
}

run_settings() {
  local opts=(
    "  Change scan path        [current: ${SCAN_PATH:-$HOME}]"
    "  Change min file size    [current: ${MIN_SIZE:-100M}]"
    "  ── Back ──"
  )
  draw_menu "  Settings" "${opts[@]}"
  if [[ $MENU_CHOICE -eq 0 || $MENU_INDEX -eq 2 ]]; then return 0; fi

  tput cnorm 2>/dev/null
  clear_screen
  echo ""

  if [[ $MENU_INDEX -eq 0 ]]; then
    printf "  Current path: ${BOLD}%s${NC}\n" "${SCAN_PATH:-$HOME}"
    read -rp "  New scan path (Enter to keep current): " new_path
    if [[ -n "$new_path" ]]; then
      if [[ -d "$new_path" ]]; then
        SCAN_PATH="$new_path"
        export SCAN_PATH
        echo -e "  ${GREEN}✓${NC}  Scan path set to: ${BOLD}$SCAN_PATH${NC}"
      else
        echo -e "  ${RED}✗${NC}  Directory does not exist: $new_path"
      fi
    fi
  elif [[ $MENU_INDEX -eq 1 ]]; then
    printf "  Current min size: ${BOLD}%s${NC}\n" "${MIN_SIZE:-100M}"
    read -rp "  New min size (e.g. 50M, 1G — Enter to keep current): " new_size
    if [[ -n "$new_size" ]]; then
      MIN_SIZE="$new_size"
      export MIN_SIZE
      echo -e "  ${GREEN}✓${NC}  Min file size set to: ${BOLD}$MIN_SIZE${NC}"
    fi
  fi
  pause
}

main "$@"
