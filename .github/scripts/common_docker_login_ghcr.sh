#!/bin/bash
ip="$(jq -r '.["${{ matrix.host }}"].ip' cmdb/cmdb.json)"
user="$(jq -r '.["${{ matrix.host }}"].ansible_user // "root"' cmdb/cmdb.json)"
ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)
printf '%s' "$GHCR_PASSWORD" \
  | ssh "${ssh_opts[@]}" "${user}@${ip}" \
      "docker login ghcr.io -u '$GHCR_USERNAME' --password-stdin"
