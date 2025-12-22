#!/usr/bin/env bash
set -euo pipefail

# Repo root (works both from repo and when installed under /usr/local/share/... if layout preserved)
_paths_this_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${_paths_this_dir}/../.." && pwd)"

# Default install roots (override via environment if needed)
: "${N150_SHARE_ROOT:=/usr/local/share/n8n-n150}"
: "${N150_ETC_ROOT:=/etc/n8n-n150}"
: "${N150_VAR_ROOT:=/var/lib/n8n-n150}"

# Repo paths
REPO_COMPOSE_DIR="${ROOT_DIR}/compose"
REPO_CONFIG_DIR="${ROOT_DIR}/config"
REPO_SCRIPTS_DIR="${ROOT_DIR}/scripts"
REPO_SYSTEMD_DIR="${ROOT_DIR}/systemd"

# Install target paths
SHARE_COMPOSE_DIR="${N150_SHARE_ROOT}/compose"
SHARE_SCRIPTS_DIR="${N150_SHARE_ROOT}/scripts"
ETC_COMPONENT_DIR="${N150_ETC_ROOT}"           # /etc/n8n-n150/<component>/...
VAR_DATA_DIR="${N150_VAR_ROOT}/data"
VAR_BACKUP_DIR="${N150_VAR_ROOT}/backup-data"

# Common names
N150_NETWORK_NAME="${N150_NETWORK_NAME:-n150-net}"
