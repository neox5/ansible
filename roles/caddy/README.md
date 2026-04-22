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
    routes:
      - backend: localhost:3000
  - domain: api.example.com
    routes:
      - backend: localhost:8080
```

### Optional Variables (defaults provided)

```yaml
caddy_version: 2 # Major version pin
```

See `defaults/main.yaml` for all available variables.

## Route Configuration

Each site requires a `routes` list. Every route must have a `backend`. Two optional fields:

- `path` — Caddy path matcher prefix (e.g. `/ui/v2/login/*`). Omit for catch-all.
- `headers_up` — list of `header_up` directives passed into the `reverse_proxy` block.

Routes are rendered in order — put path-specific routes before catch-all.

```yaml
caddy_sites:
  - domain: zitadel.example.com
    routes:
      - path: /ui/v2/login/*
        backend: http://localhost:3000
      - backend: h2c://localhost:8080
        headers_up:
          - "-TE"
```

## TLS Configuration

Three modes supported via the `tls` parameter:

### 1. Caddy Internal CA (lab/development)

```yaml
caddy_sites:
  - domain: app.lab.local
    routes:
      - backend: localhost:3000
    tls: internal
```

### 2. Let's Encrypt (production with public DNS)

```yaml
caddy_sites:
  - domain: app.example.com
    routes:
      - backend: localhost:3000
    tls: "[email protected]"
```

### 3. External Certificates (certs role integration)

```yaml
caddy_sites:
  - domain: app.example.com
    routes:
      - backend: localhost:3000
    tls:
      cert: /etc/ssl/certs/app.crt
      key: /etc/ssl/private/app.key
```

When using external certificates, configure the `certs` role to reload Caddy on certificate changes:

```yaml
certs:
  - name: app
    cert: "{{ app_cert }}"
    key: "{{ app_key }}"

certs_reload_services:
  - caddy
```

## Firewall Configuration

For any host running Caddy, open ports 80/443 in inventory:

```yaml
security_firewall_allowed_tcp_ports:
  - 80
  - 443
```

## Example Playbook

```yaml
---
- hosts: web
  become: yes
  roles:
    - caddy
```

## Certificate Management

### Let's Encrypt (Automatic)

Caddy handles certificates automatically:

- Obtains certificates on first request
- Renews before expiration
- Stored in `/var/lib/caddy/.local/share/caddy`

### External Certificates

When using external certificates via the `certs` role:

- Caddy user is added to `ssl-cert` group for key access
- Certificate paths must match certs role output locations
- Configure `certs_reload_services` to reload Caddy on cert changes

## Future Caddy Versions

When Caddy 3.x is released:

1. Evaluate migration path from 2.x → 3.x
2. Test in lab environment
3. Update role version pin
4. Document breaking changes

## License

MIT

## Author

neox5
