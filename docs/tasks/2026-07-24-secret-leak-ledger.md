# 密钥泄露台账（2026-07-24）

跨仓库的历史泄露清单。**由 haitaopanhq 手动统一处理**，本文档只负责记录范围、
定位与判定，不代表已修复。

净化历史与轮换凭据是两件事：`git filter-repo` 只能阻止**未来**被读取，
任何已经 clone 过的副本仍然持有那份密钥。**先轮换，再净化**。

## 一、`ai-workspace-infra/postgresql.svc.plus` — 已净化，待轮换

历史已用 `git filter-repo` 移除三个文件并强制推送（11 分支 + 9 tag 逐一核对，
本地重写后哈希与远端一致；三个原始提交在远端已不可达）。

**凭据轮换仍未完成**：

| 内容 | 位置（已从历史移除） | 状态 |
|---|---|---|
| 4 个账号的明文 MFA TOTP secret + bcrypt 口令哈希 | `account/account-export.yaml` @ `44f874b` | ⏳ 待重置 MFA |
| SMTP 明文密码 `no-reply@svc.plus`（2 处） | `scripts/install_exim_sendonly.md` @ `19535e2` | ⏳ 待改密 |
| OAuth `access_token` / `refresh_token`（4 处） | `TOKEN_AUTH_MANUAL.md` @ `9d184ba` | ⏳ 待确认真伪，为真则吊销 |

TOTP secret 是**可直接用于生成有效 2FA 验证码的活密钥**，不是哈希 —— 涉及账号
`shenlan`、`manbuzhe2008@gmail.com`、`Henry` 等。

副作用：任何已 clone 该仓库的副本历史已分叉，需重新 clone，`git pull` 不会收敛。

## 二、`ai-workspace-infra/gitops` — 未处理

### 真实泄露：WireGuard 网关私钥

```
playbooks/wireguard_ali_vpn_gw : 16    gateway.private_key
提交 53656ac / 6025c5c / 79e3c64   2025-05-23
```

文件**已不在 `main`**，但仍在历史里；仓库是**公开**的。同一段声明里还有对端
`aws_vpc` 的公钥与端点 `52.81.109.27:51820`，也就是说私钥、对端、端点三者齐全。

判定为真实泄露：值是 44 字符 base64、符合 WireGuard X25519 私钥格式，且键名就是
`private_key`。

处理顺序：**先在网关侧换掉密钥对并更新对端 peer 配置**，确认旧密钥失效后，再
`git filter-repo --path playbooks/wireguard_ali_vpn_gw --invert-paths` 净化历史。

### 误报：Jenkins 插件坐标

```
playbooks/roles/charts/jenkins/files/setup.sh : 38-39
```

内容是 `- credentials:1337.v60b_d7b_c7b_c9f` 这类 **Jenkins 插件名 + 版本号**，
冒号后的高熵串被 `generic-api-key` 规则误判。已加 `.gitleaks.toml` 窄豁免
（只针对该文件、该规则、该版本号模式）。

> 与第一项的差别值得强调：**gitleaks 报红的默认假设是"确有泄露"**，加白名单
> 是例外，必须逐行核对过被标记的内容才成立。这两条同时出现在一次扫描里，
> 一条是真的、一条是假的 —— 不能因为其中一条是误报就整体放行。

## 三、扫描版本差异

CI 用 gitleaks **8.21.2**，本地是 **8.30.1**。同一份历史：

| 版本 | 发现 |
|---|---|
| 8.21.2（CI） | 6 处，全部是 Jenkins 误报 |
| 8.30.1（本地） | 3 处，全部是 WireGuard 私钥 |

**两个版本各自漏掉了对方发现的东西。** CI 那个版本从未报出 WireGuard 私钥 ——
这意味着 CI 绿灯不等于历史干净。建议把 CI 的 gitleaks 版本升到与本地一致，
并在升级后重扫一遍全部仓库。

## 四、规范

已写入 skill `engineering-standards/multi-environment-delivery-and-release` §5：
文档一律引用 `kv/<path>` `<KEY_NAME>`，不写字面值；含密钥的数据导出不进仓库；
`gitleaks` 在不相关 PR 上报红不是误报，是提示某次历史提交需要净化。
