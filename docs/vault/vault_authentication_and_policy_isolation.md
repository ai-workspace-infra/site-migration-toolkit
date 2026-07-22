# Vault Authentication and Policy Isolation

本文档详细记录了 `platform-ops-toolkit` 在基于 GitHub OIDC JWT 登录 Vault 时的多环境（`sit`、`uat`、`prod`）隔离策略。

## 架构原则

平台采用严格的“按环境隔离”鉴权策略。这意味着无论是在 Vault Policy 还是在 GitHub OIDC JWT Role 层面，每一个环境的权限都互不交叉。

流水线在执行过程中，绝不会使用持久化的 GitHub Actions Secrets 存储敏感值。所有运行时的部署凭证均经由 **GitHub OIDC → Vault JWT** 登录后，从对应环境的 Vault KV 路径中动态拉取。

---

## 1. 环境与角色（Role）映射策略

为确保高敏环境（尤其是 `prod` 环境）的安全，Vault 中定义了三个独立的 JWT Role。每个 Role 通过 Vault 的 `bound_claims` 特性，严格锁定了只有当触发 GitHub Actions 的 Git `ref`（分支或标签）符合特定正则或通配符要求时，才允许换取环境凭证。

| 目标环境 (Env) | Vault JWT Role 名称 | 允许请求的 Git 分支 / Tag (`bound_claims` / `ref`) | 用途说明 |
| --- | --- | --- | --- |
| **`sit`** | `github-actions-platform-ops-toolkit-sit` | **`refs/pull/*/merge`**、**`refs/heads/*`** | Pull Request 验证，以及从分支发起的 `workflow_dispatch`。ref 仍然较宽，真正的收敛来自 `job_workflow_ref` 白名单。 |
| **`uat`** | `github-actions-platform-ops-toolkit-uat` | **`refs/heads/main`**、**`refs/heads/release/*`** | `main` 与 `release/*` 的 push 都路由到 uat，两者都必须放行。 |
| **`prod`** | `github-actions-platform-ops-toolkit-prod` | **`refs/tags/v*`** | **仅限 `v*` annotated tag**。`release/*` 是任何 writer 都能创建的分支，不能作为 prod 的凭据边界。 |

> **注**：在 `platform-ops.yaml` 流水线中，环境变量会通过逻辑计算自动映射：  
> `VAULT_ROLE: github-actions-platform-ops-toolkit-${{ env.DEPLOY_ENV }}`

### 1.1 三项通用硬化（2026-07-22）

所有 role 统一采用：

| 配置 | 值 | 原因 |
| --- | --- | --- |
| `user_claim` | `sub` | 身份绑定到工作负载（repo+ref+workflow），而非触发者的 GitHub 用户名（`actor`）。 |
| `job_workflow_ref` | 本仓库 5 个 workflow 文件的白名单（`@*` 收尾放行任意 ref） | **仓库里新增一个 workflow 换不到任何 role**。这是 ref 之外最关键的一道约束。 |
| `token_no_default_policy` | `true` | 不附加 `default` policy，最小权限。 |
| `token_type` / `token_ttl` | `batch` / `20m` | 一次部署用不了 1 小时；batch token 不可续期。 |

> ⚠️ **行为变更**：`prod` 现在只能由 `v*` tag 触发。`workflow_dispatch` 选 `prod` 会认证失败——这是刻意的，与分支规范「生产部署只经 annotated tag」一致。
>
> 已删除的死角色：`github-actions-platform-ops-toolkit-prod-tags` 从未被任何 workflow 请求过，职责已并入 `-prod`。

---

## 2. Vault Policy 数据路径隔离

除了 Role 的触发源隔离外，每个 Role 背后所绑定的 Vault Policy 也对其实际能够读写的 KV 数据范围做了强隔离。

| 目标环境 (Env) | Vault Policy 名称 | 可读写的基础核心密钥范围 (KV Path) |
| --- | --- | --- |
| **`sit`** | `github-actions-platform-ops-toolkit-sit` | 读写：`kv/data/sit/*`<br>只读：`kv/data/CICD/sit`, `kv/data/openclaw`, `kv/data/action-runner`<br><sub>PHASE 1 迁移期额外只读：`kv/data/CICD`</sub> |
| **`uat`** | `github-actions-platform-ops-toolkit-uat` | 读写：`kv/data/uat/*`<br>只读：`kv/data/CICD/uat`, `kv/data/openclaw`, `kv/data/action-runner`, `kv/data/WEB_SAAS`<br><sub>PHASE 1 迁移期额外只读：`kv/data/CICD`</sub> |
| **`prod`** | `github-actions-platform-ops-toolkit-prod` | 读写：`kv/data/prod/*`（**无 `delete`**）<br>只读：`kv/data/CICD/prod`, `kv/data/openclaw`, `kv/data/action-runner`, `kv/data/WEB_SAAS`<br><sub>PHASE 1 迁移期额外只读：`kv/data/CICD`</sub> |

### 2.1 共享基础路径才是真实的爆炸半径

原设计里三个环境**共享** `kv/data/CICD`，而该路径存放 `VULTR_API_KEY`、`TF_STATE_*`、`SSH_PRIVATE_DEPLOY_KEY_B64`、`GHCR_TOKEN`。这意味着**最松的那个 role 决定了整个系统的真实权限**：sit 可由任意分支换取，于是任何能推分支的人都能拿到全部云凭据与全主机 SSH 私钥——按环境隔离在这条路径上并不成立。

因此基础凭据改为**按环境拆分**为 `kv/data/CICD/<env>`，各 role 只读自己那份。迁移分两阶段：

- **PHASE 1（当前）**：同时授予 `kv/data/CICD/<env>` 与旧的共享 `kv/data/CICD`，保证流水线不中断。
- **PHASE 2**：删除 `vault_auth_split.sh` 中标记 `LEGACY` 的两段并重跑，收回共享路径读权限。

> ⚠️ **拆路径不能替代换密钥**：PHASE 2 的真正前提是先为每个环境准备**各自独立的凭据**（独立 Vultr API key、独立 TF state 密钥、独立 SSH 部署密钥对）。若三个环境仍共用同一把 SSH 私钥，无论 Vault 路径怎么拆，sit 失陷仍等于 prod 失陷。拆路径只是把凭据复用问题暴露出来。

> ⚠️ **同类未决问题**：`kv/data/WEB_SAAS` 目前由 uat 与 prod 共读，内含 `POSTGRES_ROOT_PASSWORD`、`ACCOUNT_DB_PASSWORD` 等——即 uat 与 prod 共用同一套数据库口令，属于与 CICD 相同的跨环境凭据复用，后续应同样按环境拆分。

> ⚠️ **其他安全约束**：
> 1. `sit` Role 绑定的 Policy 绝对不能包含 `kv/data/uat/*` 或 `kv/data/prod/*` 的读写权限。
> 2. `prod` 环境的 Policy **已剥夺 `delete` 权限**，只允许 `create`/`read`/`update`。注意 `kv/metadata/*` 的 `delete` 会**永久销毁一个 secret 的所有版本**，因此 prod 的 metadata 也只给 `list`/`read`。

---

## 3. 自动化初始化与部署实践

所有环境对应的 Role 和 Policy 都不需要手动通过 Vault UI 点击配置。我们提供了一个自动化、幂等的初始化 Bash 脚本。

当您第一次部署 `platform-ops-toolkit` 或需要全量覆盖刷新策略时，只需使用 Vault Admin Token 运行以下初始化脚本：

```bash
# 位于 platform-ops-toolkit 项目根目录中
chmod +x docs/tasks/vault_auth_split.sh
./docs/tasks/vault_auth_split.sh
```

该脚本执行完毕后，上述的三套隔离的 Policy、Role 以及绑定规则将立即在 Vault 侧生效，支撑流水线后续安全运转。
