# victoriametrics

VictoriaMetrics single-node deployment for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- VictoriaMetrics single-node (bare-metal)

**This is intentional.** Cluster mode, vmutils, and enterprise features are not supported.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+

## Role Variables

### Lifecycle

```yaml
victoriametrics_state: present # present | absent
victoriametrics_remove_data: false # true removes data dir (only valid with state: absent)
```

### Version

```yaml
victoriametrics_version: "v1.137.0"
```

### System

```yaml
victoriametrics_system_user: "victoriametrics"
victoriametrics_system_group: "victoriametrics"
```

### Storage

```yaml
victoriametrics_data_dir: "/var/lib/victoriametrics"
```

### Network

```yaml
victoriametrics_http_listen_addr: "127.0.0.1:8428"
```

### Retention and Performance

```yaml
victoriametrics_retention_period_months: "12"
victoriametrics_self_scrape_interval: "30s"
victoriametrics_search_max_unique_timeseries: "100000"
victoriametrics_max_open_files: 2097152
```

See `defaults/main.yaml` for all available variables.

## Example Playbook

```yaml
---
- hosts: monitoring
  become: true
  roles:
    - victoriametrics
```

### Removal (preserve data)

```bash
ansible-playbook playbooks/victoriametrics.yaml -e "victoriametrics_state=absent"
```

### Removal (destroy data)

```bash
ansible-playbook playbooks/victoriametrics.yaml -e "victoriametrics_state=absent victoriametrics_remove_data=true"
```

## What This Role Does

### Install (`state: present`)

1. Validates environment (Debian 13+, systemd)
2. Creates system user and group
3. Creates data directory with correct ownership
4. Downloads and installs binary from GitHub releases
5. Deploys systemd service unit
6. Enables and starts service
7. Verifies health endpoint responds

### Remove (`state: absent`)

1. Validates environment
2. Stops and disables service
3. Removes systemd unit file
4. Removes binary
5. Removes data directory (only if `victoriametrics_remove_data: true`)
6. Removes system user and group

## License

MIT

## Author

neox5
