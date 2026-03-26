# Certs Role

Deploy TLS certificates, private keys, and CA certificates to target filesystem
following Debian conventions and industry best practices.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)

**This is intentional.** Multi-distro support is explicitly not a goal.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- Certificates and keys generated externally (private CA or other)
- Leaf cert secrets encrypted via SOPS before committing to repository
- CA certificates are plaintext (public material, no encryption required)

## Role Variables

### Leaf Certificates (define in inventory)

```yaml
certs:
  - name: n8n # logical name (used as filename stem)
    cert: "{{ n8n_cert }}" # PEM content (from SOPS secret)
    key: "{{ n8n_key }}" # PEM content (from SOPS secret)
```

### CA Certificates (define in inventory)

```yaml
ca_certs:
  - name: root_ca_g1 # logical name (used as filename stem, must be unique)
    cert: | # PEM content (plaintext - public material)
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
```

### Optional Variables (defaults provided)

```yaml
# Services to reload when certificates change
certs_reload_services:
  - caddy
```

## Deployed File Paths

For each `certs` entry:

| File        | Path                              |
| ----------- | --------------------------------- |
| Certificate | `/etc/ssl/certs/{{ name }}.crt`   |
| Private key | `/etc/ssl/private/{{ name }}.key` |

For each `ca_certs` entry:

| File           | Path                                              |
| -------------- | ------------------------------------------------- |
| CA Certificate | `/usr/local/share/ca-certificates/{{ name }}.crt` |

After deploying CA certificates, `update-ca-certificates` is run to merge
into `/etc/ssl/certs/ca-certificates.crt`.

## File Permissions

| Path                                     | Owner | Group    | Mode |
| ---------------------------------------- | ----- | -------- | ---- |
| `/etc/ssl/private/`                      | root  | ssl-cert | 0710 |
| `/etc/ssl/certs/*.crt`                   | root  | root     | 0644 |
| `/etc/ssl/private/*.key`                 | root  | ssl-cert | 0640 |
| `/usr/local/share/ca-certificates/*.crt` | root  | root     | 0644 |

Private keys are accessible to the `ssl-cert` system group.
Add service users to this group to grant key access without root.

## Service Reload

When leaf certificates change, services listed in `certs_reload_services`
are reloaded via systemd. CA certificate changes trigger `update-ca-certificates`
only (no service reload).

## Example Playbook

```yaml
---
- hosts: web
  become: yes
  roles:
    - certs
```

## License

MIT

## Author

neox5
