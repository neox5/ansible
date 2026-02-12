# PostgreSQL Restore Role

Restores PostgreSQL databases from dump files.

## Purpose

Reusable role for restoring PostgreSQL databases from pg_dump backups. Handles database recreation and data restoration from dump files.

## Requirements

- PostgreSQL installed and running
- community.postgresql collection
- User with sufficient privileges to create/restore databases
- Valid dump file from pg_dump

## Role Variables

### Required Variables

```yaml
postgresql_restore_database: "myapp" # Database name
postgresql_restore_dump_file: "/path/to/dump" # Path to dump file
```

### Optional Variables

```yaml
# PostgreSQL connection
postgresql_restore_host: "localhost"
postgresql_restore_port: 5432
postgresql_restore_user: "postgres"

# Restore behavior
postgresql_restore_drop_existing: false # Drop database before restore
postgresql_restore_create_db: true # Create database if missing
postgresql_restore_owner: "postgres" # Database owner
```

## Example Playbook

```yaml
---
# Emergency restore
- hosts: db
  become: yes
  roles:
    - role: postgresql_restore
      vars:
        postgresql_restore_database: n8n
        postgresql_restore_dump_file: /backup/n8n-20260212.dump
        postgresql_restore_drop_existing: true
```

## Interactive Restore

```yaml
---
- hosts: db
  become: yes
  vars_prompt:
    - name: restore_db
      prompt: "Database name to restore"
      private: no

    - name: restore_file
      prompt: "Path to dump file"
      private: no

    - name: drop_existing
      prompt: "Drop existing database? (yes/no)"
      private: no
      default: "no"

  roles:
    - role: postgresql_restore
      vars:
        postgresql_restore_database: "{{ restore_db }}"
        postgresql_restore_dump_file: "{{ restore_file }}"
        postgresql_restore_drop_existing: "{{ drop_existing == 'yes' }}"
```

## License

MIT

## Author

neox5
