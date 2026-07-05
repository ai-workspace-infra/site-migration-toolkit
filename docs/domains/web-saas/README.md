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

**不需要提前手动在 Vault 里创建任何 `WEB_SAAS_*` 前缀的新 key。** 早期设计草稿里列过
`WEB_SAAS_POSTGRES_ROOT_PASSWORD` / `WEB_SAAS_ACCOUNT_DB_PASSWORD` /
`WEB_SAAS_BILLING_DATABASE_URL` / `WEB_SAAS_INTERNAL_SERVICE_TOKEN` /
`WEB_SAAS_GHCR_USERNAME` / `WEB_SAAS_GHCR_PASSWORD` 六个 key，后来做了两处调整,
实际只剩 2 个 key 由 workflow 自己读写，其余 4 个已经作废：

| Key (`kv/data/CICD`) | 状态 | 说明 |
|---|---|---|
| `WEB_SAAS_POSTGRES_ROOT_PASSWORD` | **自动管理, 不用手填** | Postgres 是全新初始化实例。首次部署时 job 用 `openssl rand` 现场生成, 成功后用 `vault kv patch` 写回这里；后续重跑同一环境会先读回这个 key 复用, 避免和已 `initdb` 的容器密码对不上。 |
| `WEB_SAAS_ACCOUNT_DB_PASSWORD` | **自动管理, 不用手填** | 同上, 对应 `account` 库的 `account_user` 账号密码。`billing-service` 复用同一个 `account_user`/`account` 库, 不需要单独的 `WEB_SAAS_BILLING_DATABASE_URL`。 |
| ~~`WEB_SAAS_BILLING_DATABASE_URL`~~ | **已作废** | billing-service 改为复用 `account_user`，连接串在 job 里用 `WEB_SAAS_ACCOUNT_DB_PASSWORD` 拼出来，不再需要单独一个完整 URL。 |
| ~~`WEB_SAAS_INTERNAL_SERVICE_TOKEN`~~ | **已作废，改用现成 key** | 直接复用 `kv/data/CICD` 下已经存在、`ai-workspace-services/portal` 自己流水线在用的 `INTERNAL_SERVICE_TOKEN`。 |
| ~~`WEB_SAAS_GHCR_USERNAME`~~ | **已作废** | console.svc.plus 拉镜像用 `${{ github.actor }}` 当用户名，不需要单独存。 |
| ~~`WEB_SAAS_GHCR_PASSWORD`~~ | **已作废，改用现成 key** | 直接复用 `kv/data/CICD` 下已存在的 `GHCR_TOKEN`。 |

**唯一需要人工确认的前置条件**：Vault 里 `github-actions-site-migration-toolkit`
这个角色的 policy，要对 `kv/data/CICD` 和 `kv/metadata/CICD` 有 `patch`(或
`create`+`update`) 权限，`vault kv patch` 写回两个自动生成的密码这一步才能成功。
如果目前是只读权限，这一步会 403（不影响当次已经跑完的部署，但下次重跑会重新生成
一份新密码，导致 accounts/billing 连不上已经初始化过的库）。
