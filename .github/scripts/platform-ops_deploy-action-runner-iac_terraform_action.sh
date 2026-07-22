#!/usr/bin/env bash
set -e
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env TERRAFORM_ACTION

TERRAFORM_ACTION="${TERRAFORM_ACTION:-apply}"

terraform "${TERRAFORM_ACTION}" -auto-approve -input=false
