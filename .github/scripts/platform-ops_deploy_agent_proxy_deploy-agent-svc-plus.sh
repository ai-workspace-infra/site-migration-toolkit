#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_xray_proxy_server.yml \
  -e "agent_service_hosts=${{ matrix.host }}" \
  -e "agent_controller_url=https://accounts${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}" \
  -e "agent_id=${{ matrix.host }}" \
  -e "xray_uuid=${XRAY_UUID}" \
  -e "agent_svc_plus_manage_source_checkout=true" \
  -e "agent_svc_plus_build_on_target=true"
