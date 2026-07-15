#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_zitadel_docker.yaml \
  -e "zitadel_hosts=${MATRIX_HOST}" \
  -e "domain=iam${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}"
