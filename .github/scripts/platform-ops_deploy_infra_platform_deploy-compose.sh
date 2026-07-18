#!/usr/bin/env bash
set -e

ansible -i cmdb/inventory.ini $MATRIX_HOST -m file -a "path=/opt/infra-platform-compose state=directory"
ansible -i cmdb/inventory.ini $MATRIX_HOST -m synchronize -a "src=playbooks/roles/vhosts/docker-compose/infra-platform/ dest=/opt/infra-platform-compose/"

# Run compose up
ansible -i cmdb/inventory.ini $MATRIX_HOST -m command -a "docker compose -f /opt/infra-platform-compose/docker-compose.yml up -d --build"
