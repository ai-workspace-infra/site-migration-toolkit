#!/bin/bash
if [ "${INPUT_RUN_PROVISION_AND_DEPLOY}" = "true" ]; then
  INVENTORY_PATH="../cmdb/inventory.ini"
else
  INVENTORY_PATH="../platform-ops-toolkit/inventory.ini"
fi
cd playbooks
ansible-playbook -i "$INVENTORY_PATH" update_site_dns.yml -e "target_domain=${PROVISION_TARGET_DOMAIN_BASE}" -e "source_domain=${PROVISION_SOURCE_DOMAIN_BASE}"
