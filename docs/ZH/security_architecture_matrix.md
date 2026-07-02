# 全站服务架构与安全基线矩阵 (Security & Architecture Matrix)

本文档基于 Vault 生产级安全基线标准，详细梳理并记录了各个域内核心微服务的**请求链路 (从 Caddy 入口端到端)**、**部署模式**及**底层依赖**。特别是针对数据库，严格落实了“同实例、不同库、不同用户”的最小权限隔离策略。

## 1. AI Workspace 域 (AI 核心业务)

### 1.1 LiteLLM (大模型统一路由)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `api.svc.plus`, `litellm.svc.plus` |
| **本地监听端口** | `127.0.0.1:4000` |
| **Playbook 部署模式** | `vhosts` (原生 Systemd 守护进程) |
| **IaC 所需资源** | DNS A 记录 (api, litellm) |
| **存储依赖** | Redis 高频缓存, 本地 `litellm-config.yaml` |
| **独立数据库** | `litellm` |
| **独立用户** | `litellm_user` |
| **鉴权连接串参考** | `postgres://litellm_user:${LITELLM_PG_PASSWORD}@127.0.0.1:15432/litellm?sslmode=disable` |

### 1.2 OpenClaw (Bot 代理后端)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `openclaw.svc.plus` |
| **本地监听端口** | `127.0.0.1:18789` |
| **Playbook 部署模式** | `vhosts` |
| **IaC 所需资源** | DNS A 记录 (openclaw) |
| **存储依赖** | `openclaw workdir` (模型文件与缓存档挂载) |
| **独立数据库** | *N/A* |
| **独立用户** | *N/A* |
| **鉴权连接串参考** | (无独立数据库，通过 API 接入 QMD/RAG 服务) |

### 1.3 RAG / QMD (检索增强引擎)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | 内部 API 调用 |
| **本地监听端口** | 动态分配 |
| **Playbook 部署模式** | `vhosts` / `docker` |
| **IaC 所需资源** | 内部服务网格路由 |
| **存储依赖** | PostgreSQL (启用 pgvector 扩展), 本地文档分片卷 |
| **独立数据库** | `rag` |
| **独立用户** | `rag_user` |
| **鉴权连接串参考** | `postgres://rag_user:${RAG_PG_PASSWORD}@127.0.0.1:15432/rag?sslmode=disable` |

### 1.4 Account (统一账户服务)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `accounts.svc.plus` |
| **本地监听端口** | 内部 RPC 端口 |
| **Playbook 部署模式** | `vhosts` |
| **IaC 所需资源** | DNS A 记录 (accounts) |
| **存储依赖** | 无状态 |
| **独立数据库** | `account` |
| **独立用户** | `account_user` |
| **鉴权连接串参考** | `postgres://account_user:${ACCOUNT_PG_PASSWORD}@127.0.0.1:15432/account?sslmode=disable` |

---

## 2. Open Platform Infra 域 (基础设施平台)

### 2.1 Vault (统一凭证与配置中心)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `vault.svc.plus` |
| **本地监听端口** | `127.0.0.1:8200` |
| **Playbook 部署模式** | `vhosts` (Standalone Systemd) |
| **IaC 所需资源** | DNS A 记录 (vault) |
| **存储依赖** | PostgreSQL 作为唯一强状态依赖 |
| **独立数据库** | `vault_storage` |
| **独立用户** | `vault_storage` |
| **鉴权连接串参考** | `postgres://vault_storage:${VAULT_PG_PASSWORD}@127.0.0.1:15432/vault_storage?sslmode=disable` |

### 2.2 Zitadel (全局 SSO / IAM)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `iam.svc.plus` |
| **本地监听端口** | 容器内网映射 |
| **Playbook 部署模式** | `docker` |
| **IaC 所需资源** | DNS A 记录 (iam) |
| **存储依赖** | MachineKey 主密钥挂载 (用于加解密用户信息) |
| **独立数据库** | `zitadel` |
| **独立用户** | `zitadel_user` |
| **鉴权连接串参考** | `postgres://zitadel_user:${ZITADEL_PG_PASSWORD}@127.0.0.1:15432/zitadel?sslmode=disable` |

### 2.3 Gitea (私有代码托管)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `gitea.svc.plus` |
| **本地监听端口** | `127.0.0.1:3001` |
| **Playbook 部署模式** | `vhosts` |
| **IaC 所需资源** | DNS A 记录 (gitea), 独立大容量云盘 |
| **存储依赖** | `/var/lib/gitea/data` (裸 Git 仓库及 LFS 附件) |
| **独立数据库** | `gitea` |
| **独立用户** | `gitea_user` |
| **鉴权连接串参考** | `postgres://gitea_user:${GITEA_PG_PASSWORD}@127.0.0.1:15432/gitea?sslmode=disable` |

---

## 3. Web SaaS 域

### 3.1 Console (主控台前端)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `console.svc.plus` |
| **本地监听端口** | `127.0.0.1:3000` |
| **Playbook 部署模式** | `vhosts` (基于 Node.js / Next.js) |
| **IaC 所需资源** | DNS A 记录 (console) |
| **存储依赖** | CDN 静态资源, 无服务器级状态 |
| **独立数据库** | *N/A* |
| **独立用户** | *N/A* |
| **鉴权连接串参考** | (无直连底层库，连接后端: `Accounts`, `billing`, `xworkmate-bridge`) |

### 3.2 Billing (计费流水服务)
| 属性 | 详情 |
| :--- | :--- |
| **Caddy 外网入口** | `billing.svc.plus` |
| **本地监听端口** | 内部动态映射端口 |
| **Playbook 部署模式** | `docker` / `vhosts` |
| **IaC 所需资源** | DNS A 记录 (billing) |
| **存储依赖** | 支付 Webhook 接收队列 |
| **独立数据库** | `billing` |
| **独立用户** | `billing_user` |
| **鉴权连接串参考** | `postgres://billing_user:${BILLING_PG_PASSWORD}@127.0.0.1:15432/billing?sslmode=disable` |
