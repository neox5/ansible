# SOPS Setup Guide

Age-based secret encryption for Ansible inventory.

---

## Initial Setup (First Time)

Generate new age key pair and configure SOPS.

### 1. Install Dependencies

```bash
# Arch/Manjaro
sudo pacman -S sops age

# Debian/Ubuntu
sudo apt install sops age

# macOS
brew install sops age
```

### 2. Generate Age Key

```bash
# Create SOPS config directory
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age

# Generate new age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Set permissions
chmod 600 ~/.config/sops/age/keys.txt
```

### 3. Save Keys to Password Manager

```bash
# Display the key file
cat ~/.config/sops/age/keys.txt
```

Save both lines to password manager:

- Public key: `age1...` (starts with "# public key:")
- Private key: `AGE-SECRET-KEY-1...`

### 4. Configure Repository

The public key is already configured in `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: inventory/.*/host_vars/.*/secrets\.sops\.yml$
    age: age1fmdqnls7zgddw7qxdn3rtwlk878rfly77pqw56fz7p38j36h4gtq6hsh0r
```

If you generated a new key, update this value with your public key.

### 5. Verify Access

```bash
# Test decryption of existing secrets
sops -d inventory/prod/host_vars/n150-01/secrets.sops.yml

# Should display decrypted YAML content (not encrypted values)
```

---

## Additional Device Setup

Import existing age keys from password manager.

### 1. Install Dependencies

```bash
# Same as Initial Setup step 1
```

### 2. Create Keys File

```bash
# Create SOPS config directory
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops/age

# Create keys.txt file
nvim ~/.config/sops/age/keys.txt
```

Paste both lines from password manager:

```
# created: 2026-02-08T12:30:00Z
# public key: age1fmdqnls7zgddw7qxdn3rtwlk878rfly77pqw56fz7p38j36h4gtq6hsh0r
AGE-SECRET-KEY-1...your-private-key-here...
```

Save and exit.

### 3. Set Permissions

```bash
chmod 600 ~/.config/sops/age/keys.txt
```

### 4. Verify Access

```bash
# Test decryption
sops -d inventory/prod/host_vars/n150-01/secrets.sops.yml

# Should display decrypted content
```

---

## Working with Secrets

### Edit Encrypted Files

```bash
# SOPS automatically decrypts for editing
sops inventory/prod/host_vars/n150-01/secrets.sops.yml

# Make changes, save - SOPS re-encrypts automatically
```

### Create New Secret Files

```bash
# Create and encrypt in one step
sops inventory/prod/host_vars/newhost/secrets.sops.yml

# Add your secrets in YAML format
# Save - SOPS encrypts before writing
```

### View Encrypted Files

```bash
# Decrypt to stdout (read-only)
sops -d inventory/prod/host_vars/n150-01/secrets.sops.yml

# View in encrypted form
cat inventory/prod/host_vars/n150-01/secrets.sops.yml
```

---

## Key Management

### Security Best Practices

- **Never commit private keys to git** (only public keys in `.sops.yaml`)
- **Store private keys in password manager** (encrypted backup)
- **Use file permissions** (`chmod 600` on keys.txt)
- **Rotate keys** if compromised (re-encrypt all secrets)

### Key Rotation (if needed)

```bash
# 1. Generate new age key (keep old key in place)
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Append new private key to existing keys.txt
#    SOPS supports multiple keys - keeps old key for decryption
cat ~/.config/sops/age/keys-new.txt >> ~/.config/sops/age/keys.txt

# 3. Extract new public key
NEW_PUBLIC_KEY=$(grep "public key:" ~/.config/sops/age/keys-new.txt | awk '{print $4}')
echo "New public key: $NEW_PUBLIC_KEY"

# 4. Update .sops.yaml with new public key (replace old one)
#    Edit .sops.yaml manually and commit change

# 5. Re-encrypt all secrets (uses new key from .sops.yaml, decrypts with old key from keys.txt)
find inventory -name "*.sops.yml" -exec sops updatekeys {} \;

# 6. Verify all secrets decrypt with new key
find inventory -name "*.sops.yml" -exec sops -d {} \; >/dev/null

# 7. Remove old private key from keys.txt (keep only new key)
#    Edit ~/.config/sops/age/keys.txt manually, remove old AGE-SECRET-KEY line

# 8. Update password manager with new keys
cat ~/.config/sops/age/keys.txt

# 9. Clean up
rm ~/.config/sops/age/keys-new.txt
```

**Key rotation requires both old and new private keys during re-encryption:**

- Old key decrypts existing secrets
- New key encrypts updated secrets
- Remove old key only after all secrets are re-encrypted and verified
