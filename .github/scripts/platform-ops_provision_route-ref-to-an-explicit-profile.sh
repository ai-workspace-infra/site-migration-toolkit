#!/bin/bash
set -euo pipefail

# -----------------------------------------------------------------------------
# 域名基准集中定义, 各分支不要再各写各的字面量。
#
# 主机名由 TARGET_DOMAIN_BASE 拼接 (见 config/resources/*/*.yaml 里的
# console-nat.{{ TARGET_DOMAIN_BASE }}), 而 uat 的多条触发路径共用同一个
# terraform workspace 与 state。一旦取值不一致, 同一份 state 就会被要求
# 提供名字不同的资源, terraform 会销毁一台再建一台。
#
# SOURCE 是迁移的来源 (生产站点), TARGET 是要部署/发布到的站点。
# -----------------------------------------------------------------------------
SOURCE_HOST_DEFAULT="install.svc.plus"
SOURCE_DOMAIN_BASE_DEFAULT="svc.plus"
TARGET_DOMAIN_BASE_DEFAULT="onwalk.net"
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

  case "${deployment_env}" in
    sit) env_suffix=-sit ;;
    uat) env_suffix=-uat ;;
    prod) env_suffix="" ;;
    *)
      echo "Unsupported workflow_dispatch vault_env_path: ${deployment_env}" >&2
      exit 1
      ;;
  esac
  
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
  GITHUB_EVENT_NAME="${GITHUB_EVENT_NAME:-}"
  if [ "${GITHUB_EVENT_NAME}" = "pull_request" ]; then
    deployment_env=sit; resource_file=sit/all-in-one; terraform_workspace=all-in-one-sit
    state_key=platform-ops-toolkit/sit/all-in-one.tfstate; run=true; target_domains=all
    # PR 只做 terraform plan, 不 apply。四个 deploy job 都要求
    # terraform_action == 'apply', 所以 plan 会让它们全部 skip ——
    # PR 仍然校验 terraform 配置, 但不再创建真实 VPS。
    terraform_action=plan; toolkit_action=none; infra_ref=main; console_ref=main; offline_mode=off
    source_host="${SOURCE_HOST_DEFAULT}"; source_domain_base="${SOURCE_DOMAIN_BASE_DEFAULT}"; target_domain_base="${TARGET_DOMAIN_BASE_DEFAULT}"; env_suffix=-sit; confirm_dns_switch=false
  else
    case "${GITHUB_REF}" in
      refs/heads/main|refs/heads/release/*)
        deployment_env=uat; resource_file=uat/web-saas; terraform_workspace=web-saas-uat
        state_key=platform-ops-toolkit/uat/web-saas.tfstate; run=true; target_domains=web-saas
        terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
        source_host="${SOURCE_HOST_DEFAULT}"; source_domain_base="${SOURCE_DOMAIN_BASE_DEFAULT}"; target_domain_base="${TARGET_DOMAIN_BASE_DEFAULT}"; env_suffix=-uat; confirm_dns_switch=false
        ;;
      refs/tags/v*)
        deployment_env=prod; resource_file=prod/web-saas; terraform_workspace=web-saas-prod
        state_key=platform-ops-toolkit/prod/web-saas.tfstate; run=true; target_domains=web-saas
        terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
        source_host="${SOURCE_HOST_DEFAULT}"; source_domain_base="${SOURCE_DOMAIN_BASE_DEFAULT}"; target_domain_base="${TARGET_DOMAIN_BASE_DEFAULT}"; env_suffix=""; confirm_dns_switch=false
        ;;
      *)
        deployment_env=sit; resource_file=sit/all-in-one; terraform_workspace=all-in-one-sit
        state_key=platform-ops-toolkit/sit/all-in-one.tfstate; run=true; target_domains=all
        terraform_action=apply; toolkit_action=deploy; infra_ref=main; console_ref=main; offline_mode=off
        source_host="${SOURCE_HOST_DEFAULT}"; source_domain_base="${SOURCE_DOMAIN_BASE_DEFAULT}"; target_domain_base="${TARGET_DOMAIN_BASE_DEFAULT}"; env_suffix=-sit; confirm_dns_switch=false
        ;;
    esac
  fi
fi
for key in deployment_env resource_file terraform_workspace state_key run target_domains terraform_action toolkit_action infra_ref console_ref offline_mode source_host source_domain_base target_domain_base env_suffix confirm_dns_switch; do
  value="${!key:-}"
  case "$key" in run) echo "run_provision_and_deploy=$value" ;; *) echo "$key=$value" ;; esac >> "$GITHUB_OUTPUT"
done
echo "vault_env_path=${deployment_env}" >> "$GITHUB_OUTPUT"
