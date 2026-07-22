#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
cat > /tmp/infra-platform-bootstrap.yml <<'EOF'
- name: Ensure Docker engine, Caddy, and shared network exist
  hosts: "{{ target_host }}"
  become: true
  gather_facts: true
  roles:
    - roles/vhosts/docker
    - roles/vhosts/caddy
    - roles/host/stunnel-certs
  tasks:
    - name: Check for cn-toolkit-shared Docker network
      ansible.builtin.command: docker network inspect cn-toolkit-shared
      register: shared_network_inspect
      changed_when: false
      failed_when: false
    - name: Create cn-toolkit-shared Docker network when missing
      ansible.builtin.command: docker network create cn-toolkit-shared
      when: shared_network_inspect.rc != 0
EOF
ansible-playbook -i ../cmdb/inventory.ini /tmp/infra-platform-bootstrap.yml \
  -e "target_host=${MATRIX_HOST}"
