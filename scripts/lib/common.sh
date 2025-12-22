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

ensure_dirs() {
  local mode="$1"; shift
  local d
  for d in "$@"; do
    mkdir -p -m "$mode" "$d"
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
