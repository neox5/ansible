#!/usr/bin/env bash
set -euo pipefail

create_lock() {
  date +%s > "${STATE_DIR}/${COMPONENT}.lock"
}

remove_lock() {
  rm -f "${STATE_DIR}/${COMPONENT}.lock"
}

is_installed() {
  local component="${1:-${COMPONENT}}"
  [[ -f "${STATE_DIR}/${component}.lock" ]]
}

require_sys_init() {
  [[ -f "${STATE_DIR}/sys.lock" ]] || die "system not initialized (run: ./run sys init)"
}

require_installed() {
  local component="${1:-${COMPONENT}}"
  is_installed "$component" || die "${component} not installed (run: ./run ${component} install)"
}

installed_count() {
  [[ -d "${STATE_DIR}" ]] || { echo 0; return; }
  find "${STATE_DIR}" -name "*.lock" 2>/dev/null | wc -l
}
