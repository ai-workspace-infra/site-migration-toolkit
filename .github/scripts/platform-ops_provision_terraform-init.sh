#!/bin/bash
terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=${{ steps.route.outputs.state_key }}"
