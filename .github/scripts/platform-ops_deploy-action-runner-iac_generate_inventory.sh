#!/usr/bin/env bash
set -e
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env VAULT_ENV_PATH

VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"

python3 scripts/generate.py inventory \
  --resources "config/resources/${VAULT_ENV_PATH}/action-runner.yaml" \
  --workdir "envs/action-runner"
