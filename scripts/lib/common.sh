#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
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

ensure_dirs() {
  local mode="$1"; shift
  local symbolic
  symbolic=$(mode_to_symbolic "$mode")
  
  local d
  for d in "$@"; do
    mkdir -p -m "$mode" "$d"
    if [[ "${SILENT:-false}" != "true" ]]; then
      echo "[+] (${symbolic}) ${d}"
    fi
  done
}

remove_dirs() {
  local d
  for d in "$@"; do
    rm -rf -- "$d"
    if [[ "${SILENT:-false}" != "true" ]]; then
      echo "[-] ${d}"
    fi
  done
}

state_markers_exist() {
  [[ -d "${STATE_DIR}" ]] && \
  [[ -n "$(ls -A "${STATE_DIR}" 2>/dev/null)" ]]
}

readonly -a BASE_CMDS=(
  bash
  sed
  awk
  grep
)

check_base_prereqs() {
  require_cmd "${BASE_CMDS[@]}"
}

check_component_prereqs() {
  if declare -p required_cmds >/dev/null 2>&1; then
    require_cmd "${required_cmds[@]}"
  fi
}
