#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"

mkdir -p "$IMAGES_DIR"

# Parse distro flag (default: debian13)
DISTRO="debian13"
while [ $# -gt 0 ]; do
  case "$1" in
  --distro)
    DISTRO="$2"
    shift 2
    ;;
  --distro=*)
    DISTRO="${1#*=}"
    shift
    ;;
  *)
    break
    ;;
  esac
done

# Validate distro
case "$DISTRO" in
debian13 | fedora43) ;;
*)
  echo "[vm] error: unsupported distro: $DISTRO" >&2
  echo "[vm] supported: debian13, fedora43" >&2
  exit 1
  ;;
esac

BASE="$IMAGES_DIR/${DISTRO}_base.qcow2"
WORK="$IMAGES_DIR/${DISTRO}.qcow2"

show_help() {
  cat <<EOF
Usage: $0 [--distro <n>] [COMMAND]

Options:
  --distro <n>      Select distribution (default: debian13)
                       Supported: debian13, fedora43

Commands:
  (none)           Run current state
  save <n>      Create internal snapshot
  load <n>      Revert to internal snapshot
  delete <n>    Delete internal snapshot
  reset            Delete working image (next run creates fresh copy)
  list             List all internal snapshots
  help, -h         Show this help

State Files:
  ${DISTRO}_base.qcow2   Read-only backup (never modified)
  ${DISTRO}.qcow2        Working image (contains all snapshots)

Examples:
  $0                           # Run Debian (default)
  $0 --distro fedora43         # Run Fedora VM
  $0 --distro debian13 save bootstrap    # Save Debian snapshot
  $0 --distro fedora43 load base         # Revert Fedora to fresh install
  $0 --distro debian13 reset             # Delete Debian working image

VM Access:
  SSH: ssh -p 2222 ansible@localhost
  HTTP: http://n8n.lab.local:8080 (add to /etc/hosts: 127.0.0.1 n8n.lab.local)
  Shutdown: sudo poweroff (from inside VM)
  Force kill: Ctrl+C (may corrupt state)
EOF
}

check_base() {
  if [ ! -f "$BASE" ]; then
    echo "[vm] error: base image not found: $BASE" >&2
    echo "[vm] create it first (see VM_SETUP.md)" >&2
    exit 1
  fi
}

init_work_image() {
  if [ ! -f "$WORK" ]; then
    echo "[vm] creating working image from base ($DISTRO)"
    cp "$BASE" "$WORK"

    # Check if 'base' snapshot exists
    if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].* base "; then
      echo "[vm] creating 'base' snapshot (fresh OS state)"
      qemu-img snapshot -c base "$WORK"
    fi
  fi
}

run_vm() {
  check_base
  init_work_image

  echo "[vm] starting ($DISTRO)"
  echo "[vm] ssh: ssh -p 2222 ansible@localhost"
  echo "[vm] http: http://n8n.lab.local:8080"
  echo "[vm] shutdown: sudo poweroff (from inside VM)"

  qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -drive file="$WORK",if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
    -device virtio-net-pci,netdev=net0
}

save_snapshot() {
  NAME="$1"
  if [ -z "$NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 save <name>" >&2
    exit 1
  fi

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image to snapshot" >&2
    echo "[vm] run VM first to create working image" >&2
    exit 1
  fi

  echo "[vm] creating snapshot: $NAME"
  qemu-img snapshot -c "$NAME" "$WORK"
  echo "[vm] snapshot saved: $NAME"
}

load_snapshot() {
  NAME="$1"
  if [ -z "$NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 load <name>" >&2
    exit 1
  fi

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image exists" >&2
    exit 1
  fi

  # Verify snapshot exists
  if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].* $NAME "; then
    echo "[vm] error: snapshot not found: $NAME" >&2
    echo "[vm] available snapshots:" >&2
    qemu-img snapshot -l "$WORK" >&2
    exit 1
  fi

  echo "[vm] reverting to snapshot: $NAME"
  qemu-img snapshot -a "$NAME" "$WORK"
  echo "[vm] reverted to: $NAME"
}

delete_snapshot() {
  NAME="$1"
  if [ -z "$NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 delete <name>" >&2
    exit 1
  fi

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image exists" >&2
    exit 1
  fi

  # Verify snapshot exists
  if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].* $NAME "; then
    echo "[vm] error: snapshot not found: $NAME" >&2
    echo "[vm] available snapshots:" >&2
    qemu-img snapshot -l "$WORK" >&2
    exit 1
  fi

  echo "[vm] deleting snapshot: $NAME"
  qemu-img snapshot -d "$NAME" "$WORK"
  echo "[vm] deleted: $NAME"
}

list_snapshots() {
  if [ ! -f "$WORK" ]; then
    echo "[vm] no working image exists" >&2
    exit 0
  fi

  echo "[vm] snapshots in: $WORK"
  qemu-img snapshot -l "$WORK"
}

reset_work() {
  if [ ! -f "$WORK" ]; then
    echo "[vm] no working image to delete"
    exit 0
  fi

  echo "[vm] deleting working image: $WORK"
  rm "$WORK"
  echo "[vm] deleted - next run will create fresh copy from base"
}

# Command routing
case "${1:-}" in
save)
  save_snapshot "$2"
  ;;
load)
  load_snapshot "$2"
  ;;
delete)
  delete_snapshot "$2"
  ;;
list)
  list_snapshots
  ;;
reset)
  reset_work
  ;;
help | -h | --help)
  show_help
  ;;
"")
  run_vm
  ;;
*)
  echo "[vm] error: unknown command: $1" >&2
  echo "[vm] use '$0 help' for usage" >&2
  exit 1
  ;;
esac
