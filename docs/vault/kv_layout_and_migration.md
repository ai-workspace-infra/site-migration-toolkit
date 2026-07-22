# Vault KV 布局梳理与迁移计划

`kv/` 根下的路径是逐次需要临时加出来的，积累到现在缺少统一规则：有的按环境分（`sit/`、`uat/`），
有的按服务分（`gitea.svc.plus`、`postgresql.svc.plus`），有的混装（`CICD` 里同时有公共凭据和基础凭据）。

本文按 [vault_authentication_and_policy_isolation.md §2](./vault_authentication_and_policy_isolation.md)
的**三层模型**把现存路径逐条归位，并列出迁移顺序。

三层的判据只有一条：**这个 secret 有没有「环境」这个维度**。

| 层 | 判据 | 路径形态 | 权限 |
|---|---|---|---|
| ① 公共服务 | 三个环境用的是同一份，换环境不换值 | `kv/<name>` | 三环境共读，**只读** |
| ② 基础凭据 | 授予「控制基础设施」或「登录主机」的能力 | `kv/CICD/<env>` | 各环境只读自己那份 |
| ③ 环境业务密钥 | 某个环境里某个服务自己的密钥 | `kv/<env>/<service>` | 各环境读写自己那份 |

---

## 1. 现状盘点与归位

### `CICD` —— 需要拆开，现在是混装的

| Key | 归属 | 目标路径 |
|---|---|---|
| `GHCR_USERNAME` / `GHCR_TOKEN` | ① 公共服务 | 留在 `kv/CICD` |
| `SSH_PRIVATE_DEPLOY_KEY_B64` | ② 基础凭据 | `kv/CICD/{sit,uat,prod}` |
| `VULTR_API_KEY` | ② 基础凭据 | `kv/CICD/{sit,uat,prod}` |
| `TF_STATE_ENDPOINT/BUCKET/ACCESS_KEY/SECRET_KEY/REGION` | ② 基础凭据 | `kv/CICD/{sit,uat,prod}` |
| `CLOUDFLARE_DNS_API_TOKEN` | ② 建议（**待定**） | DNS 控制即基础设施控制。留在公共层意味着 sit role 能读到一个可以改生产 DNS 指向的凭据。拆分需要先在 Cloudflare 建按 zone 限定的 token。 |
| `AI_WORKSPACE_AUTH_TOKEN` | **待确认** | 是否随环境变化未知，需要你判断。 |

### 其余根路径

| 现状路径 | 归属 | 处置 | 依据 |
|---|---|---|---|
| `action-runner` | ① 公共服务 | **保持不动** | 存 `GITEA_RUNNER_TOKEN` / `GITHUB_RUNNER_TOKEN`，runner 注册凭据跨环境通用。policy 已授权。 |
| `openclaw` | ① 公共服务 | **保持不动** | 已被三个 role 共读，policy 已授权。 |
| `sit/` `uat/` | ③ 环境业务 | **保持不动** | 已符合模型。下面已有 `databases`、`agent-proxy` 等子键。 |
| **`prod/`** | ③ 环境业务 | ⚠️ **缺失，需要创建** | policy 已授权 `kv/data/prod/*`，但路径根本不存在——prod 走的是一条从没被验证过的通路。 |
| `WEB_SAAS` | ③ 环境业务 | 迁往 `kv/{uat,prod}/web-saas` | 当前 uat 与 prod **共读同一份**，即两个环境共用同一套数据库口令。 |
| `accounts.svc.plus` | ③ 环境业务 | 迁往 `kv/<env>/accounts` | 见下方「未授权」问题。 |
| `console.svc.plus` | ③ 环境业务 | 迁往 `kv/<env>/console` | 同上。 |
| `billing-service` | ③ 环境业务 | 迁往 `kv/<env>/billing` | 同上。 |
| `gitea.svc.plus` | ③ 环境业务 | 迁往 `kv/<env>/gitea` | 由 `roles/vhosts/gitea` **运行时**读取。 |
| `iam.svc.plus` | ③ 环境业务 | 迁往 `kv/<env>/iam` | 由 `roles/docker/zitadel` **运行时**读取。 |
| `postgresql.svc.plus` | ③ 环境业务 | 迁往 `kv/<env>/postgresql` | 由 `roles/docker/postgres` **运行时**读取。 |
| `cloud` | **待确认** | — | 本仓与 playbooks 仓均无引用，用途不明。 |
| `github-actions/` | **待确认** | — | 无引用。可能是早期 role/policy 的遗留。 |
| `xworkmate/` `xworkmate-bridge/` | 域外 | **不动** | 属于 xworkmate 产品线，不在 platform-ops 的环境模型内。 |

> 服务路径以 `*.svc.plus` 这种**生产域名**命名，本身就说明它们默认只有一份（即 prod 那份）。
> 迁成 `kv/<env>/<service>` 之后名字里不再含环境信息，环境由路径前缀表达。

---

## 2. 梳理中发现的四个问题

### 2.1 `prod/` 路径不存在

`prod` policy 授权了 `kv/data/prod/*`，但 `kv/` 下没有 `prod/`。结合
[§1 role 绑定](./vault_authentication_and_policy_isolation.md) 里 tag 发版本来就认证不过这一点，
说明 **prod 这条通路整体从未被真正走通过**。创建 `prod/` 之前不要假设 prod 部署可用。

### 2.2 还有 4 个 workflow 从 `CICD` 根读基础凭据

`platform-ops.yaml` 已切到 `VAULT_KV_BASE`，但这些还没有：

| Workflow | 仍从根路径读 |
|---|---|
| `deploy-action-runner-iac.yaml` | `SSH_PRIVATE_DEPLOY_KEY_B64`、`VULTR_API_KEY`、`TF_STATE_*` |
| `iac-pipeline-multi-cloud-account-matrix.yaml` | `TF_STATE_*`（路径硬编码，未走 env 变量） |
| `iac-pipeline-multi-cloud-resources-matrix.yaml` | `TF_STATE_*`（同上） |
| `iac-pipeline-multi-cloud-landingzone-baseline.yaml` | `TF_STATE_*`（同上） |

**迁移第 4 步（从根路径删除基础凭据）之前必须先改完这 4 个**，否则它们会静默读到空值——
`vault-action` 开着 `ignoreNotFound`，路径不存在只会得到空字符串，不会报错。

### 2.3 7 个 service 路径没有被任何 policy 授权

`accounts.svc.plus`、`console.svc.plus`、`billing-service`、`gitea.svc.plus`、`iam.svc.plus`、
`postgresql.svc.plus`、`cloud` 都不在任何 policy 的授权范围内。其中三个确实被 ansible 角色在
**运行时**读取（`roles/vhosts/gitea`、`roles/docker/zitadel`、`roles/docker/postgres`
直接对 `{{ vault_addr }}/v1/kv/data/<name>` 发请求）。

### 2.4 ansible 运行时那条 Vault 通路本来就没打通

`exportToken: true` **只设在 `provision` job**。其余 14 处
`VAULT_TOKEN: ${{ steps.vault.outputs.vault_token }}` 拿到的是**空字符串**。
`platform-ops.yaml` 自己的注释（`deploy_web_saas` 内）也承认「目前这条通路没有打通」。

所以 2.3 现在不表现为 403，而是表现为**这些角色的 Vault 读取整体不生效**，各自 fallback 到
Env 或自动生成。**修 2.3 的授权之前，要先决定这条运行时通路到底要不要打通**——
如果打通，就得同步把这些 service 路径加进 policy；如果不打通，这些路径就应该由部署侧以
Env 显式传入（web-saas 的 `ACCOUNT_DB_PASSWORD` 已经是这个做法）。

---

## 3. 目标布局

```
kv/
├── CICD                    ① 公共服务：GHCR_USERNAME / GHCR_TOKEN
│   ├── sit                 ② 基础凭据：VULTR_API_KEY / TF_STATE_* / SSH_PRIVATE_DEPLOY_KEY_B64
│   ├── uat                 ②
│   └── prod                ②
├── openclaw                ① 公共服务
├── action-runner           ① 公共服务：GITEA_RUNNER_TOKEN / GITHUB_RUNNER_TOKEN
├── sit/                    ③ 环境业务
│   ├── databases
│   ├── agent-proxy
│   ├── web-saas
│   └── <service>...
├── uat/                    ③ 同上
├── prod/                   ③ 同上（待创建）
├── xworkmate/              域外，不动
└── xworkmate-bridge/       域外，不动
```

`kv/CICD` 与 `kv/CICD/<env>` 在 KV v2 里是**两个独立的 secret**，一个路径既可以是 secret
本身、也可以是子路径前缀，因此上面的层级可以直接成立，不需要改名。

---

## 4. 迁移顺序

每一步都可回退，且任一步做完流水线都应保持可用。

1. **建 `kv/CICD/{sit,uat,prod}`**，各写入该环境的 `VULTR_API_KEY` / `TF_STATE_*` /
   `SSH_PRIVATE_DEPLOY_KEY_B64`。
   > 起步可以先把现有同一份凭据复制三份让链路跑通，但要清楚：**那时路径已隔离、凭据仍复用**，
   > 真正的隔离收益要等换成各自独立的 Vultr key 与 SSH 密钥对才成立。
2. **应用 policy**（跑 `vault_auth_split.sh`）。此时新旧路径都可读，流水线不受影响。
3. **合并 workflow 侧改动**：`platform-ops.yaml` 已切 `VAULT_KV_BASE`；
   **补齐 §2.2 里剩下的 4 个 workflow**。
4. **建 `prod/`**，补齐 prod 环境业务密钥。
5. **拆 `WEB_SAAS`** → `kv/{uat,prod}/web-saas`，让两个环境不再共用数据库口令，
   同步改 `VAULT_KV_WEB_SAAS`。
6. **决定 §2.4 的运行时通路**，再据此处理 7 个 service 路径（迁移 + 授权，或改为 Env 传入）。
7. **最后**从 `kv/CICD` 根删掉已搬走的基础凭据，只留 GHCR 等公共服务键。

> ⚠️ 第 7 步是唯一不可逆的一步，务必在 §2.2 的 4 个 workflow 全部改完并各跑通一次之后再做。

---

## 5. 待你确认的三项

1. **`CLOUDFLARE_DNS_API_TOKEN`** 是否拆成按环境？拆需要先建 Cloudflare 按 zone 限定的 token。
   不拆则 sit 可读到能改生产 DNS 的凭据。
2. **`AI_WORKSPACE_AUTH_TOKEN`**、**`cloud`**、**`github-actions/`** 的用途与归属。
3. **ansible 运行时 Vault 通路**（§2.4）要不要打通——这决定 7 个 service 路径是走 policy 授权，
   还是改为部署侧 Env 显式传入。
