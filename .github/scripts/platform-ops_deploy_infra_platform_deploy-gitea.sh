#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
ansible-playbook -i ../cmdb/inventory.ini gitea_deploy_temp.yml \
  --limit "${MATRIX_HOST}"
