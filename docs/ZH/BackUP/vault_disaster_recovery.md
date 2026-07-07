# Vault 统一数据备份与灾备方案

本文档基于 `install.svc.plus` 线上环境的实际部署情况，为你规划和整理了 HashiCorp Vault 的备份、还原与灾备（DR）标准操作流程。

---

## 1. Vault 灾备架构概述

Vault 的数据备份与恢复可以从两个不同的维度进行：

1. **底座存储级备份（存储引擎级）**
   - **原理**：Vault 在线上以 PostgreSQL 作为存储后端（即 `postgresql-svc-plus` 容器中的 `vault_storage` 数据库）。
   - **特点**：备份 `vault_storage` 数据库即完成了 Vault 完整数据的冷备。备份的数据是处于密文状态的（加密后存储），恢复时需要原始 Vault 实例的 **Shamir Unseal Keys (解密密钥)**。
   - **用途**：适用于整机损坏、大版本升级失败或介质损毁后的全量底座级恢复。

2. **应用/API 级备份（KV2 秘密引擎级）**
   - **原理**：使用 Vault API 递归抓取所有 KV 秘密引擎下的明文键值对，导出为本地 JSON 结构，并使用外部密钥对称加密上传。
   - **特点**：不依赖底层数据库，支持跨平台和跨存储后端迁移。可以在没有物理主机权限的情况下，仅凭管理员 Token 进行局部 KV 的备份与恢复。
   - **用途**：适用于误删特定路径的秘密、单独同步/迁移某些环境下的 KV 配置等。

> [!CAUTION]
> **物理安全大防线**：
> 无论是存储级还是 API 级，Vault 的 **Shamir Unseal Keys (解锁凭证/密匙分片)** 和 **Root Token** 均**无法**从运行中的 API 或数据库中自动备份。请务必将它们以物理方式离线妥善保存（如打印成纸质或存储在离线物理介质中）。一旦丢失 Shamir Key，数据库备份将由于无法解开主密钥而彻底失效。

---

## 2. 自动化备份策略（API 级 / KV2 全备份）

我们已在项目中提供自动化备份与恢复脚本：
- **备份脚本**：[backup_vault_kv.py](file:///Users/shenlan/workspaces/ai-workspace-infra/site-migration-toolkit/scripts/backup/backup_vault_kv.py)
- **还原脚本**：[restore_vault_kv.py](file:///Users/shenlan/workspaces/ai-workspace-infra/site-migration-toolkit/scripts/backup/restore_vault_kv.py)

### 2.1 备份流程说明
1. 脚本会通过 `VAULT_ADDR` 与 `VAULT_TOKEN`（或 `VAULT_JWT` + `VAULT_ROLE` 动态登录）连接 Vault。
2. 自动拉取 `/v1/sys/mounts`，过滤出所有 `type: kv` 的活跃秘密引擎。
3. 如果未配置 S3 环境变量，会自动读取 Vault 中 `kv/CICD` 的 S3 访问凭证。
4. 递归爬取各个 KV 引擎下的所有秘密，拼装成统一的 JSON 格式。
5. 本地使用 `openssl aes-256-cbc` PBKDF2 对 JSON 数据进行高强度加密。
6. 上传加密后的 `.json.enc` 归档包至 S3 存储桶的 `vault-backups/` 目录下。

### 2.2 本地定时任务配置

1. 将 `backup_vault_kv.py` 拷贝至宿主机 `/opt/backup/backup_vault_kv.py`，确保可执行。
2. 配置凭证配置文件 `/opt/backup/.vault_backup_env`（`chmod 600`）：
```bash
# Vault API 访问地址
export VAULT_ADDR="https://vault.svc.plus"

# 鉴权方式（二选一）：
# 选项 A：使用静态 Admin Token
export VAULT_TOKEN="your_vault_admin_token"
# 选项 B：使用 JWT Role 鉴权
# export VAULT_JWT="your_jwt_string"
# export VAULT_ROLE="backup-role"

# 异地备份强加密口令（务必保管好，解密必须）
export BACKUP_ENCRYPTION_PASS="YourSuperSecurePassphrase"
```
3. 在宿主机添加 Cron 任务（每天凌晨 3:30 自动执行）：
```cron
30 3 * * * /usr/bin/python3 /opt/backup/backup_vault_kv.py >> /var/log/vault_backup.log 2>&1
```

---

## 3. 灾难恢复与还原流程

### 3.1 还原底座级数据（存储后端恢复）
当 Vault 彻底崩溃，且你想将数据恢复到上一次数据库备份点时：

1. **停止 Vault 服务**（防止向数据库继续写入）：
   ```bash
   systemctl stop vault
   ```
2. **恢复 `vault_storage` 数据库**：
   按 PostgreSQL 灾备方案中的步骤，将 `vault_storage` 的加密数据库备份还原至 `postgresql-svc-plus` 中。
3. **启动 Vault 服务**：
   ```bash
   systemctl start vault
   ```
4. **手动进行 unseal 操作**：
   Vault 启动后将处于 Sealed 状态。在你的安全终端依次输入 Shamir 密钥分片，直至解封：
   ```bash
   vault operator unseal
   ```

### 3.2 还原 API/KV 级秘密（使用自动化脚本）
当你希望从 S3 下载的加密秘密备份中恢复特定的 KV 秘密时：

1. **准备备份文件**：从 S3 中下载加密的备份文件 `vault_backup_YYYYMMDD_HHMMSS.json.enc`。
2. **执行恢复脚本**：
   导入环境变量并传入加密文件路径运行：
   ```bash
   export VAULT_ADDR="https://vault.svc.plus"
   export VAULT_TOKEN="your_vault_token"
   export BACKUP_ENCRYPTION_PASS="YourSuperSecurePassphrase"

   /opt/backup/restore_vault_kv.py ./vault_backup_YYYYMMDD_HHMMSS.json.enc
   ```
3. **脚本会自动完成以下操作**：
   - 使用 OpenSSL 解密备份文件为 JSON。
   - 解析出原备份中的所有秘密引擎，并在目标 Vault 中检查其是否已启用。若未启用，将自动启用对应的 KV 秘密引擎（自动识别 KV v1 或 v2 模式）。
   - 将所有秘密逐条写入目标路径下。

---

## 4. 日常灾备检查 checklist
- [ ] 备份口令 `BACKUP_ENCRYPTION_PASS` 是否已记录在团队的离线密码管理器中。
- [ ] Vault 初始化生成的三个/五个 Shamir 密钥分片，是否已放置于不同的安全离线介质。
- [ ] 定期（如每季度）从 S3 下载一次备份包，并在测试环境下执行 `openssl enc -d` 解密校验，确保数据没有损坏或密钥变更。
