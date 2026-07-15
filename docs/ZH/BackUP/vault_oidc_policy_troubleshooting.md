# Vault OIDC 策略配置与 403 Forbidden 权限排障指南

本文档旨在解决在站点迁移与容灾流水线中，通过 GitHub Actions OIDC 进行 Vault 鉴权时遇到的 `403 (Forbidden)` 权限被拒绝问题。

---

## 1. 故障现象与报错

在流水线的特定步骤（例如最后一步 `switch_dns` 阶段的 `Load Vault secrets for DNS`，或 `deploy_agent_proxy` 阶段）中，当尝试使用 `vault-action` 获取 Vault 密钥时发生如下报错：

```
Error: Response code 403 (Forbidden)
```

此时的流水线 `with` 配置片段示例：
```yaml
with:
  url: https://vault.svc.plus
  method: jwt
  role: github-actions-platform-ops-toolkit
  jwtGithubAudience: vault
  ignoreNotFound: true
  secrets: |
    kv/data/CICD CLOUDFLARE_DNS_API_TOKEN | CLOUDFLARE_DNS_API_TOKEN ;
    kv/data/uat/agent-proxy xray_uuid | XRAY_UUID
```

---

## 2. 根因分析

该报错的核心原因是 **Vault 中绑定的策略（Policy）未包含对特定敏感数据路径的读取权限**。

具体表现为：
1. 流水线使用 OIDC 换取了绑定有 `github-actions-platform-ops-toolkit` 策略的临时 Token。
2. 初始版本的策略仅放行了静态共享路径（如 `kv/data/CICD` 和 `kv/data/WEB_SAAS`）。
3. 当流水线重构并引入了参数化、分环境（如 `uat`、`prod`）的配置时，系统需要动态读写环境专属路径，例如：
   - 数据库凭证：`kv/data/uat/databases`
   - 隧道代理凭证：`kv/data/uat/agent-proxy`
4. 由于旧的 Vault 策略中没有授权这些动态路径（如 `kv/data/+/databases` 或 `kv/data/+/agent-proxy`），导致 Vault 在 Token 尝试访问上述路径时直接拦截并返回 `403 Forbidden`。

---

## 3. 解决方案

要彻底解决该问题，Vault 管理员需要更新 `github-actions-platform-ops-toolkit` 策略，追加针对动态环境路径的通配符授权。

### 3.1 完整的标准 Vault 策略配置 (Policy)

请将 `github-actions-platform-ops-toolkit` 策略更新为以下完整定义：

```hcl
# ==========================================
# 1. 共享/全局 CICD 密钥读取权限
# ==========================================
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["read", "list"]
}

# ==========================================
# 2. Web SaaS 域专属密钥读取权限
# ==========================================
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}
path "kv/metadata/WEB_SAAS" {
  capabilities = ["read", "list"]
}

# ==========================================
# 3. 动态环境数据库凭证权限 (uat/prod 等环境)
# ==========================================
# 允许自动建库流水线创建、更新和读取数据库凭证
path "kv/data/+/databases" {
  capabilities = ["read", "create", "update", "patch"]
}
path "kv/metadata/+/databases" {
  capabilities = ["read", "list"]
}

# ==========================================
# 4. 动态环境 Agent Proxy 隧道 UUID 读写权限
# ==========================================
# 允许 Xray 代理服务写入与读取自动生成的 UUID
path "kv/data/+/agent-proxy" {
  capabilities = ["read", "create", "update", "patch"]
}
path "kv/metadata/+/agent-proxy" {
  capabilities = ["read", "list"]
}
```

### 3.2 策略写入与生效命令

作为 Vault 管理员，在任何能够安全访问 `https://vault.svc.plus` 服务的终端中，运行以下命令完成策略更新：

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="你的管理员Token"

# 覆盖并更新策略
vault policy write github-actions-platform-ops-toolkit - <<'EOF'
# 共享/全局 CICD 密钥读取权限
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["read", "list"]
}

# Web SaaS 域专属密钥读取权限
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}
path "kv/metadata/WEB_SAAS" {
  capabilities = ["read", "list"]
}

# 动态环境数据库凭证权限
path "kv/data/+/databases" {
  capabilities = ["read", "create", "update", "patch"]
}
path "kv/metadata/+/databases" {
  capabilities = ["read", "list"]
}

# 动态环境 Agent Proxy 隧道 UUID 读写权限
path "kv/data/+/agent-proxy" {
  capabilities = ["read", "create", "update", "patch"]
}
path "kv/metadata/+/agent-proxy" {
  capabilities = ["read", "list"]
}
EOF
```

---

## 4. 验证 Checklist

* [ ] 执行 `vault policy read github-actions-platform-ops-toolkit`，确认输出的内容包含 `kv/data/+/agent-proxy` 等通配符规则。
* [ ] 再次触发流水线，观察 `switch_dns` 阶段中 `Load Vault secrets for DNS` 步骤是否可以成功完成（不抛出 `403` 异常）。
* [ ] 检查并确保工作流中使用的 JWT 角色为 `github-actions-platform-ops-toolkit`（与策略名称匹配）。
