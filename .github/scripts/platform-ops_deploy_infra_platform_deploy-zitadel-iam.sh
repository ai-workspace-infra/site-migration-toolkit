#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST PROVISION_ENV_SUFFIX PROVISION_TARGET_DOMAIN_BASE
ansible-playbook -i ../cmdb/inventory.ini deploy_zitadel_docker.yaml \
  -e "zitadel_hosts=${MATRIX_HOST}" \
  -e "domain=iam${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}"
