# Backup Policy — n8n Appliance

## Critical Data
- PostgreSQL database (n8n state)
- n8n file storage (`binaryData`) in `/opt/n8n/data/n8n`
- `n8n.env` (must include N8N_ENCRYPTION_KEY)

## Non-Critical / Rebuildable
- OS
- Containers and images
- podman-compose binary
- Logs

## Snapshot Frequency
- Hourly snapshots

## Retention Policy
- 24 hourly
- 7 daily
- 4 weekly
- 12 monthly

## Maximum Tolerated Data Loss
- 1 hour

## Default Repository Location (on target)
- `/opt/n8n/backup-data/restic-repo`
