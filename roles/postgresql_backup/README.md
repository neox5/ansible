# PostgreSQL Backup Role

Creates PostgreSQL database backups using pg_dump.

## Purpose

Reusable role for backing up PostgreSQL databases to dump files. This is a building block that handles only the dump operation - scheduling and storage management are separate concerns.

## Requirements

- PostgreSQL installed and running
- community.postgresql collection
- User with sufficient privileges to dump databases

## Role Variables

### Required Variables

None - role works with defaults for local PostgreSQL instance.

### Optional Variables

```yaml
# Specific databases to backup (empty = all databases)
postgresql_backup_databases:
  - myapp
  - another_db

# Backup directory
postgresql_backup_dir: "/var/backups/postgresql"

# PostgreSQL connection
postgresql_backup_host: "localhost"
postgresql_backup_port: 5432
postgresql_backup_user: "postgres"

# Backup format (custom is compressed binary)
postgresql_backup_format: "custom"

# Retention
postgresql_backup_keep_days: 7
postgresql_backup_cleanup_enabled: true
```

## Example Playbook

```yaml
---
# Backup all databases
- hosts: db
  become: yes
  roles:
    - postgresql_backup

# Backup specific databases
- hosts: db
  become: yes
  roles:
    - role: postgresql_backup
      vars:
        postgresql_backup_databases:
          - n8n
          - nextcloud
```

## Backup Files

Backups are created with naming pattern:

```
{{ inventory_hostname }}-{{ database }}-{{ timestamp }}.dump
```

Example: `n150-01-n8n-20260212T143022.dump`

## Cleanup

By default, backups older than 7 days are automatically removed. Disable with:

```yaml
postgresql_backup_cleanup_enabled: false
```

## Integration

This role outputs dump files to a directory. Other roles can:

- Copy files to remote storage (Restic, S3, etc.)
- Create systemd timers for scheduling
- Set up monitoring and alerts

## License

MIT

## Author

neox5
