#!/usr/bin/env bash
# lib/cleaner.sh - Clean common caches and iOS developer artifacts

# Get directory size in bytes (0 if not exist)
dir_size_bytes() {
  local path
  path=$(eval "echo $1")
  if [[ ! -d "$path" ]]; then
    echo 0
    return
  fi
  du -sk "$path" 2>/dev/null | awk '{ print $1 * 1024 }'
}

# ─────────────────────────────────────────────
# COMMON CACHES
# ─────────────────────────────────────────────

# Returns entries with size > 0: "BYTES\tLABEL\tPATH"
get_common_caches() {
  local brew_cache=""
  command -v brew &>/dev/null && brew_cache=$(brew --cache 2>/dev/null)

  local entries=(
    "~/Library/Caches	User Caches"
    "~/Library/Logs	User Logs"
    "~/.npm/_cacache	npm cache"
    "~/.yarn/cache	Yarn cache"
    "~/Library/Caches/pip	pip cache (Library)"
    "~/.cache/pip	pip cache (home)"
    "~/.gradle/caches	Gradle caches"
    "~/.m2/repository	Maven repository"
    "~/.Trash	Trash"
  )
  [[ -n "$brew_cache" ]] && entries+=("$brew_cache	Homebrew cache")

  local entry path label bytes
  for entry in "${entries[@]}"; do
    path="${entry%%	*}"
    label="${entry#*	}"
    bytes=$(dir_size_bytes "$path")
    [[ "$bytes" -gt 0 ]] && printf "%s\t%s\t%s\n" "$bytes" "$label" "$path"
  done
}

# Interactive common cache cleaner
run_clean_caches_interactive() {
  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}Clean Common Caches${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  echo ""

  start_spinner "Calculating cache sizes..."
  local list
  list=$(get_common_caches)
  stop_spinner

  if [[ -z "$list" ]]; then
    echo -e "  ${YELLOW}All cache directories are empty or missing.${NC}"
    pause
    return 0
  fi

  local -a lines options
  local total=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local bytes label
    bytes="${line%%	*}"
    label="${line#*	}"; label="${label%%	*}"
    lines+=("$line")
    options+=("$(printf '%-10s' "$(format_bytes "$bytes")")  $label")
    total=$(( total + bytes ))
  done <<< "$list"

  options+=("$(printf '%-10s' "$(format_bytes "$total")")  *** Clean ALL above ***")
  options+=("── Back to main menu ──")

  while true; do
    draw_menu "  Common Caches — select to delete" "${options[@]}"
    if [[ $MENU_CHOICE -eq 0 ]]; then return 0; fi

    local back_idx=$(( ${#options[@]} - 1 ))
    local all_idx=$(( ${#options[@]} - 2 ))

    if [[ $MENU_INDEX -eq $back_idx ]]; then return 0; fi

    if [[ $MENU_INDEX -eq $all_idx ]]; then
      tput cnorm 2>/dev/null
      clear_screen
      print_section "Clean ALL Caches"
      echo -e "  This will delete ALL listed cache directories (${BOLD}$(format_bytes "$total")${NC} total)."
      if confirm_dialog "Proceed?"; then
        local n=0
        for line in "${lines[@]}"; do
          [[ -z "$line" ]] && continue
          local p="${line##*	}"
          safe_delete "$p" && (( n++ )) || true
          printf "\r  ${GREEN}✓${NC}  Cleaned %-60s" "$p"
        done
        printf "\r%80s\r" ""
        echo -e "  ${GREEN}✓${NC}  Done — cleaned ${BOLD}$n${NC} location(s)."
      fi
      pause
      return 0
    fi

    local chosen="${lines[$MENU_INDEX]}"
    local path_to_del="${chosen##*	}"
    local entry_label="${chosen#*	}"; entry_label="${entry_label%%	*}"
    tput cnorm 2>/dev/null
    clear_screen
    print_section "Confirm Delete"
    printf "  Cache:  ${BOLD}%s${NC}\n" "$entry_label"
    printf "  Path:   ${DIM}%s${NC}\n" "$(eval "echo $path_to_del")"
    printf "  Size:   ${BOLD}%s${NC}\n" "$(format_bytes "${chosen%%	*}")"
    if confirm_dialog "Delete this cache?"; then
      safe_delete "$path_to_del"
      echo -e "\n  ${GREEN}✓${NC}  Deleted."
    fi
    pause
  done
}

# ─────────────────────────────────────────────
# iOS / XCODE DEVELOPER CLEAN
# ─────────────────────────────────────────────

# Returns entries with size > 0: "BYTES\tLABEL\tPATH"
get_ios_caches() {
  local entries=(
    "~/Library/Developer/Xcode/DerivedData	Xcode DerivedData (build artifacts)"
    "~/Library/Developer/Xcode/Archives	Xcode Archives (.xcarchive)"
    "~/Library/Developer/Xcode/iOS DeviceSupport	iOS Device Support (IPSW symbols)"
    "~/Library/Developer/Xcode/watchOS DeviceSupport	watchOS Device Support"
    "~/Library/Developer/Xcode/tvOS DeviceSupport	tvOS Device Support"
    "~/Library/Developer/Xcode/visionOS DeviceSupport	visionOS Device Support"
    "~/Library/Developer/CoreSimulator/Devices	Simulator Runtimes & Devices"
    "~/Library/Developer/CoreSimulator/Caches	CoreSimulator Caches"
    "~/Library/Caches/com.apple.dt.Xcode	Xcode IDE Cache"
    "~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex	Xcode Module Cache"
    "~/Library/Caches/org.swift.swiftpm	Swift Package Manager cache"
    "~/.swiftpm/cache	SPM local cache"
    "~/Library/Developer/Xcode/UserData/IB Support	Interface Builder Support"
  )

  local entry path label bytes
  for entry in "${entries[@]}"; do
    path="${entry%%	*}"
    label="${entry#*	}"
    bytes=$(dir_size_bytes "$path")
    [[ "$bytes" -gt 0 ]] && printf "%s\t%s\t%s\n" "$bytes" "$label" "$path"
  done
}

# Interactive iOS developer cleaner
run_clean_ios_interactive() {
  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}iOS / Xcode Development Clean${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  echo -e "  ${YELLOW}Note: Deleting DerivedData / Simulators will require a full rebuild.${NC}"
  echo ""

  start_spinner "Calculating Xcode artifact sizes..."
  local list
  list=$(get_ios_caches)
  stop_spinner

  if [[ -z "$list" ]]; then
    echo -e "  ${YELLOW}No Xcode/iOS directories found or all empty.${NC}"
    echo -e "  ${DIM}Make sure Xcode has been used at least once.${NC}"
    pause
    return 0
  fi

  local -a lines options
  local total=0
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local bytes label
    bytes="${line%%	*}"
    label="${line#*	}"; label="${label%%	*}"
    lines+=("$line")
    options+=("$(printf '%-10s' "$(format_bytes "$bytes")")  $label")
    total=$(( total + bytes ))
  done <<< "$list"

  options+=("$(printf '%-10s' "$(format_bytes "$total")")  *** Clean ALL above ***")
  options+=("── Back to main menu ──")

  while true; do
    draw_menu "  iOS/Xcode Artifacts — select to delete" "${options[@]}"
    if [[ $MENU_CHOICE -eq 0 ]]; then return 0; fi

    local back_idx=$(( ${#options[@]} - 1 ))
    local all_idx=$(( ${#options[@]} - 2 ))

    if [[ $MENU_INDEX -eq $back_idx ]]; then return 0; fi

    if [[ $MENU_INDEX -eq $all_idx ]]; then
      tput cnorm 2>/dev/null
      clear_screen
      print_section "Clean ALL Xcode/iOS Artifacts"
      echo -e "  This will delete ${BOLD}$(format_bytes "$total")${NC} of Xcode/iOS developer data."
      echo -e "  ${RED}Your next build and simulator boot will take longer.${NC}"
      if confirm_dialog "Proceed with full Xcode clean?"; then
        local n=0
        for line in "${lines[@]}"; do
          [[ -z "$line" ]] && continue
          local p="${line##*	}"
          safe_delete "$p" && (( n++ )) || true
          printf "\r  ${GREEN}✓${NC}  Cleaned %-60s" "$p"
        done
        printf "\r%80s\r" ""
        echo -e "  ${GREEN}✓${NC}  Done — cleaned ${BOLD}$n${NC} location(s)."
      fi
      pause
      return 0
    fi

    local chosen="${lines[$MENU_INDEX]}"
    local path_to_del="${chosen##*	}"
    local entry_label="${chosen#*	}"; entry_label="${entry_label%%	*}"
    tput cnorm 2>/dev/null
    clear_screen
    print_section "Confirm Delete"
    printf "  Item:   ${BOLD}%s${NC}\n" "$entry_label"
    printf "  Path:   ${DIM}%s${NC}\n" "$(eval "echo $path_to_del")"
    printf "  Size:   ${BOLD}%s${NC}\n" "$(format_bytes "${chosen%%	*}")"
    if confirm_dialog "Delete?"; then
      safe_delete "$path_to_del"
      echo -e "\n  ${GREEN}✓${NC}  Deleted."
    fi
    pause
  done
}
