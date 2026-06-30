# ziti_service

Reconciles OpenZiti services, configs, and service-policies against the
controller API. Controller-side only — no target host is configured.
Structurally mirrors `ziti_register.yaml`: runs on `localhost`, against
the controller's admin API, not against any inventory host's OS.

## Requirements

- `ziti` CLI available on the control node
- Controller reachable at `ziti_ctrl_advertised_address:ziti_ctrl_advertised_port`
- `ziti_admin_password` available (from SOPS-encrypted inventory)
- Declared identities/routers already enrolled (via `ziti_register.yaml`
  and the relevant deployment playbook) before policies referencing them
  will resolve correctly

## Role Variables

| Variable                       | Default | Description                             |
| ------------------------------ | ------- | --------------------------------------- |
| `ziti_services`                | `[]`    | Declared service list (see shape below) |
| `ziti_ctrl_advertised_address` | `""`    | Controller address (mandatory)          |
| `ziti_ctrl_advertised_port`    | `1280`  | Controller port                         |
| `ziti_service_prune`           | `false` | Remove controller objects not declared  |

## Declaring Services

Services are declared as data, not as hand-written tasks. Add entries to
`ziti_services` in inventory `group_vars`/`host_vars`, or pass via `-e`:

```yaml
ziti_services:
  - name: n8n-webhook
    intercept:
      addresses: ["n8n.ziti"]
      port: 443
    host: # omit when the service is bound by an SDK,
      address: "127.0.0.1" # not a tunneler — then only intercept applies
      port: 5678
    dial_roles: "#n8n-clients" # identities allowed to consume the service
    bind_roles: "@core" # identity allowed to host the service
```

Each declared service produces, as applicable:

- `<name>.intercept.v1` config (always)
- `<name>.host.v1` config (if `host` is defined)
- `<name>` service (referencing the above configs)
- `<name>.dial` service-policy (if `dial_roles` is defined)
- `<name>.bind` service-policy (if `bind_roles` is defined)

## Reconciliation Behaviour

**Create** — every declared service is created if missing. Creation is
gated on the `already exists` error from `ziti edge create`, so re-running
is safe.

**Update** — not handled. Changing a declared service's `intercept`/`host`
parameters does not update the existing controller-side config; the create
command will report `already exists` and the change is silently skipped.
To apply a parameter change, delete the affected config/service manually
(or via pruning, by removing/renaming the entry) and re-run.

**Prune** — disabled by default. When `ziti_service_prune: true`, any
service, config, or service-policy on the controller whose name is not
derivable from `ziti_services` is deleted. This is destructive: a typo in
a service name, or running with a partial `ziti_services` list (e.g. via
`-e` override), will delete real services. Only enable explicitly:

```bash
ansible-playbook -i inventory/prod playbooks/ziti_service.yaml \
  -e ziti_service_prune=true
```

Pruning deletes in dependency order: policies, then services, then configs.

## Notes

- This role does not create edge-router-policy or service-edge-router-policy
  objects. A default `#all`/`#all` pair for both is assumed to exist at the
  controller level (created during `ziti_controller` init) — see
  `ziti_controller` role for details. Per-service router restriction is out
  of scope for this role.
- Identity/router role-attributes referenced in `dial_roles`/`bind_roles`
  (e.g. `#n8n-clients`, `@core`) must be assigned separately — via
  `--role-attributes` on `ziti_register.yaml` or `ziti edge update identity`.
- Naming convention (`<name>.intercept.v1`, `<name>.host.v1`, `<name>.dial`,
  `<name>.bind`) is load-bearing: pruning derives "what should exist" from
  this convention applied to `ziti_services`, not from a separate tracked
  list.
