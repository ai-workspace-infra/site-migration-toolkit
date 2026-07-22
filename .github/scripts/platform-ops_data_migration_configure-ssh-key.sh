#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env VAULT_ANSIBLE_SSH_KEY_B64
mkdir -p ~/.ssh
printf '%s' "${VAULT_ANSIBLE_SSH_KEY_B64}" | base64 -d > ~/.ssh/id_deploy
chmod 600 ~/.ssh/id_deploy
