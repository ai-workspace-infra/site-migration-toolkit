#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
ansible-playbook -i ../cmdb/inventory.ini setup-vault.yaml \
  --limit "${MATRIX_HOST}"
