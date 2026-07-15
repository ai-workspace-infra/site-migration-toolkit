#!/bin/bash
set -euo pipefail
for key in BILLING_DATABASE_URL INTERNAL_SERVICE_TOKEN GHCR_USERNAME GHCR_PASSWORD ACCOUNT_PG_PASSWORD POSTGRES_ROOT_PASSWORD; do
  if [ -z "${!key:-}" ]; then
    echo "Required web-saas secret $key is absent for ${DEPLOY_ENV}." >&2
    exit 1
  fi
done
