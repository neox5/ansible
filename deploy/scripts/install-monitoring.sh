#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[install-monitoring] Installing monitoring stack"
echo "[install-monitoring] Repository: ${REPO_DIR}"
echo ""

cd "${REPO_DIR}"

# Verify secrets exist
echo "[install-monitoring] Verifying secret files exist"
if [[ ! -f monitoring.env ]]; then
  echo "ERROR: monitoring.env not found"
  echo "Please run ./deploy/scripts/generate-monitoring-secrets.sh first"
  exit 1
fi

if [[ ! -f n8n.env ]]; then
  echo "ERROR: n8n.env not found (required for database monitoring)"
  echo "Please run ./deploy/scripts/generate-n8n-secrets.sh first"
  exit 1
fi

echo "[install-monitoring] ✓ All secret files present"
echo ""

# Verify n8n stack is running
if ! podman network exists n8n-net; then
  echo "ERROR: n8n-net network not found"
  echo "Please install n8n stack first: ./deploy/scripts/install-n8n.sh"
  exit 1
fi

# Create required directories
echo "[install-monitoring] Creating directory structure"
mkdir -p monitoring-data/victoriametrics monitoring-data/grafana

# Pull container images
echo "[install-monitoring] Pulling container images"
podman-compose -f monitoring-compose.yml pull

# Start services
echo "[install-monitoring] Starting services"
podman-compose -f monitoring-compose.yml up -d

# Install systemd unit
echo "[install-monitoring] Installing systemd unit"
cp deploy/scripts/monitoring-stack.service /etc/systemd/system/

systemctl daemon-reload
systemctl enable monitoring-stack.service

echo ""
echo "[install-monitoring] ✓ Monitoring stack installed successfully"
echo ""
echo "Access points:"
echo "  Grafana:        http://$(hostname -I | awk '{print $1}'):3000"
echo "  VictoriaMetrics: http://$(hostname -I | awk '{print $1}'):8428"
echo "  Alloy:          http://$(hostname -I | awk '{print $1}'):12345"
echo ""
echo "Grafana login: admin / (see monitoring.env)"
echo ""
echo "Commands:"
echo "  View logs:    podman-compose -f monitoring-compose.yml logs -f"
echo "  Stop:         systemctl stop monitoring-stack"
echo "  Start:        systemctl start monitoring-stack"
echo "  Status:       systemctl status monitoring-stack"
