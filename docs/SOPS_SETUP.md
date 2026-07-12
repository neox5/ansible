# SOPS Setup

## Prerequisites

- `sops`, `age` installed on control node
- `community.sops` collection — declared in `requirements.yaml`, install via `ansible-galaxy collection install -r requirements.yaml`

## Age Key

- Private key file: `~/.config/sops/age/keys.txt` (default lookup path)
- Alt: set `SOPS_AGE_KEY_FILE` env var to override path
- No key material in-repo

## Repo Config (`.sops.yaml`)

```yaml
creation_rules:
  - path_regex: inventory/.*/host_vars/.*/secrets\.sops\.yaml$
    age: age1fmdqnls7zgddw7qxdn3rtwlk878rfly77pqw56fz7p38j36h4gtq6hsh0r
```

- Secrets are host-specific by design — only `host_vars/*/secrets.sops.yaml` matches
- No group-level secrets support

## Ansible Integration (`ansible.cfg`)

```ini
vars_plugins_enabled = host_group_vars,community.sops.sops
```

- Decryption automatic at runtime via vars plugin
- No manual `sops -d` step in playbook execution
- Same in `ansible.debug.cfg`

## File Convention

- Path: `inventory/<env>/host_vars/<host>/secrets.sops.yaml`
- One file per host
- Sibling unencrypted file (e.g. `postgresql.yaml`, `restic.yaml`) references values

## Variable Naming

- Suffix: `_secret` (e.g. `n8n_db_password_secret`, `restic_b2_key_id_secret`)
- Referenced: `password: "{{ n8n_db_password_secret }}"`

## Usage

```bash
# Create/edit (opens $EDITOR, encrypts on save)
sops inventory/<env>/host_vars/<host>/secrets.sops.yaml

# Decrypt to stdout
sops -d inventory/<env>/host_vars/<host>/secrets.sops.yaml
```
