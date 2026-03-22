# stepca Role

Deploys Smallstep [step-ca](https://smallstep.com/docs/step-ca) as an issuing CA on Debian 13 Trixie.

## Overview

Installs `step-ca` and `step` CLI binaries, generates an intermediate CA key and CSR,
and writes the CA configuration. Designed exclusively for use as an issuing CA subordinate
to an external root CA via sneakernet CSR signing.

## Bootstrap Process

### Run 1 — key, CSR, and config generation

1. Ansible writes the operator-provided password to `secrets/password`
2. Ansible generates intermediate CA key + CSR via `step certificate create --csr`
3. Ansible writes `ca.json` from template
4. Ansible installs the systemd unit (enabled, not started)
5. CSR is fetched to `stepca_csr_fetch_path` on the control node
6. Playbook halts with operator instructions

### Manual sneakernet steps

1. Sign the CSR with your root CA using an intermediate CA profile (CA:true, pathlen:0, keyCertSign, cRLSign)
2. Place the signed certificate at `{{ stepca_certs_dir }}/intermediate_ca.crt` on the target
3. Place the root CA certificate at `{{ stepca_certs_dir }}/root_ca.crt` on the target

```bash
cd <pki-root-ca-dir>
cp {{ stepca_csr_fetch_path }} csr/issuing_ca.csr.pem
openssl ca -config openssl.cnf \
  -extensions v3_intermediate_ca \
  -notext \
  -in csr/issuing_ca.csr.pem \
  -out certs/issuing_ca.cert.pem
```

### Run 2+ — idempotent

Re-running the playbook after certificates are placed is safe:
bootstrap is skipped (cert exists), service starts automatically.

## Certificate Rollover (e.g. G1 → G2)

1. Update inventory: set `stepca_name`, `stepca_cert_name`, and `stepca_key_password_secret` to G2 values.
2. Run `pki.yaml` — bootstrap detects G2 cert absent, generates new key + CSR, halts awaiting sneakernet.
3. Sign the CSR with the root CA. Place the signed G2 certificate on the target.
4. Run `pki.yaml` again — `ca.json` is rewritten pointing to G2 cert and key, service restarts.

G1 key and cert remain on disk until all G1-issued leaf certificates have expired.

## Removal

Set `stepca_state: absent` and re-run to fully remove all stepca artifacts,
binaries, configuration, and the systemd unit.

## Key Variables

| Variable                     | Default                   | Description                                          |
| ---------------------------- | ------------------------- | ---------------------------------------------------- |
| `stepca_state`               | `present`                 | `present` or `absent`                                |
| `stepca_version`             | `0.29.0`                  | step-ca binary version                               |
| `stepca_name`                | `Issuing CA`              | CA display name (used as CSR subject)                |
| `stepca_address`             | `127.0.0.1:9443`          | Listen address                                       |
| `stepca_dns_names`           | `[]`                      | Additional DNS names for CA                          |
| `stepca_db_datasource`       | `""`                      | PostgreSQL DSN (required)                            |
| `stepca_key_password_secret` | `""`                      | Intermediate key password (required, SOPS encrypted) |
| `stepca_csr_fetch_path`      | `/tmp/stepca-issuing.csr` | CSR destination on control node                      |
| `stepca_key_type`            | `EC`                      | Intermediate key type                                |
| `stepca_key_curve`           | `P-384`                   | Intermediate key curve                               |

## Notes

- The intermediate CA key never leaves the online host
- Service starts automatically on re-run once certificates are in place
- `stepca_key_password_secret` must be SOPS encrypted in inventory
- Root CA key must never be present on this host
