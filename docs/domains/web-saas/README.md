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

`Load Vault secrets` 这一步实测会因为权限不足直接 `403 Forbidden`（整个 job 在
读密钥这一步就失败，后面所有部署 step 都不会执行）。原因是 Vault 里
`github-actions-site-migration-toolkit` 这个角色的 policy 只覆盖了
`kv/data/CICD`，没有覆盖新加的 `kv/data/WEB_SAAS` 路径。

需要给这个 role 绑定的 policy 补上（KV v2 读取同时需要 `data` 和 `metadata`
两个子路径的权限）：

```hcl
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}

path "kv/metadata/WEB_SAAS" {
  capabilities = ["read"]
}
```

在 Vault 里操作步骤大致是：

1. 打开 [kv/WEB_SAAS](https://vault.svc.plus/ui/vault/secrets/kv/list/WEB_SAAS/) 确认 6 个 key 都已经填好真实值。
2. 找到 `github-actions-site-migration-toolkit` 这个 role 绑定的 policy（在 Vault UI 的 Access -> Policies 里），把上面这段 `path` 追加进去。
3. 不需要重新生成 JWT role 本身，policy 更新后下次触发 workflow 即可读到。

在这个 policy 补上之前，`target_domains=web-saas`(或 `all`) 的 run 会在
`Load Vault secrets` 这一步就 403 失败，不会部署任何 web-saas 服务。
