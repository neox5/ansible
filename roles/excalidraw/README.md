# Excalidraw Role

Self-hosted Excalidraw stack deployment via Podman Quadlet.
Deploys two containers: excalidraw (frontend) and excalibar (collaboration room server).

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- Podman 5.4+
- System-level (rootful) containers

**This is intentional.** User-level (rootless) support and multi-distro support can be added later if needed.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- quadlet role (called internally)
- Caddy configured separately via inventory

## Role Variables

### Required Variables (define in inventory)

```yaml
excalidraw_collab_server_url: "excalibar.zion.local" # hostname only, no protocol
```

### Optional Variables

```yaml
# excalidraw frontend
excalidraw_version: "v0.18.0-self-hosted"
excalidraw_port: 8080

# excalibar collaboration server
excalibar_version: "v1.0.1"
excalibar_port: 8085
excalibar_cors_origin: "*"
```

See `defaults/main.yaml` for all available variables.

## Caddy Integration

This role does NOT configure Caddy. Add to inventory:

```yaml
caddy_sites:
  - domain: excalidraw.zion.local
    backend: localhost:8080
    tls: internal
  - domain: excalibar.zion.local
    backend: localhost:8085
    tls: internal
```

## Example Playbook

```yaml
---
- hosts: excalidraw
  become: yes
  roles:
    - excalidraw
```

## What This Role Does

1. Validates environment (Debian 13+)
2. Validates required variables are set
3. Deploys excalidraw frontend container via quadlet role
4. Deploys excalibar collaboration server container via quadlet role

## License

MIT

## Author

neox5
