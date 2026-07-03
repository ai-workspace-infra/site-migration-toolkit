# AI Workspace 核心业务域 (Domain: ai-workspace)

本域覆盖 AI 代理及模型调度的核心工作链路，负责大模型的路由转发、网关及持久化工作流数据的迁移与容灾。

## 1. 资产与组件清单

本域包含以下核心应用及端口监听情况：
- **XWorkmate Bridge**: `xworkmate-bridge.svc.plus` (127.0.0.1:8787)
- **LiteLLM (API)**: `api.svc.plus` (127.0.0.1:4000)
- **LiteLLM (UI)**: `litellm.svc.plus` (127.0.0.1:4000)
- **OpenClaw (Bot)**: `openclaw.svc.plus` (127.0.0.1:18789)
- **Hermes**: `hermes.svc.plus` (127.0.0.1:18180)
- **QMD**
- **PostgreSQL**: `postgresql-ai-workspace.onwalk.net` - AI 核心业务域强状态数据库（与主服务共用主机资源）

### 相关数据库资产
运行在 AI 核心服务库 Docker (`postgresql-svc-plus`, `127.0.0.1:15432`) 下的业务系统库：
- `account`
- `vault_storage`
- `artifact`
- `litellm`
- `openclaw`
- `qmd`
- `rag`
- `notification`
- `scheduler`
- `audit`

### 关键文件与持久化挂载卷 (Stateful Volumes)
- **OpenClaw (AI 网关) 工作目录**: `openclaw workdir` (包含 AI Gateway 本地缓存档、向量化临时数据和模型资产)

## 2. 备份与同步策略

### 数据库备份示例 (PostgreSQL)
建议通过 `pg_dump` 对上述涉及到的独立库进行单独导出：
```bash
DB_URL_BASE="postgres://svcplus_vps:<YOUR_PASSWORD>@127.0.0.1:15432"
for DB in account litellm openclaw qmd rag notification scheduler audit artifact vault_storage; do
    pg_dump "$DB_URL_BASE/$DB?sslmode=disable" | gzip > "/var/backups/postgresql/${DB}_backup.sql.gz"
done
```

### 文件状态同步
通过增量同步将 `openclaw workdir` 同步至目标机：
```bash
rsync -avz --delete /path/to/openclaw/workdir/ backup-server:/path/to/backup/openclaw/
```

## 3. 恢复与上线流程
1. **数据还原**: 首先将备份的 sql.gz 文件分别解压导入对应数据库。
2. **挂载卷还原**: 将 `openclaw workdir` 放入目标机器对应绝对路径并修复权限。
3. **拉起服务**: 通过对应 IaC 或 Ansible 角色执行容器启动 `docker-compose up -d` 拉起 LiteLLM、OpenClaw 及 Hermes 等服务。
