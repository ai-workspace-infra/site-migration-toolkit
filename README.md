# Site Migration & Backup Toolkit (业务域重构版)

*🇨🇳 中文版 | Chinese version*

欢迎使用 **Site Migration & Backup Toolkit**。本代码库提供了面向 AI Workspace 基础架构灾难恢复及跨机房整体迁移的自动化解决方案。

> ℹ️ **架构升级提示**：本工具集已经从旧版的“All-in-One”大一统架构，重构为以**业务域 (Business Domains)** 为边界的高内聚架构。这允许我们针对不同业务系统进行解耦、按需迁移及独立演进。

## 🌐 核心业务域导航 (Business Domains)

本工具集依据线上系统的实际业务链路，拆分为以下三大核心域：

1. **[domain-ai-workspace](domains/ai-workspace/README.md)** (AI 核心链路域)
   - 涵盖 LiteLLM、OpenClaw、QMD 等智能代理与模型路由调度链路。
2. **[domain-web-saas](domains/web-saas/README.md)** (SaaS 前端与加速域)
   - 涵盖 Web Console、Accounts、Billing 计费及底层的 Xray 隧道代理入口。
3. **[domain-open-platform](domains/open-platform/README.md)** (开放平台与基础设施域)
   - 涵盖 Gitea、Vault、IAM (Zitadel) 以及强大的全局可观测性底座 (Observability Stack - Grafana, VictoriaMetrics 等)。

详细的各个域的迁移、备份、与恢复策略，请查阅各个子域内的 `README.md` 文档。

## 🚀 迁移编排与使用 (Orchestration)

*注：编排层正在从旧版 Python 单体脚本向模块化 Ansible / Make 支持过渡中。*

您可以通过全局的入口命令，指定单个或多个 `DOMAIN` 来执行按需备份或迁移：

```bash
# 示例：仅对 AI 工作区及开放平台底座进行数据备份
make backup DOMAIN=ai-workspace,open-platform

# 示例：一键触发全站各域的迁移与恢复流水线
make migrate DOMAIN=all
```

## 🛠️ CI/CD 与 IaC 流水线

通过流水线触发整体或部分域的迁移时，底层同样会调用相应的业务域策略模块。

### ⚠️ Vault 鉴权配置 (GitHub Actions OIDC → Vault JWT)

流水线不使用任何 GitHub Actions Secrets 存敏感值；所有凭证都在运行时经
**GitHub OIDC → Vault JWT** 登录后，从 Vault KV 按路径分发。完整初始化过程如下
（一次性操作，需要 Vault 管理员 token，在任意能访问 `https://vault.svc.plus` 的终端执行）。

#### 0. 全局前提（Vault 侧通常已存在，仅首次搭建需要）

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="hvs.xxxxxxxxx"   # 管理员 Token

# jwt auth mount（整个 org 共享一个，已存在则跳过）
vault auth enable jwt
vault write auth/jwt/config \
  oidc_discovery_url="https://token.actions.githubusercontent.com" \
  bound_issuer="https://token.actions.githubusercontent.com"

# KV v2 引擎挂载在 kv/（已存在则跳过）
vault secrets enable -path=kv kv-v2
```

#### 1. Policy：本仓库专属，按域最小授权

```bash
vault policy write github-actions-site-migration-toolkit - <<'EOF'
# 共享 CICD 键: SSH 部署私钥 / Vultr / TF state / Cloudflare DNS
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["read", "list"]
}
# web-saas 域专属键 (见 docs/domains/web-saas/README.md §4)
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}
path "kv/metadata/WEB_SAAS" {
  capabilities = ["read", "list"]
}
EOF
```

> 后续新增业务域的专属密钥时，沿用同一模式：新开 `kv/data/<DOMAIN>` 路径存放该域
> 的 key，然后在这个 policy 里追加对应的 `data` + `metadata` 两段 path。
> 不要把业务域密钥混进共享的 `kv/data/CICD`，也不要借用其他仓库的 policy
> （历史上本 role 曾借用 `github-actions-xworkspace-console` 的 policy，导致新增
> `kv/data/WEB_SAAS` 后流水线 403，见 web-saas README §4 的实测记录）。

#### 2. Role：只信任本仓库的 OIDC 身份

```bash
vault write auth/jwt/role/github-actions-site-migration-toolkit - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "repository",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/site-migration-toolkit",
    "sub": "repo:ai-workspace-infra/site-migration-toolkit:*"
  },
  "token_policies": ["github-actions-site-migration-toolkit"],
  "token_ttl": "20m",
  "token_max_ttl": "30m"
}
EOF
```

> `bound_claims` 把这个 role 锁定为**只有本仓库的 workflow** 能换取 token；
> 如需进一步只允许 main 分支触发，把 `sub` 收窄为
> `repo:ai-workspace-infra/site-migration-toolkit:ref:refs/heads/main`。

#### 3. 填充各域 KV 参数

| Vault 路径 | 键 | 用途 |
| --- | --- | --- |
| `kv/data/CICD` | `SSH_PRIVATE_DEPLOY_KEY_B64` | Ansible SSH 到目标主机（单行 base64） |
| `kv/data/CICD` | `VULTR_API_KEY` | Terraform provision VPS |
| `kv/data/CICD` | `TF_STATE_ENDPOINT/BUCKET/ACCESS_KEY/SECRET_KEY/REGION` | 远端 TF state (S3 兼容) |
| `kv/data/CICD` | `CLOUDFLARE_DNS_API_TOKEN` | switch_dns 阶段接管域名 |
| `kv/data/WEB_SAAS` | 6 个键，见 [web-saas README §4](docs/domains/web-saas/README.md) | web-saas 域服务部署 |

#### 4. Workflow 侧接入（已落地，无需改动）

`.github/workflows/deploy-env-migration.yaml` 中每个 job：

1. `permissions: { contents: read, id-token: write }` —— `id-token: write` 是 OIDC 换 token 的前提；
2. `hashicorp/vault-action@v4`：`method: jwt`、`role: github-actions-site-migration-toolkit`、`jwtGithubAudience: vault`，`secrets` 里每行 `<kv路径> <键> | <输出名>`；
3. 后续步骤经 `steps.vault.outputs.<输出名>` 消费，不落盘、不进 GitHub Secrets。

#### 5. 验收与排障

- 触发流水线后每个 job 的 `Load Vault secrets` 步骤应显示 `Token Info` 且无报错。
- `403 Forbidden`：role 绑定的 policy 未覆盖所读路径（对照 §1 检查 `data`+`metadata` 两段都在）。
- `permission denied` / role 不匹配：核对 OIDC `repository`/`sub` 与 role 的 `bound_claims`。
- vault-action 报 `valid path and key`：`secrets` 行间用 `;` 分隔、KV v2 路径必须含 `data/`（如 `kv/data/CICD` 而非 `kv/CICD`）。
