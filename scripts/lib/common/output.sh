#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

mode_to_symbolic() {
  local mode="$1"
  local perms=""
  
  # Convert octal mode to symbolic (e.g., 0755 -> rwxr-xr-x)
  # Extract last 3 digits (ignore leading 0)
  local user=$((8#${mode:1:1}))
  local group=$((8#${mode:2:1}))
  local other=$((8#${mode:3:1}))
  
  # User permissions
  [[ $((user & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((user & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((user & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  # Group permissions
  [[ $((group & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((group & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((group & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  # Other permissions
  [[ $((other & 4)) -ne 0 ]] && perms+="r" || perms+="-"
  [[ $((other & 2)) -ne 0 ]] && perms+="w" || perms+="-"
  [[ $((other & 1)) -ne 0 ]] && perms+="x" || perms+="-"
  
  echo "$perms"
}

log_operation() {
  local action="$1"
  local type="$2"
  local mode="$3"
  local path="$4"
  
  # Respect silent mode
  [[ "${SILENT:-false}" == "true" ]] && return 0
  
  # Format: [action] type (perms) path
  # or:     [action] type          path  (when mode is empty)
  
  if [[ -n "$mode" ]]; then
    local symbolic
    symbolic=$(mode_to_symbolic "$mode")
    printf "[%s] %-4s (%s) %s\n" "$action" "$type" "$symbolic" "$path"
  else
    printf "[%s] %-4s %10s %s\n" "$action" "$type" "" "$path"
  fi
}
