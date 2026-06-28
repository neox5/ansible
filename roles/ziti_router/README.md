# ziti_router Role

Deploys an [OpenZiti](https://openziti.io) edge router on Debian 13 Trixie via the official APT package.

## Overview

Installs `openziti-router` from the OpenZiti APT repository, renders `config.yml` from a template,
enrolls the router with the controller using a one-time JWT, and starts the systemd service.
The bootstrap script shipped with the package is disabled — all configuration and enrollment
is handled by the role.

## Router Profiles

Two router shapes are supported via inventory variables:

**Private router** (e.g. `core`) — LAN-resident, no link listener, tunneler host-mode:

```yaml
ziti_router_advertised_address: "10.0.0.112"
ziti_router_link_listener: false
ziti_router_tunneler_enabled: true
ziti_router_tunneler_mode: host
```

**Public router** (e.g. `heimdall`) — public ingress, link listener for mesh, no tunneler:

```yaml
ziti_router_advertised_address: "router.example.com"
ziti_router_link_listener: true
ziti_router_link_advertised_address: "router.example.com"
ziti_router_tunneler_enabled: false
```

## Bootstrap Process

### Prerequisites

Register the router with the controller before running this role:

```bash
# Public router (no tunneler):
ansible-playbook -i inventory/prod playbooks/ziti_register.yaml \
  --tags router -e "ziti_name=heimdall"

# Router with tunneler:
ansible-playbook -i inventory/prod playbooks/ziti_register.yaml \
  --tags router-tunneler -e "ziti_name=core"
```

This produces `/tmp/{{ ziti_name }}.jwt` on the control node.

### Run 1 — enrollment and service start

1. APT repository configured, `openziti-router` installed
2. Package bootstrap disabled via `service.env`
3. `config.yml` rendered from template
4. JWT copied to router host, enrollment run, JWT deleted from host
5. Service enabled and started

### Run 2+ — idempotent

Enrollment is gated on identity file existence. Re-running is safe:
existing identity files are left untouched, config changes are applied
and the service is restarted if needed.

## Enrollment Recovery

If identity files are lost after enrollment:

1. Delete the router record on the controller:
   `ziti edge delete edge-router <name>`
2. Re-register to get a fresh JWT:
   `ansible-playbook ziti_register.yaml --tags router[-tunneler] -e ziti_name=<name>`
3. Remove data and re-deploy:
   `ansible-playbook ziti_router.yaml -e "ziti_router_state=absent ziti_router_remove_data=true"`
   `ansible-playbook ziti_router.yaml`

## Variables

| Variable                              | Default                    | Description                                  |
| ------------------------------------- | -------------------------- | -------------------------------------------- |
| `ziti_router_state`                   | `present`                  | `present` or `absent`                        |
| `ziti_router_remove_data`             | `false`                    | Remove data dir when state is absent         |
| `ziti_name`                           | `{{ inventory_hostname }}` | Router name in overlay and JWT filename      |
| `ziti_jwt_path`                       | `/tmp/{{ ziti_name }}.jwt` | JWT path on control node                     |
| `ziti_router_advertised_address`      | `""`                       | Edge listener advertised address (mandatory) |
| `ziti_router_advertised_port`         | `3022`                     | Edge listener port                           |
| `ziti_router_link_listener`           | `false`                    | Enable router-to-router link listener        |
| `ziti_router_link_advertised_address` | `""`                       | Link listener advertised address             |
| `ziti_router_link_advertised_port`    | `3022`                     | Link listener port                           |
| `ziti_router_tunneler_enabled`        | `false`                    | Enable built-in tunneler                     |
| `ziti_router_tunneler_mode`           | `host`                     | Tunneler mode (`host` only)                  |

## Shared Variables (set in inventory)

| Variable                       | Description                                      |
| ------------------------------ | ------------------------------------------------ |
| `ziti_ctrl_advertised_address` | Controller address (set by ziti_controller role) |
| `ziti_ctrl_advertised_port`    | Controller port (default: 1280)                  |
