#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
ansible-playbook -i ../cmdb/inventory.ini deploy_observability.yml \
  -e "observability_server_hosts=${MATRIX_HOST}"
