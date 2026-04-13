# synapse

Matrix Synapse homeserver deployment for Debian 13 Trixie via official APT package.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Synapse installed via `packages.matrix.org/debian/` APT repository
- PostgreSQL backend (SQLite not supported)
- Single homeserver instance

**This is intentional.** Multi-distro support, SQLite, and worker deployments
are explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- PostgreSQL database and user created separately via postgresql role
- Caddy configured separately via inventory (`caddy_sites`)

## Role Variables

### Lifecycle

```yaml
synapse_state: present # present | absent
synapse_remove_data: false # true removes data dir (only valid with state: absent)
```

### Server Identity (mandatory — permanent, cannot be changed after first run)

```yaml
synapse_server_name: "" # e.g. "matrix.zion.local"
synapse_public_baseurl: "" # e.g. "https://matrix.zion.local"
```

### Database (mandatory — SOPS-encrypted password)

```yaml
synapse_db_name: "synapse"
synapse_db_user: "synapse"
synapse_db_host: "localhost"
synapse_db_port: 5432
synapse_db_password: "" # set via synapse_db_password_secret (SOPS)
```

### Secrets (mandatory — SOPS-encrypted)

```yaml
synapse_db_password: "" # references synapse_db_password_secret
synapse_registration_shared_secret: "" # references synapse_registration_shared_secret (SOPS)
```

### Network

```yaml
synapse_listener_port: 8008
```

### Optional

```yaml
synapse_report_stats: false
synapse_suppress_key_server_warning: true
```

## Caddy Integration

This role does NOT configure Caddy. Add to inventory `caddy_sites`:

```yaml
caddy_sites:
  - domain: "matrix.zion.local"
    backend: "localhost:8008"
    tls: internal
```

## Database Setup

This role does NOT create the database. Configure via `host_vars/<host>/postgresql.yaml`:

```yaml
postgresql_databases:
  - name: synapse
    owner: synapse
    lc_collate: "C"
    lc_ctype: "C"
    encoding: "UTF8"
    template: template0
    state: present

postgresql_users:
  - name: synapse
    password: "{{ synapse_db_password_secret }}"
    role_attr_flags: "NOCREATEDB,NOSUPERUSER"
    state: present

postgresql_user_privileges:
  - name: synapse
    db: synapse
    priv: "ALL"
```

**Important:** Synapse requires `lc_collate: C` and `lc_ctype: C`. This differs
from other databases in this project.

## User Creation

Registration is disabled by default. Create users via CLI:

```bash
register_new_matrix_user -c /etc/matrix-synapse/homeserver.yaml http://localhost:8008
```

Requires `registration_shared_secret` to be set (managed by this role via SOPS).

## What This Role Does

### Install (`state: present`)

1. Validates environment (Debian 13+, systemd, required variables)
2. Adds `packages.matrix.org/debian/` APT repository and GPG key
3. Installs `matrix-synapse-py3` and `libpq5`
4. Bootstraps signing key via `--generate-config` (idempotent — only runs if key absent)
5. Deploys `conf.d/ansible.yaml` override with all Ansible-managed settings
6. Enables and starts `matrix-synapse` service
7. Verifies health endpoint responds

### Remove (`state: absent`)

1. Stops and disables service
2. Removes APT package
3. Removes `conf.d/ansible.yaml`
4. Removes data directory (only if `synapse_remove_data: true`)

## License

MIT

## Author

neox5
