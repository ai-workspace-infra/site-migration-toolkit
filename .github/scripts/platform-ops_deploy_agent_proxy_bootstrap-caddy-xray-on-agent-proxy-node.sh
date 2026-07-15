#!/bin/bash
cat > /tmp/agent-proxy-bootstrap.yml <<'EOF'
- name: Bootstrap Caddy and Xray binary on Agent Proxy Node
  hosts: "{{ target_host }}"
  become: true
  gather_facts: true
  roles:
    - roles/vhosts/caddy
  tasks:
    - name: Install Xray binary using XTLS installation script
      ansible.builtin.shell: |
        curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh -o /tmp/install-release.sh
        bash /tmp/install-release.sh
      args:
        creates: /usr/local/bin/xray

    - name: Ensure dummy/template xray-tcp.service is defined
      ansible.builtin.copy:
        dest: /etc/systemd/system/xray-tcp.service
        content: |
          [Unit]
          Description=Xray Service (TCP)
          [Service]
          ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/tcp-config.json
        mode: '0644'

    - name: Ensure dummy/template xray.service is defined
      ansible.builtin.copy:
        dest: /etc/systemd/system/xray.service
        content: |
          [Unit]
          Description=Xray Service (XHTTP)
          [Service]
          ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
        mode: '0644'
EOF
ansible-playbook -i ../cmdb/inventory.ini /tmp/agent-proxy-bootstrap.yml \
  -e "target_host=${{ matrix.host }}"
