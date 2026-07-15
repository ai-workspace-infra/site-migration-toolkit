#!/bin/bash
jq -n \
  --arg hosts "${MATRIX_HOST}" \
  --arg image "ghcr.io/ai-workspace-services/console:latest" \
  --arg user "$GHCR_USERNAME" \
  --arg pass "$GHCR_PASSWORD" \
  --arg domain "console${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}" \
  '{console_service_target_host: $hosts, console_service_frontend_image: $image, console_service_registry_username: $user, console_service_registry_password: $pass, CANONICAL_DOMAIN: $domain, SERVED_DOMAINS: $domain}' \
  > /tmp/console-vars.json
ansible-playbook -i ../cmdb/inventory.ini deploy_console_svc_plus.yml \
  -e @/tmp/console-vars.json
