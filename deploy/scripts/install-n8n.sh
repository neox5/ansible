#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[install-n8n] Installing n8n stack"
echo "[install-n8n] Repository: ${REPO_DIR}"
echo ""

# Verify we're in a valid repository
if [[ ! -f "${REPO_DIR}/n8n-compose.yml" ]]; then
  echo "ERROR: n8n-compose.yml not found at ${REPO_DIR}"
  echo "This script must be run from deploy/scripts/ directory in the repository"
  exit 1
fi

cd "${REPO_DIR}"

# Verify secrets exist
echo "[install-n8n] Verifying secret files exist"
if [[ ! -f n8n.env ]]; then
  echo "ERROR: n8n.env not found"
  echo "Please run ./deploy/scripts/generate-n8n-secrets.sh first"
  exit 1
fi

echo "[install-n8n] ✓ All secret files present"
echo ""

# Create required directories
echo "[install-n8n] Creating directory structure"
mkdir -p data/n8n data/postgres/data logs

# Pull container images
echo "[install-n8n] Pulling container images"
podman-compose -f n8n-compose.yml pull

# Start services
echo "[install-n8n] Starting services"
podman-compose -f n8n-compose.yml up -d

# Install systemd unit
echo "[install-n8n] Installing systemd unit"
cp deploy/scripts/n8n-stack.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable n8n-stack.service

echo ""
echo "[install-n8n] ✓ n8n stack installed successfully"
echo ""
echo "Access n8n at: http://$(hostname -I | awk '{print $1}'):5678"
echo ""
echo "Commands:"
echo "  View logs:    podman-compose -f n8n-compose.yml logs -f"
echo "  Stop:         systemctl stop n8n-stack"
echo "  Start:        systemctl start n8n-stack"
echo "  Status:       systemctl status n8n-stack"
