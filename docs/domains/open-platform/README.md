# 开放平台与基础设施域 (Domain: open-platform)

本域包含支撑整个 AI 工作区运转的底层研发组件、安全认证机制与全局可观测性底座。

## 1. 资产与组件清单

### 开放平台核心 (Open Platform)
- **Gitea**: `gitea.svc.plus` (localhost:3001) - 私有 Git 代码托管平台
- **Vault**: `vault.svc.plus` (127.0.0.1:8200) - 统一凭证与配置中心
- **IAM (Zitadel)**: `iam.svc.plus` - IAM Global SSO (API & UI)
- **PostgreSQL**: `postgresql-platform.onwalk.net` - 开放平台核心强状态数据库（与主服务共用主机资源）
- **PostgreSQL Tunnel**: `postgresql-contabo...` - 用于 TLS 握手网络探针或特定代理入口的静态响应端点

### 可观测性底座 (Observability Stack)
统一监控及观测服务集群：`observability.svc.plus`，通过不同 Path 路由至内部组件：
- **`/grafana/*`**: Grafana (127.0.0.1:3000) - 可视化大盘面板 (包含 Root 默认跳转)
- **`/ingest/metrics/*`, `/vmetrics/*`**: VictoriaMetrics (127.0.0.1:8428) - Prometheus 指标接收与查询
- **`/ingest/logs/*`, `/vlogs/*`**: VictoriaLogs / Loki (127.0.0.1:9428) - 日志接收与查询
- **`/ingest/otlp/*`, `/vtraces/*`**: OpenTelemetry (127.0.0.1:4318 / 10428) - 分布式链路追踪
- **`/insight/*`**: Insight Workbench (127.0.0.1:8082) - ⚠️[计划废弃] 数据分析台
- **`/vmalert/*`**: VictoriaMetrics Alerting Engine (127.0.0.1:8880) - 告警引擎
- **`/alertmgr/*`**: Alertmanager (127.0.0.1:9059) - 告警路由分发
- **`/blackbox/*`**: Blackbox Exporter (127.0.0.1:9115) - 网络与域名拨测

## 2. 备份与同步策略

### Gitea 增量同步与数据库备份
Gitea 的迁移是本域的重头戏，避免打爆磁盘。
1. **数据库导出**: Gitea 使用独立的 PostgreSQL 16 (`127.0.0.1:5434`)
```bash
sudo -u postgres pg_dumpall -p 5434 | gzip > /var/backups/postgresql/gitea_backup.sql.gz
```
2. **Git 仓库与 LFS 增量流传输**: 
```bash
rsync -avz --delete /var/lib/gitea/data/ backup-server:/var/lib/gitea/data/
```

### Zitadel (IAM) 备份
Zitadel IAM 数据库（容器内）：
```bash
docker exec zitadel-db-1 pg_dumpall -U postgres | gzip > /var/backups/postgresql/zitadel_backup.sql.gz
```

### Vault 迁移
Vault 由于存储层被 AI 核心域接管或使用了内建 Raft，迁移时需确保 JWT Role 授权及对应的解密密钥（Unseal keys）能在目标服务器完好重现。

### 监控底座同步 (Observability)
针对 VictoriaMetrics (`vmetrics-data`) 和 VictoriaLogs (`vlogs-data`)，数据量极大。通常采用目录层面的 rsync 增量同步，或依赖对象存储长期归档，仅迁移最新热数据。

## 3. 恢复与上线流程

1. **核心依赖先决启动**: 优先还原 Zitadel 数据库，启动 IAM 服务，确保系统有健全的登录通道。
2. **凭证还原**: 根据 Vault 的 Unseal Keys 还原其状态并解封。
3. **大量数据挂载与还原**: 将 Gitea 和监控底座的数据卷复原，通过 `docker-compose` 重启。
