# PostgreSQL Operations Testing

---

## Install PostgreSQL

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_install.yml --limit lab-vm
```

Verify:

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo systemctl status postgresql
sudo -u postgres psql -l
sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname IN ('testdb', 'backuptest');"
sudo -u postgres psql -c "SELECT usename FROM pg_user WHERE usename = 'testuser';"
exit
```

---

## Add Test Data

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo -u postgres psql -d testdb
```

```sql
CREATE TABLE test_data (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO test_data (name) VALUES ('test_entry_1'), ('test_entry_2'), ('test_entry_3');
SELECT * FROM test_data;
\q
```

```bash
exit
```

---

## Create Backup

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_backup.yml \
  --limit lab-vm \
  -e "backup_database=testdb"
```

Verify:

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo ls -lh /var/backups/postgresql/
exit
```

---

## Download Backup

```bash
BACKUP_FILE=$(ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost \
  "sudo ls -t /var/backups/postgresql/lab-vm-testdb-*.dump | head -1")

scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  ansible@localhost:$BACKUP_FILE \
  /tmp/testdb_backup.dump

ls -lh /tmp/testdb_backup.dump
```

---

## Simulate Data Loss

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo -u postgres psql -d testdb
```

```sql
DROP TABLE test_data;
\dt
\q
```

```bash
exit
```

---

## Upload Backup

```bash
scp -i ~/.ssh/id_ed25519_ansible -P 2222 \
  /tmp/testdb_backup.dump \
  ansible@localhost:/tmp/testdb_restore.dump
```

---

## Restore from Backup

```bash
ansible-playbook -i inventory/lab playbooks/postgresql_restore.yml \
  --limit lab-vm \
  -e "restore_file=/tmp/testdb_restore.dump" \
  -e "restore_database=testdb"
```

Verify:

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo -u postgres psql -d testdb
```

```sql
SELECT * FROM test_data;
\q
```

```bash
exit
```

---

## Test Backup Scripts Directly

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
ls -la /usr/local/bin/pg_backup.sh
ls -la /usr/local/bin/pg_restore.sh
sudo -u postgres /usr/local/bin/pg_backup.sh testdb
sudo ls -lh /var/backups/postgresql/
exit
```

---

## Cleanup

```bash
ssh -i ~/.ssh/id_ed25519_ansible -p 2222 ansible@localhost
sudo -u postgres psql -d testdb -c "DROP TABLE test_data;"
sudo rm -f /var/backups/postgresql/lab-vm-testdb-*.dump
sudo rm -f /tmp/testdb_restore.dump
exit

rm -f /tmp/testdb_backup.dump
```
