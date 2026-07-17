## Router Profiles

Two router shapes are supported via inventory variables:

**Private router** (e.g. `eroc`) — LAN-resident, no link listener, tunneler host-mode:

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
  --tags router-tunneler -e "ziti_name=eroc"
```
