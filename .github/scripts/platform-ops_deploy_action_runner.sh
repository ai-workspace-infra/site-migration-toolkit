#!/usr/bin/env bash
set -e

ansible-playbook -i ../cmdb/inventory.ini deploy_action_runner.yml \
  --limit $MATRIX_HOST \
  -e "runner_engine=${RUNNER_ENGINE}" \
  -e "github_org_repo=${GITHUB_ORG_REPO}" \
  -e "github_runner_token=${GITHUB_RUNNER_TOKEN}" \
  -e "gitea_instance_url=${GITEA_INSTANCE_URL}" \
  -e "gitea_runner_token=${GITEA_RUNNER_TOKEN}" \
  -e "runner_labels=self-hosted,ubuntu,iac-runner,${VAULT_ENV_PATH}"
