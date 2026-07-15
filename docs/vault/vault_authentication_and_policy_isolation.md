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
| **`sit`** | `github-actions-platform-ops-toolkit-sit` | **`*`** (允许任意分支请求) | 用于普通开发分支 (`feature/*`, `bugfix/*` 等) 发起的 Pull Request 验证及部署测试。 |
| **`uat`** | `github-actions-platform-ops-toolkit-uat` | **`refs/heads/main`** | 仅允许 `main` 分支在代码合并后触发，用于获取 UAT (User Acceptance Testing) 预发布环境部署凭证。 |
| **`prod`** | `github-actions-platform-ops-toolkit-prod` | **`refs/heads/release/*`** 与 **`refs/tags/v*`** | 仅限维护分支或正式发行版标签触发，锁定最高权限以杜绝普通开发分支的误操作与越权读取。 |

> **注**：在 `platform-ops.yaml` 流水线中，环境变量会通过逻辑计算自动映射：  
> `VAULT_ROLE: github-actions-platform-ops-toolkit-${{ env.DEPLOY_ENV }}`

---

## 2. Vault Policy 数据路径隔离

除了 Role 的触发源隔离外，每个 Role 背后所绑定的 Vault Policy 也对其实际能够读写的 KV 数据范围做了强隔离。

所有环境均共享 `kv/data/CICD/*` 路径下的基础工具凭证（如用于 provision 服务器的全局 SSH 私钥或 Vultr API Key），但在业务及环境特有密钥上实行隔离访问。

| 目标环境 (Env) | Vault Policy 名称 | 可读写的基础核心密钥范围 (KV Path) |
| --- | --- | --- |
| **`sit`** | `github-actions-platform-ops-toolkit-sit` | 读写：`kv/data/sit/*`<br>只读：`kv/data/CICD/*`, `kv/data/openclaw/*` |
| **`uat`** | `github-actions-platform-ops-toolkit-uat` | 读写：`kv/data/uat/*`<br>只读：`kv/data/CICD/*`, `kv/data/openclaw/*`, `kv/data/WEB_SAAS/*` |
| **`prod`** | `github-actions-platform-ops-toolkit-prod` | 读写：`kv/data/prod/*`<br>只读：`kv/data/CICD/*`, `kv/data/openclaw/*`, `kv/data/WEB_SAAS/*` |

> ⚠️ **安全警告**：
> 1. `sit` Role 绑定的 Policy 绝对不能包含 `kv/data/uat/*` 或 `kv/data/prod/*` 的读写权限。
> 2. `prod` 环境的 Policy 通常会**剥夺 `delete` (删除) 权限**，只允许新建或更新（`create`, `read`, `update`），以防止生产数据被流水线异常脚本恶意或误操作销毁。

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
