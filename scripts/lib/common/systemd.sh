#!/usr/bin/env bash
set -euo pipefail

is_unit_active() {
  local unit_name="$1"
  systemctl is-active --quiet "$unit_name"
}

systemd_start_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if is_unit_active "$unit_name"; then
    echo "already running"
    return 0
  fi
  
  systemctl daemon-reload
  systemctl enable "$unit_name"
  systemctl start "$unit_name"
  
  [[ "${SILENT:-false}" == "true" ]] && return 0
  echo "[start] $unit_name"
}

systemd_stop_unit() {
  local unit_path="$1"
  local unit_name=$(basename "$unit_path")
  
  require_installed
  
  if ! is_unit_active "$unit_name"; then
    echo "already stopped"
    return 0
  fi
  
  systemctl stop "$unit_name"
  systemctl disable "$unit_name"
  
  [[ "${SILENT:-false}" == "true" ]] && return 0
  echo "[stop] $unit_name"
}
