#!/bin/bash
set -euo pipefail

: "${MATRIX_HOST:?MATRIX_HOST must be set (pass matrix.host via step env)}"
# GHCR credentials come from kv/data/CICD (GHCR_USERNAME + GHCR_TOKEN, the latter
# mapped to GHCR_PASSWORD). vault-action runs with ignoreNotFound, so a missing or
# renamed key yields an empty value — fail here rather than docker-login with it.
: "${GHCR_USERNAME:?GHCR_USERNAME is empty (check kv/data/CICD GHCR_USERNAME)}"
: "${GHCR_PASSWORD:?GHCR_PASSWORD is empty (check kv/data/CICD GHCR_TOKEN)}"

# cmdb.json is keyed by host FQDN; resolve via --arg so the host name is expanded
# by the shell, not treated as a literal jq key.
ip="$(jq -r --arg h "${MATRIX_HOST}" '.[$h].ip' cmdb/cmdb.json)"
user="$(jq -r --arg h "${MATRIX_HOST}" '.[$h].ansible_user // "root"' cmdb/cmdb.json)"
if [ -z "${ip}" ] || [ "${ip}" = "null" ]; then
  echo "::error::host '${MATRIX_HOST}' not found in cmdb/cmdb.json (ip=${ip})" >&2
  exit 1
fi

ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)
printf '%s' "$GHCR_PASSWORD" \
  | ssh "${ssh_opts[@]}" "${user}@${ip}" \
      "docker login ghcr.io -u '$GHCR_USERNAME' --password-stdin"
