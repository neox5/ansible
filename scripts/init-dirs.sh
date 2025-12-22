#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

GREEN='\033[0;32m'
NC='\033[0m'

info() { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }

info "Creating production directory structure..."

# Application files
mkdir -p "${INSTALL_COMPOSE}"
mkdir -p "${INSTALL_SCRIPTS}"

# Configuration
mkdir -p "${INSTALL_CONFIG}"

# Runtime data
mkdir -p "${INSTALL_DATA}/n8n"
mkdir -p "${INSTALL_DATA}/postgres/data"
mkdir -p "${INSTALL_DATA}/monitoring/victoriametrics"
mkdir -p "${INSTALL_DATA}/monitoring/grafana"

# Backup data
mkdir -p "${INSTALL_BACKUP}/staging/db"
mkdir -p "${INSTALL_BACKUP}/staging/n8n-files"
mkdir -p "${INSTALL_BACKUP}/staging/config"
mkdir -p "${INSTALL_BACKUP}/restic-repo"

# Set ownership
chown -R root:root "${INSTALL_PREFIX_SHARE}"
chown -R root:root "${INSTALL_PREFIX_ETC}"
chown -R root:root "${INSTALL_PREFIX_VAR}"

# Set permissions
chmod 755 "${INSTALL_PREFIX_SHARE}"
chmod 700 "${INSTALL_PREFIX_ETC}"
chmod 700 "${INSTALL_PREFIX_VAR}"

info "Directory structure created:"
info "  ${INSTALL_PREFIX_SHARE}"
info "  ${INSTALL_PREFIX_ETC}"
info "  ${INSTALL_PREFIX_VAR}"
