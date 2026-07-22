#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST PROVISION_ENV_SUFFIX PROVISION_TARGET_DOMAIN_BASE
ansible-playbook -i ../cmdb/inventory.ini deploy_node_process_exporters.yml \
  --limit "${MATRIX_HOST}" \
  -e "vector_prometheus_remote_write_url=https://observability${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}/ingest/metrics/api/v1/write"
