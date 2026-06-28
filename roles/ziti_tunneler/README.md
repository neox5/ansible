# ziti_tunneler

Deploys `ziti-edge-tunnel` in host-mode on Debian 13 Trixie targets.

Used for hosts that host OpenZiti services (bind) without running a full
edge router — e.g. NAS, router targets (Phase 8), or any host needing
overlay service hosting without fabric participation.

## Requirements

- Debian 13 Trixie
- systemd
- `ziti_ctrl_advertised_address` set in inventory
- Identity JWT at `ziti_jwt_path` on control node (produced by `ziti_register.yaml`)

## Role Variables

| Variable                        | Default                        | Description                    |
| ------------------------------- | ------------------------------ | ------------------------------ |
| `ziti_tunneler_state`           | `present`                      | `present` or `absent`          |
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
ansible-playbook -i inventory/prod playbooks/ziti_register.yaml \
  --tags tunneler -e "ziti_name=<name>"
```

Produces `/tmp/<name>.jwt` on the control node.

**Step 2 — Deploy** (control node → target host):

```bash
ansible-playbook -i inventory/prod playbooks/ziti_tunneler.yaml -l <host>
```

Copies JWT to host, runs `ziti-edge-tunnel enroll`, removes JWT.
Enrollment is gated on identity file existence — safe to re-run.

## Host Mode

This role deploys in host-mode only. The tunneler hosts services (bind)
for the overlay without kernel tun/tproxy capabilities.

Client/intercept mode (tproxy) is deferred to Phase 8 workstation targets.

## Notes

- APT keyring shared with `ziti_controller` and `ziti_router` roles
  (`/usr/share/keyrings/openziti.gpg`). Installing multiple roles on the
  same host is safe — keyring and repo are idempotent.
- Identity file permissions: `root:ziti 0640`
- Identity directory permissions: `root:ziti 0770`
- systemd drop-in configures `--identity-dir` regardless of whether the
  default path is used, ensuring consistent behaviour across upgrades.
