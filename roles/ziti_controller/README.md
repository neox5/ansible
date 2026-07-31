# ziti_controller

OpenZiti controller via APT package, for Debian 13 Trixie. Provisions the
control-plane identity (root CA, signing/intermediate CA, controller
server+client leaf certs), the controller's `config.yml`, and the bbolt
database, then starts and verifies the service.

Controller-side only — this role manages the controller process itself,
not network policy or overlay identities. See `ziti_policies` (Role
Attributes, Edge Router/Service policies) and `ziti_services` (Config/
Service objects) for those.

## Prerequisites

- Debian 13 (Trixie), systemd — enforced in preflight
- `ziti_ctrl_advertised_address`, `ziti_trust_domain`, `ziti_controller_id`,
  `ziti_admin_password` set in inventory — all four are permanent once the
  controller is first bootstrapped; changing any requires full PKI
  regeneration and re-enrollment of every identity in the overlay
- For `ziti_controller_pki_mode: external` only: the root CA's public
  certificate staged at `{{ ziti_controller_pki_dir }}/root/certs/root.cert`
  before this role runs (e.g. via the `certs` role's `ca_certs` mechanism) —
  this role never generates or receives the root private key under that mode

## PKI Modes

Two mutually exclusive modes, selected via `ziti_controller_pki_mode`:

**`native`** (default) — root CA and signing/intermediate CA are both
self-signed on this host, entirely automated, no external steps. Root
private key remains on this host permanently. This is the original
behavior, preserved unchanged as the default for backward compatibility.

**`external`** — the signing/intermediate CA's key is generated on this
host and never leaves it; only its CSR travels out, gets signed offline
against an air-gapped root, and the signed cert returns via sneakernet
(mirrors `roles/stepca/tasks/bootstrap.yaml`'s pattern). Root CA private
key never touches this host, not even transiently. If the signed cert
hasn't been returned yet, the play halts cleanly on that instance
(`ziti_controller_pki_pending`, Role-Scoped Skip) and resumes automatically
on the next run once it's in place.

Leaf cert generation (controller server+client) is identical either way —
it only needs the signing CA's cert+key already present, and doesn't know
or care which mode produced them.

## Bootstrap Process

1. Preflight — validates OS/init system, required variables, PKI mode
2. Install — APT repo, keyring, `openziti-controller` package
3. PKI — native or external (see above), then shared leaf cert generation
4. Configure — renders `config.yml` from template, notifies restart
5. Init — one-time bbolt database initialization (`ziti controller edge
init`), gated on `ctrl-ha.db` not already existing
6. Start — enables and starts the `ziti-controller` systemd service
7. Verify — polls the controller's health-checks endpoint until healthy

All PKI and init steps are gated on file/state existence — safe to re-run.

## Removal

Removal has three escalating levels, controlled by two independent flags:

| Level | Flags                                    | Removes                                                  | Preserves                                |
| ----- | ---------------------------------------- | -------------------------------------------------------- | ---------------------------------------- |
| 1     | `ziti_controller_state: absent`          | Service, package, APT repo/keyring, config file          | All PKI, database, base dir, system user |
| 2     | `+ ziti_controller_remove_data: true`    | + Signing CA, leaf certs, database                       | Root CA, base dir, system user           |
| 3     | `+ ziti_controller_remove_root_ca: true` | + Root CA, base dir, `ziti-controller` system user/group | Nothing — full prune, irreversible       |

`ziti_controller_remove_root_ca: true` requires `ziti_controller_remove_data: true` — enforced
in preflight. Level 3 destroys this network's root of trust with no recovery path; re-running
the role afterward starts an entirely new network.

## Key Variables

| Variable                         | Default                               | Description                                                                     |
| -------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------- |
| `ziti_controller_state`          | `present`                             | `present` or `absent`                                                           |
| `ziti_controller_remove_data`    | `false`                               | Level 2 removal — signing CA, leaf certs, database                              |
| `ziti_controller_remove_root_ca` | `false`                               | Level 3 removal — root CA, base dir, system user/group (requires remove_data)   |
| `ziti_ctrl_advertised_address`   | `""`                                  | Permanent DNS name of the controller (required)                                 |
| `ziti_ctrl_advertised_port`      | `1280`                                | Controller listen port                                                          |
| `ziti_trust_domain`              | `""`                                  | SPIFFE trust domain for the cluster (required)                                  |
| `ziti_controller_id`             | `""`                                  | SPIFFE ID path segment (`controller/<id>`), required, permanent once enrolled   |
| `ziti_controller_pki_mode`       | `native`                              | `native` (self-signed, on-host) or `external` (air-gapped root, CSR round-trip) |
| `ziti_curve`                     | `P-256`                               | ECC curve for native-mode PKI key generation                                    |
| `ziti_controller_external_curve` | `P-384`                               | ECC curve for external-mode signing CA key (matches air-gapped repo convention) |
| `ziti_controller_csr_fetch_dir`  | `/tmp`                                | Control-node path CSRs are fetched to under external mode                       |
| `ziti_admin_password`            | `""`                                  | Admin password for edge init and CLI auth (required, SOPS)                      |
| `ziti_controller_pki_dir`        | `/var/lib/ziti-controller/pki`        | PKI root directory                                                              |
| `ziti_controller_db_dir`         | `/var/lib/ziti-controller/db`         | Database directory                                                              |
| `ziti_controller_config_file`    | `/var/lib/ziti-controller/config.yml` | Controller config path                                                          |
| `ziti_controller_system_user`    | `ziti-controller`                     | Package-created system user (removal only)                                      |
| `ziti_controller_system_group`   | `ziti-controller`                     | Package-created system group (removal only)                                     |
| `ziti_root_ca_validity_days`     | `3650`                                | Root CA validity in days (10 years) — native mode only                          |
| `ziti_signing_ca_validity_days`  | `3650`                                | Signing CA validity in days (10 years) — native mode only                       |
| `ziti_leaf_validity_days`        | `365`                                 | Controller leaf cert validity in days                                           |
| `ziti_renew_signing_ca`          | `false`                               | Force signing CA reissue (native mode only)                                     |
