# ziti_controller Role

Deploys an [OpenZiti](https://openziti.io) controller on Debian 13 Trixie via the official APT package.

## Overview

Installs `openziti-controller` from the OpenZiti APT repository, generates a complete ECC PKI
using `ziti pki create` with a configurable curve, renders `config.yml` from a template, initialises
the bbolt database, and starts the systemd service. The bootstrap script shipped with the package is
disabled — all PKI generation and configuration is handled by the role.

## PKI Architecture

The controller requires three certificate functions:

- **Root CA** — trust anchor for the entire overlay network. Generated once per network.
  Private key must be removed from the controller host after bootstrap and stored offline.
- **Signing CA (intermediate)** — issues router and tunneler certificates during enrollment.
  Stays on the controller host. Can be reissued from the offline root if lost.
- **Controller leaf certs** — server and client certificates for the controller's mTLS identity.
  Issued from the signing CA. Renewed automatically one week before expiry.

All keys and certificates use the curve configured by `ziti_curve` (default: `P-256`).

## Bootstrap Process

### Run 1 — PKI, config, and database initialisation

1. APT repository is configured and `openziti-controller` is installed
2. Package bootstrap is disabled via `service.env`
3. PKI is generated under `ziti_controller_pki_dir`:
   - Root CA key + cert
   - Signing CA (intermediate) key + cert
   - Controller server cert + key
   - Controller client cert + key
4. Root CA private key is fetched to `ziti_root_ca_fetch_path` on the control node
5. Root CA private key is removed from the controller host
6. `config.yml` is rendered from template
7. Database is initialised with `ziti controller edge init`
8. Service is enabled and started

The role emits a post-bootstrap message instructing the operator to encrypt the fetched root CA
private key and store it offline (e.g. SOPS-encrypted or on removable media).

### Run 2+ — idempotent

PKI generation and database init are gated on file existence checks. Re-running is safe:
existing PKI and database are left untouched, configuration changes are applied and the service
is restarted if needed.

## PKI Lifecycle

### Root CA key

After Run 1, the root CA private key must be stored offline. It is required only to:

- Issue a new signing CA (e.g. after signing CA expiry or controller rebuild)
- Add a second controller node to a cluster

The controller does **not** need the root CA key during normal operation.

### Signing CA renewal

The signing CA has a 10-year validity by default. When it approaches expiry:

1. Restore the root CA private key to a secure temporary location
2. Run the role with `ziti_renew_signing_ca: true` — this generates a new signing CA,
   deploys it to the controller, and restarts the service
3. Remove the root CA private key again

### Controller leaf cert renewal

A systemd timer provided by the `openziti-controller` package renews leaf certs automatically
one week before expiry. No operator action required.

## Backup Requirements

Three stateful components must be backed up to enable recovery:

| Component                     | Path                               | Notes                                 |
| ----------------------------- | ---------------------------------- | ------------------------------------- |
| Database snapshot             | `ziti_controller_db_dir/ctrl.db-*` | Created by `ziti edge db snapshot`    |
| PKI (signing CA + leaf certs) | `ziti_controller_pki_dir/`         | Root CA key stored separately offline |
| Config file                   | `ziti_controller_config_file`      | Required to start the controller      |

### Creating a database snapshot

The controller must be running. Authenticate and trigger a snapshot:

```bash
ziti edge login https://localhost:<port> -u admin -p <password> --yes
ziti edge db snapshot
```

The snapshot is written as `ctrl.db-YYYYMMDD-HHMMSS` in the same directory as `ctrl.db`.
Back up the snapshot file, not the live `ctrl.db` (bbolt is unsafe to copy while open).

### Recovery procedure

1. Install `openziti-controller` on the replacement host
2. Restore `config.yml` (edit paths if changed)
3. Restore the PKI directory
4. Restore the database snapshot, rename it to `ctrl.db`
5. Set `ZITI_BOOTSTRAP=false` in `service.env`
6. Start the service

If the signing CA private key was also lost: restore the offline root CA key, reissue the
signing CA from it, deploy the new signing CA, then re-enroll any routers and tunnelers
whose certs were signed by the previous signing CA.

## Removal

Set `ziti_controller_state: absent` and re-run. Set `ziti_controller_remove_data: true`
to also remove the PKI and database (destructive and irreversible).

## Key Variables

| Variable                        | Default                               | Description                                                |
| ------------------------------- | ------------------------------------- | ---------------------------------------------------------- |
| `ziti_controller_state`         | `present`                             | `present` or `absent`                                      |
| `ziti_controller_remove_data`   | `false`                               | Remove PKI and database on absent                          |
| `ziti_ctrl_advertised_address`  | `""`                                  | Permanent DNS name of the controller (required)            |
| `ziti_ctrl_advertised_port`     | `1280`                                | Controller listen port                                     |
| `ziti_trust_domain`             | `""`                                  | SPIFFE trust domain for the cluster (required)             |
| `ziti_curve`                    | `P-256`                               | ECC curve for all PKI key generation                       |
| `ziti_admin_password`           | `""`                                  | Admin password for edge init and CLI auth (required, SOPS) |
| `ziti_controller_pki_dir`       | `/var/lib/ziti-controller/pki`        | PKI root directory                                         |
| `ziti_controller_db_dir`        | `/var/lib/ziti-controller/db`         | Database directory                                         |
| `ziti_controller_config_file`   | `/var/lib/ziti-controller/config.yml` | Controller config path                                     |
| `ziti_root_ca_fetch_path`       | `/tmp/ziti-root-ca.key`               | Control node path for fetched root CA key                  |
| `ziti_root_ca_validity_days`    | `3650`                                | Root CA validity in days (10 years)                        |
| `ziti_signing_ca_validity_days` | `3650`                                | Signing CA validity in days (10 years)                     |
| `ziti_leaf_validity_days`       | `365`                                 | Controller leaf cert validity in days                      |
| `ziti_renew_signing_ca`         | `false`                               | Force signing CA reissue (requires offline root CA key)    |

## Notes

- `ziti_ctrl_advertised_address` is permanent — embedded in all PKI SANs; changing it requires
  regenerating the entire PKI and re-enrolling all components
- `ziti_admin_password` must be SOPS-encrypted in inventory
- The root CA private key is removed from the host after bootstrap; store the fetched copy offline
- The controller always runs in clustered mode even for single-node deployments (OpenZiti v2.0+)
