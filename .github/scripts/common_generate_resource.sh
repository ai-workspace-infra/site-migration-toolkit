#!/usr/bin/env bash
set -e

CMD="${1:-render}"
RESOURCE_NAME="${RESOURCE_NAME:-action-runner}"
VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"

python3 scripts/generate.py "${CMD}" \
  --resources "config/resources/${VAULT_ENV_PATH}/${RESOURCE_NAME}.yaml" \
  --workdir "envs/${RESOURCE_NAME}"
