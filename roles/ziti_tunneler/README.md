# ziti_tunneler

Deploys `ziti-edge-tunnel` on Debian 13 Trixie targets, in either
host-mode (bind only) or client-mode (bind + dial/intercept).

- **Host mode** — hosts that host OpenZiti services without running a
  full edge router — e.g. NAS, router targets (Phase 8), or any host
  needing overlay service hosting without fabric participation.
- **Client mode** — workstations and devices that consume overlay
  services via tproxy intercept (e.g. desktop, mobile workstation).

## Requirements

- Debian 13 Trixie
- systemd
- `ziti_ctrl_advertised_address` set in inventory
- Identity JWT at `ziti_jwt_path` on control node (produced by `ziti_register.yaml`)
- Client mode: kernel TPROXY support (present by default on Debian 13)

## Role Variables

| Variable                        | Default                        | Description                    |
| ------------------------------- | ------------------------------ | ------------------------------ |
| `ziti_tunneler_state`           | `present`                      | `present` or `absent`          |
| `ziti_tunneler_mode`            | `host`                         | `host` or `client`             |
| `ziti_tunneler_remove_data`     | `false`                        | Remove identity dir on absence |
| `ziti_name`                     | `{{ inventory_hostname }}`     | Identity name in controller    |
| `ziti_jwt_path`                 | `/tmp/{{ ziti_name }}.jwt`     | JWT path on control node       |
| `ziti_ctrl_advertised_address`  | `""`                           | Controller address (mandatory) |
| `ziti_ctrl_advertised_port`     | `1280`                         | Controller port                |
| `ziti_tunneler_identity_dir`    | `/opt/openziti/etc/identities` | Identity file directory        |
| `ziti_tunneler_service_state`   | `started`                      | Target service state           |
| `ziti_tunneler_service_enabled` | `true`                         | Enable on boot                 |

## Enrollment Flow

Registration and deployment are two separate steps, following the same
pattern as `ziti_router`.

**Step 1 — Register** (control node → controller):

```bash
# Host-mode target
ansible-playbook -i inventory/prod playbooks/ziti_register.yaml \
  --tags tunneler -e "ziti_name=<name>"

# Client-mode target
ansible-playbook -i inventory/prod playbooks/ziti_register.yaml \
  --tags client -e "ziti_name=<name>"
```

Produces `/tmp/<name>.jwt` on the control node. Both tags create an
identical plain identity — the distinction is enforced at deployment
time via `ziti_tunneler_mode`, not at registration.

**Step 2 — Deploy** (control node → target host):

```bash
ansible-playbook -i inventory/prod playbooks/ziti_tunneler.yaml -l <host>
```

Copies JWT to host, runs `ziti-edge-tunnel enroll`, removes JWT.
Enrollment is gated on identity file existence — safe to re-run.

## Mode Selection

Mode is inventory-driven, not playbook-driven. Set in host_vars for
the target host:

```yaml
# host_vars/<workstation>/ziti.yaml
ziti_tunneler_mode: client
```

Hosts without this variable default to `host` mode.

| Mode     | Subcommand | Kernel capability | Use case                          |
| -------- | ---------- | ----------------- | --------------------------------- |
| `host`   | `run-host` | none              | NAS, router targets (bind only)   |
| `client` | `run`      | CAP_NET_ADMIN     | Workstations (bind + dial/tproxy) |

Standalone identity for the client device. Hot/standalone enrollment
flows (e.g. device self-enrollment outside Ansible) are out of scope
for this role — see Phase 7 enrollment automation track.

## Notes

- APT keyring shared with `ziti_controller` and `ziti_router` roles
  (`/usr/share/keyrings/openziti.gpg`). Installing multiple roles on the
  same host is safe — keyring and repo are idempotent.
- Identity file permissions: `root:ziti 0640`
- Identity directory permissions: `root:ziti 0770`
- systemd drop-in configures `--identity-dir` regardless of whether the
  default path is used, ensuring consistent behaviour across upgrades.
- Switching `ziti_tunneler_mode` on an already-enrolled host only
  changes the systemd drop-in (subcommand); re-run the playbook and the
  service restarts via handler. No re-enrollment needed.
