#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
ansible-playbook -i ../cmdb/inventory.ini deploy_stunnel-client.yml \
  -e "stunnel_client_hosts=${MATRIX_HOST}"
