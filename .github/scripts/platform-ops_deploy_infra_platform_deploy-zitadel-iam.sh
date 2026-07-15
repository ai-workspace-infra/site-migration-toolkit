#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_zitadel_docker.yaml \
  -e "zitadel_hosts=${{ matrix.host }}" \
  -e "domain=iam${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}"
