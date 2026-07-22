#!/usr/bin/env bash
set -euo pipefail

# cwd is the playbooks checkout (working-directory: playbooks); the CMDB artifact
# is downloaded to <repo-root>/cmdb, i.e. ../cmdb from here.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="../cmdb/inventory.ini"

# Guard: a wrong inventory path or host name makes every ansible call below a
# no-op that still exits 0. Assert the target is real and reachable first.
"${DIR}/common_assert_ansible_host.sh" "${INVENTORY}" "${MATRIX_HOST}"

# Sync docker-compose files to host (src is relative to cwd).
ansible -i "${INVENTORY}" "${MATRIX_HOST}" -m file -a "path=/opt/ai-workspace-compose state=directory"
ansible -i "${INVENTORY}" "${MATRIX_HOST}" -m synchronize -a "src=roles/vhosts/docker-compose/ai-workspace/ dest=/opt/ai-workspace-compose/"

# Run compose up
ansible -i "${INVENTORY}" "${MATRIX_HOST}" -m command -a "docker compose -f /opt/ai-workspace-compose/docker-compose.yml up -d --build"
