#!/usr/bin/env bash
set -e

VAULT_ENV_PATH="${VAULT_ENV_PATH:-uat}"

python3 scripts/generate.py render \
  --resources "config/resources/${VAULT_ENV_PATH}/action-runner.yaml" \
  --workdir "envs/action-runner"
