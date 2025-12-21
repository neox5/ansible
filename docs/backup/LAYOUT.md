# Target System Layout (N150)

Root directory:

/opt/n8n/

compose/
  n8n.yml
  monitoring.yml
  network.yml

config/
  n8n/
    n8n.conf
    n8n.env          # real secrets (NOT in git)
  monitoring/
    monitoring.conf
    monitoring.env   # real secrets (NOT in git)
    alloy-config.alloy
    grafana-provisioning/
  backup/
    backup.conf
    backup.env       # real secrets (NOT in git)
  caddy/
    Caddyfile

data/
  n8n/               # bind-mounted into n8n container
  postgres/data/     # bind-mounted into postgres container
  monitoring/
    victoriametrics/
    grafana/

backup-data/
  staging/
    db/              # PostgreSQL dumps
    n8n-files/       # copy of data/n8n
    config/
      n8n.env        # copied from config/n8n/n8n.env at backup time
  restic-repo/       # encrypted restic repository data

scripts/
  backup-n8n.sh
  verify.sh

systemd/
  caddy.service
  n8n-backup.service
  n8n-backup.timer

docs/
  backup/
