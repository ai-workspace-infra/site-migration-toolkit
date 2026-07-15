# platform-ops-toolkit

[🇬🇧 English](README.md) | [🇨🇳 中文版](README_zh.md)

欢迎使用 **platform-ops-toolkit**。本代码库提供了面向 AI Workspace 基础架构灾难恢复、跨机房整体迁移以及多环境交付生命周期的自动化解决方案。

> ℹ️ **架构升级提示**：本工具集已经从旧版的“All-in-One”大一统架构，重构为高度模块化和动态化的基础设施即代码（IaC）平台。全新架构围绕 **“多组织 (Multi-Organization) / 多账户 (Multi-Account) / 多云 (Multi-Cloud) / 多环境 (Multi-Environment)”** 的拓扑层级进行了深度整合，并实现了 **Terraform (IaC) + Ansible + HashiCorp Vault** 的无缝安全协同。这允许我们针对不同业务系统和云基础架构进行解耦、按需部署、跨云迁移及独立演进。同时，我们已全面实施统一的多环境交付与发布标准 (Multi-Environment Delivery Standard)。

## 🌐 核心业务域导航 (Business Domains)

本工具集依据线上系统的实际业务链路，拆分为以下4个核心域：

1. **[web-saas](domains/web-saas/README.md)** (SaaS 前端与加速域)
   - 涵盖 Web Console、Accounts、Billing 计费及底层的 Xray 隧道代理入口。
2. **[ai-workspace](domains/ai-workspace/README.md)** (AI 核心链路域)
   - 涵盖 LiteLLM、OpenClaw、QMD 等智能代理与模型路由调度链路。
3. **[agent-proxy](domains/agent-proxy/README.md)** (加速代理与网关域)
   - 涵盖 Caddy、Xray 隧道、Xray Exporters、Vector 观测代理和 agent-svc-plus 控制面同步节点。
4. **[open-platform](domains/open-platform/README.md)** (开放平台与基础设施域)
   - 涵盖 Gitea、Vault、IAM (Zitadel) 以及强大的全局可观测性底座 (Observability Stack - Grafana, VictoriaMetrics 等)。

详细的各个域的迁移、备份、与恢复策略，请查阅各个子域内的 `README.md` 文档。

## 🚀 迁移编排与使用 (Orchestration)

*注：编排层正在从旧版 Python 单体脚本向模块化 Ansible / Make 支持过渡中。*

您可以通过全局的入口命令，指定单个或多个 `DOMAIN` 来执行按需备份或迁移：

```bash
# 示例：仅对 AI 工作区及开放平台底座进行数据备份
make backup DOMAIN=ai-workspace,open-platform

# 示例：一键触发全站各域的迁移与恢复流水线
make migrate DOMAIN=all
```

## 🛠️ CI/CD 与 IaC 流水线

通过流水线触发整体或部分域的部署或迁移时，底层同样会调用相应的业务域策略模块。

### 环境 Profile 发布与映射规则

`platform-ops.yaml` 在被触发时会根据当前的分支或标签自动路由到对应的交付环境。Terraform 先创建或更新主机，再生成 CMDB；后续 Ansible 只能使用该 run 的 CMDB inventory。

| 触发事件 / 来源 | 目标环境 | 资源声明映射 | state key / workspace |
| --- | --- | --- | --- |
| `pull_request` | `sit` | `sit/all-in-one.yaml` | `platform-ops-toolkit/sit/all-in-one.tfstate` |
| `main` / `release/*` push | `uat` | `uat/web-saas-uat.yaml` | `platform-ops-toolkit/uat/web-saas-uat.tfstate` |
| `vMAJOR.MINOR.PATCH` tag | `prod` | `prod/web-saas-prod.yaml` | `platform-ops-toolkit/prod/web-saas-prod.tfstate` |
| `workflow_dispatch` | 用户选择 | `[env]/web-saas-[env].yaml` | 对应环境 |

首次 UAT / Prod 发布前仍须配置对应环境（例如 `console.uat.svc.plus` 或生产域名）的 DNS，并在 Vault 写入对应的 `kv/data/[env]/web-saas` 凭证。工作流会在这些凭证缺失时失败，**环境之间严格隔离，绝不会跨环境读取 Secret**。

### ⚠️ Vault 鉴权配置 (GitHub Actions OIDC → Vault JWT)

流水线不使用任何 GitHub Actions Secrets 存敏感值；所有凭证都在运行时经 **GitHub OIDC → Vault JWT** 登录后，从 Vault KV 按路径（`sit`, `uat`, `prod`）分发。

#### 1. 初始化隔离角色与策略 (一次性操作)

我们废弃了全局大一统的 Vault Policy，改为各个环境按需独立授权。
您只需要使用 Vault 管理员 Token 执行内置的初始化脚本：

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="hvs.xxxxxxxxx"   # 管理员 Token

# 赋予该脚本执行权限并运行
chmod +x docs/tasks/vault_auth_split.sh
./docs/tasks/vault_auth_split.sh
```

该脚本将自动为您创建：
- 三套环境专属策略：`github-actions-platform-ops-toolkit-sit`, `-uat`, `-prod`
- 三套 OIDC JWT 鉴权角色：`github-actions-platform-ops-toolkit-sit`, `-uat`, `-prod`
- 安全约束：例如，`prod` 角色严格限制只能被 `v*` 格式的发行版标签触发获取权限，绝不会被普通分支或 PR 劫持。

#### 2. 填充各域 KV 参数

请按照下表，分别在 `kv/data/sit/*`、`kv/data/uat/*`、`kv/data/prod/*` 等对应环境的路径中准备好密钥：

| Vault 路径示例 | 键 | 用途 |
| --- | --- | --- |
| `kv/data/CICD` | `SSH_PRIVATE_DEPLOY_KEY_B64` | 全局共享：Ansible SSH 部署私钥（单行 base64） |
| `kv/data/CICD` | `VULTR_API_KEY` | 全局共享：Terraform provision VPS 接口密钥 |
| `kv/data/CICD` | `TF_STATE_ENDPOINT`等 | 全局共享：远端 TF state (S3 兼容) |
| `kv/data/CICD` | `CLOUDFLARE_DNS_API_TOKEN` | 全局共享：接管或切换域名的云解析密钥 |
| `kv/data/uat/web-saas` | 6 个键 (见子域文档) | web-saas UAT 域服务部署必需凭证 |
| `kv/data/prod/web-saas` | 6 个键 (见子域文档) | web-saas PROD 域服务部署必需凭证 |

#### 3. Workflow 侧动态鉴权接入（已自动生效，无需改动）

工作流执行时，会自动根据您触发的分支计算并请求相应的环境 Role，进而安全地拉取隔离状态的 Secret：
```yaml
env:
  DEPLOY_ENV: ${{ steps.route.outputs.deploy_env }}
  VAULT_ROLE: github-actions-platform-ops-toolkit-${{ steps.route.outputs.deploy_env }}
```

#### 4. 验收与排障

- 触发流水线后，每个 job 的 `Authenticate to Vault` 或 `Load Vault secrets` 步骤应显示成功获取 Token 的信息且无报错。
- 报错 `403 Forbidden`：说明环境变量自动拼装的 role 绑定的 policy 未覆盖所读路径（例如在 uat 环境试图读取 prod 的密钥库）。
- 报错 `permission denied` 或 Role 不匹配：请核对触发流水线的 Git 事件（如分支名称或 Tag）是否满足 Vault JWT Role 内 `bound_claims` 的安全锁定要求。
