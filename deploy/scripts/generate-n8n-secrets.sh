#!/usr/bin/env bash
set -euo pipefail

# Dynamically determine repository root (two levels up from deploy/scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[generate-n8n-secrets] Generating credentials for n8n stack"
echo "[generate-n8n-secrets] Repository: ${REPO_DIR}"
echo ""

cd "${REPO_DIR}"

# Check if secrets already exist
if [[ -f n8n.env ]]; then
  echo "WARNING: n8n.env already exists"
  echo ""
  read -p "Overwrite existing secrets? (yes/no): " -r
  if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "Aborted. No changes made."
    exit 0
  fi
  echo ""
fi

# Generate secrets
echo "[generate-n8n-secrets] Generating random passwords and keys"
NEW_POSTGRES_PASSWORD=$(openssl rand -hex 16)
NEW_ENCRYPTION_KEY=$(openssl rand -hex 32)

# Create n8n.env
echo "[generate-n8n-secrets] Creating n8n.env"
cat > n8n.env <<EOF
# PostgreSQL Secrets
POSTGRES_USER=n8n
POSTGRES_PASSWORD=${NEW_POSTGRES_PASSWORD}
POSTGRES_DB=n8n

# n8n Database Password (MUST be identical to POSTGRES_PASSWORD above)
DB_POSTGRESDB_PASSWORD=${NEW_POSTGRES_PASSWORD}

# n8n Encryption Key (CRITICAL - do not lose)
N8N_ENCRYPTION_KEY=${NEW_ENCRYPTION_KEY}

# PostgreSQL Connection String (for monitoring)
# Password in connection string MUST match POSTGRES_PASSWORD above
POSTGRES_CONNECTION=postgresql://n8n:${NEW_POSTGRES_PASSWORD}@postgres:5432/n8n?sslmode=disable
EOF

echo ""
echo "[generate-n8n-secrets] ✓ n8n.env created successfully"
echo ""
echo "CRITICAL: Store these credentials in your password manager:"
echo "=========================================================="
echo "PostgreSQL Password: ${NEW_POSTGRES_PASSWORD}"
echo "n8n Encryption Key:  ${NEW_ENCRYPTION_KEY}"
echo "=========================================================="
echo ""
echo "File created: n8n.env"
echo "DO NOT commit this file to git (it is in .gitignore)"
