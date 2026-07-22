#!/usr/bin/env bash
set -e

# Sync docker-compose files to host
ansible -i cmdb/inventory.ini $MATRIX_HOST -m file -a "path=/opt/ai-workspace-compose state=directory"
ansible -i cmdb/inventory.ini $MATRIX_HOST -m synchronize -a "src=playbooks/roles/vhosts/docker-compose/ai-workspace/ dest=/opt/ai-workspace-compose/"

# Run compose up
ansible -i cmdb/inventory.ini $MATRIX_HOST -m command -a "docker compose -f /opt/ai-workspace-compose/docker-compose.yml up -d --build"
