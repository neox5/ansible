# ziti_services

Reconciles OpenZiti Config (`intercept.v1`/`host.v1`) and Service objects
from declarative inventory. Controller-side only.

## Scope

- In scope: Config (create/update-in-place), Service (create/update,
  full-replace `configs`/`role_attributes`/`encryption`/`tags`), prune of
  both.
- Out of scope: `host.v2` (multi-endpoint), custom Config Types, Service
  Dial/Bind/SERP policies (`ziti_policies` role), Service Edge Router
  Policies, Config Type creation, identity-level Config overrides.

## Requirements

- `ziti` CLI installed and reachable on the target host (run `-l eroc`
  only — the sole host with the CLI, same constraint as `ziti_policies`
  and `ziti_register`).
- Controller reachable, admin credentials in
  `hostvars['eroc']['ziti_admin_password']` (SOPS-encrypted).
- `ziti_ctrl_advertised_address`/`_port` sourced from `hostvars['eroc']`
  — not duplicated in this role's own vars.

## Variables

### `ziti_shared_configs` (list, default `[]`)

Configs reusable across multiple services via `ref`. Reconciled first,
independent of any service.

```yaml
ziti_shared_configs:
  - name: ssh-host
    type: host.v1
    tags: {}                          # optional, default {}
    data:
      protocol: tcp
      address: 127.0.0.1
      port: 22
```

### `ziti_services` (list, default `[]`)

```yaml
ziti_services:
  - name: postgresql
    role_attributes: [postgresql]     # optional, default []
    encryption: true                  # optional, default true
    tags: {}                          # optional, default {} — full-replace on update
    intercept:                        # optional; at least one of intercept/host required
      name: postgresql-intercept.v1   # inline form
      tags: {}                        # optional, default {}
      data:
        protocols: [tcp]
        addresses: ["postgresql.zion"]
        portRanges: [{low: 5432, high: 5432}]
    host:
      name: postgresql-host.v1
      data:
        protocol: tcp
        address: 127.0.0.1
        port: 5432

  - name: ssh-eroc
    intercept:
      name: ssh-eroc-intercept.v1
      data:
        protocols: [tcp]
        addresses: ["ssh-eroc.zion"]
        portRanges: [{low: 22, high: 22}]
    host:
      ref: ssh-host                   # reference form — must resolve into ziti_shared_configs
```

Rules, enforced in `tasks/validate.yaml` before any controller call:

- `intercept`/`host` each optional; at least one of the two required per entry.
- Each present block is exactly `{name, data}` (inline) or `{ref}`
  (reference) — never both, never neither. `tags` is a valid extra key on
  the inline form only (not on `{ref}` — a referenced config's tags are
  owned by its `ziti_shared_configs` entry).
- `ref` must resolve to a `ziti_shared_configs[].name`. No cross-referencing
  between service entries; `ziti_shared_configs` is the sole target.

## Behavior

- **Desired state is complete.** Anything not declared in
  `ziti_shared_configs`/`ziti_services` is pruned on every apply. No
  `isSystem` filter — no controller-auto-created default Config or
  Service objects are known to exist (unlike edge-router-policies).
- **Phase order is fixed and load-bearing:** validate → reconcile shared
  configs → reconcile services (resolve refs, repoint) → prune services →
  prune configs. Prune-configs runs last so nothing still attached to a
  live service is ever deleted mid-reconcile.
- **Config data and tags:** update-in-place (`ziti edge update config -d
  ... --tags-json ...`), same object ID preserved. `--tags-json` is always
  sent (full-replace), so an empty `{}` clears previously-set tags.
- **Config type:** immutable post-creation. A declared-vs-live type
  mismatch fails the play rather than attempting delete+recreate
  automatically.
- **Service `configs`/`role_attributes`/`tags`:** full-replace on update,
  not merge — `configs`/`role_attributes` confirmed empirically against
  v2.0.0; `tags` follows the same `--tags-json` full-replace convention as
  Config, not independently verified against a live payload.
- **Platform constraint enforced server-side, not by this role:** one
  Config per Config Type per Service (`intercept.v1` + at most one of
  `host.v1`/`host.v2`).

## Known Gaps

- `configTypeName` assumed as the live JSON field name for a Config's
  type in `list configs --output-json`; not directly confirmed against a
  live payload — verify before first prod run.
- Not exercised end-to-end against prod; empirical testing so far covered
  CLI semantics only (throwaway objects), not this role's task logic.
- `host.v2`, Service Dial/Bind/SERP policies, custom Config Types: not
  implemented — see Scope.

## Usage

```bash
ansible-playbook -i inventory/prod playbooks/ziti_services.yaml -l eroc
```
