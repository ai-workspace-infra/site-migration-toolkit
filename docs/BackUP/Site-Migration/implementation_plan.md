# 全站单向数据流迁移与环境复制方案 (Implementation Plan)

该方案旨在构建一套**声明式、单向数据流（Source -> Target）、域名支持参数化**的自动化环境迁移与恢复体系。基于你提供的需求，整体设计分为三个核心部分。

## Proposed Changes

### 1. 声明式迁移配置文件模板 (Declarative YAML Spec)
在 `playbooks/roles/site_migration/defaults/main.yml` 中定义全局单向数据流配置：

```yaml
# 迁移数据流方向声明
migration_flow:
  source:
    host: "install.svc.plus"
    domain_base: "svc.plus"
    ssh_user: "root"
  target:
    host: "{{ target_env_ip }}"          # IAC 流水线动态传入
    domain_base: "{{ target_domain }}"   # IAC 流水线动态传入 (例如 contabo-xyz.svc.plus)
    ssh_user: "root"

  # 定义需要迁移的数据模块
  modules:
    - name: "ai_core_db"
      type: "postgresql"
      port: 15432
      databases: ["account", "litellm", "openclaw", "qmd", "rag", "notification", "scheduler", "audit", "artifact", "vault_storage"]
    
    - name: "zitadel_db"
      type: "postgresql_docker"
      container: "zitadel-db-1"
    
    - name: "gitea_data"
      type: "gitea"
      pg_port: 5434
      data_dirs: ["/var/lib/gitea/data"]
      
    - name: "caddy_configs"
      type: "file_sync"
      paths: ["/etc/caddy/conf.d/"]
      # 核心特性：自动将 source 的域名（如 api.svc.plus）替换为 target 的域名（如 api.contabo.svc.plus）
      domain_rewrite: true
```

### 2. 迁移与恢复 Ansible Role
#### [NEW] `playbooks/roles/site_migration/`
创建用于执行全站备份、传输与恢复的专用 Ansible 角色。
- **数据提取 (Extract)**: 登录源环境，并行执行数据库 `pg_dump`，打包 Gitea 文件系统和 Caddy 配置。
- **动态转换 (Transform)**: 利用 Ansible `replace` 或 `sed` 模块，在恢复前对 Caddy 配置和数据库 Dump 中的老域名 (`svc.plus`) 进行全局替换，实现域名参数化。
- **装载恢复 (Load)**: 通过 `synchronize` (rsync) 单向推送到新环境，执行 `psql` 导入与 `systemctl/docker` 重启。

#### [NEW] `playbooks/migrate_site.yml`
作为入口 Playbook，加载上述 role，执行单向数据流迁移。

### 3. CI/CD IaC 流水线
#### [NEW] `playbooks/.github/workflows/deploy-env-migration.yaml`
参考现有的 `deploy-ai-workspace-iac.yaml`，我们将在 `playbooks/.github/workflows/` 下新建一条流水线。该流水线的核心逻辑为：
1. **Provision (Terraform)**: 接收输入参数（如新大区、配置），调用底层 IaC 申请新机器并渲染出新的 IP 与域名。
2. **Deploy (Ansible)**: 对新机器执行全新的基础环境构建 (run-on-host-bootstrap)。
3. **Data Sync (Ansible Migration)**: 新环境 ready 后，以原生产环境为 source，新机器为 target，调用 `migrate_site.yml` 将数据和配置全量平滑克隆过去。

---

## User Review Required

> [!IMPORTANT]
> 这是一个高危 / 核心架构级的操作，请审阅以下问题：

1. **域名替换风险**: 直接在 SQL dump 和 Caddy 配置中查找替换 `domain_base`（如把 `svc.plus` 换成 `xxx.svc.plus`）是否满足你的预期？（注意某些数据库字段中可能包含硬编码的老域名）。
2. **密钥库同步**: Vault Storage 的数据也会被原封不动克隆到新环境，这意味着新环境使用的解密密钥 (Unseal keys) 必须和原环境保持一致，这符合你的要求吗？
3. **Pipeline 位置**: 你要求在 `playbooks/.github/workflows/` 下建立流水线。这是否意味着 playbooks 目录本身作为一个独立的 Git 仓库进行 Action 触发，还是随 `ai-workspace-infra` 整体触发？

如果设计方向无误，请批准此计划，我将开始为你生成 YAML 模板、Ansible Role 和 Pipeline 文件。
