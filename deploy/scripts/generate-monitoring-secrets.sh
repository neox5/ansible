#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[generate-monitoring-secrets] Generating credentials for monitoring stack"
echo "[generate-monitoring-secrets] Repository: ${REPO_DIR}"
echo ""

cd "${REPO_DIR}"

# Check if secrets already exist
if [[ -f monitoring.env ]]; then
  echo "WARNING: monitoring.env already exists"
  echo ""
  read -p "Overwrite existing secrets? (yes/no): " -r
  if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Aborted. No changes made."
    exit 0
  fi
  echo ""
fi

# Generate secrets
echo "[generate-monitoring-secrets] Generating random password"
NEW_GRAFANA_PASSWORD=$(openssl rand -hex 16)

# Create monitoring.env
echo "[generate-monitoring-secrets] Creating monitoring.env"
cat > monitoring.env <<EOF
# Grafana Admin Password
GF_SECURITY_ADMIN_PASSWORD=${NEW_GRAFANA_PASSWORD}
EOF

echo ""
echo "[generate-monitoring-secrets] ✓ monitoring.env created successfully"
echo ""
echo "CRITICAL: Store these credentials in your password manager:"
echo "=========================================================="
echo "Grafana Admin Password: ${NEW_GRAFANA_PASSWORD}"
echo "=========================================================="
echo ""
echo "File created: monitoring.env"
echo "DO NOT commit this file to git (it is in .gitignore)"
