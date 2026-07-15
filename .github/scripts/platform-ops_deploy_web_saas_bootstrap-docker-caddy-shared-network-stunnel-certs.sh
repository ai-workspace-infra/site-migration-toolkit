#!/bin/bash
cat > /tmp/web-saas-bootstrap.yml <<'EOF'
- name: Ensure Docker engine, Caddy, shared network, and stunnel certs exist
  hosts: "{{ target_host }}"
  become: true
  gather_facts: true
  roles:
    - roles/vhosts/docker
    # accounts/console 角色只往 conf.d 写 fragment 并 reload caddy
    # 服务, 它们假设 Caddy 本体已经安装; 全新主机需要在这里装好
    - roles/vhosts/caddy
    - roles/host/stunnel-certs
  tasks:
    # 早期 run 渲染 of fragment 用 {$SERVED_DOMAINS} 环境变量占位符做
    # 站点键, systemd 下展开为空键, 会让后续所有服务的 caddy validate
    # 失败; 各服务角色的清理只清自己且跑得太晚, 在这里统一清掉
    - name: Remove stale Caddy fragments keyed on env placeholders
      ansible.builtin.shell: |
        set -euo pipefail
        stale="$(grep -l '{\$SERVED_DOMAINS}' /etc/caddy/conf.d/*.caddy 2>/dev/null || true)"
        if [ -n "${stale}" ]; then
          rm -f ${stale}
          echo "removed: ${stale}"
        fi
      args:
        executable: /bin/bash
      register: stale_caddy_fragments
      changed_when: stale_caddy_fragments.stdout | trim != ""
    - name: Check for cn-toolkit-shared Docker network
      ansible.builtin.command: docker network inspect cn-toolkit-shared
      register: shared_network_inspect
      changed_when: false
      failed_when: false
    - name: Create cn-toolkit-shared Docker network when missing
      ansible.builtin.command: docker network create cn-toolkit-shared
      when: shared_network_inspect.rc != 0
EOF
ansible-playbook -i ../cmdb/inventory.ini /tmp/web-saas-bootstrap.yml \
  -e "target_host=${MATRIX_HOST}"
