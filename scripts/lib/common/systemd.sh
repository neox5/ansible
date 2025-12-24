#!/usr/bin/env bash
set -euo pipefail

is_unit_active() {
  local unit_name="$1"
  systemctl is-active --quiet "$unit_name" 2>/dev/null
}

systemd_is_enabled() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  local link_path="${SYSTEMD_UNIT_DIR}/multi-user.target.wants/${unit_name}"
  
  # Check if symlink exists and points to correct target
  [[ -L "$link_path" ]] && [[ "$(readlink -f "$link_path")" == "$unit_path" ]]
}

require_unit_stopped() {
  local unit_path="$1"
  local unit_name=$(basename "${unit_path}")
  
  if is_unit_active "${unit_name}"; then
    die "component is running - stop it first (run: ./run ${COMPONENT} stop)"
  fi
}

verify_no_enabled_units() {
  local component="${1:-${COMPONENT}}"
  local registry_dir="${STATE_DIR}/${component}.registry"
  local enabled_units=()
  
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] || continue
    local unit_name=$(basename "$path")
    local link_path="${SYSTEMD_UNIT_DIR}/multi-user.target.wants/${unit_name}"
    
    if [[ -L "$link_path" ]]; then
      enabled_units+=("$unit_name")
    fi
  done < "${registry_dir}/units"
  
  if [[ "${#enabled_units[@]}" -gt 0 ]]; then
    echo "error: component has enabled units - disable first (run: ./run ${component} stop)" >&2
    echo "       enabled units: ${enabled_units[*]}" >&2
    return 1
  fi
  
  return 0
}

verify_no_active_units() {
  local component="${1:-${COMPONENT}}"
  local registry_dir="${STATE_DIR}/${component}.registry"
  local active_units=()
  
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] || continue
    local unit_name=$(basename "$path")
    
    if systemctl is-active --quiet "$unit_name" 2>/dev/null; then
      active_units+=("$unit_name")
    fi
  done < "${registry_dir}/units"
  
  if [[ "${#active_units[@]}" -gt 0 ]]; then
    echo "error: component is running - stop it first (run: ./run ${component} stop)" >&2
    echo "       active units: ${active_units[*]}" >&2
    return 1
  fi
  
  return 0
}

install_systemd_unit() {
  local src="$1" dst="$2"
  
  install_file "$src" "$dst" 0644
  registry_add units "$dst" 0644
}

systemd_enable_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  local link_path="${SYSTEMD_UNIT_DIR}/multi-user.target.wants/${unit_name}"
  
  # Check if already enabled
  if systemd_is_enabled "$unit_path"; then
    # Verify registry consistency
    if ! registry_has unit_enabled "$link_path"; then
      registry_add unit_enabled "$link_path"
    fi
    return 0
  fi
  
  # Enable unit
  systemctl daemon-reload >/dev/null 2>&1
  systemctl enable "$unit_name" >/dev/null 2>&1
  
  # Verify enablement succeeded
  if ! systemd_is_enabled "$unit_path"; then
    die "failed to enable unit: $unit_name"
  fi
  
  # Register the enablement link
  registry_add unit_enabled "$link_path"
  log_unit_operation "enable" "$unit_name"
}

systemd_disable_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  local link_path="${SYSTEMD_UNIT_DIR}/multi-user.target.wants/${unit_name}"
  
  # Check if currently enabled
  if ! systemd_is_enabled "$unit_path"; then
    # Clean registry if needed
    if registry_has unit_enabled "$link_path"; then
      registry_remove unit_enabled "$link_path"
    fi
    return 0
  fi
  
  # Disable unit
  systemctl disable "$unit_name" >/dev/null 2>&1
  
  # Verify disablement succeeded
  if systemd_is_enabled "$unit_path"; then
    die "failed to disable unit: $unit_name"
  fi
  
  # Update registry
  registry_remove unit_enabled "$link_path"
  log_unit_operation "disable" "$unit_name"
}

systemd_start_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if is_unit_active "$unit_name"; then
    return 0
  fi
  
  systemctl start "$unit_name" >/dev/null 2>&1
  
  # Verify start succeeded
  if ! is_unit_active "$unit_name"; then
    die "failed to start unit: $unit_name"
  fi
  
  log_unit_operation "start" "$unit_name"
}

systemd_stop_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if ! is_unit_active "$unit_name"; then
    return 0
  fi
  
  systemctl stop "$unit_name" >/dev/null 2>&1
  
  # Verify stop succeeded
  if is_unit_active "$unit_name"; then
    die "failed to stop unit: $unit_name"
  fi
  
  log_unit_operation "stop" "$unit_name"
}
