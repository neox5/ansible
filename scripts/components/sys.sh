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
  # Bootstrap: create base directories
  mkdir -p -m 0755 "${STATE_DIR}"
  mkdir -p -m 0755 "${ETC_ROOT}"
  mkdir -p -m 0755 "${SHARE_ROOT}"
  
  # Create registry
  ensure_registry
  
  # Register base directories
  registry_add dirs "${STATE_DIR}" 0755
  registry_add dirs "${ETC_ROOT}" 0755
  registry_add dirs "${SHARE_ROOT}" 0755
}

c_cleanup() {
  local lock_count
  lock_count=$(installed_count)
  
  if [[ "$lock_count" -ne 1 ]]; then
    echo "error: cannot cleanup - components still installed:" >&2
    find "${STATE_DIR}" -type d -name "*.registry" 2>/dev/null | \
      grep -v 'sys\.registry$' | \
      sed 's|.*/||; s|\.registry$||' | \
      sed 's/^/  - /' >&2
    exit 1
  fi
  
  # Use standard uninstall
  uninstall_from_registry
  
  # Remove registry (normally done by dispatch, but cleanup is not uninstall verb)
  rm -rf "${STATE_DIR}/sys.registry"
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
