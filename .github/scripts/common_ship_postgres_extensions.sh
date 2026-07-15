#!/bin/bash
ip="$(jq -r '.["${MATRIX_HOST}"].ip' cmdb/cmdb.json)"
user="$(jq -r '.["${MATRIX_HOST}"].ansible_user // "root"' cmdb/cmdb.json)"
ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)
docker save postgres-extensions:17 | gzip \
  | ssh "${ssh_opts[@]}" "${user}@${ip}" 'gunzip | docker load'
