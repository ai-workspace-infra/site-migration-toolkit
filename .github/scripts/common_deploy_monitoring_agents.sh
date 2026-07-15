#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_node_process_exporters.yml \
  --limit "${MATRIX_HOST}" \
  -e "vector_prometheus_remote_write_url=https://observability${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}/ingest/metrics/api/v1/write"
