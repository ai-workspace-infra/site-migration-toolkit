#!/usr/bin/env bash
set -e

VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"
STATE_KEY="${STATE_KEY:-${ENV_STEPS_ROUTE_OUTPUTS_STATE_KEY:-action-runner-${VAULT_ENV_PATH}/terraform.tfstate}}"

terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${STATE_KEY}" \
  -backend-config="region=${TF_STATE_REGION}"
