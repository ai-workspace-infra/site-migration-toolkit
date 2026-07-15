#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_stunnel-client.yml \
  -e "stunnel_client_hosts=${{ matrix.host }}"
