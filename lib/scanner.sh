#!/usr/bin/env bash
# lib/scanner.sh - Scan large files/dirs with live progress

# Normalize size spec to find -size argument (macOS BSD find supports c/k/M/G suffixes)
# Converts: 100M -> 100M, 1g -> 1G, 500kb -> 500k, 100mb -> 100M
_normalize_find_size() {
  local spec="${1:-100M}"
  spec=$(echo "$spec" | tr '[:lower:]' '[:upper:]' | sed 's/B$//' | sed 's/BYTE.*//')
  # Map K->k, keep M G as-is; default M if no suffix
  case "$spec" in
    *K) echo "${spec%K}k" ;;
    *M) echo "$spec" ;;
    *G) echo "$spec" ;;
    *[0-9]) echo "${spec}M" ;;
    *) echo "100M" ;;
  esac
}

# Interactive scan for large files with live progress
run_scan_files_interactive() {
  local path="${1:-$HOME}"
  local min_size="${2:-100M}"
  path=$(eval "echo $path")
  local find_size
  find_size=$(_normalize_find_size "$min_size")

  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}Scan Large Files${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  printf "  Path: ${BOLD}%s${NC}\n" "$path"
  printf "  Min size: ${BOLD}%s${NC}\n" "$min_size"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  echo ""

  local tmpfile
  tmpfile=$(mktemp /tmp/mac_clean_scan_XXXXX)
  local found=0 scanned=0

  printf "  ${CYAN}⠿${NC}  Starting scan...\n"
  echo ""

  while IFS= read -r f; do
    (( scanned++ ))
    show_scan_line "$f" "$found"
    local bytes
    bytes=$(stat -f%z "$f" 2>/dev/null)
    if [[ -n "$bytes" && "$bytes" -gt 0 ]]; then
      printf "%s\t%s\n" "$bytes" "$f" >> "$tmpfile"
      (( found++ ))
    fi
  done < <(find "$path" -type f -size "+${find_size}" 2>/dev/null)

  printf "\r  ${GREEN}✓${NC}  Scan complete.  ${BOLD}%d${NC} file(s) found  (scanned %d items)%20s\n" \
    "$found" "$scanned" ""

  if [[ $found -eq 0 ]]; then
    rm -f "$tmpfile"
    echo ""
    echo -e "  ${YELLOW}No files larger than ${min_size} found.${NC}"
    echo -e "  ${DIM}Tip: try a smaller threshold (e.g. 50M) in Settings.${NC}"
    pause
    return 0
  fi

  local sorted_tmp="${tmpfile}.sorted"
  sort -t$'\t' -k1 -rn "$tmpfile" > "$sorted_tmp"
  rm -f "$tmpfile"

  local -a lines options
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local bytes p
    bytes="${line%%	*}"
    p="${line#*	}"
    lines+=("$line")
    options+=("$(format_bytes "$bytes")  $p")
  done < "$sorted_tmp"
  rm -f "$sorted_tmp"

  options+=("── Back to main menu ──")

  while true; do
    draw_menu "  Large files (>${min_size}) — select to delete" "${options[@]}"
    if [[ $MENU_CHOICE -eq 0 || $MENU_INDEX -eq $((${#options[@]} - 1)) ]]; then
      return 0
    fi
    local chosen="${lines[$MENU_INDEX]}"
    local path_to_del="${chosen#*	}"
    tput cnorm 2>/dev/null
    clear_screen
    print_section "Confirm Delete"
    printf "  File:  ${BOLD}%s${NC}\n" "$path_to_del"
    printf "  Size:  ${BOLD}%s${NC}\n" "$(format_bytes "${chosen%%	*}")"
    if confirm_dialog "Delete this file?"; then
      safe_delete "$path_to_del"
      echo -e "\n  ${GREEN}✓${NC}  Deleted."
      unset 'lines[MENU_INDEX]' 'options[MENU_INDEX]'
      lines=("${lines[@]}")
      options=("${options[@]}")
      options[${#options[@]} - 1]="── Back to main menu ──"
      [[ ${#options[@]} -le 1 ]] && { pause; return 0; }
    fi
    pause
  done
}

# Interactive scan for large directories with live progress
run_scan_dirs_interactive() {
  local path="${1:-$HOME}"
  path=$(eval "echo $path")

  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}Scan Large Directories${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  printf "  Path: ${BOLD}%s${NC}\n" "$path"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  echo ""

  start_spinner "Calculating directory sizes..."

  local tmpfile
  tmpfile=$(mktemp /tmp/mac_clean_dirs_XXXXX)

  # Enumerate all immediate children (visible + hidden) then du -sk each
  local entry
  while IFS= read -r -d '' entry; do
    [[ ! -e "$entry" ]] && continue
    show_scan_line "$entry" "$(wc -l < "$tmpfile" 2>/dev/null || echo 0)"
    local kb
    kb=$(du -sk "$entry" 2>/dev/null | awk '{print $1}')
    [[ -n "$kb" && "$kb" -gt 0 ]] && printf "%s\t%s\n" "$(( kb * 1024 ))" "$entry" >> "$tmpfile"
  done < <(find "$path" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)
  printf "\r%80s\r" ""

  stop_spinner

  if [[ ! -s "$tmpfile" ]]; then
    rm -f "$tmpfile"
    echo -e "  ${YELLOW}No directories found under: ${path}${NC}"
    pause
    return 0
  fi

  local sorted_tmp="${tmpfile}.sorted"
  sort -t$'\t' -k1 -rn "$tmpfile" | head -100 > "$sorted_tmp"
  rm -f "$tmpfile"

  local -a lines options
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local bytes p
    bytes="${line%%	*}"
    p="${line#*	}"
    lines+=("$line")
    options+=("$(format_bytes "$bytes")  $p")
  done < "$sorted_tmp"
  rm -f "$sorted_tmp"

  options+=("── Back to main menu ──")

  while true; do
    draw_menu "  Large directories — select to delete" "${options[@]}"
    if [[ $MENU_CHOICE -eq 0 || $MENU_INDEX -eq $((${#options[@]} - 1)) ]]; then
      return 0
    fi
    local chosen="${lines[$MENU_INDEX]}"
    local path_to_del="${chosen#*	}"
    tput cnorm 2>/dev/null
    clear_screen
    print_section "Confirm Delete"
    printf "  Directory: ${BOLD}%s${NC}\n" "$path_to_del"
    printf "  Size:      ${BOLD}%s${NC}\n" "$(format_bytes "${chosen%%	*}")"
    echo -e "  ${RED}Warning: all contents inside will be removed!${NC}"
    if confirm_dialog "Delete this directory?"; then
      safe_delete "$path_to_del"
      echo -e "\n  ${GREEN}✓${NC}  Deleted."
      unset 'lines[MENU_INDEX]' 'options[MENU_INDEX]'
      lines=("${lines[@]}")
      options=("${options[@]}")
      options[${#options[@]} - 1]="── Back to main menu ──"
      [[ ${#options[@]} -le 1 ]] && { pause; return 0; }
    fi
    pause
  done
}
