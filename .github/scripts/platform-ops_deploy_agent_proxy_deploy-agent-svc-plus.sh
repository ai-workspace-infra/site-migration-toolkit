#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_xray_proxy_server.yml \
  -e "agent_service_hosts=${MATRIX_HOST}" \
  -e "agent_controller_url=https://accounts${PROVISION_ENV_SUFFIX}.${PROVISION_TARGET_DOMAIN_BASE}" \
  -e "agent_id=${MATRIX_HOST}" \
  -e "xray_uuid=${XRAY_UUID}" \
  -e "agent_svc_plus_manage_source_checkout=true" \
  -e "agent_svc_plus_build_on_target=true"
