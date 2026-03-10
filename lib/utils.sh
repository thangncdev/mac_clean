#!/usr/bin/env bash
# lib/utils.sh - Format size, safe delete, logging

MAC_CLEAN_LOG="${HOME}/.mac_clean.log"

# Convert bytes to human-readable (KB, MB, GB)
format_bytes() {
  local bytes="$1"
  if [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
    echo "0 B"
    return
  fi
  if (( bytes >= 1073741824 )); then
    echo "$(( bytes / 1073741824 )) GB"
  elif (( bytes >= 1048576 )); then
    echo "$(( bytes / 1048576 )) MB"
  elif (( bytes >= 1024 )); then
    echo "$(( bytes / 1024 )) KB"
  else
    echo "${bytes} B"
  fi
}

# Parse human size (e.g. 100MB, 1G) to bytes for find -size
# find uses 512-byte blocks for -size +n, so we convert to blocks
size_to_find_blocks() {
  local spec="$1"
  local num block=512
  if [[ "$spec" =~ ^([0-9]+)([kKmMgG])?[bB]?$ ]]; then
    num="${BASH_REMATCH[1]}"
    case "${BASH_REMATCH[2]:-}" in
      [kK]) num=$(( num * 1024 )) ;;
      [mM]) num=$(( num * 1048576 )) ;;
      [gG]) num=$(( num * 1073741824 )) ;;
    esac
    echo $(( (num + block - 1) / block ))
  else
    echo 0
  fi
}

# Log an action to ~/.mac_clean.log
log_action() {
  local action="$1"
  local target="$2"
  local result="${3:-ok}"
  printf "[%s] %s | %s | %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$action" "$target" "$result" >> "$MAC_CLEAN_LOG"
}

# Safe delete: check path exists, then rm -rf, log result
safe_delete() {
  local path="$1"
  if [[ -z "$path" || "$path" == "/" ]]; then
    log_action "DELETE" "$path" "rejected"
    return 1
  fi
  path=$(eval "echo $path")
  if [[ ! -e "$path" ]]; then
    log_action "DELETE" "$path" "not_found"
    return 0
  fi
  if rm -rf "$path" 2>/dev/null; then
    log_action "DELETE" "$path" "ok"
    return 0
  else
    log_action "DELETE" "$path" "failed"
    return 1
  fi
}
