## Removal

Removal has three escalating levels, controlled by two independent flags:

| Level | Flags                                                          | Removes                                                         | Preserves                                  |
| ----- | --------------------------------------------------------------- | ----------------------------------------------------------------- | --------------------------------------------- |
| 1     | `ziti_controller_state: absent`                                | Service, package, APT repo/keyring, config file                | All PKI, database, base dir, system user   |
| 2     | `+ ziti_controller_remove_data: true`                          | + Signing CA, leaf certs, database                              | Root CA, base dir, system user             |
| 3     | `+ ziti_controller_remove_root_ca: true`                       | + Root CA, base dir, `ziti-controller` system user/group        | Nothing — full prune, irreversible         |

`ziti_controller_remove_root_ca: true` requires `ziti_controller_remove_data: true` — enforced
in preflight. Level 3 destroys this network's root of trust with no recovery path; re-running
the role afterward starts an entirely new network.

## Key Variables

| Variable                          | Default                               | Description                                                                    |
| ----------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------- |
| `ziti_controller_state`           | `present`                             | `present` or `absent`                                                          |
| `ziti_controller_remove_data`     | `false`                                | Level 2 removal — signing CA, leaf certs, database                             |
| `ziti_controller_remove_root_ca`  | `false`                                | Level 3 removal — root CA, base dir, system user/group (requires remove_data)  |
| `ziti_ctrl_advertised_address`    | `""`                                   | Permanent DNS name of the controller (required)                                |
| `ziti_ctrl_advertised_port`       | `1280`                                 | Controller listen port                                                         |
| `ziti_trust_domain`               | `""`                                   | SPIFFE trust domain for the cluster (required)                                 |
| `ziti_controller_id`              | `""`                                   | SPIFFE ID path segment (`controller/<id>`), required, permanent once enrolled  |
| `ziti_curve`                      | `P-256`                                | ECC curve for all PKI key generation                                           |
| `ziti_admin_password`             | `""`                                   | Admin password for edge init and CLI auth (required, SOPS)                     |
| `ziti_controller_pki_dir`         | `/var/lib/ziti-controller/pki`         | PKI root directory                                                             |
| `ziti_controller_db_dir`          | `/var/lib/ziti-controller/db`          | Database directory                                                             |
| `ziti_controller_config_file`     | `/var/lib/ziti-controller/config.yml`  | Controller config path                                                         |
| `ziti_controller_system_user`     | `ziti-controller`                      | Package-created system user (removal only)                                     |
| `ziti_controller_system_group`    | `ziti-controller`                      | Package-created system group (removal only)                                    |
| `ziti_root_ca_validity_days`      | `3650`                                 | Root CA validity in days (10 years)                                            |
| `ziti_signing_ca_validity_days`   | `3650`                                 | Signing CA validity in days (10 years)                                         |
| `ziti_leaf_validity_days`         | `365`                                  | Controller leaf cert validity in days                                          |
| `ziti_renew_signing_ca`           | `false`                                | Force signing CA reissue                                                       |
