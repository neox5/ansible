# Zitadel Role

Zitadel identity provider deployment via Podman Quadlet for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Podman 5.4+
- Zitadel v4.x
- PostgreSQL backend (existing instance)

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Running PostgreSQL instance with zitadel database and user pre-created
- Caddy configured with path-based routing for zitadel domain

## Architecture

Two containers deployed via Podman Quadlet:

- `zitadel` — Go API server (port 8080)
- `zitadel-login` — Next.js Login V2 UI (port 3000)

Both use host network. Caddy terminates TLS and routes:

- `/ui/v2/login/*` → `http://localhost:3000`
- all other paths → `h2c://localhost:8080`

Shared volume at `zitadel_data_dir` carries the login client PAT file
written by the API at first init and read by the login container.

## Role Variables

### Required (define in inventory)

```yaml
zitadel_domain: "zitadel.zion.local"
zitadel_masterkey: "{{ zitadel_masterkey_secret }}" # exactly 32 chars
zitadel_db_password: "{{ zitadel_db_password_secret }}"
zitadel_db_admin_password: "{{ zitadel_db_admin_password_secret }}"
```

### Optional (defaults provided)

```yaml
zitadel_version: "v4.13.1"
zitadel_api_port: 8080
zitadel_login_port: 3000
zitadel_data_dir: /var/lib/zitadel
```

See `defaults/main.yaml` for all available variables.

## Secrets

Three SOPS-encrypted secrets required in inventory:

| Variable                           | Description                                     |
| ---------------------------------- | ----------------------------------------------- |
| `zitadel_masterkey_secret`         | Exactly 32 chars, generated before first deploy |
| `zitadel_db_password_secret`       | Runtime DB user password                        |
| `zitadel_db_admin_password_secret` | PostgreSQL admin password (init only)           |

Generate masterkey: `tr -dc A-Za-z0-9 </dev/urandom | head -c 32`

## PostgreSQL Prerequisites

Database and user must exist before running this role:

```yaml
# host_vars/.../postgresql.yaml
postgresql_databases:
  - name: zitadel
    owner: zitadel
    encoding: UTF-8
    lc_collate: C
    lc_ctype: C
    template: template0

postgresql_users:
  - name: zitadel
    pass: "{{ zitadel_db_password_secret }}"
    encrypted: true
```

Note: Zitadel requires `C` locale — differs from other databases on this instance.

## License

MIT

## Author

neox5
