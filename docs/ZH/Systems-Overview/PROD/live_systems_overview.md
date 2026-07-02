# 线上环境全业务系统拓扑梳理 (Caddy)

通过直连 `root@install.svc.plus` 并对其 `/etc/caddy/conf.d/*.caddy` 实际线上配置进行逆向解析，结合我们最新的架构规划，当前线上环境的业务系统划分为以下三大核心业务域（Domain）。所有强状态服务均已严格落实 Localhost (127.0.0.1) 端口绑定策略以及独立账户隔离的专用 PostgreSQL 存储库。

## 1. AI Workspace 域 (AI-Workspace)
专注于核心人工智能与工作流代理服务。

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| API Gateway | `apigateway.svc.plus` | `127.0.0.1:9080` | 通用 API 网关 |
| LiteLLM (API) | `api.svc.plus` | `127.0.0.1:4000` | 模型统一路由与 OpenAI/Anthropic 路径兼容转换层 |
| LiteLLM (UI) | `litellm.svc.plus` | `127.0.0.1:4000` | LiteLLM Admin UI / Dashboard |
| OpenClaw (Bot) | `openclaw.svc.plus` | `127.0.0.1:18789` | OpenClaw 聊天机器人后台服务 (无状态，API 对接 QMD) |
| RAG / QMD | `rag-server.svc.plus`<br>`rag-server-contabo-*.svc.plus` | `127.0.0.1:18084` | 检索增强引擎后端 (支持 pgvector) |
| XWorkmate Bridge | `xworkmate-bridge.svc.plus` | `127.0.0.1:8787` | 带有 Bearer Token 强鉴权的工作流桥接器 |
| Hermes | `hermes.svc.plus` | `127.0.0.1:18180` | 消息通知网关 (Notification) |

### 1.1 内部 Agent 技能与插件 (Internal Agent Skills)
位于线上节点 `/opt/agent.svc.plus/skills` 目录下，由 AI Workspace 统一管理并提供给智能体工作流 (Agent Workflows) 调用的内置技能库：

| 技能/插件名称 | 物理路径 | 核心功能与用途描述 |
| :--- | :--- | :--- |
| **Git Conventional Commits** | `git.conventional-commits.v1.md` | 规范化 Git 提交信息的审查与自动化生成技能 |
| **Git Commit Check** | `git.commit-check.v1.md` | 提交前置代码质量检查与合规性扫描技能 |
| **Secret Incident Response** | `git.secret-incident-response.v1.md` | 针对代码库凭证泄露等高危安全事件的自动化应急响应与封堵策略 |
| **Release Branch Policy** | `release-branch-policy/` | 复合型应用发布管线技能，包含分支保护规则应用 (`apply_ruleset.sh`)、发布清单自动生成及多仓库同步脚本 |

## 2. Web SaaS 域 (Web SaaS)
包含对外提供服务的用户前端、账户流水以及加速网络。

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| Console | `console.svc.plus` | `127.0.0.1:3000` | AI Workspace 主控台面板 (对接 Accounts, billing, xworkmate-bridge 后端) |
| Accounts | `accounts.svc.plus` | `127.0.0.1:18081` | 统一账户服务 |
| Billing | `billing.svc.plus` | *(内网集群路由)* | 计费流水服务 (与前端串联) |
| Install Scripts | `install.svc.plus` | `302 Redir -> Github` | 供 curl 拉取执行的一键安装脚本短链接分发 |
| Ebook | `ebook.svc.plus` | 静态文件 | Modern IT History 电子书 (`/opt/modern-it-history/current`) |
| Docs | `docs.svc.plus`<br>`docs-contabo-*.svc.plus` | `127.0.0.1:18083` | 系统帮助文档 |
| JP XHTTP / Xray | `jp-xhttp.svc.plus` | `/dev/shm/xray.sock` | 跨境网络代理隧道与加速资源池 |
| ~~Accounts (Preview)~~| ~~`accounts-preview...`~~ | ~~`127.0.0.1:28081`~~ | ⚠️ **[计划下线]** 测试环境服务不再拉起 |

## 3. 基础设施平台域 (Open Platform Infra)
支撑上层业务运行的通用基础设施、身份认证与可观测性集群。

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| Vault | `vault.svc.plus` | `127.0.0.1:8200` | 统一凭证与密钥持久化服务 (无 dev 模式，严控 Root) |
| Zitadel (IAM) | `iam.svc.plus` | `127.0.0.1:19080/19081` | IAM 全局单点登录 SSO (API 与 UI) |
| Gitea | `gitea.svc.plus` | `localhost:3001` | 私有 Git 代码托管平台 |
| PostgreSQL Tunnel | `postgresql-contabo...` | 静态 200 响应 | 特定代理入口与 TLS 网络探针 (数据库本身禁止公网直连) |
| ~~Code Server~~ | ~~`observability.../code/`~~ | ~~`127.0.0.1:8443`~~ | ⚠️ **[计划下线]** 网页版 VSCode 开发环境 |
| ~~Jupyter Lab~~ | ~~`observability.../jupyter/`~~| ~~`127.0.0.1:8888`~~ | ⚠️ **[计划下线]** 数据科学 Jupyter 环境 |

### 3.1 可观测性与日志监控 (Observability Stack)
`observability.svc.plus` 为所有监控组件的全局入口，按 Path 转发到不同组件：

| 路径规则 (Path) | 内网代理目标 (Upstream) | 对应组件 / 用途 |
| :--- | :--- | :--- |
| `/grafana/*` | `127.0.0.1:3000` | Grafana 可视化仪表盘 (也是根目录默认重定向) |
| `/ingest/metrics/*`<br>`/vmetrics/*` | `127.0.0.1:8428` | VictoriaMetrics (Prometheus 指标写入与查询) |
| `/ingest/logs/*`<br>`/vlogs/*` | `127.0.0.1:9428` | VictoriaLogs / Loki (日志写入与查询) |
| `/ingest/otlp/*`<br>`/vtraces/*` | `127.0.0.1:4318 / 10428` | OpenTelemetry 分布式链路追踪 |
| `/vmalert/*` | `127.0.0.1:8880` | VictoriaMetrics Alert 告警引擎 |
| `/alertmgr/*` | `127.0.0.1:9059` | Alertmanager 告警路由与发送 |
| `/blackbox/*` | `127.0.0.1:9115` | Blackbox Exporter 网络拨测 |
| ~~`/haproxy/pg-meta-1/*`~~ | ~~`10.146.0.6:9101`~~ | ⚠️ **[计划下线]** HAProxy 管理控制台转发 |
| ~~`/insight/*`~~ | ~~`127.0.0.1:8082`~~ | ⚠️ **[计划下线]** Insight Workbench 数据分析台 |

## 4. 已清理下线的基础设施
以下系统配置已从线上节点 `/etc/caddy/conf.d/` 彻底移除：
* `x-cloud-flow.svc.plus` (云上流控或编排引擎)
* `x-ops-agent.svc.plus` (自动化运维 Agent)
* `x-scope-hub.svc.plus` (资源范围枢纽)
