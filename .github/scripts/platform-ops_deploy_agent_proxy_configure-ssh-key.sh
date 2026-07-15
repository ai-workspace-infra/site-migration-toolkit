#!/bin/bash
mkdir -p ~/.ssh
printf '%s' "${{ steps.vault.outputs.ANSIBLE_SSH_KEY_B64 }}" | base64 -d > ~/.ssh/id_deploy
chmod 600 ~/.ssh/id_deploy
ssh-keygen -y -f ~/.ssh/id_deploy >/dev/null
