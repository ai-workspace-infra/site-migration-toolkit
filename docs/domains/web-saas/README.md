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
