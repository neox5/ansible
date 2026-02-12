# PostgreSQL Operations Testing

Manual testing guide for PostgreSQL install, backup, and restore playbooks.

---

## Prerequisites

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

## Test 1: Fresh Installation

**Install PostgreSQL with n8n database:**

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

# Verify n8n database exists
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname = 'n8n';"

# Verify n8n_user exists
sudo -u postgres psql -c "SELECT usename FROM pg_user WHERE usename = 'n8n_user';"
```

**Expected output:**

- PostgreSQL service active and running
- n8n database exists
- n8n_user exists

---

## Test 2: Add Test Data

**Create test table with sample data:**

```bash
# SSH into lab VM (if not already connected)
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to n8n database
sudo -u postgres psql -d n8n

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
```

**Expected output:**

```
 id |     name      |         created_at
----+---------------+----------------------------
  1 | test_entry_1  | 2026-02-12 15:30:00.123456
  2 | test_entry_2  | 2026-02-12 15:30:00.234567
  3 | test_entry_3  | 2026-02-12 15:30:00.345678
```

---

## Test 3: Create Backup

**Run backup playbook:**

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_backup.yml --limit lab-vm
```

**Verify backup created:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# List backups
sudo ls -lh /var/backups/postgresql/

# Check backup file size (should be non-zero)
sudo du -h /var/backups/postgresql/n8n_*.dump
```

**Expected output:**

- Backup file exists in `/var/backups/postgresql/`
- Filename format: `n8n_YYYYMMDD-HHMMSS.dump`
- File size > 0 bytes

---

## Test 4: Download Backup to Control Node

**Copy backup from lab VM to local machine:**

```bash
# From control node (your machine)
# Get latest backup filename
BACKUP_FILE=$(ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo ls -t /var/backups/postgresql/n8n_*.dump | head -1")

echo "Backup file: $BACKUP_FILE"

# Copy to local machine
scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  ansible@localhost:$BACKUP_FILE \
  /tmp/n8n_backup.dump

# Verify local copy
ls -lh /tmp/n8n_backup.dump
```

**Expected output:**

- Backup file downloaded to `/tmp/n8n_backup.dump`
- File size matches remote backup

---

## Test 5: Simulate Data Loss

**Drop test table to simulate data loss:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to n8n database
sudo -u postgres psql -d n8n

# Drop test table
DROP TABLE test_data;

# Verify table is gone
\dt

# Try to query (should fail)
SELECT * FROM test_data;

# Exit psql
\q
```

**Expected output:**

- Table `test_data` no longer exists
- Query returns error: `relation "test_data" does not exist`

---

## Test 6: Upload Backup Back to Host

**Copy backup from local machine back to lab VM:**

```bash
# From control node (your machine)
# Upload backup to different location
scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  /tmp/n8n_backup.dump \
  ansible@localhost:/tmp/n8n_restore.dump

# Verify upload
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "ls -lh /tmp/n8n_restore.dump"
```

**Expected output:**

- File uploaded to `/tmp/n8n_restore.dump` on lab VM
- File size matches original backup

---

## Test 7: Restore from Backup

**Run restore playbook:**

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_restore.yml \
  --limit lab-vm \
  -e "pg_restore_file=/tmp/n8n_restore.dump"
```

**Verify restoration:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to n8n database
sudo -u postgres psql -d n8n

# Check if table exists
\dt

# Query restored data
SELECT * FROM test_data;

# Exit psql
\q
```

**Expected output:**

```
 id |     name      |         created_at
----+---------------+----------------------------
  1 | test_entry_1  | 2026-02-12 15:30:00.123456
  2 | test_entry_2  | 2026-02-12 15:30:00.234567
  3 | test_entry_3  | 2026-02-12 15:30:00.345678
```

**Success criteria:**

- All 3 rows restored
- Data matches original entries
- Timestamps preserved

---

## Test 8: Verify Data Integrity

**Compare original and restored data:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to n8n database
sudo -u postgres psql -d n8n

# Count rows
SELECT COUNT(*) FROM test_data;

# Verify specific entries
SELECT * FROM test_data WHERE name = 'test_entry_2';

# Exit psql
\q
```

**Expected output:**

- Row count: 3
- All original data present and intact

---

## Cleanup

**Remove test data:**

```bash
# SSH into lab VM
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost

# Connect to n8n database
sudo -u postgres psql -d n8n

# Drop test table
DROP TABLE test_data;

# Exit psql
\q

# Remove backup files
sudo rm -f /var/backups/postgresql/n8n_*.dump
sudo rm -f /tmp/n8n_restore.dump
```

**Remove local backup:**

```bash
# From control node
rm -f /tmp/n8n_backup.dump
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
sudo -u postgres psql -d n8n << SQL
CREATE TABLE IF NOT EXISTS test_data (id SERIAL PRIMARY KEY, name VARCHAR(100));
INSERT INTO test_data (name) VALUES ('test_entry_1'), ('test_entry_2'), ('test_entry_3');
SELECT COUNT(*) as row_count FROM test_data;
SQL
EOF

echo "3. Creating backup..."
ansible-playbook -i inventory/lab playbooks/postgresql_backup.yml --limit lab-vm

echo "4. Getting backup filename..."
BACKUP_FILE=$(ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo ls -t /var/backups/postgresql/n8n_*.dump | head -1")
echo "Backup: $BACKUP_FILE"

echo "5. Downloading backup..."
scp -i ~/.ssh/id_ed25519_ansible -P 2222 ansible@localhost:$BACKUP_FILE /tmp/n8n_backup.dump

echo "6. Simulating data loss..."
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo -u postgres psql -d n8n -c 'DROP TABLE test_data;'"

echo "7. Uploading backup..."
scp -i ~/.ssh/id_ed25519_ansible -P 2222 /tmp/n8n_backup.dump ansible@localhost:/tmp/n8n_restore.dump

echo "8. Restoring database..."
ansible-playbook -i inventory/lab playbooks/postgresql_restore.yml \
  --limit lab-vm \
  -e "pg_restore_file=/tmp/n8n_restore.dump"

echo "9. Verifying restoration..."
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost << 'EOF'
sudo -u postgres psql -d n8n << SQL
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
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost "ls -la /tmp/n8n_restore.dump"
```

**Issue: "Permission denied"**

```bash
# Solution: Check file ownership
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo chown postgres:postgres /tmp/n8n_restore.dump"
```
