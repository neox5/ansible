# Lab VM Setup

Minimal Debian/Fedora VM for Ansible testing.

---

## Create Base Image

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

   **Why empty root password?** Bootstrap will set root password from encrypted vars. Debian auto-installs sudo and adds temp user to sudo group.

5. After install: Shutdown VM

---

## Bootstrap

Generate root password hash:

```bash
openssl passwd -6 -stdin
# Add hash to inventory/lab/host_vars/lab-vm/secrets.yml
# Encrypt with SOPS
```

Bootstrap command:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml \
  -i inventory/lab -l lab-vm \
  -e ansible_user=temp \
  -k \
  -K
```

After bootstrap:

- `temp` user removed
- `ansible` user: automation access
- `admin` user: operator access (personal + emergency keys)
- Root password: set from encrypted vars (console access)

---

## Network Setup

Add hosts entry:

```bash
echo "127.0.0.1 n8n.lab.local" | sudo tee -a /etc/hosts
```

Access:

- SSH: `ssh -p 2222 ansible@localhost`
- HTTP: `http://n8n.lab.local:8080`
- Console: QEMU window (root/password from secrets)

---

## Common Workflow

```bash
# Start VM
./run-lab.sh

# Deploy
ansible-playbook -i inventory/lab playbooks/site.yml

# Save state
./run-lab.sh save <name>

# Revert to state
./run-lab.sh load <name>

# Revert to fresh OS
./run-lab.sh load base

# Shutdown VM
# From inside VM: sudo poweroff
```

---

## Troubleshooting

**VM won't start:**

```bash
./run-lab.sh reset  # Delete working image, start fresh
```

**Network issues:**

```bash
# Verify hosts entry
grep n8n.lab.local /etc/hosts

# Test connectivity
ssh -p 2222 ansible@localhost
curl http://n8n.lab.local:8080
```

**List snapshots:**

```bash
./run-lab.sh list
```
