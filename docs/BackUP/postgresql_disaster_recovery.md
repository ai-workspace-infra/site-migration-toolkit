# 统一数据库备份与灾备方案 (PostgreSQL) | Unified DB Backup & DR Plan

*🇨🇳 中文版在下方 | Chinese version below*

---

# English Version

This document is based on the actual deployment of the `install.svc.plus` production environment. It outlines the standard operating procedures for the global PostgreSQL database backup, restoration, and Disaster Recovery (DR).

## 1. Production Database Architecture Checklist

Based on the production environment reconnaissance, there are currently **three independently running PostgreSQL instances**. When performing unified backups, data must be exported from these three instances separately.

| Instance Purpose | Runtime Mode | Listen Port/Address | Contained Business Databases |
| :--- | :--- | :--- | :--- |
| **AI Core Services DB** | Docker (`postgresql-svc-plus`) | `127.0.0.1:5432` | Account, Vault Storage, Artifact, LiteLLM, OpenClaw, QMD, RAG, Notification, Scheduler, Audit |
| **Zitadel IAM DB** | Docker (`zitadel-db-1`) | Container Internal Net | Zitadel IAM Data |
| **Gitea Code DB** | Native Systemd (PG 16) | `127.0.0.1:5434` | Gitea |

## 2. Unified Backup Strategy

To achieve seamless disaster recovery, we recommend a strategy combining **Logical Backup** with **Offsite Sync**.

### 2.1 Global Backup Script

Create a unified backup script `pg_backup.sh` in the `/opt/backup/` directory of the host (`install.svc.plus`):

```bash
#!/bin/bash
# ==========================================
# Unified PostgreSQL Backup Script
# ==========================================
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +"%Y%m%d_%H%M%S")
mkdir -p $BACKUP_DIR

echo "[INFO] Backing up AI Core Services databases (Port 15432)..."
DB_URL_BASE="postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432"
for DB in account litellm openclaw qmd rag notification scheduler audit artifact vault_storage; do
    pg_dump "$DB_URL_BASE/$DB?sslmode=disable" | gzip > "$BACKUP_DIR/${DB}_$DATE.sql.gz"
done

echo "[INFO] Backing up Zitadel IAM DB (zitadel-db-1)..."
docker exec zitadel-db-1 pg_dumpall -U postgres | gzip > "$BACKUP_DIR/zitadel_$DATE.sql.gz"

echo "[INFO] Backing up Gitea Code DB (Native PG 16)..."
sudo -u postgres pg_dumpall -p 5434 | gzip > "$BACKUP_DIR/gitea_$DATE.sql.gz"

echo "[INFO] Cleaning up backups older than 7 days..."
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete

echo "[INFO] Backup complete!"
```

> [!TIP]
> It is highly recommended to push backup files to an offsite S3 storage (like MinIO) or sync via `rclone` to other cloud storage to prevent datacenter-level disasters.

### 2.2 Cron Schedule

Add an automatic backup job at 3:00 AM daily via `crontab -e`:
```cron
0 3 * * * /bin/bash /opt/backup/pg_backup.sh >> /var/log/pg_backup.log 2>&1
```

## 3. Disaster Recovery & Restore Operations

When data corruption or full-machine migration occurs, please strictly follow this restore sequence.

> [!WARNING]
> Before executing a restore, you must first stop the business services generating write traffic (like Gitea, LiteLLM, etc.), keeping ONLY the PostgreSQL processes running.

### 3.1 Restore AI Core Services DB (Port 15432)
Includes: `Account`, `Vault Storage`, `Artifact`, `LiteLLM`, `OpenClaw`, `QMD`, `RAG`, `Notification`, `Scheduler`, `Audit`
```bash
# Unzip backup and import directly via credential URI (Using account as an example)
gunzip -c /var/backups/postgresql/account_YYYYMMDD.sql.gz | psql "postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432/account?sslmode=disable"
```

### 3.2 Restore Zitadel IAM DB (Docker)
```bash
# Unzip backup and import
gunzip -c /var/backups/postgresql/zitadel_YYYYMMDD.sql.gz | docker exec -i zitadel-db-1 psql -U postgres
```

### 3.3 Restore Gitea Code DB (Native)
Since Gitea is on the physical host, we need to switch to the `postgres` user:
```bash
# Unzip backup and import (Note port 5434)
gunzip -c /var/backups/postgresql/gitea_YYYYMMDD.sql.gz | sudo -u postgres psql -p 5434
```

## 4. High Availability & Advanced Recommendations

For the current single-node multi-instance architecture, logical backups (`pg_dumpall`) are sufficient for most scenarios, but the RPO (Recovery Point Objective) is approximately 24 hours (depending on backup frequency).

> [!IMPORTANT]
> **Recommendations for upgrading DR tier:**
> 1. **Incremental Backups (WAL Archiving)**: For mission-critical databases like AI Core Services and Gitea, introduce `pgBackRest` or `WAL-G` to continuously archive physical WAL logs to S3 (MinIO) in real-time. This reduces the risk of data loss (RPO) to minutes.
> 2. **Application-Level DR**: 
>    - Vault Storage decryption keys cannot solely exist in the database. Ensure Vault's physical Root Token / Unseal Keys are safely stored offline.
>    - For Gitea, in addition to backing up the database, you must periodically back up `/var/lib/gitea/data` (bare Git repositories and LFS artifacts) on the host. Using Gitea's built-in `gitea dump` command is highly recommended to achieve an integrated backup of both data and repositories.

---

# 中文版 (Chinese Version)

本文档基于 `install.svc.plus` 线上环境的实际部署情况，为你规划和整理了全局 PostgreSQL 数据库的备份、还原与灾备（DR）标准操作流程。

## 1. 线上环境数据库架构清单

根据线上环境探勘，当前系统存在 **三个独立运行的 PostgreSQL 实例**。在进行统一备份时，必须分别对这三个实例进行数据导出。

| 实例用途 | 运行模式 | 监听端口/地址 | 包含的业务系统库 |
| :--- | :--- | :--- | :--- |
| **AI 核心服务库** | Docker (`postgresql-svc-plus`) | `127.0.0.1:5432` | Account, Vault Storage, Artifact, LiteLLM, OpenClaw, QMD, RAG, Notification, Scheduler, Audit |
| **Zitadel 认证库** | Docker (`zitadel-db-1`) | 容器内部网 | Zitadel IAM 数据 |
| **Gitea 代码库** | Native Systemd (PG 16) | `127.0.0.1:5434` | Gitea |

## 2. 统一备份策略 (Backup)

为了实现无缝灾备，建议采用 **逻辑备份 (Logical Backup)** 结合 **定时异地转储 (Offsite Sync)** 的策略。

### 2.1 编写全局备份脚本

在宿主机 (`install.svc.plus`) 的 `/opt/backup/` 目录下创建统一备份脚本 `pg_backup.sh`：

```bash
#!/bin/bash
# ==========================================
# 统一 PostgreSQL 备份脚本
# ==========================================
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +"%Y%m%d_%H%M%S")
mkdir -p $BACKUP_DIR

echo "[INFO] 开始备份 AI 核心服务各业务库 (15432 端口)..."
DB_URL_BASE="postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432"
for DB in account litellm openclaw qmd rag notification scheduler audit artifact vault_storage; do
    pg_dump "$DB_URL_BASE/$DB?sslmode=disable" | gzip > "$BACKUP_DIR/${DB}_$DATE.sql.gz"
done

echo "[INFO] 开始备份 Zitadel 认证库 (zitadel-db-1)..."
docker exec zitadel-db-1 pg_dumpall -U postgres | gzip > "$BACKUP_DIR/zitadel_$DATE.sql.gz"

echo "[INFO] 开始备份 Gitea 代码库 (Native PG 16)..."
sudo -u postgres pg_dumpall -p 5434 | gzip > "$BACKUP_DIR/gitea_$DATE.sql.gz"

echo "[INFO] 清理 7 天前的旧备份..."
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete

echo "[INFO] 备份完成！"
```

> [!TIP]
> 建议将备份文件推送到异地 S3 (例如 MinIO) 或通过 `rclone` 同步到其他云存储，以防范机房级灾难。

### 2.2 配置定时任务 (Cron)

通过 `crontab -e` 添加每天凌晨 3 点自动备份：
```cron
0 3 * * * /bin/bash /opt/backup/pg_backup.sh >> /var/log/pg_backup.log 2>&1
```

## 3. 灾难恢复与还原 (Restore)

当发生数据损坏或整机迁移时，请严格按照以下顺序进行恢复。

> [!WARNING]
> 在执行还原前，必须先停止产生写入流量的业务服务（如 Gitea, LiteLLM 等），仅保留 PostgreSQL 进程运行。

### 3.1 还原 AI 核心服务库 (15432 端口)
包含：`Account`, `Vault Storage`, `Artifact`, `LiteLLM`, `OpenClaw`, `QMD`, `RAG`, `Notification`, `Scheduler`, `Audit`
```bash
# 解压备份文件并使用凭证直接导入 (以 account 为例)
gunzip -c /var/backups/postgresql/account_YYYYMMDD.sql.gz | psql "postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432/account?sslmode=disable"
```

### 3.2 还原 Zitadel 认证库 (Docker)
```bash
# 解压备份文件并导入
gunzip -c /var/backups/postgresql/zitadel_YYYYMMDD.sql.gz | docker exec -i zitadel-db-1 psql -U postgres
```

### 3.3 还原 Gitea 代码库 (Native)
由于 Gitea 在宿主机物理机上，我们需要切换到 postgres 用户执行：
```bash
# 解压备份文件并导入 (注意端口 5434)
gunzip -c /var/backups/postgresql/gitea_YYYYMMDD.sql.gz | sudo -u postgres psql -p 5434
```

## 4. 高可用与进阶建议 (Disaster Recovery)

对于目前的单机多实例架构，逻辑备份（`pg_dumpall`）足够应付大多数场景，但存在 RPO (恢复点目标) 约为 24 小时的问题（取决于备份频率）。

> [!IMPORTANT]
> **提升容灾级别的建议：**
> 1. **增量备份 (WAL Archiving)**: 针对业务极其核心的 AI 核心服务库和 Gitea，可引入 `pgBackRest` 或 `WAL-G`，将物理 WAL 日志实时归档至 S3（MinIO）。这样可以将数据丢失风险（RPO）降低到分钟级别。
> 2. **应用级灾备**: 
>    - Vault Storage 的加解密密钥不能仅存在数据库中，请确保 Vault 的物理 Root Token/Unseal Keys 已被安全离线保存。
>    - Gitea 除了备份数据库，还必须定期备份宿主机上的 `/var/lib/gitea/data` (Git 仓库裸数据和 LFS 制品)。可以借助 Gitea 自带的 `gitea dump` 命令来实现数据 + 仓库的一体化备份。
