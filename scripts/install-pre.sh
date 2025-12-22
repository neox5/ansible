#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { printf "${GREEN}[INFO]${NC}  %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }

if [[ $EUID -ne 0 ]]; then
   error "Must run as root"
   exit 1
fi

info "Installing system prerequisites..."

# Detect package manager
if command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
elif command -v apt >/dev/null 2>&1; then
  PKG_MGR="apt"
else
  error "No supported package manager found (dnf or apt)"
  exit 1
fi

info "Package manager: ${PKG_MGR}"

# Install packages
case "${PKG_MGR}" in
  dnf)
    dnf install -y \
      podman \
      restic \
      caddy \
      rsync \
      openssl
    ;;
  apt)
    apt-get update
    apt-get install -y \
      podman \
      restic \
      caddy \
      rsync \
      openssl
    ;;
esac

# Verify installations
MISSING=()
for cmd in podman restic caddy rsync openssl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    MISSING+=("${cmd}")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  error "Missing commands after installation:"
  for cmd in "${MISSING[@]}"; do
    echo "  - ${cmd}"
  done
  exit 1
fi

info "Prerequisites installed successfully"
info "Versions:"
podman --version
restic version | head -1
caddy version
openssl version
