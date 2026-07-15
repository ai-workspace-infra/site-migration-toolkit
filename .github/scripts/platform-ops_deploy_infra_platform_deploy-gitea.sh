#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini gitea_deploy_temp.yml \
  --limit "${{ matrix.host }}"
