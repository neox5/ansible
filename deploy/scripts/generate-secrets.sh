#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Generate All Secrets - n8n-n150"
echo "========================================"
echo "Repository: ${REPO_DIR}"
echo ""

# Check which secrets already exist
EXISTING_SECRETS=()
[[ -f "${REPO_DIR}/n8n.env" ]] && EXISTING_SECRETS+=("n8n.env")
[[ -f "${REPO_DIR}/monitoring.env" ]] && EXISTING_SECRETS+=("monitoring.env")
[[ -f "${REPO_DIR}/backup.env" ]] && EXISTING_SECRETS+=("backup.env")

if [[ ${#EXISTING_SECRETS[@]} -gt 0 ]]; then
  echo "WARNING: The following secret files already exist:"
  for secret in "${EXISTING_SECRETS[@]}"; do
    echo "  - ${secret}"
  done
  echo ""
  read -p "Overwrite all existing secrets? (yes/no): " -r
  if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Aborted. No changes made."
    exit 0
  fi
  echo ""
fi

# Generate n8n secrets
echo "========================================"
echo "1/3: Generating n8n secrets"
echo "========================================"
"${SCRIPT_DIR}/generate-n8n-secrets.sh"
echo ""

# Generate monitoring secrets
echo "========================================"
echo "2/3: Generating monitoring secrets"
echo "========================================"
"${SCRIPT_DIR}/generate-monitoring-secrets.sh"
echo ""

# Generate backup secrets
echo "========================================"
echo "3/3: Generating backup secrets"
echo "========================================"
"${SCRIPT_DIR}/generate-backup-secrets.sh"
echo ""

echo "========================================"
echo "✓ All secrets generated successfully"
echo "========================================"
echo ""
echo "Files created:"
echo "  - n8n.env"
echo "  - monitoring.env"
echo "  - backup.env"
echo ""
echo "CRITICAL: All credentials have been displayed above."
echo "Store them in your password manager NOW."
echo ""
echo "DO NOT commit these files to git (they are in .gitignore)"
echo ""
echo "Next steps:"
echo "  Individual: ./deploy/scripts/install-n8n.sh"
echo "  All-in-one: ./deploy/scripts/install.sh"
