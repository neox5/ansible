# security_hardening

Baseline security hardening for Debian systems.

## Requirements

- Debian 13 (Trixie) or later
- Ansible 2.15+
- OpenSSH 9.0+ (for post-quantum key exchange)

## What This Role Does

- **SSH Hardening:** PQ hybrid key exchange, public key auth only, no root login
- **Firewall:** nftables with default deny policy
- **Automatic Updates:** unattended-upgrades for security patches
- **Intrusion Prevention:** fail2ban for SSH brute-force protection
- **Logging:** Persistent journald with 30-day retention
- **Sudo:** Hardened configuration with passwordless access for automation users

## Variables

