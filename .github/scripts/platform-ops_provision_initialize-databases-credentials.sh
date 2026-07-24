#!/bin/bash
# 初始化 kv/data/<env>/databases 的数据库口令。
#
# 幂等的判据是"必需的键是否都在", 不是"这个 secret 在不在"。KV v2 里一个
# secret 可以存在却缺键 —— 早先某次写入只放了部分键, 或结构不同, 都会让
# 单纯的 200/404 探测得出"已存在, 跳过"的错误结论, 而下游读某个缺失的键时
# 才以 "No match data was found" 失败。那正是这里要提前拦住的静默不一致。
set -euo pipefail

: "${VAULT_ADDR:?VAULT_ADDR is required}"
: "${VAULT_TOKEN:?VAULT_TOKEN is required}"
: "${VAULT_ENV_PATH:?VAULT_ENV_PATH is required}"

URL="${VAULT_ADDR}/v1/kv/data/${VAULT_ENV_PATH}/databases"

# 下游确实会去读的键。缺任何一个都必须让这一步失败, 而不是留给
# bootstrap 阶段以一句难以定位的 Vault 报错崩掉。
REQUIRED_KEYS=(
  postgres_root_password
  account_pg_password
  litellm_pg_password
  rag_pg_password
  zitadel_pg_password
  gitea_pg_password
  vault_pg_password
  billing_pg_password
)

body="$(mktemp)"
trap 'rm -f "${body}"' EXIT
status="$(curl -s -o "${body}" -w '%{http_code}' -H "X-Vault-Token: ${VAULT_TOKEN}" "${URL}")"

generate_payload() {
  local args=() k
  for k in "${REQUIRED_KEYS[@]}"; do
    args+=(--arg "${k}" "$(openssl rand -base64 16)")
  done
  jq -n "${args[@]}" '{data: $ARGS.named}'
}

write_secret() {
  local http
  http="$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    -H "X-Vault-Token: ${VAULT_TOKEN}" -H "Content-Type: application/json" \
    -d "$(generate_payload)" "${URL}")"
  [[ "${http}" =~ ^2 ]] || {
    echo "::error::Failed to write ${URL} (HTTP ${http})." >&2
    exit 1
  }
}

case "${status}" in
  404)
    echo "Secret does not exist; initializing all database credentials."
    write_secret
    ;;
  200)
    # secret 在 —— 逐一核对必需键。缺一个就补齐: 因为主机上的 postgres 是
    # 由这份口令首次初始化的, 缺键意味着这个环境还没被这份口令建立过,
    # 补齐是安全的; 已存在的键一律不动, 避免轮换掉一个已在用的口令。
    missing=()
    for k in "${REQUIRED_KEYS[@]}"; do
      v="$(jq -r --arg k "${k}" '.data.data[$k] // empty' < "${body}")"
      [[ -n "${v}" ]] || missing+=("${k}")
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
      echo "All ${#REQUIRED_KEYS[@]} required database credentials present. Skipping."
    else
      # merge-patch 只增补缺失键, 保留已有键的值(不轮换在用口令)。
      echo "::warning::${URL} exists but is missing: ${missing[*]}. Patching only the missing keys."
      patch_args=()
      for k in "${missing[@]}"; do
        patch_args+=(--arg "${k}" "$(openssl rand -base64 16)")
      done
      patch_payload="$(jq -n "${patch_args[@]}" '{data: $ARGS.named}')"
      http="$(curl -s -o /dev/null -w '%{http_code}' -X PATCH \
        -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -H "Content-Type: application/merge-patch+json" \
        -d "${patch_payload}" "${URL}")"
      [[ "${http}" =~ ^2 ]] || {
        echo "::error::Failed to patch missing keys into ${URL} (HTTP ${http})." >&2
        exit 1
      }
      echo "Patched ${#missing[@]} missing key(s) into ${URL}."
    fi
    ;;
  *)
    echo "::error::Unexpected HTTP ${status} probing ${URL}." >&2
    head -c 300 "${body}" >&2
    exit 1
    ;;
esac
