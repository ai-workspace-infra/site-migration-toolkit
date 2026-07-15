#!/bin/bash
ip="$(jq -r '.["${{ matrix.host }}"].ip' cmdb/cmdb.json)"
user="$(jq -r '.["${{ matrix.host }}"].ansible_user // "root"' cmdb/cmdb.json)"
ssh_opts=(-i ~/.ssh/id_deploy -o StrictHostKeyChecking=no -o BatchMode=yes)

# Ensure 'account' database exists
ssh "${ssh_opts[@]}" "${user}@${ip}" \
  "docker exec -i postgresql psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname = 'account'\" | grep -q 1 || docker exec -i postgresql psql -U postgres -c 'CREATE DATABASE account;'"

pg="docker exec -i postgresql psql -U postgres -d account"
has_users="$(ssh "${ssh_opts[@]}" "${user}@${ip}" \
  "$pg -tAc \"SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='users'\"" || true)"
if [ "${has_users}" = "1" ]; then
  echo "account schema already present; skipping baseline init"
else
  ssh "${ssh_opts[@]}" "${user}@${ip}" "$pg -v ON_ERROR_STOP=1 -f -" \
    < accounts-svc-plus/sql/schema.sql
  echo "account baseline schema applied"
fi
