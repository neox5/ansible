# wifi

Wi-Fi connection management for Debian 13 Trixie via NetworkManager.

## Constraints

**This role ONLY supports:**

- Debian 13 (Trixie)
- WPA-PSK secured networks
- Static IP configuration
- NetworkManager-managed interfaces

**This is intentional.** DHCP, WEP, WPA-Enterprise, and non-NM configurations are not supported.

## Requirements

- Debian 13 Trixie
- Ansible 2.15+
- community.general collection

## Role Variables

### Mandatory (no defaults — preflight asserts these are set)

```yaml
wifi_connections:
  - conn_name: "" # NetworkManager connection profile name
    ssid: "" # Target network SSID
    password: "" # WPA-PSK passphrase (use SOPS secret)
    ip4: "" # Static IPv4 address with prefix (e.g. 192.168.1.50/24)
    gw4: "" # IPv4 gateway
```

### Optional (per connection)

```yaml
wifi_connections:
  - ...
    ifname: wlan0         # Interface name (default: wifi_ifname)
    dns4: ""              # DNS server (default: gw4 value)
    priority: 0           # Autoconnect priority — higher wins (default: 0)
    never_default: false  # Prevent this connection from becoming the default route (default: false)
```

### Role-level defaults

```yaml
wifi_ifname: wlan0 # Fallback interface if not set per connection
```

## Connection Policy

NetworkManager handles failover natively:

- Active connection is never replaced by autoconnect
- On disconnect: highest priority available network connects
- Infinite retry (`autoconnect-retries: -1`) on all profiles
- `never_default: true` on fallback prevents it from stealing the default route when both networks are up

## Example Inventory

```yaml
# inventory/prod/host_vars/<host>/wifi.yaml
wifi_connections:
  - conn_name: CUSTOMER_WIFI
    ssid: CUSTOMER_SSID
    password: "{{ wifi_customer_password_secret }}"
    ip4: 192.168.1.50/24
    gw4: 192.168.1.1
    priority: 10

  - conn_name: DEFAULT_WIFI
    ssid: NUC_RECOVERY
    password: "{{ wifi_recovery_password_secret }}"
    ip4: 192.168.50.2/24
    gw4: 192.168.50.1
    priority: 0
    never_default: true
```

## What This Role Does

1. Validates environment (Debian 13+) and required variables
2. Installs NetworkManager via apt
3. Enables and starts NetworkManager service
4. Creates or updates each connection profile via `community.general.nmcli`

## License

MIT

## Author

neox5
