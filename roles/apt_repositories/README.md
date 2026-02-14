# apt_repositories

Manage APT repository configuration for Debian systems.

## Requirements

- Debian 13 (Trixie) or later
- Ansible 2.15+

## What This Role Does

- Configures Debian repositories using modern DEB822 format
- Enables configurable repository components (main, contrib, non-free, non-free-firmware)
- Manages both binary and source repositories
- Updates APT cache after configuration changes
- Backs up existing sources.list before making changes

## Variables

```yaml
# Repository components to enable
apt_repositories_components:
  - main
  - contrib
  - non-free
  - non-free-firmware

# Include source repositories
apt_repositories_include_source: yes

# Debian suite (release codename)
apt_repositories_suite: "{{ ansible_distribution_release }}"

# Mirror URLs
apt_repositories_mirror: "http://deb.debian.org/debian"
apt_repositories_security_mirror: "http://deb.debian.org/debian-security"
```

## Example Usage

### In a playbook:

```yaml
- hosts: all
  become: yes
  roles:
    - apt_repositories
```

### Override components in inventory:

```yaml
# inventory/prod/group_vars/all/apt.yml
apt_repositories_components:
  - main
  - non-free-firmware
```

### Use custom mirror:

```yaml
apt_repositories_mirror: "http://ftp.us.debian.org/debian"
```

## File Management

- Creates `/etc/apt/sources.list.d/debian.sources` (DEB822 format)
- Disables `/etc/apt/sources.list` (replaced with comment)
- Backs up original `/etc/apt/sources.list` to `/etc/apt/sources.list.backup`
