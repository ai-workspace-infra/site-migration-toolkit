#!/bin/bash
URL="${VAULT_ADDR}/v1/kv/data/${VAULT_ENV_PATH}/databases"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Vault-Token: $VAULT_TOKEN" "$URL")
if [ "$STATUS" = "404" ]; then
  echo "Initializing databases credentials..."
  PAYLOAD=$(jq -n \
    --arg postgres_root_password "$(openssl rand -base64 16)" \
    --arg account_pg_password "$(openssl rand -base64 16)" \
    --arg litellm_pg_password "$(openssl rand -base64 16)" \
    --arg rag_pg_password "$(openssl rand -base64 16)" \
    --arg zitadel_pg_password "$(openssl rand -base64 16)" \
    --arg gitea_pg_password "$(openssl rand -base64 16)" \
    --arg vault_pg_password "$(openssl rand -base64 16)" \
    --arg billing_pg_password "$(openssl rand -base64 16)" \
    '{data: {postgres_root_password: $postgres_root_password, account_pg_password: $account_pg_password, litellm_pg_password: $litellm_pg_password, rag_pg_password: $rag_pg_password, zitadel_pg_password: $zitadel_pg_password, gitea_pg_password: $gitea_pg_password, vault_pg_password: $vault_pg_password, billing_pg_password: $billing_pg_password}}')
  curl -sS -X POST -H "X-Vault-Token: $VAULT_TOKEN" -H "Content-Type: application/json" -d "$PAYLOAD" "$URL"
else
  echo "Credentials already exist (Status: $STATUS). Skipping."
fi
