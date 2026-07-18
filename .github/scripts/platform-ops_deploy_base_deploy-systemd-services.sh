#!/usr/bin/env bash
set -e

ansible-playbook -i cmdb/inventory.ini deploy_gateway_openclaw.yml --limit $MATRIX_HOST
ansible-playbook -i cmdb/inventory.ini deploy_agent_hermes.yml --limit $MATRIX_HOST
