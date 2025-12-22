#!/usr/bin/env bash
set -euo pipefail

# Minimal, quiet-by-default helpers.

is_root() { [[ "${EUID:-$(id -u)}" -eq 0 ]]; }

require_root() {
  if ! is_root; then
    echo "error: requires root" >&2
    exit 1
  fi
}

die() {
  echo "error: $*" >&2
  exit 1
}

warn() { echo "warn: $*" >&2; }
err()  { echo "error: $*" >&2; }

log() {
  # Only emit when explicitly enabled.
  if [[ "${N150_VERBOSE:-0}" == "1" ]]; then
    echo "$*" >&2
  fi
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing command: ${c}"
  done
}

run_cmd() {
  # Execute exactly as passed; no banner output.
  "$@"
}

# Deploy helpers (idempotent copies with permissions)
ensure_dir() {
  local d="$1"
  mkdir -p -- "$d"
}

deploy_file() {
  # deploy_file <src> <dst> [mode]
  local src="$1" dst="$2" mode="${3:-}"
  ensure_dir "$(dirname -- "$dst")"
  install -m "${mode:-0644}" -D -- "$src" "$dst"
}

deploy_exec() {
  # deploy_exec <src> <dst>
  deploy_file "$1" "$2" "0755"
}

deploy_dir() {
  # deploy_dir <src_dir> <dst_dir>
  local src="$1" dst="$2"
  ensure_dir "$dst"
  rsync -a --delete -- "${src%/}/" "${dst%/}/"
}

systemctl_cmd() {
  require_cmd systemctl
  run_cmd systemctl "$@"
}

systemd_daemon_reload() {
  systemctl_cmd daemon-reload
}
