# web-saas UAT 打通 —— 阶段汇总（2026-07-24）

`/goal` 的两条验收标准仍然有效：

1. `deploy_web_saas` 能顺利完成部署 UAT 环境
2. 部署完成后 DNS 解析能正常发布

这份文档汇总本轮（2026-07-23 至 2026-07-24）跨三个仓库（`platform-ops-toolkit`、
`playbooks`、`gitops`）的全部改动，作为继续推进时的单一入口。逐层缺陷的完整
排查过程见 [2026-07-23-uat-web-saas-deploy-unblocking.md](2026-07-23-uat-web-saas-deploy-unblocking.md)；
密钥泄露事件见 [2026-07-24-secret-leak-ledger.md](2026-07-24-secret-leak-ledger.md)。

## 一、部署链路缺陷（共 10 层，全部已修复并合入 main）

延续前一份文档的记法，缺陷按发现顺序编号：

| # | 缺陷 | 仓库 | PR |
|---|---|---|---|
| 0–6 | 假绿路径、`always()` 传递、exec 位、Vault role 绑定、Doco-CD 无条件要 token、Doco-CD 不装 Docker | 见 [#0-6 详情](2026-07-23-uat-web-saas-deploy-unblocking.md) | 已合 |
| 7 | `domain-cd.yaml` 跨仓 `workflow_call` 下 checkout 错误仓库 | playbooks | [#181](https://github.com/ai-workspace-infra/playbooks/pull/181) |
| 8 | `domain-cd.yaml` 校验完输入就结束，从不执行部署 | playbooks | [#183](https://github.com/ai-workspace-infra/playbooks/pull/183)†[#184](https://github.com/ai-workspace-infra/playbooks/pull/184) |
| 9 | `deploy_base` 仍硬编码旧 playbook `setup-Doco-CD.yaml`，且没有任何步骤把 Vault 里的 web-saas 机密喂给它 | platform-ops-toolkit | [#102](https://github.com/ai-workspace-infra/platform-ops-toolkit/pull/102) |

† **#183 的教训（新增一类缺陷模式）**：squash-merge 只捕获了 PR 分支上 merge
那一刻已推送的 commit。我在你点合并**之后**才 push 了第二个 commit，它被
留在一个已合并、已关闭的分支上，`git merge-base --is-ancestor` 能立刻验证
这类遗漏——**描述完 PR 包含哪几部分之后，必须确认全部 commit 已推送完，
再请求合并，而不是反过来。** 已在 #184 中恢复，行为与 §10 的 C2/C5 同属
"看起来合并了、实际没生效"的假绿家族，值得记进 `workflow_gating_verify.py`
的候选检查列表（尚未实现：需要对比 PR 的最后一次 push 时间与 merge 时间）。

## 二、新增的部署机制：Doco-CD + gitops，而非直接 ansible-playbook

**这是一次经过用户两次确认的架构选择**，不是默认路径：`playbooks` 仓已存在
四个成熟、在生产跑着的按服务 playbook（`deploy_accounts_svc_plus.yml` 等），
本可以更省事地直接复用。选择 Doco-CD/GitOps 路线是为了拿到 GitOps 的审计与
回滚能力，代价是要新建一整套机制。记这笔账，是为了未来如果要复盘"当初为什么
不用现成的四个 playbook"能查到原因。

### 职责边界（贯穿三个仓库的核心设计判据）

判据是**谁来管版本**：

| | 归属 | 版本记录 |
|---|---|---|
| 镜像 tag（业务发布） | `gitops` 仓 `compose/web-saas/.env.<env>` | `git log` |
| 口令、证书、配置（基础设施） | `playbooks` 仓 `web_saas_host_config` 角色 ← Vault | Vault 版本 |

混在一起会导致「改个镜像 tag 要动 TLS 证书」，或反过来「轮换证书触发一次
业务发布」。

### 三个仓库各自新增了什么

**`gitops`**（[#110](https://github.com/ai-workspace-infra/gitops/pull/110)，已合）
- `compose/web-saas/{.doco-cd.yml,docker-compose.yml,.env.uat}`
- 铁律：机密不进仓库；bind mount 一律绝对路径（相对路径在 Doco-CD 的临时
  clone 里会挂载出空目录而不是报错）；镜像引用用 `${VAR:?...}` 让空值直接
  失败

**`playbooks`**（[#181](https://github.com/ai-workspace-infra/playbooks/pull/181)
[#183](https://github.com/ai-workspace-infra/playbooks/pull/183)
[#184](https://github.com/ai-workspace-infra/playbooks/pull/184)，已合）
- 新角色 `web_saas_host_config`：渲染 `/etc/xcontrol/web-saas/` 下的
  `secrets.env`（0600）、`config/`、`certs/`（0700）、`Caddyfile`；断言
  全部前置，空口令/缺证书必须让 play 失败，不能静默产出一个能起来但连不上
  的服务
- `setup-web-saas-domain.yml`：装配 `web_saas_host_config` + `Doco-CD`，
  Doco-CD 轮询 `gitops` 主分支，60s（不用 webhook，省一个新密钥）
- `domain-cd.yaml`：真正执行部署——把 `deploy_tag` 写进 gitops 的
  `.env.<env>`、提交、推送；两个 step 条件严格互补，不存在"两个都跳过、
  job 报绿却什么都没做"的组合

**`platform-ops-toolkit`**（[#102](https://github.com/ai-workspace-infra/platform-ops-toolkit/pull/102)
[#103](https://github.com/ai-workspace-infra/platform-ops-toolkit/pull/103)，已合）
- `deploy_base` 的 `Load Vault secrets` 步骤补上 `kv/data/WEB_SAAS` 下全部
  必需/可选键，导出给 `Bootstrap node` 步骤
- `WEB_SAAS_CONSOLE_DOMAIN` / `WEB_SAAS_ACCOUNTS_DOMAIN` 由
  `TARGET_DOMAIN_BASE` + `DEPLOY_ENV` 推导，不存成机密——它们是拓扑，不是
  凭据
- `bootstrap-node.sh` 的 `web_saas` 组映射改指向 `setup-web-saas-domain.yml`
- 配套脚本 `docs/tasks/2026-07-24-populate-web-saas-vault-secrets.sh`：
  生成随机内部凭据 + 自签 stunnel 证书链（已用 `openssl verify` 验证），
  写入 `kv/WEB_SAAS`

## 三、安全事件（与部署链路并行处理，互不阻塞）

详见 [secret-leak-ledger.md](2026-07-24-secret-leak-ledger.md)。摘要：

- `postgresql.svc.plus` 仓：4 个账号的活 MFA TOTP secret、SMTP 明文密码、
  疑似 OAuth token，历史已用 `git filter-repo` 净化（11 分支 + 9 tag 核对
  一致）。**凭据轮换仍是待办**，净化历史不能让已泄露的密钥重新变安全。
- `gitops` 仓：WireGuard 网关私钥（真实泄露，文件已不在 main 但历史里还有）
  与 Jenkins 插件坐标（`generic-api-key` 误报，已加 `.gitleaks.toml` 窄
  豁免）混在同一次扫描结果里——两者判定方式不同，不能因一条误报就整体放行。
- `gitops` 与 `postgresql.svc.plus` 两仓的 `main` 分支保护已按你的要求收紧：
  `allow_force_pushes=false`、`required_approving_review_count=1`、
  `enforce_admins=false`（后者是刻意的——你是仓库唯一协作者，`enforce_admins:
  true` 配 required review 会让你自己也合不了任何 PR）。

## 四、当前状态与下一步

三个仓库的 main 分支现在都含有完整链路。**尚未验证的是端到端结果**：

1. 需要你跑 `docs/tasks/2026-07-24-populate-web-saas-vault-secrets.sh` 把
   Vault 里 `kv/WEB_SAAS` 的必需键（`POSTGRES_PASSWORD`、
   `ACCOUNT_PG_PASSWORD`、`AUTH_TOKEN_*`、`STUNNEL_*_B64`）补齐
2. 重新触发 `platform-ops.yaml`（`run_infrastructure=false` 即可，主机已
   存在；`run_application_deploy=true`；`target_domains=web-saas`；
   `confirm_dns_switch=true`）
3. 上 `root@167.179.64.91` 核对：`/etc/xcontrol/web-saas/` 是否被正确渲染、
   `doco-cd` 容器是否配上了 `POLL_CONFIG`、compose 栈是否真的拉起

## 五、值得记进规范但还没做的

- `workflow_gating_verify.py` 补一条检查：PR 最后一次 push 时间晚于其合并
  时间 → 该 PR 大概率有 commit 被 squash-merge 丢弃（本次 §一 †的教训）
- CI 的 `gitleaks` 版本（8.21.2）落后本地（8.30.1）两个版本，且两个版本
  在同一份历史上给出了不同的发现——CI 绿灯不等于历史干净，建议升级并
  重扫全部仓库
- `kv/data/WEB_SAAS` 目前由 uat 与 prod 共读，应按三层模型拆分为
  `kv/data/<env>/web-saas`（本轮为了尽快打通 UAT，暂时沿用共享路径）
