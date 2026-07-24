# Handover Notes: CD Pipeline & DNS Switch Debugging

## Goal
Run the `platform-ops.yaml` pipeline end-to-end to verify the deployment of the `web-saas` stack on a UAT environment (using `action=resize` to bypass Vultr downgrade limitations) all the way to the DNS switch using Cloudflare.

## Current State
- **Status**: Blocked by Vault Branch Restrictions (Security Policy).
- **PR**: [PR #105](https://github.com/ai-workspace-infra/platform-ops-toolkit/pull/105) contains all necessary fixes but is waiting for human approval/merge due to branch protection and strict no-admin-bypass rules.

## Issues Identified & Fixed (in PR #105)

### 1. Database Passwords Vault Path Mismatch
- **Error**: `Unable to retrieve result for data.data."BILLING_DB_PASSWORD".`
- **Root Cause**: The initialization script (`platform-ops_provision_initialize-databases-credentials.sh`) correctly stores new database passwords in `kv/data/uat/databases`. However, `platform-ops.yaml` was still trying to read them from the legacy path `kv/data/WEB_SAAS`.
- **Fix**: Updated `platform-ops.yaml` to read `POSTGRES_PASSWORD`, `ACCOUNT_PG_PASSWORD`, and `BILLING_DB_PASSWORD` from `${{ env.VAULT_KV_DATABASES }}` instead of `WEB_SAAS`.

### 2. Cloudflare Token Vault Path Mismatch
- **Context**: The user provisioned `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN`, and `CLOUDFLARE_DNS_API_TOKEN` in the root `kv/CICD` path.
- **Root Cause**: The `resize-instance.yaml` workflow was attempting to read the Cloudflare API token from `kv/data/CICD/${{ inputs.vault_env_path }}` (e.g., `CICD/uat`).
- **Fix**: Updated `resize-instance.yaml` to include `VAULT_KV: kv/data/CICD` and read the Cloudflare tokens from that root path.

## The Blocker (Vault Policy)
While attempting to test the pipeline on the `bugfix/vault-secrets-web-saas` branch, the workflow crashed at the **Load Vault secrets** step with a `400 Bad Request` from Vault:
> `claim "ref" does not match any associated bound claim values`

**Why this happens:**
The Vault JWT Role for UAT (`github-actions-platform-ops-toolkit-uat`) strictly requires the GitHub Action to be triggered from `refs/heads/main` or `refs/heads/release/*`. It rejects any `bugfix/*` branch.
Since we cannot bypass GitHub Branch Protection (rule: *Never push directly to main or use gh pr merge --admin*), we cannot merge the PR ourselves to test it on `main`. 

## Next Steps for the Next Agent

1. **Merge PR #105**: Ensure the user approves and merges [PR #105](https://github.com/ai-workspace-infra/platform-ops-toolkit/pull/105) into `main`.
2. **Trigger the Pipeline**: Once merged, run the pipeline on `main` using the following exact parameters to continue the UAT and DNS switch debugging:
   ```bash
   gh workflow run platform-ops.yaml \
     --repo ai-workspace-infra/platform-ops-toolkit \
     --ref main \
     -f action=resize \
     -f confirm_dns_switch=true \
     -f vault_env_path=uat \
     -f target_domain_base=onwalk.net \
     -f target_domains=web-saas \
     -f run_infrastructure=true \
     -f run_application_deploy=true \
     -f cloud_provider=vultr-vps \
     -f instance_plan=4C8G \
     -f confirm_resize=true
   ```
3. **Monitor execution**: Verify that the `Load Vault secrets` step passes, the databases credentials step functions properly, and that the `resize-instance.yaml` job successfully executes the `Switch DNS after health check` step using the `kv/CICD` tokens.
