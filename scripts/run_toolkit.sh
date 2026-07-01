#!/bin/bash
set -euo pipefail

ACTION=$1

if [[ -z "$ACTION" ]]; then
  echo "Usage: $0 <migrate|backup|restore>"
  exit 1
fi

PLAYBOOK_DIR="../playbooks"
INVENTORY_DIR="../cmdb"

if [[ ! -d "$PLAYBOOK_DIR" ]]; then
  echo "[ERROR] Cannot find playbooks directory at $PLAYBOOK_DIR"
  echo "Make sure ai-workspace-infra/playbooks is checked out."
  exit 1
fi

if [[ ! -f "$INVENTORY_DIR/inventory" ]] && [[ ! -f "$INVENTORY_DIR/inventory.ini" ]] && [[ ! -f "cmdb/inventory" ]]; then
  echo "[WARNING] Cannot find cmdb/inventory. Assuming manual inventory or default."
fi

# In GitHub Actions, cmdb is at the root of site-recovery. Locally it might be ../cmdb.
INV_PATH="cmdb/inventory"
if [[ ! -f "$INV_PATH" ]]; then
  if [[ -f "../cmdb/inventory" ]]; then
    INV_PATH="../cmdb/inventory"
  elif [[ -f "../cmdb/inventory.ini" ]]; then
    INV_PATH="../cmdb/inventory.ini"
  fi
fi

PLAYBOOK_FILE="${ACTION}_site.yml"

echo "[INFO] Starting Toolkit Action: $ACTION"
echo "[INFO] Playbook: $PLAYBOOK_DIR/$PLAYBOOK_FILE"

cd "$PLAYBOOK_DIR"

if [[ -f "../site-recovery/$INV_PATH" ]]; then
  ansible-playbook -i "../site-recovery/$INV_PATH" "$PLAYBOOK_FILE" "${@:2}"
elif [[ -f "../cmdb/inventory" ]]; then
  ansible-playbook -i "../cmdb/inventory" "$PLAYBOOK_FILE" "${@:2}"
else
  echo "[WARNING] No inventory found. Running playbook without explicit inventory flag."
  ansible-playbook "$PLAYBOOK_FILE" "${@:2}"
fi

echo "[INFO] Toolkit Action $ACTION completed."
