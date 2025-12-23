#!/usr/bin/env bash
set -euo pipefail

supported_verbs=(
  init
  cleanup
  tree
)

required_cmds=(
  tree
)

c_init() {
  ensure_dirs 0755 \
    "${STATE_DIR}" \
    "${ETC_ROOT}" \
    "${SHARE_ROOT}"
  
  create_lock
}

c_cleanup() {
  local lock_count
  lock_count=$(installed_count)
  
  if [[ "$lock_count" -ne 1 ]]; then
    echo "error: cannot cleanup - components still installed:" >&2
    ls "${STATE_DIR}"/*.lock 2>/dev/null | \
      grep -v 'sys.lock$' | \
      sed 's|.*/||; s|\.lock$||' | \
      sed 's/^/  - /' >&2
    exit 1
  fi
  
  remove_lock
  remove_dirs "${VAR_ROOT}" "${ETC_ROOT}" "${SHARE_ROOT}"
}

c_tree() {
  [[ -d "${STATE_DIR}" ]] || die "system not initialized (run: ./run sys init)"
  
  # Silent mode: no output
  [[ "${SILENT:-false}" == "true" ]] && return 0
  
  local tree_args=("$@")
  if [[ "${#tree_args[@]}" -eq 0 ]]; then
    tree_args=(-C --noreport)
  else
    tree_args+=(--noreport)
  fi
  
  # Main directories
  for dir in "${SHARE_ROOT}" "${ETC_ROOT}" "${VAR_ROOT}"; do
    tree "${tree_args[@]}" "${dir}" 2>/dev/null || true
    echo ""
  done
  
  # Systemd units - Level 1 service files only
  tree "${tree_args[@]}" -L 1 -P "*.service" --prune "${SYSTEMD_UNIT_DIR}"
  echo ""
  
  # multi-user.target.wants - all service files
  local target_dir="${SYSTEMD_UNIT_DIR}/multi-user.target.wants"
  if [[ -d "${target_dir}" ]]; then
    tree "${tree_args[@]}" -P "*.service" "${target_dir}" 2>/dev/null || true
    echo ""
  fi
}
