#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini create_databases_and_users.yml \
  --limit "${MATRIX_HOST}"
