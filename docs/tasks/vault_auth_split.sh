#!/usr/bin/env bash
set -e

# =============================================================================
# Vault Authentication & Policy Split Initialization (sit, uat, prod)
#
# Requirements:
# 1. Run this script from a terminal with access to Vault (e.g. https://vault.svc.plus).
# 2. Vault must be initialized and unsealed.
# 3. Export VAULT_ADDR and VAULT_TOKEN (with admin privileges).
# =============================================================================

export VAULT_ADDR="${VAULT_ADDR:-https://vault.svc.plus}"

if [ -z "$VAULT_TOKEN" ]; then
  echo "Error: VAULT_TOKEN is not set. Please export your Vault admin token."
  exit 1
fi

echo "Creating SIT Policy..."
vault policy write github-actions-platform-ops-toolkit-sit - <<'EOF'
# SIT Environment Access
path "kv/data/CICD/*" {
  capabilities = ["read"]
}
path "kv/data/openclaw/*" {
  capabilities = ["read"]
}
path "kv/data/sit/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv/metadata/sit/*" {
  capabilities = ["list", "read", "delete"]
}
EOF

echo "Creating UAT Policy..."
vault policy write github-actions-platform-ops-toolkit-uat - <<'EOF'
# UAT Environment Access
path "kv/data/CICD/*" {
  capabilities = ["read"]
}
path "kv/data/openclaw/*" {
  capabilities = ["read"]
}
path "kv/data/WEB_SAAS/*" {
  capabilities = ["read"]
}
path "kv/data/uat/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv/metadata/uat/*" {
  capabilities = ["list", "read", "delete"]
}
EOF

echo "Creating PROD Policy..."
vault policy write github-actions-platform-ops-toolkit-prod - <<'EOF'
# PROD Environment Access
path "kv/data/CICD/*" {
  capabilities = ["read"]
}
path "kv/data/openclaw/*" {
  capabilities = ["read"]
}
path "kv/data/WEB_SAAS/*" {
  capabilities = ["read"]
}
path "kv/data/prod/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "kv/metadata/prod/*" {
  capabilities = ["list", "read", "delete"]
}
EOF

echo "Creating SIT Role..."
vault write auth/jwt/role/github-actions-platform-ops-toolkit-sit - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/platform-ops-toolkit"
  },
  "token_policies": ["github-actions-platform-ops-toolkit-sit"],
  "token_ttl": "1h"
}
EOF

echo "Creating UAT Role (Bound to main branch)..."
vault write auth/jwt/role/github-actions-platform-ops-toolkit-uat - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/platform-ops-toolkit",
    "ref": "refs/heads/main"
  },
  "token_policies": ["github-actions-platform-ops-toolkit-uat"],
  "token_ttl": "1h"
}
EOF

echo "Creating PROD Role (Bound to release/* and v*)..."
vault write auth/jwt/role/github-actions-platform-ops-toolkit-prod - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/platform-ops-toolkit",
    "ref": "refs/heads/release/*"
  },
  "token_policies": ["github-actions-platform-ops-toolkit-prod"],
  "token_ttl": "1h"
}
EOF

# We add a separate role for prod tags since bound_claims is an exact match for glob objects, 
# and vault CLI might have limitations combining multiple globs in a single ref field.
# Alternatively, "ref" could just use a common prefix, but for precision we create another role:
echo "Creating PROD Tags Role (Bound to v*)..."
vault write auth/jwt/role/github-actions-platform-ops-toolkit-prod-tags - <<'EOF'
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_audiences": ["vault"],
  "bound_claims_type": "glob",
  "bound_claims": {
    "repository": "ai-workspace-infra/platform-ops-toolkit",
    "ref": "refs/tags/v*"
  },
  "token_policies": ["github-actions-platform-ops-toolkit-prod"],
  "token_ttl": "1h"
}
EOF

echo "Done! Ensure you update your GitHub Actions workflow to request the appropriate role."
