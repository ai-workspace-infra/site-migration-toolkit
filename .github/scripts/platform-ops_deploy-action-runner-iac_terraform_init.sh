#!/usr/bin/env bash
set -e

VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"

terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=action-runner-${VAULT_ENV_PATH}/terraform.tfstate" \
  -backend-config="region=${TF_STATE_REGION}"
