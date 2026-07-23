#!/bin/bash
set -euo pipefail

write_output() {
  local key="$1"
  local val="$2"
  echo "${key}<<EOF" >> "$GITHUB_OUTPUT"
  echo "${val}" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
}

hosts="$(jq -c 'keys' cmdb.json)"
hosts_web_saas="$(jq -c '[to_entries[] | select(.value.groups // [] | contains(["web_saas"])) | .key]' cmdb.json)"
hosts_ai_workspace="$(jq -c '[to_entries[] | select(.value.groups // [] | contains(["ai_workspace"])) | .key]' cmdb.json)"
hosts_infra_platform="$(jq -c '[to_entries[] | select(.value.groups // [] | contains(["infra_platform"])) | .key]' cmdb.json)"
hosts_agent_proxy="$(jq -c '[to_entries[] | select(.value.groups // [] | contains(["agent_proxy"])) | .key]' cmdb.json)"
count="$(jq 'length' cmdb.json)"

write_output "hosts" "${hosts}"
write_output "hosts_web_saas" "${hosts_web_saas}"
write_output "hosts_ai_workspace" "${hosts_ai_workspace}"
write_output "hosts_infra_platform" "${hosts_infra_platform}"
write_output "hosts_agent_proxy" "${hosts_agent_proxy}"
write_output "count" "${count}"
