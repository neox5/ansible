#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="$SCRIPT_DIR/images/fedora43_fresh.qcow2"
WORK="$SCRIPT_DIR/images/fedora43.qcow2"

# Ensure images directory exists
mkdir -p "$SCRIPT_DIR/images"

# Check base image exists
if [ ! -f "$BASE" ]; then
  echo "[vm] error: base image not found: $BASE" >&2
  echo "[vm] create it first (see README.md)" >&2
  exit 1
fi

if [ "$1" = "fresh" ]; then
  echo "[vm] creating fresh overlay from base"
  rm -f "$WORK"
  qemu-img create -f qcow2 -b "$BASE" -F qcow2 "$WORK"
else
  echo "[vm] reusing existing overlay"
  if [ ! -f "$WORK" ]; then
    echo "[vm] overlay missing, creating from base"
    qemu-img create -f qcow2 -b "$BASE" -F qcow2 "$WORK"
  fi
fi

exec qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -drive file="$WORK",if=virtio \
  -nic user,hostfwd=tcp::2222-:22
