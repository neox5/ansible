#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

info "Deploying configuration to production..."

# Deploy compose files with path rewriting
info "Deploying compose files..."

sed "s|../config/|${INSTALL_CONFIG}/|g; s|../data/|${INSTALL_DATA}/|g" \
  "${REPO_ROOT}/compose/n8n.yml" > "${INSTALL_COMPOSE}/n8n.yml"

sed "s|../config/|${INSTALL_CONFIG}/|g; s|../data/|${INSTALL_DATA}/|g" \
  "${REPO_ROOT}/compose/monitoring.yml" > "${INSTALL_COMPOSE}/monitoring.yml"

cp "${REPO_ROOT}/compose/network.yml" "${INSTALL_COMPOSE}/network.yml"

# Deploy backup script with path rewriting
info "Deploying backup script..."

sed "s|BASE_DIR=\"/opt/n8n\"|BASE_DIR=\"${INSTALL_PREFIX_VAR}\"|g; \
     s|/config/n8n/n8n.env|${INSTALL_CONFIG}/n8n.env|g; \
     s|/config/backup/backup.env|${INSTALL_CONFIG}/backup.env|g; \
     s|/config/backup/backup.conf|${INSTALL_CONFIG}/backup.conf|g; \
     s|cd \"\${BASE_DIR}/compose\"|cd ${INSTALL_COMPOSE}|g; \
     s|\${BASE_DIR}/config/n8n/n8n.env|${INSTALL_CONFIG}/n8n.env|g" \
  "${REPO_ROOT}/scripts/backup-n8n.sh" > "${INSTALL_SCRIPTS}/backup-n8n.sh"

chmod 755 "${INSTALL_SCRIPTS}/backup-n8n.sh"

# Deploy static configuration
info "Deploying static configuration..."

cp "${REPO_ROOT}/config/n8n/n8n.conf" "${INSTALL_CONFIG}/n8n.conf"
cp "${REPO_ROOT}/config/monitoring/monitoring.conf" "${INSTALL_CONFIG}/monitoring.conf"

# Deploy backup configuration with path rewriting
sed "s|BACKUP_SOURCE=/backup-data/staging|BACKUP_SOURCE=${INSTALL_BACKUP}/staging|g; \
     s|RESTIC_REPOSITORY=/backup-data/restic-repo|RESTIC_REPOSITORY=${INSTALL_BACKUP}/restic-repo|g" \
  "${REPO_ROOT}/config/backup/backup.conf" > "${INSTALL_CONFIG}/backup.conf"

# Deploy Caddyfile
cp "${REPO_ROOT}/config/caddy/Caddyfile" "${INSTALL_CONFIG}/Caddyfile"

# Deploy alloy config
mkdir -p "${INSTALL_CONFIG}/monitoring"
cp "${REPO_ROOT}/config/monitoring/alloy-config.alloy" "${INSTALL_CONFIG}/monitoring/alloy-config.alloy"

# Deploy grafana provisioning
mkdir -p "${INSTALL_CONFIG}/monitoring/grafana-provisioning/datasources"
cp "${REPO_ROOT}/config/monitoring/grafana-provisioning/datasources/victoriametrics-datasource.yml" \
   "${INSTALL_CONFIG}/monitoring/grafana-provisioning/datasources/victoriametrics-datasource.yml"

info "Configuration deployed successfully"
info "  Compose files: ${INSTALL_COMPOSE}"
info "  Secrets: ${INSTALL_CONFIG}/*.env"
info "  Scripts: ${INSTALL_SCRIPTS}"
