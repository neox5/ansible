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

1. Download Debian 13 Trixie Server ISO: https://www.debian.org/distrib/
2. Create base disk:

```bash
cd lab/vm/images
qemu-img create -f qcow2 debian13_base.qcow2 50G
```

3. Install OS:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -m 4G \
  -smp 4 \
  -drive file=debian13_base.qcow2,if=virtio \
  -cdrom ~/Downloads/debian-*.iso \
  -boot d
```

4. During install:
   - **Root password: Leave empty (press Enter)**
   - Create user: `temp`
   - Install: SSH server + standard system utilities

   **Why empty root password?**
   - Debian auto-installs sudo package
   - Adds temp user to sudo group
   - Bootstrap will set root password from encrypted vars

5. After install: Shutdown VM

### VM Management

**Basic commands:**

```bash
cd lab/vm

# Start VM (continues current work)
./run-lab.sh

# Create snapshot of current state
./run-lab.sh save <name>

# Revert to snapshot
./run-lab.sh load <name>

# Revert to fresh OS install
./run-lab.sh load base

# Delete working image (start fresh next run)
./run-lab.sh reset

# List all snapshots
./run-lab.sh list

# Show help
./run-lab.sh help
```

**Common workflow:**

```bash
# 1. First run (creates working image + 'base' snapshot)
./run-lab.sh

# 2. Bootstrap
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml \
  -i inventory/lab -l lab-vm \
  --user temp \
  -k \
  -K

# (shut down VM: sudo poweroff)

# 3. Save bootstrapped state
./run-lab.sh save bootstrap

# 4. Test configurations
./run-lab.sh
ansible-playbook -i inventory/lab playbooks/site.yml

# 5. Save working states
./run-lab.sh save postgres
./run-lab.sh save n8n-deployed

# 6. Revert to any state
./run-lab.sh load bootstrap
```

**Snapshot management:**

- Location: `lab/vm/images/`
- Base: `debian13_base.qcow2` (read-only backup, never modified)
- Work: `debian13.qcow2` (working image with all snapshots)
- Snapshots stored internally in working image
- List: `./run-lab.sh list`
- Disaster recovery: `./run-lab.sh reset` (deletes working image, next run creates fresh copy)

---

## Ansible Access

### Bootstrap

Generate root password hash before first bootstrap:

```bash
# Generate SHA-512 password hash
openssl passwd -6 -stdin

# Or with Python
python3 -c 'import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))'

# Add hash to inventory/lab/host_vars/lab-vm/secrets.yml
# Then encrypt with SOPS
```

Bootstrap command:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml \
  -i "localhost," \
  --user temp \
  --ask-become-pass \
  -e ansible_port=2222
```

After bootstrap:

- `temp` user removed
- `ansible` user: automation access
- `admin` user: operator access (personal + emergency keys)
- Root password: set from encrypted vars (console access)

### Deploy

```bash
# Full deployment
ansible-playbook -i inventory/lab playbooks/site.yml

# Updates only
ansible-playbook -i inventory/lab playbooks/update.yml

# Test prod config on VM
ansible-playbook -i inventory/prod playbooks/site.yml \
  --limit n150-01 \
  -e ansible_host=127.0.0.1 \
  -e ansible_port=2222
```

### Access After Bootstrap

```bash
# Automation access
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Operator access
ssh -i ~/.ssh/id_ed25519_desktop -p 2222 admin@localhost

# Emergency access
ssh -i ~/.ssh/id_ed25519_emergency -p 2222 admin@localhost

# Console access (via QEMU window)
# Login as: root
# Password: From inventory/lab/host_vars/lab-vm/secrets.yml (decrypted)
```

---

## Network

- Host: `localhost:2222` (SSH forwarded from VM port 22)
- VM internal: Standard network (NAT via QEMU user networking)
