#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

# Check for existing files
EXISTING_FILES=()
[[ -f "${REPO_ROOT}/config/n8n/n8n.env" ]] && EXISTING_FILES+=("config/n8n/n8n.env")
[[ -f "${REPO_ROOT}/config/monitoring/monitoring.env" ]] && EXISTING_FILES+=("config/monitoring/monitoring.env")
[[ -f "${REPO_ROOT}/config/backup/backup.env" ]] && EXISTING_FILES+=("config/backup/backup.env")

if [[ ${#EXISTING_FILES[@]} -gt 0 ]]; then
  echo ""
  warn "Existing .env files found:"
  for file in "${EXISTING_FILES[@]}"; do
    echo "  - ${file}"
  done
  echo ""
  read -rp "Overwrite? [y/N] " -n 1 REPLY
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    info "Aborted"
    exit 0
  fi
fi

echo ""
info "Generating secrets..."
echo ""

# Generate n8n secrets
info "n8n:"
POSTGRES_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c32)
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)

sed \
  -e "s/POSTGRES_PASSWORD=CHANGE_ME/POSTGRES_PASSWORD=${POSTGRES_PASSWORD}/" \
  -e "s/DB_POSTGRESDB_PASSWORD=CHANGE_ME/DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}/" \
  -e "s/N8N_ENCRYPTION_KEY=CHANGE_ME/N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}/" \
  -e "s|postgresql://n8n:CHANGE_ME@|postgresql://n8n:${POSTGRES_PASSWORD}@|" \
  "${REPO_ROOT}/config/n8n/n8n.env.example" > "${REPO_ROOT}/config/n8n/n8n.env"

chmod 600 "${REPO_ROOT}/config/n8n/n8n.env"

echo "  POSTGRES_PASSWORD=${POSTGRES_PASSWORD}"
echo "  N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}"
echo ""

# Generate monitoring secrets
info "Monitoring:"
GF_SECURITY_ADMIN_PASSWORD=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c32)

sed \
  -e "s/GF_SECURITY_ADMIN_PASSWORD=CHANGE_ME/GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}/" \
  "${REPO_ROOT}/config/monitoring/monitoring.env.example" > "${REPO_ROOT}/config/monitoring/monitoring.env"

chmod 600 "${REPO_ROOT}/config/monitoring/monitoring.env"

echo "  GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}"
echo ""

# Generate backup secrets
info "Backup:"
RESTIC_PASSWORD=$(openssl rand -base64 96 | tr -dc 'a-zA-Z0-9' | head -c64)

sed \
  -e "s/RESTIC_PASSWORD=CHANGE_ME/RESTIC_PASSWORD=${RESTIC_PASSWORD}/" \
  "${REPO_ROOT}/config/backup/backup.env.example" > "${REPO_ROOT}/config/backup/backup.env"

chmod 600 "${REPO_ROOT}/config/backup/backup.env"

echo "  RESTIC_PASSWORD=${RESTIC_PASSWORD}"
echo ""

info "Secret files created in config/*/"
echo ""
warn "BACKUP ALL SECRETS IMMEDIATELY"
warn "Store in password manager or encrypted vault"
warn "The n8n encryption key cannot be changed without data loss"
echo ""
