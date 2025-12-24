#!/usr/bin/env bash
set -euo pipefail

supported_verbs=(
  install
  uninstall
  start
  stop
)

readonly NET_COMPOSE_SRC="${ROOT_DIR}/compose/network.yml"
readonly NET_COMPOSE_DST="${SHARE_ROOT}/compose/network.yml"
readonly NET_UNIT_SRC="${ROOT_DIR}/systemd/n150-net.service"
readonly NET_UNIT_DST="${SYSTEMD_UNIT_DIR}/n150-net.service"

c_install() {
  require_sys_init
  
  ensure_dirs 0755 "${SHARE_ROOT}/compose"
  install_file "${NET_COMPOSE_SRC}" "${NET_COMPOSE_DST}"
  install_systemd_unit "${NET_UNIT_SRC}" "${NET_UNIT_DST}"
}

# No c_uninstall - uses default_uninstall

c_start() {
  systemd_enable_unit "${NET_UNIT_DST}"
  systemd_start_unit "${NET_UNIT_DST}"
}

c_stop() {
  systemd_stop_unit "${NET_UNIT_DST}"
  systemd_disable_unit "${NET_UNIT_DST}"
}
