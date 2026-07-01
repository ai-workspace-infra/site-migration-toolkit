# Site Migration & Backup Toolkit (site-migration-toolkit)

*🇨🇳 中文版在下方 | Chinese version below*

Welcome to the **Site Migration & Backup Toolkit**. This repository provides the orchestrations, runbooks, and automated playbooks for managing the disaster recovery lifecycle of the AI Workspace infrastructure.

## Phase Roadmap

This project is iteratively rolling out disaster recovery capabilities. Currently, we are heavily focused on **Phase 1**.

### Phase 1: Migration / Cold Backup / Offline Restore (Current)

Implement only the foundation:

* Ansible automated migration skeleton
* File and configuration packaging
* PostgreSQL dump / restore skeleton
* Vault secret migration design placeholder
* DNS cutover pre-check placeholder
* GitHub Actions regression verification skeleton
* Manual recovery fallback scripts and runbook

### Phase 2: Warm Standby / Scheduled Backup

Only reserve documentation and interface placeholders for:

* Scheduled backup
* Incremental sync
* Object storage archive
* Restore drill
* RPO / RTO report

### Phase 3: Hot Backup / DTS / Replication

Only reserve roadmap placeholders for:

* PostgreSQL streaming replication
* Redis replication
* DTS / CDC
* Dual-write validation
* Failover plan

### Phase 4: Multi-Active / DR Platform

Only reserve roadmap placeholders for:

* Multi-region deployment
* Traffic routing
* Data consistency strategy
* Active-Active / Active-Passive
* DR orchestration platform

### ⚠️ CI/CD Prerequisites (Important Notice)

If you are running the GitHub Actions workflow (`deploy-env-migration.yaml`), please ensure that your Vault environment is correctly configured:
- **Vault Role**: The required role name is `github-actions-site-migration-toolkit`.
- **Role Binding**: Ensure the JWT `bound_claims` match the new repository name (`repo:ai-workspace-infra/site-migration-toolkit:ref:refs/heads/main` or similar).

**Vault Role Provisioning Script**:
To avoid CLI parsing issues, use the following JSON payload format to create or update the role. This also binds the correct policy to the role.

1. **Create the Vault Policy** (Grants read access to required secrets):
```bash
vault policy write github-actions-site-migration-toolkit - <<EOF
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/data/openclaw" {
  capabilities = ["read"]
}
EOF
```

2. **Create the Vault JWT Role** (Binds the repository claim to the policy):
```bash
vault write auth/jwt/role/github-actions-site-migration-toolkit - <<EOF
{
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/site-migration-toolkit"
  },
  "user_claim": "actor",
  "role_type": "jwt",
  "policies": ["github-actions-site-migration-toolkit"], 
  "ttl": "1h"
}
EOF
```

### 🐛 Common Vault Authentication Issues (Troubleshooting)

- **`400 Bad Request` (role could not be found)**: 
  - *Cause*: The `VAULT_ROLE` defined in `.github/workflows/deploy-env-migration.yaml` does not match any existing role in your Vault server.
  - *Fix*: Create the role using the script above, ensuring the name is exactly `github-actions-site-migration-toolkit`.
- **`403 Forbidden` (during Get Vault Secrets)**: 
  - *Cause*: The JWT authenticated successfully, but the token lacks read permissions for the requested KV paths (e.g., `kv/data/CICD`). This happens if the assigned `policies` in your Role do not exist or lack the `read` capability.
  - *Fix*: Run `vault policy list` to verify. If missing, create the `github-actions-site-migration-toolkit` policy as shown above and bind it to the role.

---

# 站点迁移与备份工具集 (Site Migration & Backup Toolkit)

欢迎使用 **Site Migration & Backup Toolkit**。本代码库提供了管理 AI Workspace 基础架构灾难恢复生命周期的编排、运维手册和自动化 Playbooks。

## 阶段演进路线图 (Phase Roadmap)

本项目正在迭代推出灾备能力。目前，我们正重点聚焦于 **Phase 1 (第一阶段)**。

### Phase 1: 迁移 / 冷备 / 离线恢复 (当前阶段)

仅实现基础底座：

* Ansible 自动化迁移骨架
* 文件与配置打包
* PostgreSQL 逻辑备份 / 还原骨架
* Vault 凭证迁移设计占位符
* DNS 流量切换前置检查占位符
* GitHub Actions 回归验证骨架
* 手动恢复降级脚本与运维手册

### Phase 2: 温备 / 定时备份

仅保留文档与接口占位符：

* 定时计划备份
* 增量同步
* 对象存储归档
* 还原演练
* RPO / RTO 报告

### Phase 3: 热备 / DTS / 复制

仅保留路线图占位符：

* PostgreSQL 流复制
* Redis 数据复制
* DTS / CDC (变更数据捕获)
* 双写验证
* 故障转移 (Failover) 计划

### Phase 4: 多活 / 灾备管理平台

仅保留路线图占位符：

* 多地域 (Multi-region) 部署
* 流量智能路由
* 数据一致性策略
* 双活 (Active-Active) / 主备 (Active-Passive)
* DR 灾备编排平台

### ⚠️ CI/CD 前置条件 (重要提示)

如果您正在运行 GitHub Actions 流水线 (`deploy-env-migration.yaml`)，请确保您的 Vault 环境已正确配置：
- **Vault 角色 (Role)**: 所需的角色名为 `github-actions-site-migration-toolkit`。
- **角色绑定 (Role Binding)**: 请确保 JWT 的 `bound_claims` 匹配新的代码库名称（例如 `repo:ai-workspace-infra/site-migration-toolkit:ref:refs/heads/main`）。

**Vault 角色配置脚本**:
为了避免 Vault CLI 在解析命令行 Map 类型时出现报错，推荐使用以下 JSON payload 的格式直接创建或更新角色，并同时配齐必需的 Policy。

1. **创建 Vault Policy** (授予访问必需敏感信息的读权限)：
```bash
vault policy write github-actions-site-migration-toolkit - <<EOF
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/data/openclaw" {
  capabilities = ["read"]
}
EOF
```

2. **创建 Vault JWT Role** (将代码库的身份标识与权限 Policy 绑定)：
```bash
vault write auth/jwt/role/github-actions-site-migration-toolkit - <<EOF
{
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/site-migration-toolkit"
  },
  "user_claim": "actor",
  "role_type": "jwt",
  "policies": ["github-actions-site-migration-toolkit"], 
  "ttl": "1h"
}
EOF
```

### 🐛 常见 Vault 鉴权排错指南 (Troubleshooting)

- **报错 `400 Bad Request` (role could not be found)**: 
  - *原因*: Github Actions 流水线中定义的 `VAULT_ROLE` 在你的 Vault 服务器上不存在。
  - *解法*: 请使用上方脚本创建名为 `github-actions-site-migration-toolkit` 的角色。
- **报错 `403 Forbidden` (发生在 Get Vault Secrets 阶段)**: 
  - *原因*: JWT 登录成功，但是签发的 Token 没有对应路径（如 `kv/data/CICD`）的读权限。这通常是因为绑定在 Role 上的 `policies` 不存在，或者里面的权限配置不包含 `read`。
  - *解法*: 在服务端运行 `vault policy list` 检查。如果缺少对应策略，请执行上方的【创建 Vault Policy】步骤补充权限，并确保 Role 正确绑定了该 Policy。
