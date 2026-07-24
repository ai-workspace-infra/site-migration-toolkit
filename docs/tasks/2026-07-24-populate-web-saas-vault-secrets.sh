#!/usr/bin/env bash
# 生成 web_saas_host_config 角色需要的机密并写入 kv/data/WEB_SAAS。
#
# POSTGRES_PASSWORD / ACCOUNT_PG_PASSWORD / AUTH_TOKEN_* 是内部凭据 ——
# 不对应任何外部账号, 随机生成即可, 谁也不需要"记住"它们。
# stunnel 证书是内部 mTLS, 自签 CA 是标准做法, 不需要公开 CA 签发。
#
# OAuth client id/secret 不在这里生成 —— 那是 GitHub/Google 开发者后台的
# 真实凭据, 只能你去申请。脚本把它们留空, web_saas_host_config 角色本身
# 允许它们为空(不在 required_secrets 列表里)。
#
# 用法:
#   export VAULT_ADDR=https://vault.svc.plus
#   export VAULT_TOKEN="hvs.xxxxxxxxx"   # 管理员 token
#   ./docs/tasks/2026-07-24-populate-web-saas-vault-secrets.sh
set -euo pipefail

: "${VAULT_ADDR:?export VAULT_ADDR first}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first}"

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

echo "==> 生成内部凭据"
POSTGRES_PASSWORD="$(openssl rand -base64 24)"
ACCOUNT_PG_PASSWORD="$(openssl rand -base64 24)"
AUTH_TOKEN_PUBLIC_TOKEN="$(openssl rand -hex 32)"
AUTH_TOKEN_REFRESH_SECRET="$(openssl rand -hex 32)"
AUTH_TOKEN_ACCESS_SECRET="$(openssl rand -hex 32)"

echo "==> 生成 stunnel 自签 CA 与 server 证书"
openssl genrsa -out "${workdir}/ca-key.pem" 4096 2>/dev/null
openssl req -x509 -new -nodes -key "${workdir}/ca-key.pem" -sha256 -days 3650 \
  -out "${workdir}/ca-cert.pem" -subj "/CN=web-saas-internal-ca" 2>/dev/null

openssl genrsa -out "${workdir}/server-key.pem" 2048 2>/dev/null
openssl req -new -key "${workdir}/server-key.pem" \
  -out "${workdir}/server.csr" -subj "/CN=web-saas-stunnel-server" 2>/dev/null
openssl x509 -req -in "${workdir}/server.csr" \
  -CA "${workdir}/ca-cert.pem" -CAkey "${workdir}/ca-key.pem" -CAcreateserial \
  -out "${workdir}/server-cert.pem" -days 3650 -sha256 2>/dev/null

STUNNEL_CA_CERT_B64="$(base64 < "${workdir}/ca-cert.pem" | tr -d '\n')"
STUNNEL_SERVER_CERT_B64="$(base64 < "${workdir}/server-cert.pem" | tr -d '\n')"
STUNNEL_SERVER_KEY_B64="$(base64 < "${workdir}/server-key.pem" | tr -d '\n')"

echo "==> 写入 kv/data/WEB_SAAS"
vault kv patch kv/WEB_SAAS \
  POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
  ACCOUNT_PG_PASSWORD="${ACCOUNT_PG_PASSWORD}" \
  AUTH_TOKEN_PUBLIC_TOKEN="${AUTH_TOKEN_PUBLIC_TOKEN}" \
  AUTH_TOKEN_REFRESH_SECRET="${AUTH_TOKEN_REFRESH_SECRET}" \
  AUTH_TOKEN_ACCESS_SECRET="${AUTH_TOKEN_ACCESS_SECRET}" \
  STUNNEL_CA_CERT_B64="${STUNNEL_CA_CERT_B64}" \
  STUNNEL_SERVER_CERT_B64="${STUNNEL_SERVER_CERT_B64}" \
  STUNNEL_SERVER_KEY_B64="${STUNNEL_SERVER_KEY_B64}"

echo "==> 校验(不打印值, 只列键名)"
vault kv get -format=json kv/WEB_SAAS | python3 -c "
import json, sys
d = json.load(sys.stdin)['data']['data']
required = ['POSTGRES_PASSWORD', 'ACCOUNT_PG_PASSWORD', 'AUTH_TOKEN_PUBLIC_TOKEN',
            'AUTH_TOKEN_REFRESH_SECRET', 'AUTH_TOKEN_ACCESS_SECRET',
            'STUNNEL_CA_CERT_B64', 'STUNNEL_SERVER_CERT_B64', 'STUNNEL_SERVER_KEY_B64']
missing = [k for k in required if not d.get(k, '').strip()]
print('  keys present:', sorted(d.keys()))
if missing:
    print('  MISSING:', missing); sys.exit(1)
print('  all required keys present and non-empty')
"

echo
echo "完成。以下是可选键, 只在你真的接了对应的第三方登录 / 计费口径时才需要:"
echo "  BILLING_DB_PASSWORD, OAUTH_GITHUB_CLIENT_{ID,SECRET}, OAUTH_GOOGLE_CLIENT_{ID,SECRET}"
echo "  vault kv patch kv/WEB_SAAS OAUTH_GITHUB_CLIENT_ID=... OAUTH_GITHUB_CLIENT_SECRET=..."
