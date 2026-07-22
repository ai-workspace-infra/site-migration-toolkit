#!/usr/bin/env bash
set -e
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env VAULT_ENV_PATH TF_STATE_BUCKET TF_STATE_REGION

VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"

terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=action-runner-${VAULT_ENV_PATH}/terraform.tfstate" \
  -backend-config="region=${TF_STATE_REGION}"
