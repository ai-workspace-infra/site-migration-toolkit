#!/usr/bin/env bash
set -e

# Ensure dependent DB variables are populated if needed
ansible -i cmdb/inventory.ini $MATRIX_HOST -m file -a "path=/opt/web-saas-compose state=directory"
ansible -i cmdb/inventory.ini $MATRIX_HOST -m synchronize -a "src=playbooks/roles/vhosts/docker-compose/web-saas/ dest=/opt/web-saas-compose/"

# Inject Env
cat <<EOF > .env.saas
BILLING_DATABASE_URL=${BILLING_DATABASE_URL}
INTERNAL_SERVICE_TOKEN=${INTERNAL_SERVICE_TOKEN}
GHCR_USERNAME=${GHCR_USERNAME}
GHCR_PASSWORD=${GHCR_PASSWORD}
POSTGRES_PASSWORD=${POSTGRES_ROOT_PASSWORD}
EOF

ansible -i cmdb/inventory.ini $MATRIX_HOST -m copy -a "src=.env.saas dest=/opt/web-saas-compose/.env"

# Run compose up
ansible -i cmdb/inventory.ini $MATRIX_HOST -m command -a "docker compose -f /opt/web-saas-compose/docker-compose.yml up -d --build"
