#!/bin/bash
ansible-playbook -i ../cmdb/inventory.ini setup-vault.yaml \
  --limit "${{ matrix.host }}"
