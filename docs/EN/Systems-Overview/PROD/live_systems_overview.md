# Live Environment Business Systems Topology Overview (Caddy)

By directly connecting to `root@install.svc.plus` and reverse-engineering the actual configurations under `/etc/caddy/conf.d/*.caddy`, and consolidating them with our latest domain-driven security architecture, the production environment's business systems have been mapped into three core domains. All services now strictly bind to localhost (`127.0.0.1`) and stateful services connect to isolated PostgreSQL databases using least-privilege dedicated user accounts.

## 1. AI Workspace Domain
Focuses on core AI and workflow agent services.

| Business System | Exposed Domain | Internal Proxy Target (Upstream) | Description |
| :--- | :--- | :--- | :--- |
| API Gateway | `apigateway.svc.plus` | `127.0.0.1:9080` | General API Gateway |
| LiteLLM (API) | `api.svc.plus` | `127.0.0.1:4000` | Unified model routing & OpenAI/Anthropic path compatibility layer |
| LiteLLM (UI) | `litellm.svc.plus` | `127.0.0.1:4000` | LiteLLM Admin UI / Dashboard |
| OpenClaw (Bot) | `openclaw.svc.plus` | `127.0.0.1:18789` | Chatbot Backend Service (Stateless, API connection to QMD) |
| RAG / QMD | `rag-server.svc.plus`<br>`rag-server-contabo-*.svc.plus` | `127.0.0.1:18084` | Retrieval-Augmented Generation Backend (pgvector enabled) |
| XWorkmate Bridge | `xworkmate-bridge.svc.plus` | `127.0.0.1:8787` | Workflow Bridge with Bearer Token strict authentication |
| Hermes | `hermes.svc.plus` | `127.0.0.1:18180` | Message Notification Gateway |

### 1.1 Internal Agent Skills & Plugins
Maintained under the live node directory `/opt/agent.svc.plus/skills`, this is a centralized repository of built-in capabilities designed to be mounted and executed by Agent Workflows in the AI Workspace:

| Skill / Plugin Name | Physical Path | Description & Core Purpose |
| :--- | :--- | :--- |
| **Git Conventional Commits** | `git.conventional-commits.v1.md` | Skill for enforcing and generating standard Git conventional commits |
| **Git Commit Check** | `git.commit-check.v1.md` | Pre-commit code quality and compliance validation checks |
| **Secret Incident Response** | `git.secret-incident-response.v1.md` | Automated incident response and mitigation workflows for leaked credentials |
| **Release Branch Policy** | `release-branch-policy/` | A composite release pipeline skill including branch ruleset enforcement (`apply_ruleset.sh`), release manifest generation, and multi-repo sync scripts |

## 2. Web SaaS Domain
Includes user-facing frontends, account billing flows, and network acceleration pools.

| Business System | Exposed Domain | Internal Proxy Target (Upstream) | Description |
| :--- | :--- | :--- | :--- |
| Console | `console.svc.plus` | `127.0.0.1:3000` | AI Workspace Main Control Panel (Connects to Accounts, billing, xworkmate-bridge) |
| Accounts | `accounts.svc.plus` | `127.0.0.1:18081` | Unified Account Management Service |
| Billing | `billing.svc.plus` | *(Internal Cluster Routing)* | Billing and Payment Gateway |
| Install Scripts | `install.svc.plus` | `302 Redir -> Github` | Short link distribution for curl-based one-click installation scripts |
| Ebook | `ebook.svc.plus` | Static Files | Modern IT History E-book (`/opt/modern-it-history/current`) |
| Docs | `docs.svc.plus`<br>`docs-contabo-*.svc.plus` | `127.0.0.1:18083` | System Help Documentation |
| JP XHTTP / Xray | `jp-xhttp.svc.plus` | `/dev/shm/xray.sock` | Cross-border Network Proxy Tunnel & Acceleration Pool |
| ~~Accounts (Preview)~~| ~~`accounts-preview...`~~ | ~~`127.0.0.1:28081`~~ | ⚠️ **[Planned for Deprecation]** Testing environment |

## 3. Open Platform Infra Domain
Provides the universal foundational infrastructure, IAM, and observability stack.

| Business System | Exposed Domain | Internal Proxy Target (Upstream) | Description |
| :--- | :--- | :--- | :--- |
| Vault | `vault.svc.plus` | `127.0.0.1:8200` | Unified Credentials & Secrets Persistence (Production mode, Root token stripped) |
| Zitadel (IAM) | `iam.svc.plus` | `127.0.0.1:19080/19081` | IAM Global SSO (API & UI) |
| Gitea | `gitea.svc.plus` | `localhost:3001` | Private Git Code Hosting Platform |
| PostgreSQL Tunnel | `postgresql-contabo...` | Static 200 Response | Pure TLS handshake network probe (DB public access is strictly prohibited) |
| ~~Code Server~~ | ~~`observability.../code/`~~ | ~~`127.0.0.1:8443`~~ | ⚠️ **[Planned for Deprecation]** Web-based VSCode Environment |
| ~~Jupyter Lab~~ | ~~`observability.../jupyter/`~~| ~~`127.0.0.1:8888`~~ | ⚠️ **[Planned for Deprecation]** Jupyter Environment |

### 3.1 Observability Stack
`observability.svc.plus` serves as the global entry point for all monitoring components, routing based on Path:

| Path Rule | Internal Proxy Target (Upstream) | Component / Purpose |
| :--- | :--- | :--- |
| `/grafana/*` | `127.0.0.1:3000` | Grafana Visualization Dashboard (Also default root redirect) |
| `/ingest/metrics/*`<br>`/vmetrics/*` | `127.0.0.1:8428` | VictoriaMetrics (Prometheus Metrics Ingestion & Query) |
| `/ingest/logs/*`<br>`/vlogs/*` | `127.0.0.1:9428` | VictoriaLogs / Loki (Logs Ingestion & Query) |
| `/ingest/otlp/*`<br>`/vtraces/*` | `127.0.0.1:4318 / 10428` | OpenTelemetry Distributed Tracing |
| `/vmalert/*` | `127.0.0.1:8880` | VictoriaMetrics Alerting Engine |
| `/alertmgr/*` | `127.0.0.1:9059` | Alertmanager Routing & Dispatch |
| `/blackbox/*` | `127.0.0.1:9115` | Blackbox Exporter Network Probing |
| ~~`/haproxy/pg-meta-1/*`~~ | ~~`10.146.0.6:9101`~~ | ⚠️ **[Planned for Deprecation]** HAProxy Admin UI route |
| ~~`/insight/*`~~ | ~~`127.0.0.1:8082`~~ | ⚠️ **[Planned for Deprecation]** Insight Workbench Data Analysis Desk |

## 4. Cleaned up Infrastructure
The following systems have been completely removed from the live `/etc/caddy/conf.d/` configurations:
* `x-cloud-flow.svc.plus`
* `x-ops-agent.svc.plus`
* `x-scope-hub.svc.plus`
