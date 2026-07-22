#!/usr/bin/env bash
set -e

TERRAFORM_ACTION="${TERRAFORM_ACTION:-${ENV_STEPS_ROUTE_OUTPUTS_TERRAFORM_ACTION:-apply}}"

terraform "${TERRAFORM_ACTION}" -auto-approve -input=false
