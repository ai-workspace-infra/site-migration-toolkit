#!/bin/bash
if [ "${{ github.event.inputs.run_provision_and_deploy }}" = "true" ]; then
  INVENTORY_PATH="../cmdb/inventory.ini"
else
  INVENTORY_PATH="../platform-ops-toolkit/inventory.ini"
fi
cd playbooks
ansible-playbook -i "$INVENTORY_PATH" update_site_dns.yml -e "target_domain=${{ needs.provision.outputs.target_domain_base }}" -e "source_domain=${{ needs.provision.outputs.source_domain_base }}"
