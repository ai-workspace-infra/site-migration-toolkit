#!/bin/bash
# 角色默认的 Caddy 站点写死 accounts.svc.plus / svc.plus, 迁移环境
# 必须按目标域参数化, 否则 fragment 服务的是源站域名
jq -n \
  --arg site "accounts${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}" \
  --arg fwd "${{ needs.provision.outputs.target_domain_base }}" \
  '{accounts_service_caddy_sites: [{server_names: [$site], default_forwarded_host: $fwd, upstream: "127.0.0.1:18081"}]}' \
  > /tmp/accounts-caddy-vars.json
ansible-playbook -i ../cmdb/inventory.ini deploy_accounts_svc_plus.yml \
  -e "accounts_service_hosts=${{ matrix.host }}" \
  -e @/tmp/accounts-caddy-vars.json
