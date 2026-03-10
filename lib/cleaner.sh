#!/usr/bin/env bash
# lib/cleaner.sh - Clean common caches, iOS and Android developer artifacts

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

# Emit "BYTES\tLABEL\tPATH" lines for each directory matching a glob pattern
_emit_glob_entries() {
  local glob_pattern="$1"
  local label_prefix="$2"
  local dir
  for dir in $glob_pattern; do
    [[ -d "$dir" ]] || continue
    local bytes
    bytes=$(du -sk "$dir" 2>/dev/null | awk '{ print $1 * 1024 }')
    [[ -n "$bytes" && "$bytes" -gt 0 ]] && \
      printf "%s\t%s (%s)\t%s\n" "$bytes" "$label_prefix" "$(basename "$dir")" "$dir"
  done
}

# Shared interactive cleaner UI — used by iOS, Android (and anything else with same shape)
# Usage: _run_clean_section_interactive "Title" "Warning" list_function_name
_run_clean_section_interactive() {
  local title="$1"
  local warning="$2"
  local list_fn="$3"

  clear_screen
  echo ""
  echo -e "  ${BOLD}${BLUE}${title}${NC}"
  echo -e "  ${DIM}────────────────────────────────────────────${NC}"
  [[ -n "$warning" ]] && echo -e "  ${YELLOW}${warning}${NC}"
  echo ""

  start_spinner "Calculating sizes..."
  local list
  list=$("$list_fn")
  stop_spinner

  if [[ -z "$list" ]]; then
    echo -e "  ${YELLOW}No relevant directories found or all empty.${NC}"
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
    draw_menu "  ${title} — select to delete" "${options[@]}"
    if [[ $MENU_CHOICE -eq 0 ]]; then return 0; fi

    local back_idx=$(( ${#options[@]} - 1 ))
    local all_idx=$(( ${#options[@]} - 2 ))

    if [[ $MENU_INDEX -eq $back_idx ]]; then return 0; fi

    if [[ $MENU_INDEX -eq $all_idx ]]; then
      tput cnorm 2>/dev/null
      clear_screen
      print_section "Clean ALL"
      echo -e "  This will delete ${BOLD}$(format_bytes "$total")${NC} of developer artifacts."
      [[ -n "$warning" ]] && echo -e "  ${RED}${warning}${NC}"
      if confirm_dialog "Proceed?"; then
        local n=0
        for line in "${lines[@]}"; do
          [[ -z "$line" ]] && continue
          local p="${line##*	}"
          safe_delete "$p" && (( n++ )) || true
          printf "\r  ${GREEN}✓${NC}  %-70s" "$p"
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
    printf "  Item:  ${BOLD}%s${NC}\n" "$entry_label"
    printf "  Path:  ${DIM}%s${NC}\n" "$(eval "echo $path_to_del")"
    printf "  Size:  ${BOLD}%s${NC}\n" "$(format_bytes "${chosen%%	*}")"
    if confirm_dialog "Delete?"; then
      safe_delete "$path_to_del"
      echo -e "\n  ${GREEN}✓${NC}  Deleted."
    fi
    pause
  done
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
  _run_clean_section_interactive \
    "Clean Common Caches" \
    "" \
    "get_common_caches"
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
  _run_clean_section_interactive \
    "iOS / Xcode Development Clean" \
    "Deleting DerivedData / Simulators requires a full rebuild next time." \
    "get_ios_caches"
}

# ─────────────────────────────────────────────
# ANDROID DEVELOPER CLEAN
# ─────────────────────────────────────────────

# Returns entries with size > 0: "BYTES\tLABEL\tPATH"
get_android_caches() {
  # Fixed paths
  local fixed_entries=(
    "~/.gradle/caches	Gradle dependency cache"
    "~/.gradle/wrapper/dists	Gradle wrapper distributions"
    "~/.gradle/daemon	Gradle daemon logs"
    "~/.android/avd	Android Virtual Devices (AVD)"
    "~/.android/cache	Android SDK tools cache"
    "~/Library/Android/sdk/system-images	Android SDK system images"
    "~/Library/Android/sdk/temp	Android SDK temp files"
    "~/.kotlin/daemon	Kotlin daemon logs"
    "~/.android/.android	Android credentials cache"
  )

  local entry path label bytes
  for entry in "${fixed_entries[@]}"; do
    path="${entry%%	*}"
    label="${entry#*	}"
    bytes=$(dir_size_bytes "$path")
    [[ "$bytes" -gt 0 ]] && printf "%s\t%s\t%s\n" "$bytes" "$label" "$path"
  done

  # Android Studio IDE caches (multiple versions may exist)
  _emit_glob_entries "$HOME/Library/Caches/Google/AndroidStudio*"    "Android Studio IDE Cache"
  _emit_glob_entries "$HOME/Library/Logs/Google/AndroidStudio*"      "Android Studio Logs"
  _emit_glob_entries "$HOME/Library/Caches/JetBrains/AndroidStudio*" "Android Studio IDE Cache (JB)"
  _emit_glob_entries "$HOME/Library/Logs/JetBrains/AndroidStudio*"   "Android Studio Logs (JB)"
}

# Interactive Android developer cleaner
run_clean_android_interactive() {
  _run_clean_section_interactive \
    "Android Development Clean" \
    "Deleting Gradle cache will require re-downloading dependencies on next build." \
    "get_android_caches"
}
