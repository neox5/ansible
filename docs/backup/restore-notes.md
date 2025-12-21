# Restore Notes

## A. Fast Rollback (same machine)

1. Stop n8n and postgres
```bash
   cd /opt/n8n/compose
   podman-compose -f n8n.yml down
```

2. Restore snapshot to /opt/n8n/backup-data/staging
```bash
   restic restore latest --target /opt/n8n/backup-data/staging
```

3. Restore DB from dump
```bash
   # Start postgres only
   podman-compose -f n8n.yml up -d postgres
   # Restore latest dump
   gunzip -c /opt/n8n/backup-data/staging/db/n8n-*.sql.gz | \
     podman exec -i n8n-postgres psql -U n8n n8n
```

4. Restore n8n data
```bash
   rsync -a /opt/n8n/backup-data/staging/n8n-files/ /opt/n8n/data/n8n/
```

5. Restore configuration
```bash
   cp /opt/n8n/backup-data/staging/config/n8n.env /opt/n8n/config/n8n/n8n.env
```

6. Start services
```bash
   podman-compose -f n8n.yml up -d
```

## B. Disaster Recovery (new machine)

1. Install OS + podman + restic

2. Recreate /opt/n8n layout
```bash
   mkdir -p /opt/n8n/{compose,config,data,backup-data,scripts,systemd,docs}
```

3. Restore git repository to /opt/n8n
```bash
   cd /opt/n8n
   git clone <repo-url> .
```

4. Restore restic repository
```bash
   # Copy restic-repo from backup location
   # OR mount remote repository
```

5. Restore latest snapshot
```bash
   restic restore latest --target /opt/n8n/backup-data/staging
```

6. Restore secrets
```bash
   cp /opt/n8n/backup-data/staging/config/n8n.env /opt/n8n/config/n8n/n8n.env
   # Create other .env files from .example files
```

7. Restore data
```bash
   rsync -a /opt/n8n/backup-data/staging/n8n-files/ /opt/n8n/data/n8n/
```

8. Start containers
```bash
   cd /opt/n8n/compose
   podman-compose -f network.yml up -d
   podman-compose -f n8n.yml up -d
   podman-compose -f monitoring.yml up -d
```

9. Restore database
```bash
   gunzip -c /opt/n8n/backup-data/staging/db/n8n-*.sql.gz | \
     podman exec -i n8n-postgres psql -U n8n n8n
```

10. Install systemd units
```bash
    cp /opt/n8n/systemd/*.service /etc/systemd/system/
    cp /opt/n8n/systemd/*.timer /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now caddy.service
    systemctl enable --now n8n-backup.timer
```
