#!/bin/bash
jq -n \
  --arg artifact "${{ github.workspace }}/billing-service/dist/billing-service-linux-amd64" \
  --arg image_ref "ghcr.io/ai-workspace-services/billing-service:${{ github.sha }}" \
  --arg db_url "$BILLING_DATABASE_URL" \
  --arg token "$INTERNAL_SERVICE_TOKEN" \
  --arg hosts "${{ matrix.host }}" \
  '{billing_service_hosts: $hosts, billing_service_binary_artifact: $artifact, billing_service_image_ref: $image_ref, billing_service_database_url: $db_url, billing_service_internal_service_token: $token}' \
  > /tmp/billing-service-vars.json
ansible-playbook -i ../cmdb/inventory.ini deploy_billing_service.yml \
  -e @/tmp/billing-service-vars.json
