# Unified Database Backup & DR Plan (PostgreSQL)

This document is based on the actual deployment of the `install.svc.plus` production environment. It outlines the standard operating procedures for the global PostgreSQL database backup, restoration, and Disaster Recovery (DR).

## 1. Production Database Architecture Checklist

| Instance Purpose | Runtime Mode | Listen Port/Address | Contained Business Databases |
| :--- | :--- | :--- | :--- |
| **Global AI/IAM/Code DB** | Docker (`postgresql-svc-plus`) | `127.0.0.1:5432` | Account, Vault Storage, Artifact, LiteLLM, OpenClaw, QMD, RAG, Notification, Scheduler, Audit, Zitadel IAM, Gitea Code |

## 2. Unified Backup Strategy

To achieve seamless disaster recovery, we recommend a strategy of **Logical Backup** combined with **Offsite Sync**.

### 2.1 Writing the Global Backup Script

Create a unified backup script `pg_backup.sh` in the `/opt/backup/` directory on the host machine (`install.svc.plus`):

```bash
#!/bin/bash
# ==========================================
# Unified PostgreSQL Backup Script
# ==========================================
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +"%Y%m%d_%H%M%S")
mkdir -p $BACKUP_DIR

echo "[INFO] Backing up all business databases (Port 15432)..."
DB_URL_BASE="postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432"
for DB in account litellm openclaw qmd rag notification scheduler audit artifact vault_storage; do
    pg_dump "$DB_URL_BASE/$DB?sslmode=disable" | gzip > "$BACKUP_DIR/${DB}_$DATE.sql.gz"
done

echo "[INFO] Backing up Zitadel IAM database..."
docker exec postgresql-svc-plus pg_dump -U postgres zitadel | gzip > "$BACKUP_DIR/zitadel_$DATE.sql.gz"

echo "[INFO] Backing up Gitea Code database..."
docker exec postgresql-svc-plus pg_dump -U postgres gitea | gzip > "$BACKUP_DIR/gitea_$DATE.sql.gz"

echo "[INFO] Cleaning up backups older than 7 days..."
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete

echo "[INFO] Backup complete!"
```

> [!TIP]
> We recommend pushing the backup files to an offsite S3 (e.g., MinIO) or syncing to other cloud storage via `rclone` to prevent data center-level disasters.

### 2.2 Configure Cron Jobs

Add an automated backup every day at 3:00 AM using `crontab -e`:
```cron
0 3 * * * /bin/bash /opt/backup/pg_backup.sh >> /var/log/pg_backup.log 2>&1
```

## 3. Disaster Recovery and Restore

When data corruption or a full machine migration occurs, please follow the restoration sequence strictly.

> [!WARNING]
> Before executing the restoration, you must stop business services that generate write traffic (such as Gitea, LiteLLM, etc.), keeping only the PostgreSQL process running.

### 3.1 Restore Global Business Databases
Includes: `Account`, `Vault Storage`, `Artifact`, `LiteLLM`, `OpenClaw`, `QMD`, `RAG`, `Notification`, `Scheduler`, `Audit`
```bash
# Decompress the backup file and import directly using credentials (using account as an example)
gunzip -c /var/backups/postgresql/account_YYYYMMDD.sql.gz | psql "postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432/account?sslmode=disable"
```

### 3.2 Restore Zitadel IAM Database
```bash
# Decompress the backup file and import
gunzip -c /var/backups/postgresql/zitadel_YYYYMMDD.sql.gz | docker exec -i postgresql-svc-plus psql -U postgres -d zitadel
```

### 3.3 Restore Gitea Code Database
```bash
# Decompress the backup file and import
gunzip -c /var/backups/postgresql/gitea_YYYYMMDD.sql.gz | docker exec -i postgresql-svc-plus psql -U postgres -d gitea
```

## 4. High Availability & Advanced Recommendations

For the current single-node architecture, logical backups (`pg_dumpall`) are sufficient for most scenarios, but they introduce an RPO (Recovery Point Objective) of about 24 hours (depending on backup frequency).

> [!IMPORTANT]
> **Recommendations for upgrading Disaster Recovery Level:**
> 1. **Incremental Backups (WAL Archiving)**: For highly critical core AI business databases and Gitea, consider introducing `pgBackRest` or `WAL-G` to archive physical WAL logs to S3 (MinIO) in real-time. This can reduce the data loss risk (RPO) to minutes.
> 2. **Application-Level Disaster Recovery**: 
>    - Vault Storage encryption keys cannot reside solely in the database. Ensure Vault's physical Root Token/Unseal Keys are securely saved offline.
>    - For Gitea, besides backing up the database, you must periodically back up `/var/lib/gitea/data` (Git repository bare data and LFS artifacts) on the host machine. You can leverage Gitea's built-in `gitea dump` command to realize unified data + repository backups.
