# Restic Backup Role

Custom restic role for Debian 13 Trixie — automated backups with systemd timers and off-site replication via restic copy.

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
    stdin_command: "sudo -u postgres pg_dump -Fc db1"
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
restic_prune: true
restic_tags: []

# Scheduling
restic_schedule_enabled: true

# Restore
restic_restore_target: "/tmp/restic-restore"
```

See `defaults/main.yml` for all available variables.

## Backup Configuration

Each entry in `restic_backups` defines a backup job. Exactly one input mode is required: stdin or directory.

### stdin Mode (Database Dumps)

```yaml
restic_backups:
  postgresql:
    stdin: true
    stdin_command: "sudo -u postgres pg_dump -Fc mydb"
    stdin_filename: "mydb.dump"
    schedule: "*-*-* 02:00:00"
```

### Directory Mode (Filesystem Paths)

```yaml
restic_backups:
  grafana:
    paths: /var/lib/grafana/dashboards
    schedule: "*-*-* 03:00:00"
    exclude:
      - "*.tmp"
      - "cache/*"
```

### Multiple Directories

```yaml
restic_backups:
  configs:
    paths:
      - /etc/postgresql
      - /etc/caddy
    schedule: "*-*-* 04:00:00"
```

### Per-Backup Overrides

Each backup can override repository-level retention and behavior defaults:

```yaml
restic_backups:
  important_db:
    stdin: true
    stdin_command: "sudo -u postgres pg_dump -Fc critical"
    stdin_filename: "critical.dump"
    schedule: "*-*-* 01:00:00"
    keep_daily: 30 # Override repository default
    keep_weekly: 12
    prune: true
    tags:
      - critical
    restore_target: "/tmp/critical-restore"
    monitoring_url: "https://hc.example.com/uuid"
```

## Off-Site Replication (Copy)

Backups can be replicated to remote repositories using `restic copy`. This requires backend definitions and per-backup copy entries.

### Backend Definitions

Backends define remote storage credentials. Defined once, referenced by name in copy jobs.

```yaml
restic_backends:
  offsite_b2:
    type: s3_compatible
    endpoint: "https://s3.us-east-005.backblazeb2.com"
    bucket: "my-restic-bucket"
    key_id: "{{ restic_b2_key_id_secret }}"
    key_secret: "{{ restic_b2_key_secret }}"
```

Supported backend types: `s3_compatible` (covers B2 via S3 API, Wasabi, MinIO, R2).

### Copy Configuration

Add `copies` to any backup to replicate its snapshots to a remote repository:

```yaml
restic_backups:
  n8n_database:
    stdin: true
    stdin_command: "sudo -u postgres pg_dump -Fc n8n"
    stdin_filename: "n8n.dump"
    schedule: "*-*-* 02:30:00"
    prune: true
    copies:
      - backend: offsite_b2
        path: "n150-01"
        password: "{{ restic_b2_repo_password_secret }}"
        schedule: "*-*-* 05:30:00"
```

Each copy entry creates a systemd timer that runs `restic copy` filtered to the parent backup's paths, followed by `restic forget` on the destination repository.

### Copy Retention

Copy destinations enforce retention after each copy. The precedence chain is: copy-level override → backup-level override → repository default.

```yaml
copies:
  - backend: offsite_b2
    path: "n150-01"
    password: "{{ secret }}"
    schedule: "*-*-* 05:30:00"
    keep_daily: 3 # Shorter remote retention to reduce storage costs
    keep_weekly: 2
    prune: true
```

### Copy Scheduling Defaults

```yaml
restic_copy_schedule_enabled: true # Enable/disable all copy timers
restic_copy_prune: true # Run --prune with remote forget
```

## Backup Grammar Reference

Complete per-backup key reference:

```yaml
restic_backups:
  <name>:
    # --- Input mode (exactly one required) ---
    # Directory mode:
    paths: <string or list> # File/directory paths to back up
    exclude: <list> # Exclude patterns (directory mode only)

    # OR stdin mode:
    stdin: true # Enable stdin mode
    stdin_command: <string> # Command piped to restic backup
    stdin_filename: <string> # Filename stored in snapshot

    # --- Scheduling ---
    schedule: <OnCalendar> # systemd timer schedule
    schedule_enabled: <bool> # Override restic_schedule_enabled

    # --- Retention (override repository defaults) ---
    keep_last: <int>
    keep_hourly: <int>
    keep_daily: <int>
    keep_weekly: <int>
    keep_monthly: <int>
    keep_yearly: <int>
    keep_within: <duration>
    prune: <bool> # Override restic_prune

    # --- Tags ---
    tags: <list> # Additional snapshot tags

    # --- Restore ---
    restore_target: <path> # Default restore location

    # --- Monitoring ---
    monitoring_url: <url> # Ping URL on backup+forget success

    # --- Copy jobs ---
    copies:
      - backend: <backend_name> # Reference to restic_backends key
        path: <string> # Sub-path within backend bucket
        password: <string> # Destination repository password
        schedule: <OnCalendar> # systemd timer schedule
        schedule_enabled: <bool> # Override restic_copy_schedule_enabled
        keep_daily: <int> # Override backup/repository retention
        keep_weekly: <int>
        keep_monthly: <int>
        prune: <bool> # Override restic_copy_prune
```

## Generated Scripts

The role deploys operational scripts to `{{ restic_script_dir }}` (default: `/opt/restic/`):

### Local Repository

| Script              | Purpose                                       |
| ------------------- | --------------------------------------------- |
| `backup-<name>.sh`  | Run backup, then forget with retention policy |
| `list.sh`           | List all snapshots in repository              |
| `list-<name>.sh`    | List snapshots for a specific backup          |
| `restore-<name>.sh` | Restore from local repository                 |
| `check.sh`          | Verify local repository integrity             |

### Remote Repository (per copy job)

| Script                             | Purpose                                              |
| ---------------------------------- | ---------------------------------------------------- |
| `copy-<name>-<backend>.sh`         | Copy snapshots to remote, then forget with retention |
| `check-copy-<name>-<backend>.sh`   | Verify remote repository integrity                   |
| `restore-copy-<name>-<backend>.sh` | Restore from remote repository                       |

### Manual Execution

```bash
# Run backup manually
sudo /opt/restic/backup-postgresql.sh

# With additional restic flags
sudo /opt/restic/backup-postgresql.sh --verbose

# List snapshots
sudo /opt/restic/list.sh
sudo /opt/restic/list-postgresql.sh

# Check repository integrity
sudo /opt/restic/check.sh
sudo /opt/restic/check-copy-postgresql-offsite_b2.sh

# Restore from local
sudo /opt/restic/restore-postgresql.sh [snapshot_id]

# Restore from remote (disaster recovery)
sudo /opt/restic/restore-copy-postgresql-offsite_b2.sh [snapshot_id]

# stdin restore piped to pg_restore
sudo /opt/restic/restore-postgresql.sh latest | sudo -u postgres pg_restore -d mydb --clean --if-exists
```

## systemd Units

Each backup creates a service and timer pair. Each copy job creates an additional pair.

```bash
# List backup timers
systemctl list-timers 'restic-backup-*'

# List copy timers
systemctl list-timers 'restic-copy-*'

# Run backup immediately
systemctl start restic-backup-postgresql.service

# Run copy immediately
systemctl start restic-copy-postgresql-offsite_b2.service
```

## Example Playbook

```yaml
---
- hosts: backup
  become: yes
  roles:
    - restic
```

## Tags

- `restic` — All tasks
- `restic-preflight` — Environment validation
- `restic-install` — Binary installation
- `restic-repository` — Repository initialization
- `restic-backup` — Backup job configuration
- `restic-copy` — Copy job configuration

## License

MIT

## Author

neox5
