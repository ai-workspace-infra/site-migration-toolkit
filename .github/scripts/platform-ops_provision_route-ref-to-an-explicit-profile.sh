#!/bin/bash
set -euo pipefail
# Defaults are intentionally safe: no branch deployment reads a host
# variable. Terraform creates the host and its CMDB is the only deploy
# inventory for that run.
if [ "${GITHUB_EVENT_NAME}" = "workflow_dispatch" ]; then
  deployment_env="${INPUT_VAULT_ENV_PATH}"
  target_domains="${INPUT_TARGET_DOMAINS}"
  
  if [ "${deployment_env}" = "sit" ] && [ "${target_domains}" = "all" ]; then
    rf="all-in-one"
  elif [ "${target_domains}" = "all" ]; then
    rf="web-saas"
  else
    rf="${target_domains}"
  fi
  
  resource_file="${deployment_env}/${rf}"
  terraform_workspace="${rf}-${deployment_env}"
  state_key="platform-ops-toolkit/${deployment_env}/${rf}.tfstate"
  run="${INPUT_RUN_PROVISION_AND_DEPLOY}"
  
  user_action="${INPUT_ACTION}"
  if [ "$user_action" = "destroy" ]; then
    terraform_action="destroy"
    toolkit_action="none"
  else
    terraform_action="apply"
    toolkit_action="$user_action"
  fi
  
  infra_ref="${INPUT_INFRA_REF}"
  console_ref="${INPUT_CONSOLE_REF}"
  offline_mode="${INPUT_OFFLINE_MODE}"
  source_host="${INPUT_SOURCE_HOST}"
  source_domain_base="${INPUT_SOURCE_DOMAIN_BASE}"
  target_domain_base="${INPUT_TARGET_DOMAIN_BASE}"
  confirm_dns_switch="${INPUT_CONFIRM_DNS_SWITCH}"
else
  case "${GITHUB_REF}" in
    refs/heads/main)
      deployment_env=uat; resource_file=uat/web-saas; terraform_workspace=web-saas-uat
      state_key=platform-ops-toolkit/uat/web-saas.tfstate; run=true; target_domains=web-saas
      terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
      source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=svc.plus; env_suffix=-uat; confirm_dns_switch=false
      ;;
    refs/heads/release/*|refs/tags/v*)
      deployment_env=prod; resource_file=prod/web-saas; terraform_workspace=web-saas-prod
      state_key=platform-ops-toolkit/prod/web-saas.tfstate; run=true; target_domains=web-saas
      terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
      source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=onwalk.net; env_suffix=""; confirm_dns_switch=false
      ;;
    *)
      deployment_env=sit; resource_file=sit/all-in-one; terraform_workspace=all-in-one-sit
      state_key=platform-ops-toolkit/sit/all-in-one.tfstate; run=true; target_domains=all
      terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
      source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=svc.plus; env_suffix=-sit; confirm_dns_switch=false
      ;;
  esac
fi
for key in deployment_env resource_file terraform_workspace state_key run target_domains terraform_action toolkit_action infra_ref console_ref offline_mode source_host source_domain_base target_domain_base env_suffix confirm_dns_switch; do
  value="${!key:-}"
  case "$key" in run) echo "run_provision_and_deploy=$value" ;; *) echo "$key=$value" ;; esac >> "$GITHUB_OUTPUT"
done
echo "vault_env_path=${deployment_env}" >> "$GITHUB_OUTPUT"
