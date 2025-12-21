#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="/etc/n8n-n150"

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

# Check source files exist
MISSING_FILES=()
[[ ! -f "${REPO_ROOT}/config/n8n/n8n.env" ]] && MISSING_FILES+=("config/n8n/n8n.env")
[[ ! -f "${REPO_ROOT}/config/monitoring/monitoring.env" ]] && MISSING_FILES+=("config/monitoring/monitoring.env")
[[ ! -f "${REPO_ROOT}/config/backup/backup.env" ]] && MISSING_FILES+=("config/backup/backup.env")

if [[ ${#MISSING_FILES[@]} -gt 0 ]]; then
  echo ""
  error "Missing .env files in repository:"
  for file in "${MISSING_FILES[@]}"; do
    echo "  - ${file}"
  done
  echo ""
  error "Run 'make generate-secrets' first"
  exit 1
fi

# Check for existing files in target
EXISTING_FILES=()
[[ -f "${TARGET_DIR}/n8n.env" ]] && EXISTING_FILES+=("n8n.env")
[[ -f "${TARGET_DIR}/monitoring.env" ]] && EXISTING_FILES+=("monitoring.env")
[[ -f "${TARGET_DIR}/backup.env" ]] && EXISTING_FILES+=("backup.env")

if [[ ${#EXISTING_FILES[@]} -gt 0 ]]; then
  echo ""
  warn "Existing .env files found in ${TARGET_DIR}:"
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
info "Deploying secrets to ${TARGET_DIR}..."

# Create target directory
mkdir -p "${TARGET_DIR}"

# Copy files
cp "${REPO_ROOT}/config/n8n/n8n.env" "${TARGET_DIR}/n8n.env"
chmod 600 "${TARGET_DIR}/n8n.env"
info "Deployed: n8n.env"

cp "${REPO_ROOT}/config/monitoring/monitoring.env" "${TARGET_DIR}/monitoring.env"
chmod 600 "${TARGET_DIR}/monitoring.env"
info "Deployed: monitoring.env"

cp "${REPO_ROOT}/config/backup/backup.env" "${TARGET_DIR}/backup.env"
chmod 600 "${TARGET_DIR}/backup.env"
info "Deployed: backup.env"

echo ""
info "Secret deployment complete"
echo ""
