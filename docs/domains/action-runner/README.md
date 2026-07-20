# Action Runner 部署前置条件

本文档说明了在使用 `deploy-action-runner-iac.yaml` 流水线自动起机并注册 Self-hosted Runner（GitHub Actions 或 Gitea act_runner）之前，必须要在 Vault 中完成的前置密钥配置工作。

---

## 1. 为什么需要前置条件？
为了保证流水线的绝对安全，所有的 Runner 注册令牌（Registration Token）均不在 GitHub 仓库的 Secrets 中固化保存。相反，它们由 Vault 统一托管，并在流水线执行时利用 OIDC JWT 动态拉取。

因此，在首次运行部署流水线前，您必须用有写权限的 Token 登录 Vault，提前写入相应环境的 Runner 凭证。

---

## 2. 写入 Vault KV 凭证

流水线默认按照所选择的部署环境（`sit` / `uat` / `prod`）到 Vault 中的 `kv/data/{env}/action-runner` 路径下读取变量。

### 获取 Token：
- **GitHub Runner Token**：前往需要挂载 Runner 的 GitHub 仓库（或组织）-> **Settings** -> **Actions** -> **Runners** -> 点击 **New self-hosted runner**，在页面中间找到那串临时的注册 Token。
- **Gitea Runner Token**：登录 Gitea 管理后台 -> **站点管理 (Site Administration)** -> **Actions** -> **Runners** -> 点击 **Create new Runner** 复制弹窗里的 Token。

### 写入命令：

请在您的终端中执行以下命令（以 UAT 环境为例）：

```bash
# 1. 登录 Vault（替换为您的 Vault 管理员 Token）
export VAULT_ADDR="https://vault.svc.plus"
vault login <YOUR_VAULT_TOKEN>

# 2. 写入 action-runner 机密（如果没有 Gitea 或 GitHub，可以留空或写假字符串，但不要漏掉 key）
vault kv put kv/data/uat/action-runner \
  GITHUB_RUNNER_TOKEN="ghp_xxx_your_github_token_here_xxx" \
  GITEA_RUNNER_TOKEN="xxx_your_gitea_token_here_xxx"
```

如果您还需要为 `sit` 和 `prod` 环境注册专属的机器，请将上述命令中的 `uat` 替换为您对应的环境名称并重复执行。

---

## 3. 部署参数说明

在触发流水线时，需要正确选择对应的 Runner 类型及目标仓库：

1. **runner_engine**: 
   - 选 `github` 将自动读取 `GITHUB_RUNNER_TOKEN` 并安装 GitHub 官方 Action Runner。
   - 选 `gitea` 将自动读取 `GITEA_RUNNER_TOKEN` 并安装 Gitea `act_runner`。
2. **github_org_repo**: 
   - 仅当 `runner_engine=github` 时有效，填写注册 Runner 所在的 GitHub 组织和仓库路径，例如 `ai-workspace-infra` 或 `ai-workspace-infra/platform-ops-toolkit`。
3. **gitea_instance_url**: 
   - 仅当 `runner_engine=gitea` 时有效，指向自建 Gitea 的外网可用地址（必须与您在 Gitea Runner 后台看到的一致，如 `https://gitea.svc.plus`）。

配置好以上前置参数后，即可放心运行 IaC 流水线！
