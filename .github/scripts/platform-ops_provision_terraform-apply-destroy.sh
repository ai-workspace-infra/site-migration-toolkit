#!/bin/bash
set -euo pipefail

terraform workspace select -or-create "${ENV_STEPS_ROUTE_OUTPUTS_TERRAFORM_WORKSPACE}"

ACTION="${ENV_STEPS_ROUTE_OUTPUTS_TERRAFORM_ACTION}"
case "${ACTION}" in
  plan)
    # plan 不接受 -auto-approve; 也不产生任何变更。
    terraform plan -input=false
    ;;
  apply|destroy)
    terraform "${ACTION}" -auto-approve -input=false
    ;;
  *)
    echo "::error::unsupported terraform action: ${ACTION}" >&2
    exit 1
    ;;
esac
