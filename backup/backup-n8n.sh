#!/usr/bin/env bash
set -euo pipefail

# Base directory = repo root
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load DB credentials from n8n.env (used for pg_dump)
if [[ -f "${BASE_DIR}/n8n.env" ]]; then
  # shellcheck disable=SC1090
  source "${BASE_DIR}/n8n.env"
else
  echo "ERROR: ${BASE_DIR}/n8n.env not found"
  exit 1
fi

# Load restic password from backup.env
if [[ -f "${BASE_DIR}/backup.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${BASE_DIR}/backup.env"
  set +a
else
  echo "ERROR: ${BASE_DIR}/backup.env not found"
  exit 1
fi

# Load restic config (KEEP_* + BACKUP_SOURCE + RESTIC_REPOSITORY)
if [[ -f "${BASE_DIR}/backup.conf" ]]; then
  # shellcheck disable=SC1090
  source "${BASE_DIR}/backup.conf"
else
  echo "ERROR: ${BASE_DIR}/backup.conf not found"
  exit 1
fi

# Set restic repository path
export RESTIC_REPOSITORY="${BASE_DIR}${RESTIC_REPOSITORY}"

# Ensure backup-src structure exists
mkdir -p \
  "${BASE_DIR}${BACKUP_SOURCE}/db" \
  "${BASE_DIR}${BACKUP_SOURCE}/n8n-files" \
  "${BASE_DIR}${BACKUP_SOURCE}/config"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
PG_DUMP_FILE="${BASE_DIR}${BACKUP_SOURCE}/db/n8n-${TIMESTAMP}.sql.gz"

echo "[backup] $(date) starting backup run"

# Find postgres container ID via podman-compose
cd "${BASE_DIR}"
PG_CID="$(podman-compose -f n8n-compose.yml ps -q postgres || true)"

if [[ -z "${PG_CID}" ]]; then
  echo "ERROR: postgres container not running (podman-compose ps -q postgres returned empty)"
  exit 1
fi

echo "[backup] dumping PostgreSQL database to ${PG_DUMP_FILE}"

# Use pg_dump inside the postgres container
podman exec "${PG_CID}" pg_dump \
  -U "${POSTGRES_USER}" \
  "${POSTGRES_DB}" | gzip > "${PG_DUMP_FILE}"

echo "[backup] syncing n8n files into backup-src"
rsync -a --delete \
  "${BASE_DIR}/data/n8n/" \
  "${BASE_DIR}${BACKUP_SOURCE}/n8n-files/"

echo "[backup] copying n8n.env into backup-src/config/n8n.env"
cp "${BASE_DIR}/n8n.env" "${BASE_DIR}${BACKUP_SOURCE}/config/n8n.env"

echo "[backup] running restic backup on ${BASE_DIR}${BACKUP_SOURCE}"
restic backup "${BASE_DIR}${BACKUP_SOURCE}"

echo "[backup] applying retention policy: hourly=${KEEP_HOURLY} daily=${KEEP_DAILY} weekly=${KEEP_WEEKLY} monthly=${KEEP_MONTHLY}"
restic forget \
  --keep-hourly "${KEEP_HOURLY}" \
  --keep-daily  "${KEEP_DAILY}" \
  --keep-weekly "${KEEP_WEEKLY}" \
  --keep-monthly "${KEEP_MONTHLY}" \
  --prune

echo "[backup] $(date) backup run finished"
