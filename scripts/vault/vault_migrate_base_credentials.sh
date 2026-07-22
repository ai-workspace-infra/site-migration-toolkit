#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 迁移第 1 步: 把基础凭据从 kv/CICD 根路径复制到 kv/CICD/{sit,uat,prod}
#
# 用法:
#   export VAULT_ADDR=https://vault.svc.plus
#   export VAULT_TOKEN=<admin token>
#   ./scripts/vault/vault_migrate_base_credentials.sh --dry-run   # 先看要做什么
#   ./scripts/vault/vault_migrate_base_credentials.sh             # 实际执行
#
# 安全属性:
#   * 绝不打印任何密钥值 (只打印键名)
#   * 值经 stdin 传给 vault, 不出现在进程参数里 (ps 看不到)
#   * 不覆盖: 目标路径若已存在同名键, 默认跳过。这样当你后续把某个环境换成
#     独立凭据之后, 重跑本脚本不会把它清回共享的那一份。要强制覆盖用 --force。
#   * 只新增/复制, 不删除根路径的任何东西 (删除是迁移第 7 步, 另有脚本)
#
# 前置: 请先跑 scripts/backup/vault_backup_to_keychain.sh 做全量备份。
# =============================================================================

ADDR="${VAULT_ADDR:-https://vault.svc.plus}"
export VAULT_ADDR="${ADDR}"

DRY_RUN=0
FORCE=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=1 ;;
    --force)   FORCE=1 ;;
    *) echo "未知参数: $a" >&2; exit 2 ;;
  esac
done

# 第 ② 层: 授予「控制基础设施」或「登录主机」能力的键
BASE_KEYS=(
  VULTR_API_KEY
  TF_STATE_ENDPOINT
  TF_STATE_BUCKET
  TF_STATE_ACCESS_KEY
  TF_STATE_SECRET_KEY
  TF_STATE_REGION
  SSH_PRIVATE_DEPLOY_KEY_B64
)

ENVS=(sit uat prod)

command -v jq >/dev/null || { echo "需要 jq" >&2; exit 2; }

echo "==> 读取源路径 kv/CICD"
SRC="$(vault kv get -format=json kv/CICD 2>/dev/null)" || {
  echo "!! 读取 kv/CICD 失败" >&2; exit 1; }

missing=()
for k in "${BASE_KEYS[@]}"; do
  echo "${SRC}" | jq -e --arg k "$k" '.data.data | has($k)' >/dev/null || missing+=("$k")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "!! 源路径缺少以下键, 中止: ${missing[*]}" >&2
  exit 1
fi
echo "    源路径包含全部 ${#BASE_KEYS[@]} 个基础凭据键"

for env in "${ENVS[@]}"; do
  target="kv/CICD/${env}"
  echo
  echo "==> ${target}"

  existing="$(vault kv get -format=json "${target}" 2>/dev/null || echo '{}')"

  # 逐键决定: 已存在则跳过 (除非 --force)
  to_write=()
  for k in "${BASE_KEYS[@]}"; do
    if [ "${FORCE}" -eq 0 ] && echo "${existing}" | jq -e --arg k "$k" '.data.data // {} | has($k)' >/dev/null 2>&1; then
      echo "    跳过 ${k} (目标已存在, 用 --force 覆盖)"
    else
      to_write+=("$k")
    fi
  done

  if [ ${#to_write[@]} -eq 0 ]; then
    echo "    无需改动"
    continue
  fi

  echo "    将写入: ${to_write[*]}"
  if [ "${DRY_RUN}" -eq 1 ]; then
    echo "    (dry-run, 未执行)"
    continue
  fi

  # 合并: 保留目标已有的其他键, 叠加本次要写的键。
  #
  # 注意 --argjson 会把值放进 jq 的进程参数(ps 可见), 所以这里改用
  # --slurpfile 从 0600 临时文件读取, 再把结果经 stdin 交给 vault。
  # 全链路(jq 输入 / vault 输入)都不经过 argv; 只有键名走参数。
  src_f="$(mktemp "${TMPDIR:-/tmp}/.vmig-src.XXXXXX")"
  cur_f="$(mktemp "${TMPDIR:-/tmp}/.vmig-cur.XXXXXX")"
  chmod 600 "${src_f}" "${cur_f}"
  printf '%s' "${SRC}"      | jq '.data.data'      > "${src_f}"
  printf '%s' "${existing}" | jq '.data.data // {}' > "${cur_f}"

  jq -n \
    --slurpfile src "${src_f}" \
    --slurpfile cur "${cur_f}" \
    --argjson keys "$(printf '%s\n' "${to_write[@]}" | jq -R . | jq -s .)" \
    '($cur[0]) + ($keys | map({(.): $src[0][.]}) | add)' \
    | vault kv put "${target}" - >/dev/null

  rm -f "${src_f}" "${cur_f}"
  echo "    ✅ 已写入 ${#to_write[@]} 个键"
done

echo
echo "==> 校验 (只对比键名, 不打印值)"
for env in "${ENVS[@]}"; do
  keys="$(vault kv get -format=json "kv/CICD/${env}" 2>/dev/null | jq -r '.data.data | keys | join(", ")' || echo '<读取失败>')"
  printf '    %-6s %s\n' "${env}:" "${keys}"
done

echo
echo "完成。下一步:"
echo "  1. 跑 ./scripts/vault/vault_layout_verify.py 校验分层不变式"
echo "  2. 应用 policy:  ./docs/tasks/vault_auth_split.sh"
echo
echo "注意: 现在三个环境用的还是同一份凭据 —— 路径已隔离, 凭据仍复用。"
echo "真正的隔离收益要等各环境换成独立的 Vultr key / SSH 密钥对之后才成立。"
