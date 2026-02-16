# Caddy Reverse Proxy Role

Custom Caddy role for Debian 13 Trixie - reverse proxy with automatic HTTPS.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Caddy 2.x (installed via APT)

**This is intentional.** Multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Valid domain names (for Let's Encrypt)
- Ports 80/443 accessible (for ACME HTTP-01 challenge)

## Role Variables

### Required Variables (define in inventory)

```yaml
caddy_email: "[email protected]" # Let's Encrypt contact

caddy_sites:
  - domain: app.example.com
    backend: localhost:3000
  - domain: api.example.com
    backend: localhost:8080
```

### Optional Variables (defaults provided)

```yaml
caddy_version: 2 # Major version pin
```

See `defaults/main.yml` for all available variables.

## Example Playbook

```yaml
---
- hosts: web
  become: yes
  roles:
    - caddy
```

## Inventory Example

```yaml
# group_vars/web/caddy.yml
caddy_email: "[email protected]"

caddy_sites:
  - domain: n8n.example.com
    backend: localhost:5678
```

## Tags

- `caddy` - All tasks
- `caddy-preflight` - Environment validation
- `caddy-install` - Package installation
- `caddy-configure` - Configuration deployment

## Certificate Management

Caddy handles Let's Encrypt certificates automatically:

- Obtains certificates on first request
- Renews before expiration
- Stored in `/var/lib/caddy/.local/share/caddy`

## Future Caddy Versions

When Caddy 3.x is released:

1. Evaluate migration path from 2.x → 3.x
2. Test in lab environment
3. Update role version pin
4. Update templates if needed
5. Document breaking changes

## License

MIT

## Author

neox5
