#!/usr/bin/env bash
set -euo pipefail

: "${MATRIX_HOST:?MATRIX_HOST must be set (pass matrix.host via step env)}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set from the Vault OIDC login}"

ansible-playbook \
  -i ../cmdb/inventory.ini \
  -l "${MATRIX_HOST}" \
  setup-Doco-CD.yaml
