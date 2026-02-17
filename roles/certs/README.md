# Certs Role

Deploy TLS certificates and private keys to target filesystem following
Debian conventions and industry best practices.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)

**This is intentional.** Multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Certificates and keys generated externally (private CA or other)
- Secrets encrypted via SOPS before committing to repository

## Role Variables

### Required Variables (define in inventory)

```yaml
certs:
  - name: n8n # logical name (used as filename stem)
    cert: "{{ n8n_cert }}" # PEM content (from SOPS secret)
    key: "{{ n8n_key }}" # PEM content (from SOPS secret)
```

### Optional Variables (defaults provided)

```yaml
# Services to reload when certificates change
certs_reload_services:
  - caddy
```

## Deployed File Paths

For each cert entry:

| File        | Path                              |
| ----------- | --------------------------------- |
| Certificate | `/etc/ssl/certs/{{ name }}.crt`   |
| Private key | `/etc/ssl/private/{{ name }}.key` |

## File Permissions

| Path                | Owner | Group    | Mode |
| ------------------- | ----- | -------- | ---- |
| `/etc/ssl/private/` | root  | ssl-cert | 0710 |
| `*.crt`             | root  | root     | 0644 |
| `*.key`             | root  | ssl-cert | 0640 |

Private keys are accessible to the `ssl-cert` system group.
Add service users to this group to grant key access without root.

## Service Reload

When certificates change, services listed in `certs_reload_services`
are reloaded via systemd. Configure at the inventory level alongside
the cert definitions.

## Example Playbook

```yaml
---
- hosts: web
  become: yes
  roles:
    - certs
```

## Tags

- `certs` - All tasks
- `certs-preflight` - Environment validation
- `certs-deploy` - Certificate and key deployment

## License

MIT

## Author

neox5
