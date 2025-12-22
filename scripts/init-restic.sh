#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/paths.sh
source "${SCRIPT_DIR}/lib/paths.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

if [[ ! -f "${INSTALL_CONFIG}/backup.env" ]]; then
  error "${INSTALL_CONFIG}/backup.env not found"
  exit 1
fi

info "Initializing restic repository..."

# Load restic password
set -a
# shellcheck source=/dev/null
source "${INSTALL_CONFIG}/backup.env"
set +a

export RESTIC_REPOSITORY="${INSTALL_BACKUP}/restic-repo"

# Check if already initialized
if restic snapshots >/dev/null 2>&1; then
  info "Restic repository already initialized"
  info "  Location: ${RESTIC_REPOSITORY}"
  exit 0
fi

# Initialize repository
restic init

info "Restic repository initialized successfully"
info "  Location: ${RESTIC_REPOSITORY}"
