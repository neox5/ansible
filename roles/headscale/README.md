# headscale

Headscale coordination server deployment for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- systemd
- Headscale 0.29.x
- Reverse proxy mode (Caddy terminates TLS)

## Architecture

Headscale runs as a bare-metal systemd service (via official `.deb` package).
Caddy terminates TLS and proxies to `127.0.0.1:8080`.
No Tailscale dependency — external DERP URLs are empty by default.

# headscale

Headscale coordination server deployment for Debian 13 Trixie.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- systemd
- Headscale 0.29.x
- Reverse proxy mode (Caddy terminates TLS)

## Architecture

Headscale runs as a bare-metal systemd service (via official `.deb` package).
Caddy terminates TLS and proxies to `127.0.0.1:8080`.
No Tailscale dependency — external DERP URLs are empty by default.

```
internet → Caddy (443) → headscale (127.0.0.1:8080)
                              │
                         SQLite DB
                    /var/lib/headscale/db.sqlite
```

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Caddy deployed and configured with headscale site block
- Public DNS record pointing `headscale_domain` to host IP

## Role Variables

### Required (set in inventory)

```yaml
headscale_domain: "hs.neox5.com" # domain Caddy serves headscale on
```

### Optional (defaults provided)

```yaml
headscale_version: "0.29.1"
headscale_state: present # present | absent
headscale_remove_data: false # true removes data dir on absent
headscale_node_expiry: "0s" # 0s = disabled
headscale_derp_embedded: false
headscale_derp_urls: [] # empty = no Tailscale dependency
headscale_log_level: "info"
```

See `defaults/main.yaml` for all variables.

## DERP

Embedded DERP and external URLs are mutually exclusive.

**No DERP (default):** direct peer-to-peer WireGuard only.

**Embedded DERP (future):**

```yaml
headscale_derp_embedded: true
```

Also requires UDP 3478 open in the firewall (`security_firewall_allowed_udp_ports`).

**External DERP:**

```yaml
headscale_derp_urls:
  - https://derp.example.com/derp
```

## Node Registration (Operational)

Preauthkeys are short-lived and only needed at registration time.
They are never stored — pass at ansible run time via `--extra-vars`.

```bash
# 1. Create a preauthkey on heimdall
headscale users create infra          # first time only
headscale preauthkeys create --user infra --expiration 1h

# 2. Register a node (run from control node)
ansible-playbook -i inventory/prod playbooks/mesh_join.yaml \
  -l <hostname> \
  --extra-vars "tailscale_authkey=<key>"

# 3. Verify
headscale nodes list
```

## License

MIT

## Author

neox5
