# Restic Role

Ansible role for restic backup automation on Debian 13 Trixie. Unified repository model with full backup lifecycle support.

## Model

Three entities:

- **Sources** — what gets backed up (paths or stdin)
- **Repositories** — where snapshots are stored (any backend)
- **Jobs** — when and how (backup or copy, on a schedule)

## Requirements

- Debian 13 Trixie or later
- SSH access from control node

## Configuration

### Sources

```yaml
restic_sources:
  postgresql:
    stdin: true
    stdin_command: "sudo -u postgres pg_dump -Fc mydb"
    stdin_filename: "mydb.dump"
    tags:
      - database

  configs:
    paths:
      - /etc/postgresql
      - /etc/caddy
    tags:
      - config
```

Each source requires exactly one input mode: `stdin` (with `stdin_command` and `stdin_filename`) or `paths` (string or list). Optional `exclude` patterns for directory mode. Optional `tags` applied to all snapshots.

### Repositories

```yaml
restic_repos:
  local:
    primary: true
    password: "{{ vault_restic_local_password }}"
    backend:
      local:
        path: "/srv/restic"
    retention:
      keep_daily: 7
      keep_weekly: 4
      keep_monthly: 3
      prune: true
    check:
      schedule: "*-*-01 06:00:00"
      read_data_subset: "10%"

  offsite_b2:
    password: "{{ vault_restic_offsite_password }}"
    backend:
      s3:
        endpoint: "https://s3.us-east-005.backblazeb2.com"
        bucket: "my-bucket"
        key_id: "{{ vault_b2_key_id }}"
        key_secret: "{{ vault_b2_key_secret }}"
    retention:
      keep_daily: 3
      keep_weekly: 2
      prune: true
```

Exactly one repository must have `primary: true`. Non-primary repositories are initialized with `--copy-chunker-params` from the primary to ensure deduplication across copies.

**Backend types:**

`local` — `path`

`s3` — `endpoint`, `bucket`, `key_id`, `key_secret`

### Jobs

```yaml
restic_jobs:
  nightly_backup:
    type: backup
    sources:
      - postgresql
      - configs
    repo: local
    schedule: "*-*-* 02:00:00"
    on_failure: continue
    tags:
      - nightly

  offsite_copy:
    type: copy
    sources:
      - postgresql
      - configs
    from: local
    to: offsite_b2
    schedule: "*-*-* 05:30:00"
    on_failure: continue
```

`type: backup` requires `repo`. `type: copy` requires `from` and `to`.

`on_failure`: `continue` (default) runs all sources even if one fails. `stop` exits on first failure. Either way, the systemd unit reports failure if any source failed.

Job `tags` are additive to source tags.

## Defaults

```yaml
restic_version: "0.18.0"
restic_download_path: "/opt"
restic_install_path: "/usr/local/bin"
restic_script_dir: "/opt/restic"
restic_log_dir: "/var/log/restic"
restic_user: "root"
restic_restore_target: "/tmp/restic-restore"
restic_retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 3
  prune: true
```

## Generated Artifacts

**Scripts** in `restic_script_dir`:

| Script                       | Per              | Purpose                           |
| ---------------------------- | ---------------- | --------------------------------- |
| `env-<repo>.sh`              | repository       | Environment variables             |
| `backup-<job>.sh`            | backup job       | Backup + scoped forget per source |
| `copy-<job>.sh`              | copy job         | Copy + scoped forget per source   |
| `restore-<source>-<repo>.sh` | source-repo pair | Restore from any repository       |
| `check-<repo>.sh`            | repository       | Integrity verification            |

**systemd units** in `/etc/systemd/system`:

| Unit                                     | Per        | Purpose                   |
| ---------------------------------------- | ---------- | ------------------------- |
| `restic-<job>.service` + `.timer`        | job        | Scheduled backup/copy     |
| `restic-check-<repo>.service` + `.timer` | repository | Scheduled integrity check |

## Manual Operations

```bash
# Run backup manually
sudo /opt/restic/backup-nightly_backup.sh

# Run copy manually
sudo /opt/restic/copy-offsite_copy.sh

# Restore stdin source (pipe to pg_restore)
sudo /opt/restic/restore-postgresql-local.sh latest | sudo -u postgres pg_restore -d mydb --clean --if-exists

# Restore directory source
sudo /opt/restic/restore-configs-local.sh latest /tmp/restore

# Restore from offsite (disaster recovery)
sudo /opt/restic/restore-postgresql-offsite_b2.sh latest | sudo -u postgres pg_restore -d mydb --clean --if-exists

# Check repository
sudo /opt/restic/check-local.sh

# List timers
systemctl list-timers 'restic-*'
```

## Example Playbook

```yaml
---
- hosts: backup
  become: yes
  roles:
    - restic
```

## License

MIT

## Author

neox5
