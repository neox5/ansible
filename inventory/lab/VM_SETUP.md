# Lab Environment

Quick reference for local development VM.

---

## VM Setup

### Prerequisites
```bash
# Arch/Manjaro
sudo pacman -S qemu-full
```

### Create Base Image

1. Download Fedora Server ISO: https://fedoraproject.org/server/download
2. Create base disk:
```bash
   cd inventory/lab/vm/images
   qemu-img create -f qcow2 fedora43_fresh.qcow2 50G
```
3. Install OS:
```bash
   qemu-system-x86_64 \
     -enable-kvm \
     -m 4G \
     -smp 4 \
     -drive file=fedora43_fresh.qcow2,if=virtio \
     -cdrom ~/Downloads/Fedora-Server-*.iso \
     -boot d
```
4. During install: Set root password only (no user creation)
5. After install: Shutdown VM, remove ISO

### VM Management
```bash
cd inventory/lab/vm

# Start VM (creates overlay if missing)
./run-fedora.sh

# Reset to fresh state
./run-fedora.sh fresh

# SSH access (after bootstrap)
ssh -p 2222 ansible@localhost
```

---

## Ansible Access

### Bootstrap
```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml -i "localhost," --user root --ask-pass -e ansible_port=2222
```

### Deploy
```bash
# Full deployment
ansible-playbook -i inventory/lab playbooks/site.yml

# Updates only
ansible-playbook -i inventory/lab playbooks/update.yml
```

---

## Network

- Host: `localhost:2222` (SSH forwarded from VM port 22)
- VM internal: Standard network (NAT via QEMU user networking)
