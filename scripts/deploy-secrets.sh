#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

if [[ $EUID -ne 0 ]]; then
   error "Must run as root"
   exit 1
fi

# Verify secrets exist in repository
MISSING_SECRETS=()
[[ ! -f "${REPO_ROOT}/config/n8n/n8n.env" ]] && MISSING_SECRETS+=("config/n8n/n8n.env")
[[ ! -f "${REPO_ROOT}/config/monitoring/monitoring.env" ]] && MISSING_SECRETS+=("config/monitoring/monitoring.env")
[[ ! -f "${REPO_ROOT}/config/backup/backup.env" ]] && MISSING_SECRETS+=("config/backup/backup.env")

if [[ ${#MISSING_SECRETS[@]} -gt 0 ]]; then
  echo ""
  error "Missing .env files in repository:"
  for file in "${MISSING_SECRETS[@]}"; do
    echo "  - ${file}"
  done
  echo ""
  error "Run 'make generate-secrets' first"
  exit 1
fi

# Check for existing secrets in production
EXISTING_SECRETS=()
[[ -f "${INSTALL_CONFIG}/n8n.env" ]] && EXISTING_SECRETS+=("n8n.env")
[[ -f "${INSTALL_CONFIG}/monitoring.env" ]] && EXISTING_SECRETS+=("monitoring.env")
[[ -f "${INSTALL_CONFIG}/backup.env" ]] && EXISTING_SECRETS+=("backup.env")

if [[ ${#EXISTING_SECRETS[@]} -gt 0 ]]; then
  echo ""
  warn "Existing secrets found in ${INSTALL_CONFIG}:"
  for file in "${EXISTING_SECRETS[@]}"; do
    echo "  - ${file}"
  done
  echo ""
  read -rp "Overwrite? [y/N] " -n 1 REPLY
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted - no secrets modified"
    exit 0
  fi
fi

echo ""
info "Deploying secrets to ${INSTALL_CONFIG}..."

# Deploy secrets
cp "${REPO_ROOT}/config/n8n/n8n.env" "${INSTALL_CONFIG}/n8n.env"
chmod 600 "${INSTALL_CONFIG}/n8n.env"
info "  Deployed: n8n.env"

cp "${REPO_ROOT}/config/monitoring/monitoring.env" "${INSTALL_CONFIG}/monitoring.env"
chmod 600 "${INSTALL_CONFIG}/monitoring.env"
info "  Deployed: monitoring.env"

cp "${REPO_ROOT}/config/backup/backup.env" "${INSTALL_CONFIG}/backup.env"
chmod 600 "${INSTALL_CONFIG}/backup.env"
info "  Deployed: backup.env"

echo ""
info "Secrets deployed successfully"
echo ""
warn "REMINDER: Secrets are stored in:"
warn "  ${INSTALL_CONFIG}/*.env"
warn "Ensure you have backed up these secrets to a password manager"
echo ""
