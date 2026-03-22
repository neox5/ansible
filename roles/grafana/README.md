# grafana

Grafana deployment for Debian 13 Trixie via Podman Quadlet.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Grafana OSS container (single instance)
- Quadlet-based deployment (Podman)

**This is intentional.** Grafana Enterprise, HA, and non-container deployments are not supported.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- quadlet role (called internally)

## Role Variables

### Version

```yaml
grafana_version: "12.3.0"
```

### Network

```yaml
grafana_port: 3000
grafana_domain: "localhost"
```

### Authentication

```yaml
grafana_auth:
  server_admin:
    user: "admin"
    password: "" # required - set via SOPS secret "grafana_admin_password_secret"
  anonymous:
    enabled: false
    org_role: "Viewer" # Viewer | Editor | Admin
```

`server_admin` provisions the Grafana server administrator (server-wide superadmin).
`password` must be set in inventory via a SOPS-encrypted secret — it is required when `grafana_state: present`.

`anonymous` controls unauthenticated access. When enabled, users land on dashboards
without login. The server admin login remains accessible at `/login` regardless.

### Datasources

```yaml
grafana_datasources:
  - name: "VictoriaMetrics"
    uid: "victoriametrics"
    type: "victoriametrics-metrics-datasource"
    url: "http://localhost:8428"
    is_default: true
```

Supported types: `prometheus`, `victoriametrics-metrics-datasource`, `loki`,
`victoriametrics-logs-datasource`, `alertmanager`, `postgres`, `elasticsearch`

Plugin types are automatically downloaded and allowed. Plugin versions are
pinned via `grafana_plugin_versions`.

### Plugin versions

```yaml
grafana_plugin_versions:
  victoriametrics-metrics-datasource: "v0.23.1"
  victoriametrics-logs-datasource: "v0.26.3"
```

## Directory Structure

All paths are host bind mounts under a single root — simplifies backup/restore:

```
/var/lib/grafana/
├── data/               # SQLite database, sessions (backup target)
├── plugins/            # Ansible-managed plugin downloads (backup target)
├── provisioning/
│   └── datasources/    # Ansible-rendered datasource configs
└── dashboards/         # User-managed dashboard JSON files (backup target)
```

Backup scope: `/var/lib/grafana`

## Tags

- `grafana` - All tasks
- `grafana-preflight` - Environment validation
- `grafana-install` - Directory creation and plugin downloads
- `grafana-configure` - Datasource provisioning
- `grafana-start` - Container deployment

## What This Role Does

1. Validates environment (Debian 13+) and required variables
2. Creates directory structure under `/var/lib/grafana`
3. Downloads required plugins from GitHub releases (version-pinned)
4. Renders datasource provisioning files from templates
5. Deploys Grafana container via quadlet role
