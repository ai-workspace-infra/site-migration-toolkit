#!/bin/bash
terraform workspace select -or-create ${{ steps.route.outputs.terraform_workspace }}
terraform ${{ steps.route.outputs.terraform_action }} -auto-approve -input=false
