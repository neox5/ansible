# Ansible

Ansible-based infrastructure management.

## Prerequisites

### Target System Requirements

- Fresh Fedora installation
- Root SSH access enabled (for bootstrap only)

**File:** `/etc/ssh/sshd_config`

```conf
PermitRootLogin yes
```

### Control Node Requirements

- Ansible installed
- SOPS installed (for secret management)
- Age key configured for SOPS

## Setup

### 1. Install Ansible Galaxy Dependencies

```bash
ansible-galaxy install -r requirements.yml
```

### 2. Configure Secrets

Generate secure passwords:

```bash
# Generate PostgreSQL password
openssl rand -base64 32
```

Edit secrets file:

```bash
vim inventory/prod/group_vars/n150/secrets.yml
```

Encrypt with SOPS:

```bash
sops -e -i inventory/prod/group_vars/n150/secrets.yml
```

## Bootstrap

Bootstrap a fresh Fedora install by specifying the **target IP address** and disabling host key checking:

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook playbooks/bootstrap.yml \
  -i "<TARGET_IP>," \
  --user root \
  --ask-pass
```

Replace `<TARGET_IP>` with the IP address of the host being bootstrapped.

The trailing comma tells Ansible to treat the value as a single inventory host instead of a file path.

Example:

```bash
ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook playbooks/bootstrap.yml \
  -i "192.168.33.11," \
  --user root \
  --ask-pass
```

After bootstrap, verify connectivity:

```bash
ansible -i inventory/prod all -m ping
```

## Deploy

### Full System Deployment

Deploy all roles:

```bash
ansible-playbook playbooks/site.yml
```

### Partial Deployment

Apply specific role:

```bash
ansible-playbook playbooks/site.yml --tags security_hardening
```

### System Updates

Apply security updates:

```bash
ansible-playbook playbooks/update.yml
```

## Verify Deployment

Check PostgreSQL status:

```bash
ansible n150 -m shell -a "sudo systemctl status postgresql"
```

List databases:

```bash
ansible n150 -m shell -a "sudo -u postgres psql -l"
```

Verify n8n database:

```bash
ansible n150 -m shell -a "sudo -u postgres psql -c '\l n8n'"
```

## Architecture

### Roles

- `security_hardening` - System hardening (SSH, firewall, fail2ban, updates)
- `geerlingguy.postgresql` - PostgreSQL installation and configuration

### Configuration Structure

```
inventory/prod/
  group_vars/
    all/
      postgresql.yml      # Global PostgreSQL defaults
    n150/
      postgresql.yml      # Hardware-specific tuning + n8n database
      secrets.yml         # SOPS-encrypted passwords
```

### Hardware Specifications

**N150 Mini Cube:**

- CPU: x86_64
- RAM: 12GB
- Storage: 512GB SSD
- OS: Fedora (systemd-based)
