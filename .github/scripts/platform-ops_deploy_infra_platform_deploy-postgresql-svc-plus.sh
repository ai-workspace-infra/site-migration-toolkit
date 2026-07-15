#!/bin/bash
jq -n --arg pw "$POSTGRES_ROOT_PASSWORD" \
  '{postgresql_service_postgres_env_defaults: {POSTGRES_USER: "postgres", POSTGRES_PASSWORD: $pw, POSTGRES_DB: "postgres", PG_LOCAL_PORT: "5432", PG_MAJOR: "17", PG_DATA_PATH: "/data"}}' \
  > /tmp/postgres-env-vars.json
ansible-playbook -i ../cmdb/inventory.ini deploy_postgresql_svc_plus.yml \
  -e "postgresql_service_hosts=${{ matrix.host }}" \
  -e @/tmp/postgres-env-vars.json
