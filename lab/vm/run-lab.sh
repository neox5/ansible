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
Usage: $0 [--distro <name>] [COMMAND]

Options:
  --distro <name>      Select distribution (default: debian13)
                       Supported: debian13, fedora43

Commands:
  (none)           Run current state
  save <name>      Create internal snapshot
  load <name>      Revert to internal snapshot
  delete <name>    Delete internal snapshot
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
    if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*base"; then
      echo "[vm] creating 'base' snapshot"
      qemu-img snapshot -c base "$WORK" >/dev/null
    fi
  fi
}

case "${1:-}" in
help | -h | --help)
  show_help
  exit 0
  ;;

save)
  SNAPSHOT_NAME="${2:-}"
  if [ -z "$SNAPSHOT_NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 [--distro <name>] save <name>" >&2
    exit 1
  fi

  check_base
  init_work_image

  # Check for duplicates
  if qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*$SNAPSHOT_NAME"; then
    echo "[vm] warning: snapshot '$SNAPSHOT_NAME' already exists" >&2
    echo "[vm] this will create a duplicate" >&2
    printf "Continue? [y/N]: " >&2
    read -r response
    case "$response" in
    [yY] | [yY][eE][sS]) ;;
    *)
      echo "[vm] cancelled" >&2
      exit 0
      ;;
    esac
  fi

  echo "[vm] creating snapshot: $SNAPSHOT_NAME ($DISTRO)"
  qemu-img snapshot -c "$SNAPSHOT_NAME" "$WORK"
  echo "[vm] snapshot created: $SNAPSHOT_NAME"
  exit 0
  ;;

load)
  SNAPSHOT_NAME="${2:-}"
  if [ -z "$SNAPSHOT_NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 [--distro <name>] load <name>" >&2
    exit 1
  fi

  check_base

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image found: $WORK" >&2
    echo "[vm] run without arguments to create it" >&2
    exit 1
  fi

  if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*$SNAPSHOT_NAME"; then
    echo "[vm] error: snapshot not found: $SNAPSHOT_NAME" >&2
    echo "[vm] available snapshots ($DISTRO):" >&2
    qemu-img snapshot -l "$WORK" | tail -n +3 | awk '{print "  - " $2}' >&2
    exit 1
  fi

  echo "[vm] reverting to snapshot: $SNAPSHOT_NAME ($DISTRO)"
  qemu-img snapshot -a "$SNAPSHOT_NAME" "$WORK"
  echo "[vm] snapshot loaded: $SNAPSHOT_NAME"
  exit 0
  ;;

delete)
  SNAPSHOT_NAME="${2:-}"
  if [ -z "$SNAPSHOT_NAME" ]; then
    echo "[vm] error: snapshot name required" >&2
    echo "[vm] usage: $0 [--distro <name>] delete <name>" >&2
    exit 1
  fi

  check_base

  if [ ! -f "$WORK" ]; then
    echo "[vm] error: no working image found: $WORK" >&2
    echo "[vm] run without arguments to create it" >&2
    exit 1
  fi

  # Protect 'base' snapshot
  if [ "$SNAPSHOT_NAME" = "base" ]; then
    echo "[vm] error: cannot delete 'base' snapshot (protected)" >&2
    exit 1
  fi

  # Check if snapshot exists
  if ! qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*$SNAPSHOT_NAME"; then
    echo "[vm] error: snapshot not found: $SNAPSHOT_NAME" >&2
    echo "[vm] available snapshots ($DISTRO):" >&2
    qemu-img snapshot -l "$WORK" | tail -n +3 | awk '{print "  - " $2}' >&2
    exit 1
  fi

  # Count occurrences of this snapshot name
  SNAPSHOT_COUNT=$(qemu-img snapshot -l "$WORK" 2>/dev/null | grep -c "^[0-9].*$SNAPSHOT_NAME" || true)

  if [ "$SNAPSHOT_COUNT" -gt 1 ]; then
    echo "[vm] warning: found $SNAPSHOT_COUNT snapshots named '$SNAPSHOT_NAME'" >&2
    echo "[vm] this will delete ALL of them" >&2
    printf "Continue? [y/N]: " >&2
    read -r response
    case "$response" in
    [yY] | [yY][eE][sS]) ;;
    *)
      echo "[vm] cancelled" >&2
      exit 0
      ;;
    esac
  fi

  echo "[vm] deleting snapshot: $SNAPSHOT_NAME ($DISTRO)"
  # Delete all snapshots with this name (handles duplicates)
  while qemu-img snapshot -l "$WORK" 2>/dev/null | grep -q "^[0-9].*$SNAPSHOT_NAME"; do
    qemu-img snapshot -d "$SNAPSHOT_NAME" "$WORK" 2>/dev/null
  done
  echo "[vm] snapshot deleted: $SNAPSHOT_NAME"
  exit 0
  ;;

reset)
  if [ -f "$WORK" ]; then
    echo "[vm] deleting working image ($DISTRO)"
    rm -f "$WORK"
    echo "[vm] working image deleted (next run will create fresh copy)"
  else
    echo "[vm] no working image to delete ($DISTRO)"
  fi
  exit 0
  ;;

list)
  check_base

  if [ ! -f "$WORK" ]; then
    echo "[vm] no working image ($DISTRO) - run without arguments to create it"
    exit 0
  fi

  echo "[vm] available snapshots ($DISTRO):"
  if qemu-img snapshot -l "$WORK" 2>/dev/null | tail -n +3 | grep -q .; then
    qemu-img snapshot -l "$WORK" | tail -n +3 | awk '{print "  - " $2 " (" $3 " " $4 ")"}'
  else
    echo "  (none)"
  fi
  exit 0
  ;;

"")
  check_base
  init_work_image
  echo "[vm] starting VM ($DISTRO)"
  ;;

*)
  echo "[vm] error: unknown command: $1" >&2
  echo "[vm] run '$0 help' for usage" >&2
  exit 1
  ;;
esac

exec qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -drive file="$WORK",if=virtio \
  -nic user,hostfwd=tcp::2222-:22
