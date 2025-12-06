#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[install-backup] Installing backup system"
echo "[install-backup] Repository: ${REPO_DIR}"
echo ""

cd "${REPO_DIR}"

# Verify secrets exist
echo "[install-backup] Verifying secret files exist"
if [[ ! -f backup.env ]]; then
  echo "ERROR: backup.env not found"
  echo "Please run ./deploy/scripts/generate-backup-secrets.sh first"
  exit 1
fi

if [[ ! -f n8n.env ]]; then
  echo "ERROR: n8n.env not found (required for database backup)"
  echo "Please run ./deploy/scripts/generate-n8n-secrets.sh first"
  exit 1
fi

echo "[install-backup] ✓ All secret files present"
echo ""

# Load backup configuration
source backup.conf
source backup.env

# Create required directories
echo "[install-backup] Creating directory structure"
mkdir -p \
  "${REPO_DIR}${BACKUP_SOURCE}/db" \
  "${REPO_DIR}${BACKUP_SOURCE}/n8n-files" \
  "${REPO_DIR}${BACKUP_SOURCE}/config" \
  "${REPO_DIR}${RESTIC_REPOSITORY}"

# Initialize restic repository
export RESTIC_REPOSITORY="${REPO_DIR}${RESTIC_REPOSITORY}"
if [[ ! -f "${RESTIC_REPOSITORY}/config" ]]; then
  echo "[install-backup] Initializing restic repository at ${RESTIC_REPOSITORY}"
  restic init
else
  echo "[install-backup] Restic repository already initialized"
fi

# Install systemd units
echo "[install-backup] Installing systemd units"
cp deploy/scripts/n8n-backup.service /etc/systemd/system/
cp deploy/scripts/n8n-backup.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now n8n-backup.timer

echo ""
echo "[install-backup] ✓ Backup system installed successfully"
echo ""
echo "Backup configuration:"
echo "  Repository:  ${RESTIC_REPOSITORY}"
echo "  Source:      ${REPO_DIR}${BACKUP_SOURCE}"
echo "  Schedule:    Hourly"
echo "  Retention:   ${KEEP_HOURLY}h / ${KEEP_DAILY}d / ${KEEP_WEEKLY}w / ${KEEP_MONTHLY}m"
echo ""
echo "Commands:"
echo "  Manual backup:      ${REPO_DIR}/backup/backup-n8n.sh"
echo "  Timer status:       systemctl status n8n-backup.timer"
echo "  View snapshots:     restic -r ${RESTIC_REPOSITORY} snapshots"
