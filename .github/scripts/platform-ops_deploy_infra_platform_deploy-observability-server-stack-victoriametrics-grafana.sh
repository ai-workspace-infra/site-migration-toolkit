#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_observability.yml \
  -e "observability_server_hosts=${{ matrix.host }}"
