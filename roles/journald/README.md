# journald

Operational journald configuration for Debian 13 Trixie systems.

## Drop-in Ordering

Deploys to `/etc/systemd/journald.conf.d/{{ journald_conf_file }}` (default:
`20_journald.conf`). Designed to compose with other roles configuring journald
via numeric prefix ordering:

| File               | Owner                | Purpose               |
| ------------------ | -------------------- | --------------------- |
| `10_security.conf` | `security_hardening` | secure baseline       |
| `20_journald.conf` | `journald`           | operational overrides |

Both roles are fully independent. Later files win on conflict.

## Requirements

- Debian 13 (Trixie) or later
- Ansible 2.15+

## Variables

```yaml
journald_conf_file: 20_journald.conf # drop-in filename
journald_storage: persistent # persistent or volatile
journald_max_retention_sec: 604800 # 7 days

# Mandatory - no defaults, preflight fails if unset
# journald_system_max_use: 512M
# journald_system_keep_free: 2G
```

## Example

```yaml
# inventory/group_vars/n150/journald.yml
journald_storage: persistent
journald_max_retention_sec: 604800
journald_system_max_use: 512M
journald_system_keep_free: 2G
```
