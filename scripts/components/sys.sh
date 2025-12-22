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
  rm -rf -- \
    "${VAR_ROOT}" \
    "${ETC_ROOT}" \
    "${SHARE_ROOT}"
}

c_tree() {
  [[ -d "${STATE_DIR}" ]] || die "system not initialized (run: ./run sys init)"
  
  local tree_args=("$@")
  if [[ "${#tree_args[@]}" -eq 0 ]]; then
    tree_args=(-C -L 3)
  fi
  
  echo "${SHARE_ROOT}/"
  tree "${tree_args[@]}" "${SHARE_ROOT}"
  echo ""
  
  echo "${ETC_ROOT}/"
  tree "${tree_args[@]}" "${ETC_ROOT}"
  echo ""
  
  echo "${VAR_ROOT}/"
  tree "${tree_args[@]}" "${VAR_ROOT}"
}
