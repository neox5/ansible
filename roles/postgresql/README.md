# PostgreSQL Custom Role

PostgreSQL 17 deployment for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- PostgreSQL 17

**This is intentional.** Multi-version and multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- community.postgresql collection

## Role Variables

### Required Variables (define in inventory)

```yaml
postgresql_databases:
  - name: myapp
    owner: myapp_user
    encoding: UTF-8
    lc_collate: en_US.UTF-8
    lc_ctype: en_US.UTF-8

postgresql_users:
  - name: myapp_user
    password: "{{ myapp_db_password }}" # Use SOPS encryption
    encrypted: yes
    role_attr_flags: NOCREATEDB,NOSUPERUSER
```

### Hardware Tuning (override in inventory)

```yaml
# Example: N150 mini cube (12GB RAM, SSD)
postgresql_shared_buffers: "3GB"
postgresql_effective_cache_size: "8GB"
postgresql_work_mem: "30MB"
postgresql_maintenance_work_mem: "512MB"
postgresql_random_page_cost: 1.1 # SSD
postgresql_effective_io_concurrency: 200 # SSD
```

See `defaults/main.yml` for all available variables.

## Database Ownership and Privileges

**Database ownership grants ALL privileges automatically.**

There is no separate `postgresql_user_privileges` variable. When you specify `owner` in `postgresql_databases`, that user receives full privileges on the database.

## Example Playbook

```yaml
---
- hosts: db
  become: yes
  roles:
    - postgresql
```

## Tags

- `postgresql` - All tasks
- `postgresql-preflight` - Environment validation
- `postgresql-install` - Package installation
- `postgresql-configure` - Configuration deployment
- `postgresql-databases` - Database creation
- `postgresql-users` - User creation

## Migration from anxs.postgresql

1. Remove `anxs.postgresql` from `requirements.yml`
2. Remove `postgresql_user_privileges` variable from inventory
3. Ensure `role_attr_flags` is in `postgresql_users` (not privileges)
4. Deploy role

## Future PostgreSQL Versions

When PostgreSQL 18 is released:

1. Evaluate migration path from 17 → 18
2. Test in lab environment
3. Update role version pin
4. Update templates if needed
5. Document breaking changes

This role does NOT support running multiple PostgreSQL versions simultaneously.

## License

MIT

## Author

neox5
