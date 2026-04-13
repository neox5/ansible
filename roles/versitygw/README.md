# versitygw

VersityGW S3-compatible gateway for Debian 13 Trixie — bare-metal deployment
with POSIX backend and optional WebGUI.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- VersityGW installed via `.deb` package from GitHub releases
- POSIX backend only

**This is intentional.** ScoutFS, Azure, and S3 proxy backends are not
supported. Multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Caddy configured separately via inventory (`caddy_sites`)

## Role Variables

### Lifecycle

```yaml
versitygw_state: present # present | absent
versitygw_remove_data: false # true removes data dir (only valid with state: absent)
```

### Version

```yaml
versitygw_version: "1.4.0"
```

### System

```yaml
versitygw_system_user: "versitygw"
versitygw_system_group: "versitygw"
```

### Storage

```yaml
versitygw_data_dir: "/var/lib/versitygw/data"
versitygw_iam_dir: "/var/lib/versitygw/iam"
```

### Network

```yaml
versitygw_s3_listen_addr: "127.0.0.1:7070"
versitygw_webui_listen_addr: "127.0.0.1:7071"
versitygw_webui_gateway_url: "" # public URL for WebGUI → S3 API, e.g. https://s3.zion.local
```

### Credentials (mandatory — SOPS-encrypted in inventory)

```yaml
versitygw_root_access_key_secret: "" # ROOT_ACCESS_KEY
versitygw_root_secret_key_secret: "" # ROOT_SECRET_KEY
```

See `defaults/main.yaml` for all available variables.

## Caddy Integration

This role does NOT configure Caddy. Add to inventory `caddy_sites`:

```yaml
caddy_sites:
  - domain: "s3.zion.local"
    backend: "localhost:7070"
  - domain: "s3ui.zion.local"
    backend: "localhost:7071"
```

## Credentials

Root credentials are written to `/etc/versitygw/env` (mode `0640`,
`root:versitygw`) and loaded via systemd `EnvironmentFile=`. They never
appear in `ExecStart` or process listings.

## What This Role Does

### Install (`state: present`)

1. Validates environment (Debian 13+, systemd)
2. Creates system user and group
3. Creates data, IAM, and config directories
4. Downloads and installs `.deb` package from GitHub releases
5. Deploys `EnvironmentFile` with root credentials
6. Deploys systemd service unit
7. Enables and starts service
8. Verifies health endpoint responds

### Remove (`state: absent`)

1. Validates environment
2. Stops and disables service
3. Removes systemd unit file and environment file
4. Removes config directory
5. Removes data and IAM directories (only if `versitygw_remove_data: true`)
6. Removes system user and group

## License

MIT

## Author

neox5
