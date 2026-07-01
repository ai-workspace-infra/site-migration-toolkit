# 线上环境全业务系统拓扑梳理 (Caddy) | Live Systems Overview (Caddy)

*🇨🇳 中文版在下方 | Chinese version below*

---

# English Version

By reverse-engineering the configurations under `/etc/caddy/conf.d/` on the `install.svc.plus` node, I have outlined all business systems currently running in the production environment, their corresponding domains, and internal port mappings.

## 1. Core AI Infrastructure

| Business System | Exposed Domain | Internal Upstream | Description |
| :--- | :--- | :--- | :--- |
| API Gateway | `apigateway.svc.plus` | `127.0.0.1:9080` | Universal API Gateway |
| LiteLLM (API) | `api.svc.plus` | `127.0.0.1:4000` | Unified model routing & OpenAI/Anthropic path translation layer |
| LiteLLM (UI) | `litellm.svc.plus` | `127.0.0.1:4000` | LiteLLM Admin UI / Dashboard |
| OpenClaw (Bot) | `openclaw.svc.plus` | `127.0.0.1:18789` | OpenClaw chatbot backend service |
| RAG Server | `rag-server.svc.plus`<br>`rag-server-contabo-*.svc.plus` | `127.0.0.1:18084` | RAG (Retrieval-Augmented Generation) backend |
| XWorkmate Bridge | `xworkmate-bridge.svc.plus` | `127.0.0.1:8787` | Workflow bridge with Bearer Token strict authentication |

## 2. DevOps & Tools

| Business System | Exposed Domain | Internal Upstream | Description |
| :--- | :--- | :--- | :--- |
| Gitea | `gitea.svc.plus` | `localhost:3001` | Private Git code hosting platform |
| Vault | `vault.svc.plus` | `127.0.0.1:8200` | Unified credential and secret persistence service |
| ~~Code Server~~ | ~~`observability.svc.plus/code/`~~ | ~~`127.0.0.1:8443`~~ | ⚠️ **[To Be Deprecated]** Web-based VSCode development environment |
| ~~Jupyter Lab~~ | ~~`observability.svc.plus/jupyter/`~~ | ~~`127.0.0.1:8888`~~ | ⚠️ **[To Be Deprecated]** Data science Jupyter environment |

## 3. IAM & Accounts

| Business System | Exposed Domain | Internal Upstream | Description |
| :--- | :--- | :--- | :--- |
| Zitadel | `zitadel.svc.plus` | `127.0.0.1:19080/19081` | IAM Global SSO (API & UI) |
| Accounts | `accounts.svc.plus`<br>`accounts-contabo-*.svc.plus` | `127.0.0.1:18081` | Production account management service |
| ~~Accounts (Preview)~~ | ~~`accounts-preview.svc.plus`~~ | ~~`127.0.0.1:28081`~~ | ⚠️ **[To Be Deprecated]** Preview/Test account service (Will not be brought up on DR node) |

## 4. Frontends

| Business System | Exposed Domain | Internal Upstream | Description |
| :--- | :--- | :--- | :--- |
| Console | `console.svc.plus` | `127.0.0.1:3000` | AI Workspace main console dashboard |
| Docs | `docs.svc.plus`<br>`docs-contabo-*.svc.plus` | `127.0.0.1:18083` | System documentation (Reuses x-cloud-flow port) |
| Install Scripts | `install.svc.plus` | `302 Redir -> Github` | Short link distribution for curl-based one-click install scripts |
| Ebook | `ebook.svc.plus` | Static Files | Modern IT History ebook (`/opt/modern-it-history/current`) |

## 5. Observability Stack

`observability.svc.plus` acts as the global ingress for all monitoring components, routing by path:

| Path Rule | Internal Upstream | Component / Purpose |
| :--- | :--- | :--- |
| `/grafana/*` | `127.0.0.1:3000` | Grafana visual dashboards (Also default root redirect) |
| `/ingest/metrics/*`<br>`/vmetrics/*` | `127.0.0.1:8428` | VictoriaMetrics (Prometheus metrics write & query) |
| `/ingest/logs/*`<br>`/vlogs/*` | `127.0.0.1:9428` | VictoriaLogs / Loki (Log write & query) |
| `/ingest/otlp/*`<br>`/vtraces/*` | `127.0.0.1:4318 / 10428` | OpenTelemetry distributed tracing |
| ~~`/insight/*`~~ | ~~`127.0.0.1:8082`~~ | ⚠️ **[To Be Deprecated]** Insight Workbench data analysis console |
| `/vmalert/*` | `127.0.0.1:8880` | VictoriaMetrics Alert engine |
| `/alertmgr/*` | `127.0.0.1:9059` | Alertmanager alert routing & dispatch |
| `/blackbox/*` | `127.0.0.1:9115` | Blackbox Exporter network probing |

## 6. Other Underlying/Network Components

| Business System | Exposed Domain | Internal Upstream | Description |
| :--- | :--- | :--- | :--- |
| ~~X-Cloud-Flow~~ | ~~`x-cloud-flow.svc.plus`~~ | ~~`127.0.0.1:18083/18087`~~ | ⚠️ **[To Be Deprecated]** Cloud traffic control or orchestration engine |
| ~~X-Ops-Agent~~ | ~~`x-ops-agent.svc.plus`~~ | ~~`127.0.0.1:18084/18086`~~ | ⚠️ **[To Be Deprecated]** Automated operations Agent |
| ~~X-Scope-Hub~~ | ~~`x-scope-hub.svc.plus`~~ | ~~`127.0.0.1:18085`~~ | ⚠️ **[To Be Deprecated]** Resource scoping hub |
| Hermes | `hermes.svc.plus` | `127.0.0.1:18180` | Message notification gateway |
| JP XHTTP / Xray | `jp-xhttp.svc.plus` | `/dev/shm/xray.sock` | Cross-border network proxy tunnel (gRPC) |
| PostgreSQL Tunnel | `postgresql-contabo...` | Static 200 Response | Network probe or specific proxy ingress for TLS handshakes |

---

# 中文版 (Chinese Version)

通过对 `install.svc.plus` 节点 `/etc/caddy/conf.d/` 下的配置进行逆向解析，我为你梳理出了线上环境中运行的所有业务系统、对应域名及内网端口映射。

## 1. 核心 AI 基础设施 (AI Infrastructure)

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| API Gateway | `apigateway.svc.plus` | `127.0.0.1:9080` | 通用 API 网关 |
| LiteLLM (API) | `api.svc.plus` | `127.0.0.1:4000` | 模型统一路由与 OpenAI/Anthropic 路径兼容转换层 |
| LiteLLM (UI) | `litellm.svc.plus` | `127.0.0.1:4000` | LiteLLM Admin UI / Dashboard |
| OpenClaw (Bot) | `openclaw.svc.plus` | `127.0.0.1:18789` | OpenClaw 聊天机器人后台服务 |
| RAG Server | `rag-server.svc.plus`<br>`rag-server-contabo-*.svc.plus` | `127.0.0.1:18084` | RAG (检索增强生成) 服务后端 |
| XWorkmate Bridge | `xworkmate-bridge.svc.plus` | `127.0.0.1:8787` | 带有 Bearer Token 强鉴权的工作流桥接器 |

## 2. 开发者与协同工具 (DevOps & Tools)

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| Gitea | `gitea.svc.plus` | `localhost:3001` | 私有 Git 代码托管平台 |
| Vault | `vault.svc.plus` | `127.0.0.1:8200` | 统一凭证与密钥持久化服务 |
| ~~Code Server~~ | ~~`observability.svc.plus/code/`~~ | ~~`127.0.0.1:8443`~~ | ⚠️ **[计划下线]** 网页版 VSCode 开发环境 |
| ~~Jupyter Lab~~ | ~~`observability.svc.plus/jupyter/`~~ | ~~`127.0.0.1:8888`~~ | ⚠️ **[计划下线]** 数据科学 Jupyter 环境 |

## 3. 身份认证与账号体系 (IAM & Accounts)

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| Zitadel | `zitadel.svc.plus` | `127.0.0.1:19080/19081` | IAM 全局单点登录 (API 与 UI) |
| Accounts | `accounts.svc.plus`<br>`accounts-contabo-*.svc.plus` | `127.0.0.1:18081` | 生产环境账户管理服务 |
| ~~Accounts (Preview)~~ | ~~`accounts-preview.svc.plus`~~ | ~~`127.0.0.1:28081`~~ | ⚠️ **[计划下线]** 预览 / 测试环境账户服务 (灾备节点不再拉起) |

## 4. 控制台与前端应用 (Frontends)

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| Console | `console.svc.plus` | `127.0.0.1:3000` | AI Workspace 主控台面板 |
| Docs | `docs.svc.plus`<br>`docs-contabo-*.svc.plus` | `127.0.0.1:18083` | 系统帮助文档 (复用 x-cloud-flow 端口) |
| Install Scripts | `install.svc.plus` | `302 Redir -> Github` | 供 curl 拉取执行的一键安装脚本短链接分发 |
| Ebook | `ebook.svc.plus` | 静态文件 | Modern IT History 电子书 (`/opt/modern-it-history/current`) |

## 5. 可观测性与日志监控 (Observability Stack)

`observability.svc.plus` 为所有监控组件的全局入口，按 Path 转发到不同组件：

| 路径规则 (Path) | 内网代理目标 (Upstream) | 对应组件 / 用途 |
| :--- | :--- | :--- |
| `/grafana/*` | `127.0.0.1:3000` | Grafana 可视化仪表盘 (也是根目录默认重定向) |
| `/ingest/metrics/*`<br>`/vmetrics/*` | `127.0.0.1:8428` | VictoriaMetrics (Prometheus 指标写入与查询) |
| `/ingest/logs/*`<br>`/vlogs/*` | `127.0.0.1:9428` | VictoriaLogs / Loki (日志写入与查询) |
| `/ingest/otlp/*`<br>`/vtraces/*` | `127.0.0.1:4318 / 10428` | OpenTelemetry 分布式链路追踪 |
| ~~`/insight/*`~~ | ~~`127.0.0.1:8082`~~ | ⚠️ **[计划下线]** Insight Workbench 数据分析台 |
| `/vmalert/*` | `127.0.0.1:8880` | VictoriaMetrics Alert 告警引擎 |
| `/alertmgr/*` | `127.0.0.1:9059` | Alertmanager 告警路由与发送 |
| `/blackbox/*` | `127.0.0.1:9115` | Blackbox Exporter 网络拨测 |

## 6. 其他底层/网络组件

| 业务系统 | 对外暴露域名 (Domain) | 内网代理目标 (Upstream) | 备注描述 |
| :--- | :--- | :--- | :--- |
| ~~X-Cloud-Flow~~ | ~~`x-cloud-flow.svc.plus`~~ | ~~`127.0.0.1:18083/18087`~~ | ⚠️ **[计划下线]** 云上流控或编排引擎 |
| ~~X-Ops-Agent~~ | ~~`x-ops-agent.svc.plus`~~ | ~~`127.0.0.1:18084/18086`~~ | ⚠️ **[计划下线]** 自动化运维 Agent |
| ~~X-Scope-Hub~~ | ~~`x-scope-hub.svc.plus`~~ | ~~`127.0.0.1:18085`~~ | ⚠️ **[计划下线]** 资源范围枢纽 |
| Hermes | `hermes.svc.plus` | `127.0.0.1:18180` | 消息通知网关 (Notification) |
| JP XHTTP / Xray | `jp-xhttp.svc.plus` | `/dev/shm/xray.sock` | 跨境网络代理隧道 (gRPC) |
| PostgreSQL Tunnel | `postgresql-contabo...` | 静态 200 响应 | 仅作为 TLS 握手的网络探针或特定代理入口 |
