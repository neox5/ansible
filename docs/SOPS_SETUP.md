# PostgreSQL Operations Testing

Manual testing guide for PostgreSQL install, backup, and restore playbooks.

---

## Prerequisites

**Configure SOPS for lab environment:**

```bash
# Ensure age key is available
cat ~/.config/sops/age/keys.txt

# Verify SOPS can decrypt lab secrets
sops -d inventory/lab/host_vars/lab-vm/secrets.sops.yml
```

**Start lab VM:**

```bash
cd lab/vm
./run-lab.sh
```

**Verify connectivity:**

```bash
ansible -i inventory/lab lab-vm -m ping
```

---

## Test 1: Configure Test Database Credentials

**Create encrypted secrets file:**

```bash
# Create/edit secrets file (SOPS will encrypt on save)
sops inventory/lab/host_vars/lab-vm/secrets.sops.yml
```

**Add test database configuration:**

```yaml
---
# PostgreSQL test credentials for lab environment
# Encrypted with SOPS - use: sops inventory/lab/host_vars/lab-vm/secrets.sops.yml

# Test database user password
testuser_db_password: "testpass123"
```

**Create PostgreSQL configuration file:**

```bash
# Create unencrypted PostgreSQL configuration
cat > inventory/lab/host_vars/lab-vm/postgresql.yml << 'EOF'
---
# PostgreSQL test configuration for lab environment
# Uses encrypted credentials from secrets.sops.yml

# Test databases
postgresql_databases:
  - name: testdb
    owner: testuser
    encoding: UTF-8
    lc_collate: en_US.UTF-8
    lc_ctype: en_US.UTF-8
    state: present

  - name: backuptest
    owner: testuser
    encoding: UTF-8
    lc_collate: en_US.UTF-8
    lc_ctype: en_US.UTF-8
    state: present

# Test users
postgresql_users:
  - name: testuser
    password: "{{ testuser_db_password }}"
    encrypted: yes
    role_attr_flags: "CREATEDB,NOSUPERUSER"
    state: present

# Notes:
# - testdb: Primary database for general testing and queries
# - backuptest: Secondary database for pg_dump/pg_restore workflow testing
# - testuser: Has CREATEDB privilege for testing database operations
# - Password referenced from secrets.sops.yml (SOPS-encrypted)
EOF
```

**Verify configuration:**

```bash
# Check that secrets can be decrypted
sops -d inventory/lab/host_vars/lab-vm/secrets.sops.yml | grep testuser_db_password

# Verify Ansible can access encrypted variables
ansible-inventory -i inventory/lab --host lab-vm | grep testuser_db_password
```

---

## Test 2: Fresh Installation

**Install PostgreSQL:**

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_install.yml --limit lab-vm
```

**Verify installation:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Check service status
sudo systemctl status postgresql

# List databases
sudo -u postgres psql -l

# Verify test databases exist
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname IN ('testdb', 'backuptest');"

# Verify testuser exists
sudo -u postgres psql -c "SELECT usename, usecreatedb FROM pg_user WHERE usename = 'testuser';"

# Exit SSH
exit
```

**Expected output:**

- PostgreSQL service active and running
- testdb and backuptest databases exist
- testuser exists with CREATEDB privilege

---

## Test 3: Add Test Data

**Create test table with sample data:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to testdb database
sudo -u postgres psql -d testdb

# Create test table
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

# Insert test data
INSERT INTO test_data (name) VALUES
    ('test_entry_1'),
    ('test_entry_2'),
    ('test_entry_3');

# Verify data
SELECT * FROM test_data;

# Exit psql
\q

# Exit SSH
exit
```

**Expected output:**

```
 id |     name      |         created_at
----+---------------+----------------------------
  1 | test_entry_1  | 2026-02-15 15:30:00.123456
  2 | test_entry_2  | 2026-02-15 15:30:00.234567
  3 | test_entry_3  | 2026-02-15 15:30:00.345678
```

---

## Test 4: Create Backup

**Run backup playbook:**

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_backup.yml \
  --limit lab-vm \
  -e "backup_database=testdb"
```

**Verify backup created:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# List backups
sudo ls -lh /var/backups/postgresql/

# Check backup file size (should be non-zero)
sudo du -h /var/backups/postgresql/lab-vm-testdb-*.dump

# Exit SSH
exit
```

**Expected output:**

- Backup file exists in `/var/backups/postgresql/`
- Filename format: `lab-vm-testdb-YYYYMMDDTHHMMSS.dump`
- File size > 0 bytes

---

## Test 5: Download Backup to Control Node

**Copy backup from lab VM to local machine:**

```bash
# Get latest backup filename
BACKUP_FILE=$(ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo ls -t /var/backups/postgresql/lab-vm-testdb-*.dump | head -1")

echo "Backup file: $BACKUP_FILE"

# Copy to local machine
scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  ansible@localhost:$BACKUP_FILE \
  /tmp/testdb_backup.dump

# Verify local copy
ls -lh /tmp/testdb_backup.dump
```

**Expected output:**

- Backup file downloaded to `/tmp/testdb_backup.dump`
- File size matches remote backup

---

## Test 6: Simulate Data Loss

**Drop test table to simulate data loss:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to testdb database
sudo -u postgres psql -d testdb

# Drop test table
DROP TABLE test_data;

# Verify table is gone
\dt

# Try to query (should fail)
SELECT * FROM test_data;

# Exit psql
\q

# Exit SSH
exit
```

**Expected output:**

- Table `test_data` no longer exists
- Query returns error: `relation "test_data" does not exist`

---

## Test 7: Upload Backup Back to Host

**Copy backup from local machine back to lab VM:**

```bash
# Upload backup to different location
scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  /tmp/testdb_backup.dump \
  ansible@localhost:/tmp/testdb_restore.dump

# Verify upload
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "ls -lh /tmp/testdb_restore.dump"
```

**Expected output:**

- File uploaded to `/tmp/testdb_restore.dump` on lab VM
- File size matches original backup

---

## Test 8: Restore from Backup

**Run restore playbook:**

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_restore.yml \
  --limit lab-vm \
  -e "restore_file=/tmp/testdb_restore.dump" \
  -e "restore_database=testdb"
```

**Verify restoration:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to testdb database
sudo -u postgres psql -d testdb

# Check if table exists
\dt

# Query restored data
SELECT * FROM test_data;

# Exit psql
\q

# Exit SSH
exit
```

**Expected output:**

```
 id |     name      |         created_at
----+---------------+----------------------------
  1 | test_entry_1  | 2026-02-15 15:30:00.123456
  2 | test_entry_2  | 2026-02-15 15:30:00.234567
  3 | test_entry_3  | 2026-02-15 15:30:00.345678
```

**Success criteria:**

- All 3 rows restored
- Data matches original entries
- Timestamps preserved

---

## Test 9: Verify Data Integrity

**Compare original and restored data:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to testdb database
sudo -u postgres psql -d testdb

# Count rows
SELECT COUNT(*) FROM test_data;

# Verify specific entries
SELECT * FROM test_data WHERE name = 'test_entry_2';

# Exit psql
\q

# Exit SSH
exit
```

**Expected output:**

- Row count: 3
- All original data present and intact

---

## Test 10: Verify Backup Scripts

**Check script deployment:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Verify scripts exist
ls -la /usr/local/bin/pg_backup.sh
ls -la /usr/local/bin/pg_restore.sh

# Test backup script directly
sudo -u postgres /usr/local/bin/pg_backup.sh testdb

# List backups
sudo ls -lh /var/backups/postgresql/

# Exit SSH
exit
```

**Expected output:**

- Scripts executable and owned by root
- Direct script execution creates backup
- Backup appears in `/var/backups/postgresql/`

---

## Cleanup

**Remove test data:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to testdb database
sudo -u postgres psql -d testdb

# Drop test table
DROP TABLE test_data;

# Exit psql
\q

# Remove backup files
sudo rm -f /var/backups/postgresql/lab-vm-testdb-*.dump
sudo rm -f /tmp/testdb_restore.dump

# Exit SSH
exit
```

**Remove local backup:**

```bash
# From control node
rm -f /tmp/testdb_backup.dump
```

**Remove test configuration (optional):**

```bash
# Remove test databases and user via playbook
# (Modify postgresql.yml to set state: absent, then run install playbook)

# Or manually via psql
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost << 'EOF'
sudo -u postgres psql << SQL
DROP DATABASE IF EXISTS testdb;
DROP DATABASE IF EXISTS backuptest;
DROP USER IF EXISTS testuser;
SQL
EOF
```

**Clean up SOPS secrets (optional):**

```bash
# Edit secrets file and remove test credentials
sops inventory/lab/host_vars/lab-vm/secrets.sops.yml

# Remove postgresql.yml if no longer needed
rm inventory/lab/host_vars/lab-vm/postgresql.yml
```

---

## Quick Test Sequence

**Complete test in one script:**

```bash
#!/bin/bash
set -e

echo "=== PostgreSQL Operations Test ==="

echo "1. Installing PostgreSQL..."
ansible-playbook -i inventory/lab playbooks/postgresql_install.yml --limit lab-vm

echo "2. Adding test data..."
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost << 'EOF'
sudo -u postgres psql -d testdb << SQL
CREATE TABLE IF NOT EXISTS test_data (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO test_data (name) VALUES ('test_entry_1'), ('test_entry_2'), ('test_entry_3');
SELECT COUNT(*) as row_count FROM test_data;
SQL
EOF

echo "3. Creating backup..."
ansible-playbook -i inventory/lab playbooks/postgresql_backup.yml \
  --limit lab-vm \
  -e "backup_database=testdb"

echo "4. Getting backup filename..."
BACKUP_FILE=$(ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo ls -t /var/backups/postgresql/lab-vm-testdb-*.dump | head -1")
echo "Backup: $BACKUP_FILE"

echo "5. Downloading backup..."
scp -i ~/.ssh/id_ed25519_ansible -P 2222 ansible@localhost:$BACKUP_FILE /tmp/testdb_backup.dump

echo "6. Simulating data loss..."
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo -u postgres psql -d testdb -c 'DROP TABLE test_data;'"

echo "7. Uploading backup..."
scp -i ~/.ssh/id_ed25519_ansible -P 2222 /tmp/testdb_backup.dump ansible@localhost:/tmp/testdb_restore.dump

echo "8. Restoring database..."
ansible-playbook -i inventory/lab playbooks/postgresql_restore.yml \
  --limit lab-vm \
  -e "restore_file=/tmp/testdb_restore.dump" \
  -e "restore_database=testdb"

echo "9. Verifying restoration..."
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost << 'EOF'
sudo -u postgres psql -d testdb << SQL
SELECT COUNT(*) as restored_rows FROM test_data;
SELECT * FROM test_data;
SQL
EOF

echo "=== Test Complete ==="
```

**Save as `test-postgresql-ops.sh` and run:**

```bash
chmod +x test-postgresql-ops.sh
./test-postgresql-ops.sh
```

---

## Common Issues

**Issue: "Target database does not exist"**

```bash
# Solution: Run install playbook first
ansible-playbook -i inventory/lab playbooks/postgresql_install.yml --limit lab-vm
```

**Issue: "Backup file does not exist"**

```bash
# Solution: Verify file path
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost "ls -la /tmp/testdb_restore.dump"
```

**Issue: "Permission denied"**

```bash
# Solution: Check file ownership
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo chown postgres:postgres /tmp/testdb_restore.dump"
```

**Issue: "SOPS decryption failed"**

```bash
# Verify age key is available
cat ~/.config/sops/age/keys.txt

# Test decryption manually
sops -d inventory/lab/host_vars/lab-vm/secrets.sops.yml
```
