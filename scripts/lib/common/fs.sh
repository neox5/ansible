#!/usr/bin/env bash
set -euo pipefail

# Create operations (with registration)
ensure_dirs() {
  local mode="$1"; shift
  
  local d
  for d in "$@"; do
    mkdir -p -m "$mode" "$d"
    registry_add dirs "$d" "$mode"
    log_operation "+" "dir" "$mode" "$d"
  done
}

install_file() {
  local src="$1"
  local dst="$2"
  local mode="${3:-0644}"
  
  cp "$src" "$dst"
  chmod "$mode" "$dst"
  registry_add files "$dst" "$mode"
  
  log_operation "+" "file" "$mode" "$dst"
}

create_link() {
  local target="$1" link="$2"
  
  ln -sf "$target" "$link"
  registry_add links "$link"
  log_operation "+" "link" "" "$link"
}

# Remove operations (no registration - used during uninstall)
remove_files() {
  local f
  for f in "$@"; do
    [[ -f "$f" ]] && rm -f -- "$f"
    log_operation "-" "file" "" "$f"
  done
}

remove_links() {
  local l
  for l in "$@"; do
    [[ -L "$l" ]] && rm -f -- "$l"
    log_operation "-" "link" "" "$l"
  done
}

remove_dirs() {
  local d
  for d in "$@"; do
    [[ -d "$d" ]] && rmdir "$d" 2>/dev/null || true
    log_operation "-" "dir" "" "$d"
  done
}
