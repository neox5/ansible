# Restic Backup Role

Custom restic role for Debian 13 Trixie - automated backups with systemd timers.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Restic 0.18+
- systemd timer scheduling

**This is intentional.** Multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- systemd

## Role Variables

### Required Variables (define in inventory)

```yaml
restic_repository: "/var/backups/restic"
restic_password: "{{ restic_password_secret }}" # Use SOPS encryption

restic_backups:
  postgresql_db1:
    stdin: true
    stdin_cmd: "sudo -u postgres pg_dump -Fc db1"
    stdin_filename: "db1.dump"
    schedule: "*-*-* 02:00:00"
```

### Optional Variables

```yaml
# Installation
restic_version: "0.18.0"
restic_install_path: "/usr/local/bin"

# Repository defaults
restic_keep_daily: 7
restic_keep_weekly: 4
restic_keep_monthly: 3

# Per-backup overrides
restic_backups:
  important_db:
    keep_daily: 30 # Override repository default
    monitoring_url: "https://hc.example.com/uuid"
```

See `defaults/main.yml` for all available variables.

## Backup Modes

### stdin Mode (Database Dumps)

```yaml
restic_backups:
  postgresql:
    stdin: true
    stdin_cmd: "sudo -u postgres pg_dump -Fc mydb"
    stdin_filename: "mydb.dump"
```

### Directory Mode (Filesystem Paths)

```yaml
restic_backups:
  grafana:
    src: /var/lib/grafana/dashboards
    exclude:
      - "*.tmp"
      - "cache/*"
```

### Multiple Directories

```yaml
restic_backups:
  configs:
    src:
      - /etc/postgresql
      - /etc/caddy
```

## Example Playbook

```yaml
---
- hosts: db
  become: yes
  roles:
    - restic
```

## Manual Backup Execution

```bash
# Run backup manually
sudo /opt/restic/backup-postgresql.sh

# With additional restic flags
sudo /opt/restic/backup-postgresql.sh --verbose
```

## Tags

- `restic` - All tasks
- `restic-preflight` - Environment validation
- `restic-install` - Binary installation
- `restic-repository` - Repository initialization
- `restic-backup` - Backup job configuration

## License

MIT

## Author

neox5
