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

print_systemd_table() {
  echo "Systemd units:"
  printf "%-15s %-35s %-10s %s\n" "COMPONENT" "UNIT" "STATUS" "STATE"
  
  local found_units=false
  
  # Iterate through all component registries (sorted)
  for registry_dir in "${STATE_DIR}"/*.registry; do
    [[ -d "$registry_dir" ]] || continue
    
    local component=$(basename "$registry_dir" .registry)
    
    # Read units for this component
    while IFS=' ' read -r unit_path mode; do
      [[ -n "$unit_path" ]] || continue
      
      found_units=true
      local unit_name=$(basename "$unit_path")
      local status="disabled"
      local state="inactive"
      
      # Check if enabled (actual system state)
      if systemd_is_enabled "$unit_path"; then
        status="enabled"
      fi
      
      # Check runtime state
      if systemctl is-active --quiet "$unit_name" 2>/dev/null; then
        state="active"
      fi
      
      printf "%-15s %-35s %-10s %s\n" "$component" "$unit_name" "$status" "$state"
    done < "${registry_dir}/units"
  done
  
  if [[ "$found_units" == "false" ]]; then
    echo "(no systemd unit files installed)"
  fi
  
  echo ""
}

c_tree() {
  # Check if system is initialized
  if [[ ! -d "${STATE_DIR}" ]]; then
    echo "system not initialized (run: ./run sys init)"
    return 0
  fi
  
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
    if [[ ! -d "$dir" ]]; then
      echo "$dir (not created)"
      echo ""
    else
      tree "${tree_args[@]}" "${dir}" 2>/dev/null || true
      echo ""
    fi
  done
  
  # Systemd units table
  print_systemd_table
}
