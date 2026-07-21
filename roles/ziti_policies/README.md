# ziti_policies

Reconciles OpenZiti controller-side policy objects — Edge Router Policies,
Service Dial/Bind Policies, Service Edge Router Policies — and Role
Attributes on Edge Routers and Identities, against a declarative YAML
source of truth.

Controller-side only. No target host state is managed; the play runs
against the `ziti` CLI, which must be installed and reachable from the
host the play executes on.

## Prerequisites

- `ziti` CLI installed on the execution host (run with `-l <host>` —
  this repo uses `eroc`, the only host with the CLI installed)
- Controller reachable at `ziti_ctrl_advertised_address:ziti_ctrl_advertised_port`
- `ziti_admin_password` available (SOPS-encrypted inventory)
- Edge Routers and Identities referenced in `ziti_edge_router_role_attributes`
  / `ziti_identity_role_attributes` must already exist on the controller
- Services referenced by `@name` in `ziti_service_dial_policies`,
  `ziti_service_bind_policies`, or `ziti_service_edge_router_policies`
  must already exist on the controller. **This role does not create
  Services or Configs (`intercept.v1`/`host.v1`)** — that is out of scope.

## Variables

| Variable                            | Description                                                                               |
| ----------------------------------- | ----------------------------------------------------------------------------------------- |
| `ziti_edge_router_role_attributes`  | List of `{router, role_attributes, tags?}` — Role Attributes reconciled onto Edge Routers |
| `ziti_identity_role_attributes`     | List of `{identity, role_attributes, tags?}` — Role Attributes reconciled onto Identities |
| `ziti_edge_router_policies`         | List of `{name, identity_roles, edge_router_roles, semantic?, tags?}`                     |
| `ziti_service_dial_policies`        | List of `{name, service_roles, dial_roles, semantic?, tags?}`                             |
| `ziti_service_bind_policies`        | List of `{name, service_roles, bind_roles, semantic?, tags?}`                             |
| `ziti_service_edge_router_policies` | List of `{name, service_roles, edge_router_roles, semantic?, tags?}`                      |

All default to `[]`. See `defaults/main.yaml` for the full shape and
`group_vars/site_zion/ziti_policies.yaml` for a live example, including
role-selector syntax (`#attribute` / `@name` / `#all`).

## Behavior

The declared variables are treated as complete desired state:

- **Additive and corrective** — every declared Role Attribute assignment
  and policy is applied on every run, including changes to existing
  entries (role lists, semantic, tags).
- **Pruning is unconditional** — every apply also removes any Edge
  Router Policy, Service Policy, or Service Edge Router Policy that
  exists on the controller but is no longer declared. There is no
  opt-in flag; removing an entry from the YAML removes it from the
  controller on the next run.
- **Role Attributes are never pruned** — clearing an attribute from an
  entity is not a delete operation on the entity itself, so no orphan
  concept applies there.
- **Controller-managed system policies are never touched** — objects
  with `isSystem: true` (e.g. a router's own self-referencing policy,
  auto-created by the controller) are excluded from all reconciliation
  and pruning.

## Usage

```bash
ansible-playbook -i inventory/prod playbooks/ziti_policies.yaml -l eroc
```

## Validation

```bash
ziti edge list edge-router-policies
ziti edge list service-policies
ziti edge list service-edge-router-policies
ziti edge list edge-routers
ziti edge list identities
```
