#!/bin/bash
# pipefail matters here: without it a failing `docker save` is masked by a
# succeeding ssh, shipping nothing while the step still reports success.
set -euo pipefail

: "${MATRIX_HOST:?MATRIX_HOST must be set (pass matrix.host via step env)}"

# cmdb.json is keyed by host FQDN; resolve via --arg so the host name is expanded
# by the shell, not treated as a literal jq key.
ip="$(jq -r --arg h "${MATRIX_HOST}" '.[$h].ip' cmdb/cmdb.json)"
user="$(jq -r --arg h "${MATRIX_HOST}" '.[$h].ansible_user // "root"' cmdb/cmdb.json)"
if [ -z "${ip}" ] || [ "${ip}" = "null" ]; then
  echo "::error::host '${MATRIX_HOST}' not found in cmdb/cmdb.json (ip=${ip})" >&2
  exit 1
fi

ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)
docker save postgres-extensions:17 | gzip \
  | ssh "${ssh_opts[@]}" "${user}@${ip}" 'gunzip | docker load'
