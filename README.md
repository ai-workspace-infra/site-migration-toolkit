# platform-ops-toolkit

[🇬🇧 English](README.md) | [🇨🇳 中文版](README_zh.md)

Welcome to **platform-ops-toolkit**. This repository provides automated solutions for disaster recovery, cross-datacenter full migrations, and multi-environment delivery lifecycles for the AI Workspace infrastructure.

> ℹ️ **Architecture Upgrade Notice**: This toolkit has been refactored from a legacy "All-in-One" monolithic architecture into a highly cohesive architecture bounded by **Business Domains**. This allows us to decouple, migrate on-demand, and independently evolve different business systems. Simultaneously, we have fully implemented a unified [Multi-Environment Delivery Standard](docs/standards/multi-environment-delivery-and-release-standard.md).

## 🌐 Core Business Domains

This toolkit is divided into four core domains based on the actual business topology of the production systems:

1. **[web-saas](domains/web-saas/README.md)** (SaaS Frontend & Acceleration Domain)
   - Covers Web Console, Accounts, Billing, and the underlying Xray tunnel proxy ingress.
2. **[ai-workspace](domains/ai-workspace/README.md)** (AI Core Routing Domain)
   - Covers LiteLLM, OpenClaw, QMD, and other intelligent agent/model routing pipelines.
3. **[agent-proxy](domains/agent-proxy/README.md)** (Acceleration Proxy & Gateway Domain)
   - Covers Caddy, Xray tunnels, Xray Exporters, Vector observability proxies, and agent-svc-plus control plane sync nodes.
4. **[open-platform](domains/open-platform/README.md)** (Open Platform & Infrastructure Domain)
   - Covers Gitea, Vault, IAM (Zitadel), and a robust global Observability Stack (Grafana, VictoriaMetrics, etc.).

For detailed migration, backup, and restoration strategies for each domain, please refer to the `README.md` documents within their respective sub-directories.

## 🚀 Orchestration and Usage

*Note: The orchestration layer is currently transitioning from legacy monolithic Python scripts to a modular Ansible / Make supported architecture.*

You can perform on-demand backups or migrations by specifying one or more `DOMAIN`s using the global entry commands:

```bash
# Example: Data backup exclusively for the AI workspace and open platform domains
make backup DOMAIN=ai-workspace,open-platform

# Example: One-click trigger for a full-site migration and recovery pipeline across all domains
make migrate DOMAIN=all
```

## 🛠️ CI/CD and IaC Pipelines

When triggering deployments or migrations for the whole site or specific domains via CI/CD pipelines, the underlying logic will invoke the corresponding business domain strategy modules.

### Environment Profile Releases and Routing Rules

When triggered, `platform-ops.yaml` automatically routes to the appropriate delivery environment based on the current Git branch or tag. Terraform creates or updates the hosts first, then generates the CMDB; subsequently, Ansible will strictly use the CMDB inventory generated during that specific run.

| Trigger Event / Source | Target Environment | Resource Declaration | State Key / Workspace |
| --- | --- | --- | --- |
| `pull_request` | `sit` | `sit/all-in-one.yaml` | `site-migration-toolkit/sit/all-in-one.tfstate` |
| `main` / `release/*` push | `uat` | `uat/web-saas-uat.yaml` | `site-migration-toolkit/uat/web-saas-uat.tfstate` |
| `vMAJOR.MINOR.PATCH` tag | `prod` | `prod/web-saas-prod.yaml` | `site-migration-toolkit/prod/web-saas-prod.tfstate` |
| `workflow_dispatch` | User selected | `[env]/web-saas-[env].yaml` | Environment specific |

Prior to the initial UAT / Prod release, you must configure DNS for the target environment (e.g., `console.uat.svc.plus` or the production domains) and inject the corresponding `kv/data/[env]/web-saas` credentials into Vault. The workflow will fail if these credentials are missing. **Environments are strictly isolated, and pipelines will never read secrets across environments.**

### ⚠️ Vault Authentication Configuration (GitHub Actions OIDC → Vault JWT)

Pipelines do NOT store sensitive values in GitHub Actions Secrets. All credentials are distributed at runtime from Vault KV paths (`sit`, `uat`, `prod`) after authenticating via **GitHub OIDC → Vault JWT**.

#### 1. Initialize Isolated Roles and Policies (One-time Setup)

We have deprecated the global monolithic Vault Policy in favor of independent authorization per environment. You only need to execute the built-in initialization script using a Vault Administrator Token:

```bash
export VAULT_ADDR=https://vault.svc.plus
export VAULT_TOKEN="hvs.xxxxxxxxx"   # Admin Token

# Grant execution permissions and run
chmod +x docs/tasks/vault_auth_split.sh
./docs/tasks/vault_auth_split.sh
```

This script will automatically create:
- Three environment-specific policies: `github-actions-platform-ops-toolkit-sit`, `-uat`, `-prod`
- Three OIDC JWT authentication roles: `github-actions-platform-ops-toolkit-sit`, `-uat`, `-prod`
- Security constraints: For example, the `prod` role is strictly bound to only accept requests triggered by `v*` release tags, preventing hijacking from regular branches or PRs.

#### 2. Populate KV Parameters for Each Domain

Please prepare your secrets in the corresponding environment paths, such as `kv/data/sit/*`, `kv/data/uat/*`, and `kv/data/prod/*`, according to the table below:

| Vault Path Example | Key | Purpose |
| --- | --- | --- |
| `kv/data/CICD` | `SSH_PRIVATE_DEPLOY_KEY_B64` | Globally Shared: Ansible SSH deployment private key (single-line base64) |
| `kv/data/CICD` | `VULTR_API_KEY` | Globally Shared: Terraform API key for provisioning VPS |
| `kv/data/CICD` | `TF_STATE_ENDPOINT` etc. | Globally Shared: Remote TF state configuration (S3-compatible) |
| `kv/data/CICD` | `CLOUDFLARE_DNS_API_TOKEN` | Globally Shared: Cloud DNS API token for hijacking or switching domains |
| `kv/data/uat/web-saas` | 6 keys (see sub-domain docs) | Required credentials for web-saas UAT domain services |
| `kv/data/prod/web-saas` | 6 keys (see sub-domain docs) | Required credentials for web-saas PROD domain services |

#### 3. Workflow Dynamic Authentication Integration (Active, No Changes Required)

During execution, the workflow will dynamically compute and request the corresponding environment Role based on your trigger branch, ensuring a secure fetch of isolated secrets:
```yaml
env:
  DEPLOY_ENV: ${{ steps.route.outputs.deploy_env }}
  VAULT_ROLE: github-actions-platform-ops-toolkit-${{ steps.route.outputs.deploy_env }}
```

#### 4. Acceptance and Troubleshooting

- After triggering a pipeline, the `Authenticate to Vault` or `Load Vault secrets` step within each job should display successful Token retrieval info without errors.
- `403 Forbidden` error: This indicates that the policy bound to the dynamically assembled role does not cover the requested path (e.g., attempting to read production secrets from within the UAT environment).
- `permission denied` or Role mismatch error: Please verify whether the Git event triggering the pipeline (such as the branch name or Tag) satisfies the strict security boundary constraints defined in the `bound_claims` of the Vault JWT Role.
