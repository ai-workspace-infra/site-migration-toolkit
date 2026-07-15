#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini deploy_xray_exporter.yml \
  -e "xray_exporter_hosts=${MATRIX_HOST}"
