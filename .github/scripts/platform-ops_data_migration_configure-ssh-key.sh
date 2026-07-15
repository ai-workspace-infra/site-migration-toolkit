#!/bin/bash
mkdir -p ~/.ssh
printf '%s' "${VAULT_ANSIBLE_SSH_KEY_B64}" | base64 -d > ~/.ssh/id_deploy
chmod 600 ~/.ssh/id_deploy
