#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST

# cwd is the playbooks checkout (working-directory: playbooks); the CMDB artifact
# is downloaded to <repo-root>/cmdb, i.e. ../cmdb from here.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="../cmdb/inventory.ini"

# Guard: ansible-playbook --limit exits 0 even when it matches no host, which
# turns a broken inventory path into a silent no-op. Assert reachability first.
"${DIR}/common_assert_ansible_host.sh" "${INVENTORY}" "${MATRIX_HOST}"

ansible-playbook -i "${INVENTORY}" deploy_gateway_openclaw.yml --limit "${MATRIX_HOST}"
ansible-playbook -i "${INVENTORY}" deploy_agent_hermes.yml --limit "${MATRIX_HOST}"
