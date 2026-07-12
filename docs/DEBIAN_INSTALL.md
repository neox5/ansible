# Debian 13 Server Install (Bare Metal)

Physical target install via DVD-1 minimal ISO. Normal (non-graphical) installer.

---

## Prerequisites

Capture card as HDMI monitor (if no display attached):

```bash
v4l2-ctl --list-formats-ext -d /dev/videoN
mpv --profile=low-latency --no-cache --fs \
  --demuxer-lavf-o=input_format=mjpeg,video_size=<max_supported>,framerate=30 \
  av://v4l2:/dev/videoN
```

---

## Installer Steps

**Language / Location / Keyboard**

- Language: English
- Location: (country)
- Keyboard: (layout)

**Network**

- Hostname: `<hostname>` (e.g. `core`)
- Domain: `zion.local`
- Configure network manually: yes
  - IP: `<ip>/<cidr>` (e.g. `10.30.0.2/24`)
  - Gateway: `<gateway>` (VLAN gateway, e.g. `10.30.0.1`)
  - Nameserver: `<gateway>` (router resolver, e.g. `10.30.0.1`)
    - Router runs DNS (forwards to Quad9/Cloudflare) but requires a firewall rule permitting UDP/TCP 53 inbound from the target's VLAN — add on router before install if not present, or fix post-install via `/etc/resolv.conf`.

**Root Password**

- Leave empty (Enter)
- Debian auto-installs sudo, adds install-time user to sudo group

**User Account**

- Full name: any
- Username: `temp`
- Password: one-time bootstrap login password

**Partitioning**

- Guided - use entire disk
- All files in one partition

**Software Selection**

- [x] SSH server
- [x] standard system utilities
- [ ] everything else (desktop envs, print server, etc.)

**GRUB**

- Install to primary disk

---

## Post-Install

Shutdown:

```bash
sudo poweroff
```

Update inventory before bootstrap:

- `inventory/prod/hosts.yaml` — add `<hostname> ansible_host=<ip>`
- `inventory/prod/host_vars/<hostname>/secrets.sops.yaml` — `bootstrap_root_password_hash_secret`
  - Generate: `openssl passwd -6 -stdin`
  - Encrypt: `sops inventory/prod/host_vars/<hostname>/secrets.sops.yaml`

Bootstrap:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yaml -i inventory/prod -l <hostname> -e ansible_user=temp -k -K
```

Result:

- `temp` removed
- `ansible` user: automation access
- `admin` user: operator access (personal + emergency keys)
- Root password: set from encrypted vars (console only)
- Root SSH: still open — run `security_hardening` next
