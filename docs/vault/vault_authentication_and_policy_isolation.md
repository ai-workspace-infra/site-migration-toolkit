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

路径分两类：**公共服务 secret** 三个环境共读、不按环境拆分；**环境专属 secret** 严格隔离。

| 目标环境 (Env) | Vault Policy 名称 | 可读写的基础核心密钥范围 (KV Path) |
| --- | --- | --- |
| **`sit`** | `github-actions-platform-ops-toolkit-sit` | 读写：`kv/data/sit/*`<br>只读（公共）：`kv/data/CICD`, `kv/data/openclaw`, `kv/data/action-runner` |
| **`uat`** | `github-actions-platform-ops-toolkit-uat` | 读写：`kv/data/uat/*`<br>只读（公共）：`kv/data/CICD`, `kv/data/openclaw`, `kv/data/action-runner`<br>只读（业务）：`kv/data/WEB_SAAS` |
| **`prod`** | `github-actions-platform-ops-toolkit-prod` | 读写：`kv/data/prod/*`（**无 `delete`**）<br>只读（公共）：`kv/data/CICD`, `kv/data/openclaw`, `kv/data/action-runner`<br>只读（业务）：`kv/data/WEB_SAAS` |

### 2.1 为什么 `kv/data/CICD` 是共享的，不按环境拆分

该路径存放的是**公共服务凭据**：GHCR 镜像拉取凭据、云账号 API key、TF state 后端凭据、SSH 部署密钥。这些是全平台共用的公共能力——拉的是同一批镜像、访问的是同一个云账号、写的是同一个 state 后端——**本身不存在「环境」这个维度**。拆成 sit/uat/prod 三份只会产生三份需要同步轮换的副本，不产生隔离收益。

关于共享路径的爆炸半径，需要说清楚一件事：**共享路径的风险上限由「最松的那个 role」决定**。

原先 sit role 只绑 `repository`、没有任何 ref / workflow 约束，任何人推个分支、加个自己的 workflow 就能换到 sit token 并读走 `kv/data/CICD` 里的全部云凭据和全主机 SSH 私钥——**那个状态下共享确实是危险的**。

本次把三个 role 全部钉死到 `job_workflow_ref` 白名单加各自的 `ref` 之后，能换到 token 的路径已收敛到本仓库这 5 个 workflow 文件，仓库里新加一个 workflow 换不到任何 role。**真正堵住提权的是绑定收紧，而不是拆路径**——所以共享 `kv/data/CICD` 在当前绑定下是可接受的。

> ⚠️ **未决问题（性质不同）**：`kv/data/WEB_SAAS` 由 uat 与 prod 共读，内含 `POSTGRES_ROOT_PASSWORD`、`ACCOUNT_DB_PASSWORD`——即两个环境共用同一套数据库口令。**数据库口令是环境专属的业务密钥，不是公共服务凭据**，与 `kv/data/CICD` 不是一回事，后续应拆分为 `kv/data/<env>/web-saas`。

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
