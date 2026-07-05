# Web SaaS 服务与入口域 (Domain: web-saas)

本域覆盖面向外部用户的 Web 控制台、静态分发、支付系统及流量加速代理入口。

## 1. 资产与组件清单

本域主要由无状态前端服务、分发平台及代理隧道节点构成：

### Web 服务与控制台 (核心入口)
- **Console**: `console.svc.plus` (127.0.0.1:3000) - Web Site Home Page Control Panel
  - **子路由 `/billing`**: 包含 Billing 计费流水、Payment Amount 等相关服务
  - **子路由 `/ebook`**: 包含在线文档、开源解决方案等静态分发 (`/opt/modern-it-history/current`)
- **Accounts**: `accounts.svc.plus` - 统一账户服务
- **Install Scripts**: `install.svc.plus` (302 Redir -> Github) - Short link distribution for curl-based one-click installation scripts

### 核心数据库层 (Database)
- **PostgreSQL**: `postgresql-saas.onwalk.net` - 承载 Web SaaS 业务的强状态独立数据库服务

### 加速 Pools (代理节点)
- **JP XHTTP / Xray**: `jp-xhttp.svc.plus` (跨越代理隧道 `/dev/shm/xray.sock`)
- **TKY Proxy**: `tky-proxy.svc.plus` (跨越代理隧道 `/dev/shm/xray.sock`)

## 2. 备份与同步策略

### 代理隧道与证书配置
- 导出底层的 Xray 路由与网关证书。由于本域大部分为前端入口与无状态转发层，重点在于确保底层证书 (`acme.json` 或 Caddy/Nginx 证书文件) 以及路由表的平滑迁移。
- 若包含 Xstream 和 Billing 相关的独立数据库，则需要使用 `pg_dump` 备份计费和支付状态信息。

### 静态文件同步
针对 Ebook 等挂载的静态数据，执行常规增量同步：
```bash
rsync -avz --delete /opt/modern-it-history/current/ backup-server:/opt/modern-it-history/current/
```

## 3. 恢复与上线流程
1. **静态数据还原**: 同步并恢复前端资源和挂载的静态卷。
2. **代理环境还原**: 在目标服务器配置相关的网络套接字（如 `/dev/shm/xray.sock`）。
3. **前端/网关重启**: 在 DNS 切换之前，确保对应的 Web 服务、Console 以及反代网关正确加载。DNS 切至新机器后，Caddy 会自动重新执行 HTTP 质询获取证书或加载迁移过的证书。

## 4. CI 部署前置 (`deploy_web_saas` job / Vault Secrets)

`.github/workflows/deploy-env-migration.yaml` 里 `target_domains=web-saas`(或 `all`)
触发的 `deploy_web_saas` job，实际部署 postgresql.svc.plus / stunnel-client /
accounts.svc.plus / billing-service / console.svc.plus 这 5 个服务到同一台
provision 出来的主机上。

所有 web-saas 专属密钥集中放在 **`kv/data/WEB_SAAS`**（人工维护，workflow 只读不写）：

| Key (`kv/data/WEB_SAAS`) | 说明 |
|---|---|
| `POSTGRES_ROOT_PASSWORD` | Postgres 容器的 root (`postgres`) 密码，首次 `initdb` 时写入；换密码要先手动改容器里的密码，再同步改这里，否则下次重跑对不上。 |
| `ACCOUNT_DB_PASSWORD` | `account` 库 `account_user` 账号的密码，由 `create_databases_and_users.yml` 建号时使用，也是 `accounts.svc.plus` 连库用的密码。 |
| `BILLING_DATABASE_URL` | billing-service 的完整 Postgres 连接串（`postgres://user:pass@stunnel-client:15432/db?sslmode=disable`），可以复用 `account_user`/`account`，也可以单独建一个账号。 |
| `INTERNAL_SERVICE_TOKEN` | billing-service 内部服务间鉴权 token。 |
| `GHCR_USERNAME` | 拉取 `ghcr.io/ai-workspace-services/console` 镜像用的 GHCR 用户名。 |
| `GHCR_PASSWORD` | 对应的 GHCR token/密码。 |

这 6 个 key 都需要提前在 Vault 里手动填好真实值；缺哪个，对应 ansible 任务会在
assert/连接阶段明确报错，不会静默用空值跑下去。

### 必须的 Vault Policy (已在 [run #28732574921](https://github.com/ai-workspace-infra/site-migration-toolkit/actions/runs/28732574921/job/85200873591) 实测确认为阻塞项)

`Load Vault secrets` 这一步实测 `403 Forbidden`（整个 job 在读密钥这一步就失败，
后面所有部署 step 都不会执行）。

**根因**：`github-actions-site-migration-toolkit` 这个 JWT role 初始化时
（见 [walkthrough.md §4](../../ZH/BackUP/Site-Migration/walkthrough.md)）**没有自己的
policy，借用的是 `token_policies: ["github-actions-xworkspace-console"]`**。而那个
policy（定义在 xworkspace-console 仓库
`docs/operations/vault-github-actions.md`）只覆盖 `kv/data/CICD` 和
`kv/data/openclaw` 两条路径，所以读新加的 `kv/data/WEB_SAAS` 必然 403。

**修复（推荐做法：给本仓库建独立 policy，不再蹭 xworkspace-console 的）**——
用管理员 token 在 `vault.svc.plus` 执行：

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="hvs.xxxxxxxxx"   # 管理员 Token

# 1. 独立 policy：CICD 共享键(SSH/TF/Vultr) + web-saas 专属键
vault policy write github-actions-site-migration-toolkit - <<'EOF'
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["read", "list"]
}
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}
path "kv/metadata/WEB_SAAS" {
  capabilities = ["read", "list"]
}
EOF

# 2. 把 role 的 token_policies 从借用的 xworkspace-console 切换到独立 policy
#    (其余 bound_claims 参数与 walkthrough.md 首次初始化保持一致)
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

> 备选做法是直接往共享的 `github-actions-xworkspace-console` policy 里追加
> WEB_SAAS 路径，改动更小，但会让 xworkspace-console 仓库的流水线也能读到
> web-saas 的数据库密码，不符合最小权限，不推荐。

操作完成后：

1. 打开 [kv/WEB_SAAS](https://vault.svc.plus/ui/vault/secrets/kv/list/WEB_SAAS/) 确认 6 个 key 都已填好真实值。
2. 直接重新触发 workflow 即可，role/policy 变更立即生效，无需其他操作。

在修复之前，`target_domains=web-saas`(或 `all`) 的 run 会在 `Load Vault secrets`
这一步就 403 失败，不会部署任何 web-saas 服务。
