#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Vault Authentication & Policy Split Initialization (sit, uat, prod)
#
# Requirements:
# 1. Run this script from a terminal with access to Vault (e.g. https://vault.svc.plus).
# 2. Vault must be initialized and unsealed.
# 3. Export VAULT_ADDR and VAULT_TOKEN (with admin privileges).
#
# -----------------------------------------------------------------------------
# 2026-07-22 安全硬化。修复的问题:
#
#   1. sit role 原先只绑 `repository`, 没有任何 ref / workflow 约束 —— 任何能推
#      分支的人, 用任何自己新加的 workflow, 都能换到 sit token。而三个 role 的
#      policy 都能读共享的 `kv/data/CICD`(存 VULTR_API_KEY / TF_STATE_* /
#      SSH_PRIVATE_DEPLOY_KEY_B64), 于是"按环境隔离"实际不成立。
#   2. uat role 只绑 `refs/heads/main`, 但流水线把 `release/*` push 也路由到
#      uat -> release 分支认证必然失败。
#   3. prod role 绑 `refs/heads/release/*`, 但流水线只在 `v*` tag 时请求 prod
#      -> tag 发版认证必然失败; 而单独建的 `-prod-tags` role 从来没有被任何
#      workflow 请求过(死角色)。同时 `release/*` 是任何 writer 都能创建的分支,
#      等于 prod 权限对所有 writer 敞开。
#   4. prod policy 带 `delete`(含 `kv/metadata/prod/*` 的永久销毁), 与文档
#      《vault_authentication_and_policy_isolation.md》自己的安全警告矛盾。
#
# 硬化要点: user_claim 用 sub 而非 actor; 钉死 job_workflow_ref(只有本仓库这
# 5 个 workflow 文件能换 token, 新加的 workflow 换不到); ref 绑定与流水线真实
# 触发路径对齐; batch token + 20m TTL + 去掉 default policy。
#
# ⚠️ 行为变更: prod 现在只能由 `v*` tag 触发。workflow_dispatch 选 prod 会认证
#    失败 —— 这是刻意的, 与分支规范"生产部署只经 annotated tag"一致。
# =============================================================================

export VAULT_ADDR="${VAULT_ADDR:-https://vault.svc.plus}"

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "Error: VAULT_TOKEN is not set. Please export your Vault admin token."
  exit 1
fi

REPO="ai-workspace-infra/platform-ops-toolkit"

# 允许换取这些 role 的 workflow 文件白名单。job_workflow_ref 的值形如
# <org>/<repo>/.github/workflows/<file>@<ref>, 所以用 @* 收尾放行任意 ref,
# 但文件名本身是钉死的 —— 仓库里新增一个 workflow 无法换到任何 role。
WF_PREFIX="${REPO}/.github/workflows"
read -r -d '' ALLOWED_WORKFLOWS <<EOF || true
    "${WF_PREFIX}/platform-ops.yaml@*",
    "${WF_PREFIX}/deploy-action-runner-iac.yaml@*",
    "${WF_PREFIX}/iac-pipeline-multi-cloud-account-matrix.yaml@*",
    "${WF_PREFIX}/iac-pipeline-multi-cloud-resources-matrix.yaml@*",
    "${WF_PREFIX}/iac-pipeline-multi-cloud-landingzone-baseline.yaml@*"
EOF

# -----------------------------------------------------------------------------
# Policies
#
# PHASE 1 (当前): 同时授予新的按环境路径 kv/data/CICD/<env> 和旧的共享
#   kv/data/CICD, 保证迁移期间流水线不中断。
# PHASE 2 (数据迁移完成后): 删掉下面标了 "LEGACY" 的两段, 再跑一次本脚本。
#   届时 sit 被攻破只会泄露 sit 自己的云凭据, 而不是全环境的。
#
# ⚠️ PHASE 2 的前提不是改 policy, 而是先真正准备好"每个环境各自独立的凭据":
#   独立的 Vultr API key、独立的 TF state 访问密钥、独立的 SSH 部署密钥对。
#   如果三个环境共用同一把 SSH 私钥, 那么无论 Vault 路径怎么拆, sit 失陷
#   仍然等于 prod 失陷 —— 拆路径只是把凭据复用问题暴露出来, 不能替代换密钥。
# -----------------------------------------------------------------------------

emit_common_read_paths() {
  cat <<'EOF'
path "kv/data/openclaw" {
  capabilities = ["read"]
}
path "kv/data/action-runner" {
  capabilities = ["read"]
}
path "kv/metadata/action-runner" {
  capabilities = ["list", "read"]
}
EOF
}

# $1 = env name (sit|uat|prod)
emit_env_policy() {
  local env="$1"

  cat <<EOF
# ${env} environment: 该环境自己的 CI/CD 基础凭据
path "kv/data/CICD/${env}" {
  capabilities = ["read"]
}
path "kv/metadata/CICD/${env}" {
  capabilities = ["list", "read"]
}

# LEGACY (PHASE 1 only) —— 迁移完成后删除这两段
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["list", "read"]
}
EOF

  emit_common_read_paths

  # WEB_SAAS 目前是 uat / prod 共读(内含 POSTGRES_ROOT_PASSWORD /
  # ACCOUNT_DB_PASSWORD 等)。这意味着 uat 与 prod 共用同一套数据库口令,
  # 属于与 CICD 同类的跨环境凭据复用问题, 后续应同样按环境拆分。
  if [ "${env}" != "sit" ]; then
    cat <<'EOF'
path "kv/data/WEB_SAAS" {
  capabilities = ["read"]
}
path "kv/metadata/WEB_SAAS" {
  capabilities = ["list", "read"]
}
EOF
  fi

  if [ "${env}" = "prod" ]; then
    # prod 不给 delete: kv/data 的 delete 是软删, kv/metadata 的 delete 会
    # 永久销毁一个 secret 的所有版本, 流水线异常时足以摧毁生产密钥。
    cat <<EOF
path "kv/data/${env}/*" {
  capabilities = ["create", "read", "update", "list"]
}
path "kv/metadata/${env}/*" {
  capabilities = ["list", "read"]
}
EOF
  else
    cat <<EOF
path "kv/data/${env}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv/metadata/${env}/*" {
  capabilities = ["list", "read", "delete"]
}
EOF
  fi
}

for env in sit uat prod; do
  echo "Creating ${env} policy..."
  emit_env_policy "${env}" | vault policy write "github-actions-platform-ops-toolkit-${env}" -
done

# -----------------------------------------------------------------------------
# Roles
#
# 共同硬化项:
#   user_claim=sub            身份绑定到工作负载(repo+ref+workflow), 而不是
#                             触发者的 GitHub 用户名(actor)
#   job_workflow_ref          钉死到白名单 workflow 文件
#   token_no_default_policy   不附加 default policy, 最小权限
#   token_type=batch          CI 用不可续期的一次性 token
#   token_ttl/max_ttl=1h      见下方 TOKEN_TTL 说明
#
# ⚠️ TTL 校准: 这里保持 1h(与硬化前一致), 是为了不引入新的中断风险 ——
#   deploy_web_saas 现在要在 runner 上编译 billing 二进制、构建并 docker save
#   postgres-extensions 镜像, 再跑完整 ansible 部署, 且多个后置步骤会把
#   VAULT_TOKEN 传给 ansible; 若 TTL 短于 job 实际耗时, token 会在部署中途过期。
#   等测到 job 时长的 p95 之后, 再把 TTL 收敛到"略大于 p95"的值。
#   本轮的安全收益来自绑定收紧 / batch token / 去掉 default policy, 而不是 TTL。
# -----------------------------------------------------------------------------

TOKEN_TTL="1h"

# $1 = role name suffix, $2 = policy name, $3 = ref claim JSON value
write_role() {
  local suffix="$1" policy="$2" ref_claim="$3"
  vault write "auth/jwt/role/github-actions-platform-ops-toolkit-${suffix}" - <<EOF
{
  "role_type": "jwt",
  "user_claim": "sub",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "${REPO}",
    "job_workflow_ref": [
${ALLOWED_WORKFLOWS}
    ],
    "ref": ${ref_claim}
  },
  "token_policies": ["${policy}"],
  "token_no_default_policy": true,
  "token_type": "batch",
  "token_ttl": "${TOKEN_TTL}",
  "token_max_ttl": "${TOKEN_TTL}"
}
EOF
}

# sit: PR 验证 + 非 main 分支的 workflow_dispatch。ref 仍然较宽, 真正的收敛
# 来自 job_workflow_ref 白名单, 以及 PHASE 2 之后 sit 只能读自己的凭据。
echo "Creating SIT role (PR + branch dispatch)..."
write_role sit github-actions-platform-ops-toolkit-sit \
  '["refs/pull/*/merge", "refs/heads/*"]'

# uat: main 与 release/* 的 push 都路由到 uat, 两者都要放行。
echo "Creating UAT role (main + release/*)..."
write_role uat github-actions-platform-ops-toolkit-uat \
  '["refs/heads/main", "refs/heads/release/*"]'

# prod: 只认 v* tag。release/* 是任何 writer 都能建的分支, 不能作为 prod 的
# 凭据边界; 流水线也只在 tag 时请求 prod。
echo "Creating PROD role (v* tags only)..."
write_role prod github-actions-platform-ops-toolkit-prod \
  '"refs/tags/v*"'

# 死角色清理: -prod-tags 从来没有被任何 workflow 请求过, 其职责已并入 -prod。
echo "Removing dead role github-actions-platform-ops-toolkit-prod-tags (if present)..."
vault delete auth/jwt/role/github-actions-platform-ops-toolkit-prod-tags 2>/dev/null \
  || echo "  (not present, nothing to remove)"

echo
echo "Done."
echo
echo "PHASE 1 完成。接下来要做的(按顺序):"
echo "  1. 为每个环境生成各自独立的凭据(Vultr API key / TF state 密钥 / SSH 部署密钥对)。"
echo "  2. 写入 kv/CICD/sit、kv/CICD/uat、kv/CICD/prod。"
echo "  3. 把 workflow 里的 VAULT_KV 从 kv/data/CICD 改为 kv/data/CICD/\${DEPLOY_ENV}。"
echo "  4. 删除本脚本中标记 LEGACY 的两段, 重新执行, 收回对共享 kv/data/CICD 的读权限。"
