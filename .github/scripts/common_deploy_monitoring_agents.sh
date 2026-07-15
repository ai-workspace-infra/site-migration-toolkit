#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_node_process_exporters.yml \
  --limit "${{ matrix.host }}" \
  -e "vector_prometheus_remote_write_url=https://observability${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}/ingest/metrics/api/v1/write"
