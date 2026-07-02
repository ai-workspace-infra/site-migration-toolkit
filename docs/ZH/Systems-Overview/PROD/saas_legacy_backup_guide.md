# Web SaaS Legacy 旧环境链路资源与备份指南

本文档旨在梳理当前运行在 `console.svc.plus` 节点上的旧版 Web SaaS 业务部署链路，并明确在紧急迁移、节点重建或灾备情况下的备份目标、镜像资产清单以及 Vault 密文流转策略。

---

## 一、 部署链路与核心资产清单

该节点的 Web SaaS 业务通过一组紧密耦合的 Docker 容器和 Caddy 网关对外提供服务，所有核心配置文件目前已在宿主机侧被施加 Immutable (防篡改) 锁定 (`chattr +i`)。

在进行系统级备份或迁移时，必须包含以下物理目录：

### 1. 流量网关层 (Caddy)
该层负责承接 `console.svc.plus`, `accounts.svc.plus` 等核心域名的 SSL 卸载与反向代理。
- **备份路径**: `/etc/caddy/conf.d/`
- **重点文件**: `console-80c545a-jp-xhttp-contabo.svc.plus-console-svc-plus.caddy`, `accounts.svc.plus.caddy`

### 2. 容器编排基建与状态 (Docker Compose)
各微服务的配置文件与 `.env` 声明：
- **Console 前端**: `/opt/cloud-neutral/console/console-c894924-contabo`
- **Accounts 服务**: `/opt/cloud-neutral/accounts/managed/prod`
- **PostgreSQL 数据库集群**: `/opt/cloud-neutral/postgresql.svc.plus/deploy/docker`
- **Stunnel 安全隧道**: `/opt/cloud-neutral/stunnel-server`

### 3. 静态镜像资产 (离线备份)
为防止依赖的特定 Tag 镜像从远端仓库丢失，建议通过 `docker save` 导出以下基座镜像：
- Console: `ghcr.io/x-evor/console:081bedd637f0b1983f73bb5d00bf58a11c507e21`
- Accounts: `ghcr.io/x-evor/accounts:sha-7292fca3b8a0bcf18802a90070190a6515225a17`
- Database: `postgres-extensions:17`
- Tunnel: `ghcr.io/x-evor/stunnel-server:2330d36`

### 4. 业务数据快照 (PostgreSQL)
建议采用逻辑备份获取最新的数据库状态：
- **执行方式**: 经由容器执行 `pg_dumpall -U svcplus_vps > db_dump.sql`。
- 宿主机物理挂载点（可选备份）：`PG_DATA_PATH` 对应的目录。

---

## 二、 敏感信息提取与 Vault 纳管策略

旧环境中大量使用了本地 `.env` 明文存储凭证。为了向现代化的云原生基建演进，所有从 `.env` 中提取的高危变量必须入驻至私有的 `vault.svc.plus` 服务中。

在编写迁移脚本或部署新环境时，需严格遵循以下 Vault 键值对映射层级结构：

### 📁 `secret/saas/legacy/database`
存储核心数据库鉴权：
- `POSTGRES_USER`: `svcplus_vps`
- `POSTGRES_PASSWORD`: [核心数据库密码]

### 📁 `secret/saas/legacy/internal_auth`
存储微服务之间的内网通信凭证：
- `INTERNAL_SERVICE_TOKEN`: [服务间校验 Token]
- `BRIDGE_AUTH_TOKEN`: [Bridge 认证令牌]
- `BRIDGE_REVIEW_AUTH_TOKEN`: [Bridge 测试令牌]

### 📁 `secret/saas/legacy/third_party`
存储第三方云厂商及 SaaS 服务的 API Keys：
- `CLOUDFLARE_API_TOKEN`: [CF 解析管理凭证]
- `SMTP_USERNAME`: [发件邮箱] (例如: `manbuzhe2009@qq.com`)
- `SMTP_PASSWORD`: [邮箱授权码]

### 📁 `secret/saas/legacy/infrastructure`
存储节点本身或集群控制平面的基建凭证：
- `VAULT_SERVER_ROOT_ACCESS_TOKEN`: [Vault 超级管理员 Token]

---

> [!TIP]
> **后续操作指引**
> 本指南梳理了需要提取、打包、清理以及 Vault 化的资源骨架。
> 在您的团队执行具体的容灾脚本、实施重构或手动迁移时，请确保完整对照以上四个分类列表，并在提取敏感配置后第一时间清除物理服务器上的 `.env` 等明文配置文件。
