# victorialogs

VictoriaLogs single-node deployment for Debian 13 Trixie.
Parameterized for multi-instance deployment via inventory.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- VictoriaLogs single-node (bare-metal)

**This is intentional.** Cluster mode and enterprise features are not supported.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+

## Role Variables

### Mandatory (no defaults - preflight asserts these are set)

```yaml
victorialogs_http_listen_port: 9428 # unique per instance
victorialogs_retention_period: "14d" # duration string: 1d, 30d, 1y, etc.
```

### Lifecycle

```yaml
victorialogs_state: present # present | absent
victorialogs_remove_data: false # true removes data dir (only valid with state: absent)
```

### Version

```yaml
victorialogs_version: "v1.48.0"
```

### Instance and system identity

```yaml
victorialogs_instance_name: "victorialogs" # drives service name and data dir
victorialogs_system_user: "victorialogs" # shared across all instances
victorialogs_system_group: "victorialogs" # shared across all instances
victorialogs_data_dir: "/var/lib/{{ victorialogs_instance_name }}"
```

### Performance

```yaml
victorialogs_max_open_files: 2097152
```

## Multi-Instance Usage

Define instances in inventory, playbook handles the loop automatically:

```yaml
# inventory/prod/group_vars/n150/victorialogs.yaml
victorialogs_instances:
  - victorialogs_instance_name: victorialogs-access
    victorialogs_http_listen_port: 9428
    victorialogs_retention_period: "14d"
  - victorialogs_instance_name: victorialogs-app
    victorialogs_http_listen_port: 9429
    victorialogs_retention_period: "30d"
```

## Single-Instance Usage

Set variables directly in inventory without `victorialogs_instances`:

```yaml
victorialogs_http_listen_port: 9428
victorialogs_retention_period: "30d"
```

## What This Role Does

### Install (`state: present`)

1. Validates environment (Debian 13+, systemd, mandatory vars)
2. Creates system user and group (`victorialogs`)
3. Creates data directory with correct ownership
4. Downloads and installs binary from GitHub releases
5. Deploys systemd service unit (named after instance)
6. Enables and starts service
7. Verifies health endpoint responds

### Remove (`state: absent`)

1. Validates environment
2. Stops and disables service
3. Removes systemd unit file
4. Removes binary
5. Removes data directory (only if `victorialogs_remove_data: true`)
6. Removes system user and group

## License

MIT

## Author

neox5
