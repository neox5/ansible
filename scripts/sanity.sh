#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

# Parse arguments
SILENT=false
if [[ "${1:-}" == "--silent" ]]; then
  SILENT=true
fi

ok()   { [[ "$SILENT" == "false" ]] && printf "[OK]   %s\n" "$1" || true; }
warn() { printf "[WARN] %s\n" "$1"; }
info() { [[ "$SILENT" == "false" ]] && printf "[INFO] %s\n" "$1" || true; }
fail() { printf "[FAIL] %s\n" "$1"; }

section() { [[ "$SILENT" == "false" ]] && printf "\n== %s ==\n" "$1" || true; }

section "OS"
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  info "${PRETTY_NAME:-unknown}"
  info "ID=${ID:-unknown} VERSION_ID=${VERSION_ID:-unknown}"
else
  fail "/etc/os-release not readable"
fi

section "Installation paths (should be absent on a fresh host)"
for p in "${INSTALL_PREFIX_SHARE}" "${INSTALL_PREFIX_ETC}" "${INSTALL_PREFIX_VAR}"; do
  if [[ -e "$p" ]]; then
    warn "present: $p"
  else
    ok "absent:  $p"
  fi
done

section "systemd units (should be absent before install)"
if systemctl list-unit-files 2>/dev/null | grep -qE '(n150-net|n8n-stack|monitoring-stack|n8n-backup)'; then
  warn "found n8n-n150 unit files"
  systemctl list-unit-files 2>/dev/null | grep -E '(n150-net|n8n-stack|monitoring-stack|n8n-backup)' || true
else
  ok "no n8n-n150 unit files"
fi

section "Podman baseline"
if command -v podman >/dev/null 2>&1; then
  info "$(podman --version)"
  running="$(podman ps --format '{{.ID}}' 2>/dev/null | wc -l | tr -d ' ')"
  allc="$(podman ps -a --format '{{.ID}}' 2>/dev/null | wc -l | tr -d ' ')"
  info "containers: running=${running} total=${allc}"
  if [[ "$SILENT" == "false" ]]; then
    info "networks:"
    podman network ls --format '  {{.Name}} ({{.Driver}})' 2>/dev/null || true
  fi
else
  fail "podman missing"
fi

section "Disk space"
available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
if [[ ${available} -ge 100 ]]; then
  ok "${available}GB available (minimum 100GB)"
else
  warn "${available}GB available (recommended: 100GB minimum)"
fi

[[ "$SILENT" == "false" ]] && echo "" || true
