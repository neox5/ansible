# otelcol

OpenTelemetry Collector deployment for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Single collector instance (bare-metal)

## Requirements

- Debian 13 Trixie
- Ansible 2.15+

## Role Variables

### Version and Binary

```yaml
otelcol_version: "v0.147.0"
otelcol_binary_name: "otelcol-contrib"
```

### System

```yaml
otelcol_system_user: "otelcol"
otelcol_system_group: "otelcol"
```

### Paths

```yaml
otelcol_config_dir: "/etc/otelcol"
otelcol_config_file: "{{ otelcol_config_dir }}/config.yaml"
```

### Network

```yaml
otelcol_health_check_endpoint: "http://127.0.0.1:13133"
```

### Collector Configuration (required)

```yaml
otelcol_config: {}
```

Must be defined in inventory (`host_vars` or `group_vars`). Contains the full collector pipeline configuration.

See `examples/` for deployment pattern references.

## Example Playbook

```yaml
---
- hosts: monitoring
  become: true
  roles:
    - otelcol
```

## License

MIT

## Author

neox5
