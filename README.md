# Ansible

Ansible-based infrastructure management.

---

## Install Requirements (Control Node)

```bash
pacman -S ansible sops age
```

---

## Secrets (SOPS)

See [SOPS Setup Guide](docs/SOPS_SETUP.md) for initial setup and additional device configuration.

Quick verification:

```bash
# Verify access (must succeed):
sops -d inventory/prod/host_vars/<host>/secrets.yml >/dev/null
```

---

## Bootstrap

Bootstrap requires temporary user created during OS installation:

**Debian:** Installer creates non-root user automatically  
**Fedora:** Manually create user during installation

Use username `temp` for consistency.

Bootstrap command:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yml \
  -i "<TARGET_IP>," \
  -e ansible_user=temp \
  -k -K
```

After bootstrap completes:

- `ansible` user: automation access (single key)
- `admin` user: operator access (multiple personal keys + emergency key)
- `temp` user: removed by playbook
- Root account: locked (no password, console access via admin user)
- Root SSH access: prohibited (console only via admin user)

Verify access:

```bash
# Automation
ssh -i ~/.ssh/id_ed25519_ansible ansible@<TARGET_IP>

# Operator
ssh -i ~/.ssh/id_ed25519_desktop admin@<TARGET_IP>

# Emergency
ssh -i ~/.ssh/id_ed25519_emergency admin@<TARGET_IP>

# Console access (via QEMU window or physical console)
# Login as: admin
# Use personal SSH key password or emergency key password
```

---

## Deploy

Full deployment:

```bash
ansible-playbook playbooks/site.yml
```

Updates only:

```bash
ansible-playbook playbooks/update.yml
```
