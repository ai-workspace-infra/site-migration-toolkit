#!/bin/bash
terraform workspace select -or-create ${ENV_STEPS_ROUTE_OUTPUTS_TERRAFORM_WORKSPACE}
terraform ${ENV_STEPS_ROUTE_OUTPUTS_TERRAFORM_ACTION} -auto-approve -input=false
