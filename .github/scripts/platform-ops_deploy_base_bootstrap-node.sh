#!/usr/bin/env bash
set -euo pipefail

: "${MATRIX_HOST:?MATRIX_HOST must be set (pass matrix.host via step env)}"

cmdb_file="../cmdb/cmdb.json"
mapfile -t node_groups < <(jq -r --arg host "${MATRIX_HOST}" '.[$host].groups[]? // empty' "${cmdb_file}")

playbook=""
for group in "${node_groups[@]}"; do
  case "${group}" in
    web_saas)
      playbook=setup-Doco-CD.yaml
      break
      ;;
    ai_workspace)
      playbook=setup-ai-workspace-rootless.yml
      break
      ;;
    k3s|k3s_server|k3s_agent)
      playbook=setup-k3s-node.yaml
      ;;
    k8s|k8s_node|gpu_k8s)
      playbook=setup-k8s-node.yaml
      ;;
  esac
done

if [[ -z "${playbook}" ]]; then
  echo "No bootstrap playbook mapping found for ${MATRIX_HOST}; CMDB groups: ${node_groups[*]:-none}" >&2
  exit 1
fi

# vault-action 开着 ignoreNotFound, 键名写错或路径里没这个键都只会拿到空串。
# 不在这里断言的话, 失败会沉到 Doco-CD role 的 assert 里, 报 "Set
# DOCO_CD_GIT_ACCESS_TOKEN" —— 完全没说该去哪个 Vault 路径设。
if [ "${playbook}" = "setup-Doco-CD.yaml" ] && [ -z "${DOCO_CD_GIT_ACCESS_TOKEN:-}" ]; then
  echo "::error::DOCO_CD_GIT_ACCESS_TOKEN is empty; setup-Doco-CD.yaml cannot bootstrap ${MATRIX_HOST}. Set key DOCO_CD_GIT_ACCESS_TOKEN under Vault path ${VAULT_KV:-kv/data/CICD}." >&2
  exit 1
fi

echo "Bootstrapping ${MATRIX_HOST} with ${playbook}"
ansible-playbook -i ../cmdb/inventory.ini -l "${MATRIX_HOST}" "${playbook}"
