#!/usr/bin/env bash
set -euo pipefail

component_name="sys"

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
}

c_cleanup() {
  if state_markers_exist; then
    echo "error: cannot cleanup - components still deployed:" >&2
    ls "${STATE_DIR}" | sed 's/\.lock$//' | sed 's/^/  - /' >&2
    exit 1
  fi
  
  remove_dirs \
    "${VAR_ROOT}" \
    "${ETC_ROOT}" \
    "${SHARE_ROOT}"
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
  
  for dir in "${SHARE_ROOT}" "${ETC_ROOT}" "${VAR_ROOT}"; do
    echo "${dir}"
    tree "${tree_args[@]}" "${dir}" 2>/dev/null || true
    echo ""
  done
}
