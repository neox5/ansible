#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

GREEN='\033[0;32m'
NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }

if [[ $EUID -ne 0 ]]; then
   echo "[ERROR] Must run as root"
   exit 1
fi

info "Deploying systemd units..."

# Deploy service and timer files with path rewriting
for unit_file in "${REPO_ROOT}"/systemd/*.{service,timer}; do
  [[ -f "$unit_file" ]] || continue
  
  unit_name=$(basename "$unit_file")
  
  # General path replacements
  sed "s|/opt/n8n|${INSTALL_PREFIX_VAR}|g; \
       s|WorkingDirectory=/usr/local/share/n8n-n150|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g; \
       s|WorkingDirectory=/opt/n8n|WorkingDirectory=${INSTALL_PREFIX_SHARE}|g; \
       s|ExecStart=/opt/n8n/scripts/backup-n8n.sh|ExecStart=${INSTALL_SCRIPTS}/backup-n8n.sh|g" \
    "$unit_file" > "/etc/systemd/system/$unit_name"
  
  info "  Deployed: $unit_name"
done

# Special handling for caddy.service (Caddyfile path)
sed "s|/opt/n8n/config/caddy/Caddyfile|${INSTALL_CONFIG}/Caddyfile|g" \
  "${REPO_ROOT}/systemd/caddy.service" > /etc/systemd/system/caddy.service

info "  Updated: caddy.service (Caddyfile path)"

# Reload systemd
info "Reloading systemd daemon..."
systemctl daemon-reload

info "Systemd units deployed successfully"
info "  Location: /etc/systemd/system/"
info ""
info "Units installed:"
systemctl list-unit-files | grep -E '(n150-net|n8n-stack|n8n-backup|monitoring-stack|caddy)' || true
