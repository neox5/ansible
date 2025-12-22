#!/usr/bin/env bash
set -euo pipefail

ensure_dirs() {
  local mode="$1"; shift
  
  local d
  for d in "$@"; do
    mkdir -p -m "$mode" "$d"
    log_operation "+" "dir" "$mode" "$d"
  done
}

remove_dirs() {
  local d
  for d in "$@"; do
    rm -rf -- "$d"
    log_operation "-" "dir" "" "$d"
  done
}

install_file() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  
  cp "$src" "$dst"
  chmod "$mode" "$dst"
  
  log_operation "+" "file" "$mode" "$dst"
}

remove_files() {
  local f
  for f in "$@"; do
    rm -f -- "$f"
    log_operation "-" "file" "" "$f"
  done
}
