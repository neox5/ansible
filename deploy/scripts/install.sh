#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Install All Stacks - n8n-n150"
echo "========================================"
echo "Repository: ${REPO_DIR}"
echo ""

# Verify we're in a valid repository
if [[ ! -f "${REPO_DIR}/n8n-compose.yml" ]]; then
  echo "ERROR: n8n-compose.yml not found at ${REPO_DIR}"
  echo "This script must be run from deploy/scripts/ directory in the repository"
  exit 1
fi

# Verify all secrets exist
echo "Verifying secret files..."
MISSING_SECRETS=()
[[ ! -f "${REPO_DIR}/n8n.env" ]] && MISSING_SECRETS+=("n8n.env")
[[ ! -f "${REPO_DIR}/monitoring.env" ]] && MISSING_SECRETS+=("monitoring.env")
[[ ! -f "${REPO_DIR}/backup.env" ]] && MISSING_SECRETS+=("backup.env")

if [[ ${#MISSING_SECRETS[@]} -gt 0 ]]; then
  echo "ERROR: Missing secret files:"
  for secret in "${MISSING_SECRETS[@]}"; do
    echo "  - ${secret}"
  done
  echo ""
  echo "Please run ./deploy/scripts/generate-secrets.sh first"
  exit 1
fi

echo "✓ All secret files present"
echo ""

# Install n8n stack
echo "========================================"
echo "1/3: Installing n8n stack"
echo "========================================"
"${SCRIPT_DIR}/install-n8n.sh"
echo ""

# Install monitoring stack
echo "========================================"
echo "2/3: Installing monitoring stack"
echo "========================================"
"${SCRIPT_DIR}/install-monitoring.sh"
echo ""

# Install backup system
echo "========================================"
echo "3/3: Installing backup system"
echo "========================================"
"${SCRIPT_DIR}/install-backup.sh"
echo ""

echo "========================================"
echo "✓ Complete deployment finished"
echo "========================================"
echo ""
echo "Access points:"
echo "  n8n:             http://$(hostname -I | awk '{print $1}'):5678"
echo "  Grafana:         http://$(hostname -I | awk '{print $1}'):3000"
echo "  VictoriaMetrics: http://$(hostname -I | awk '{print $1}'):8428"
echo ""
echo "Services installed:"
echo "  - n8n-stack.service"
echo "  - monitoring-stack.service"
echo "  - n8n-backup.timer (hourly)"
echo ""
echo "Commands:"
echo "  View n8n logs:        podman-compose -f n8n-compose.yml logs -f"
echo "  View monitoring logs: podman-compose -f monitoring-compose.yml logs -f"
echo "  Manual backup:        ${REPO_DIR}/backup/backup-n8n.sh"
echo "  Backup timer status:  systemctl status n8n-backup.timer"
