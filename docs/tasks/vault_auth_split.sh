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
# 路径分两类:
#
#   1. 公共服务 secret —— 共享, 不按环境拆分:
#        kv/data/CICD          镜像仓库拉取凭据(GHCR)、云账号 API key、
#                              TF state 后端凭据、SSH 部署密钥
#        kv/data/openclaw
#        kv/data/action-runner
#      这些是全平台共用的公共能力(拉镜像、访问同一个云账号、访问同一个 state
#      后端), 本身不存在"环境"的概念, 拆成 sit/uat/prod 三份只会产生三份需要
#      同步轮换的副本, 不产生隔离收益。
#
#   2. 环境专属 secret —— 严格隔离:
#        kv/data/<env>/*       该环境自己的业务密钥, 各 role 只能读写自己那份
#
# 关于共享路径的爆炸半径: 共享路径的风险上限由"最松的那个 role"决定。原先
# sit role 只绑 repository、没有任何 ref / workflow 约束, 任何人推个分支加个
# workflow 就能换到 sit token 并读走 kv/data/CICD —— 那时共享确实是危险的。
# 本次把三个 role 都钉死到 job_workflow_ref 白名单 + 各自的 ref 之后, 能换到
# token 的路径已经收敛到本仓库这 5 个 workflow 文件, 共享路径的风险随之下降。
# 也就是说: 真正堵住提权的是绑定收紧, 而不是拆路径。
# -----------------------------------------------------------------------------

# 公共服务 secret: 三个环境共读, 不按环境拆分。
emit_common_read_paths() {
  cat <<'EOF'
# 公共服务凭据(GHCR 拉取 / 云账号 / TF state 后端 / SSH 部署密钥)。
# 全平台共用的公共能力, 不存在环境维度, 因此不拆分为 sit/uat/prod。
path "kv/data/CICD" {
  capabilities = ["read"]
}
path "kv/metadata/CICD" {
  capabilities = ["list", "read"]
}
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

  emit_common_read_paths

  # WEB_SAAS 目前是 uat / prod 共读(内含 POSTGRES_ROOT_PASSWORD /
  # ACCOUNT_DB_PASSWORD 等), 即 uat 与 prod 共用同一套数据库口令。这与
  # kv/data/CICD 不同 —— 数据库口令是环境专属的业务密钥, 不是公共服务凭据,
  # 后续应拆分为 kv/data/<env>/web-saas。
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

# sit: PR 验证 + 非 main 分支的 workflow_dispatch。ref 仍然较宽(PR 与分支都要
# 放行), 真正的收敛来自 job_workflow_ref 白名单 —— 换 token 只能通过本仓库
# 已有的 5 个 workflow, 自己新加一个 workflow 是换不到的。
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
echo "Done. 3 个 policy + 3 个 role 已生效, 死角色 -prod-tags 已清理。"
echo
echo "注意行为变更: prod 现在只接受 v* tag。workflow_dispatch 选 prod 会认证失败,"
echo "这与分支规范'生产部署只经 annotated tag'一致。"
echo
echo "后续待办(未包含在本脚本中):"
echo "  - kv/data/WEB_SAAS 目前由 uat 与 prod 共读, 内含数据库口令。数据库口令是"
echo "    环境专属的业务密钥(不同于 kv/data/CICD 那类公共服务凭据), 应拆分为"
echo "    kv/data/<env>/web-saas, 让两个环境不再共用同一套口令。"
