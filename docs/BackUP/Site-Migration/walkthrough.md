# 站点迁移与数据同步实施总结 (Walkthrough)

我已经按照你确认的设计思路，完整实现了**全站单向数据流迁移与环境复制体系**。这一体系完全支持多环境部署，并且以声明式、参数化的方式自动改写域名（例如将 `svc.plus` 迁移至 `onwalk.net`）。

---

## 核心实现结构

### 1. 声明式配置模板 (YAML)
**文件**: [defaults/main.yml](file:///Users/shenlan/workspaces/ai-workspace-infra/playbooks/roles/site_migration/defaults/main.yml)

在这里，我为你定义了基于数据流方向的全局变量 `migration_flow`。其中 `source.domain_base` 和 `destination.domain_base` 是完全参数化的，可以通过流水线按需覆盖。配置中清晰地拆分了 `ai_core_db`、`zitadel_db`、`gitea_data` 以及 `caddy_configs` 等四大模块，后续只需增删此处的 List 即可扩展迁移内容，无需改动底层逻辑代码。

### 2. 核心执行引擎 (Ansible Role)
**角色目录**: [roles/site_migration](file:///Users/shenlan/workspaces/ai-workspace-infra/playbooks/roles/site_migration/)
**入口剧本**: [migrate_site.yml](file:///Users/shenlan/workspaces/ai-workspace-infra/playbooks/migrate_site.yml)

该角色分为两阶段执行：
- **Phase 1 (Extract)**: 登录 `migration_source` 机器，根据 YAML 配置执行并发的 `pg_dump`，并自动打包需要同步的文件路径。最终调用 Ansible 的拉取机制 (`fetch/synchronize pull`)，将所有制品安全缓存到执行机 (Runner)。
- **Phase 2 (Load)**: 将制品通过推送机制 (`synchronize push`) 发送到 `migration_target` 机器上。执行阶段会自动拦截含有 `domain_rewrite: true` 的制品模块，利用流式替换 (`sed` 替换 SQL dumpfile、Caddy 配置文件内容以及重命名文件名），彻底将类似 `svc.plus` 冲刷为 `onwalk.net`。随后按需恢复并自动重启 Gitea, Caddy 及相关的 Docker 服务。

### 3. CI/CD IaC 协同流水线
**流水线**: [.github/workflows/deploy-env-migration.yaml](file:///Users/shenlan/workspaces/ai-workspace-infra/playbooks/.github/workflows/deploy-env-migration.yaml)

在 Github Actions 中，我为你搭建了一条包含了 `workflow_dispatch` 的新流水线。你可以直接在 UI 上填入 `source_domain_base`（如 `svc.plus`）和 `target_domain_base`（如 `onwalk.net`）。
流水线完整编排了：
1. **Provision**: 调用底层 Terraform 申请新服务器。
2. **Deploy Base**: 执行最初的 Bootstrap 环境搭建。
3. **Data Migration**: 生成动态的 Ansible inventory，随后触发上述编写的 `migrate_site.yml` 完成旧环境数据与配置克隆。

### 4. 运行前置条件 (Vault OIDC 授权)

由于我们新建了独立的 `site-migration-toolkit` 仓库，该仓库需要通过 GitHub Actions 的 OIDC 身份认证到 Vault 获取凭证。在首次运行流水线之前，你必须使用拥有管理员权限的凭据在你的终端（或 Vault 所在的 `vault.svc.plus` 主机）执行以下操作，以授权新的流水线拉取密钥：

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="hvs.xxxxxxxxx" # 请替换为你拥有管理员权限的真实 Token

vault write auth/jwt/role/github-actions-site-migration-toolkit - <<EOF
{
  "role_type": "jwt",
  "user_claim": "repository",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/site-migration-toolkit",
    "sub": "repo:ai-workspace-infra/site-migration-toolkit:*"
  },
  "token_policies": ["github-actions-xworkspace-console"],
  "token_ttl": "20m",
  "token_max_ttl": "30m"
}
EOF
```

> [!TIP]
> 如果你在已经申请好并构建好的机器之间进行单纯的“灾备演练”或“环境数据同步”，你可以取消勾选流水线中的 `run_provision_and_deploy`，流水线将直接执行最核心的**数据克隆阶段**，速度会非常快。
