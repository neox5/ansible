# n8n Role

Workflow automation platform deployment via Podman Quadlet.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Podman Quadlet deployment
- PostgreSQL backend

**This is intentional.** SQLite and other backends are not supported.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- quadlet role (called internally)
- PostgreSQL database (created separately via postgresql role)

## Role Variables

### Required Variables (define in inventory)

```yaml
n8n_webhook_url: "https://n8n.example.com/"
n8n_encryption_key: "{{ n8n_encryption_key_secret }}" # SOPS-encrypted
n8n_db_password: "{{ n8n_db_password_secret }}" # SOPS-encrypted
```

### Optional Variables

```yaml
# Version
n8n_version: "2.7.5"

# Network
n8n_host: "n8n.example.com"
n8n_port: 5678
n8n_protocol: "https"

# Database
n8n_db_host: "localhost"
n8n_db_port: 5432
n8n_db_name: "n8n"
n8n_db_user: "n8n_user"

# Timezone
n8n_timezone: "UTC"
```

See `defaults/main.yml` for all available variables.

## Example Playbook

```yaml
---
- hosts: n8n
  become: yes
  roles:
    - postgresql
    - n8n
```

## Tags

- `n8n` - All tasks
- `n8n-preflight` - Environment validation

## What This Role Does

1. Validates environment (Debian 13+)
2. Validates required variables are set
3. Calls quadlet role to deploy n8n container
4. Container connects to existing PostgreSQL database

## Database Setup

This role does NOT create the database. Configure database creation via inventory:

```yaml
# inventory/lab/group_vars/n8n/postgresql.yml
postgresql_databases:
  - name: n8n
    owner: n8n_user

postgresql_users:
  - name: n8n_user
    password: "{{ n8n_db_password }}"
```

## License

MIT

## Author

neox5
