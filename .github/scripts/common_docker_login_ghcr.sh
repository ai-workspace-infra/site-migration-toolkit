#!/bin/bash
ip="$(jq -r '.["${MATRIX_HOST}"].ip' cmdb/cmdb.json)"
user="$(jq -r '.["${MATRIX_HOST}"].ansible_user // "root"' cmdb/cmdb.json)"
ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)
printf '%s' "$GHCR_PASSWORD" \
  | ssh "${ssh_opts[@]}" "${user}@${ip}" \
      "docker login ghcr.io -u '$GHCR_USERNAME' --password-stdin"
