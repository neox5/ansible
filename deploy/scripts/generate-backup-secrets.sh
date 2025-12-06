#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[generate-backup-secrets] Generating credentials for backup system"
echo "[generate-backup-secrets] Repository: ${REPO_DIR}"
echo ""

cd "${REPO_DIR}"

# Check if secrets already exist
if [[ -f backup.env ]]; then
  echo "WARNING: backup.env already exists"
  echo ""
  read -p "Overwrite existing secrets? (yes/no): " -r
  if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Aborted. No changes made."
    exit 0
  fi
  echo ""
fi

# Generate secrets
echo "[generate-backup-secrets] Generating random password"
NEW_RESTIC_PASSWORD=$(openssl rand -hex 32)

# Create backup.env
echo "[generate-backup-secrets] Creating backup.env"
cat > backup.env <<EOF
# Restic Repository Password
RESTIC_PASSWORD=${NEW_RESTIC_PASSWORD}
EOF

echo ""
echo "[generate-backup-secrets] ✓ backup.env created successfully"
echo ""
echo "CRITICAL: Store these credentials in your password manager:"
echo "=========================================================="
echo "Restic Password: ${NEW_RESTIC_PASSWORD}"
echo "=========================================================="
echo ""
echo "File created: backup.env"
echo "DO NOT commit this file to git (it is in .gitignore)"
