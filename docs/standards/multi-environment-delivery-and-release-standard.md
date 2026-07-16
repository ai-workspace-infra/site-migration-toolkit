# 多云多环境交付与发布规范
(Multi-Environment Delivery and Release Standard)

This page defines the infrastructure-wide working standard for multi-environment delivery, branch usage, release tagging, and secret governance within the `platform-ops-toolkit`.

## 1. Environment Profile Releases and Routing Rules

When triggered, `platform-ops.yaml` automatically routes to the appropriate delivery environment based on the current Git branch or tag. Terraform creates or updates the hosts first, then generates the CMDB; subsequently, Ansible will strictly use the CMDB inventory generated during that specific run.

| Trigger Event / Source | Target Environment | Resource Declaration | State Key / Workspace |
|---|---|---|---|
| `pull_request` | `sit` | `sit/all-in-one.yaml` | `platform-ops-toolkit/sit/all-in-one.tfstate` |
| `main` / `release/*` push | `uat` | `uat/web-saas-uat.yaml` | `platform-ops-toolkit/uat/web-saas-uat.tfstate` |
| `vMAJOR.MINOR.PATCH` tag | `prod` | `prod/web-saas-prod.yaml` | `platform-ops-toolkit/prod/web-saas-prod.tfstate` |
| `workflow_dispatch` | User selected | `[env]/web-saas-[env].yaml` | Environment specific |

> [!IMPORTANT]
> Prior to the initial UAT / Prod release, you must configure DNS for the target environment (e.g., `console.uat.svc.plus` or the production domains) and inject the corresponding `kv/data/[env]/web-saas` credentials into Vault. The workflow will fail if these credentials are missing. Environments are strictly isolated, and pipelines will never read secrets across environments.

## 2. Vault Authentication Configuration (OIDC → Vault JWT)

Pipelines do **NOT** store sensitive values in GitHub Actions Secrets. All credentials are distributed at runtime from Vault KV paths (`sit`, `uat`, `prod`) after authenticating via GitHub OIDC → Vault JWT.

### Initialize Isolated Roles and Policies (One-time Setup)

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
- **Security constraints**: For example, the `prod` role is strictly bound to only accept requests triggered by `v*` release tags, preventing hijacking from regular branches or PRs.

## 3. Branch Roles and Delivery Lifecycle

We adhere strictly to the following branch roles, inherited from the application-level development standard:

| Ref | Role | Typical Lifetime | Lands Into |
|---|---|---|---|
| `main` | Main timeline / trunk (Triggers `uat` env) | Long-lived | Receives `feature/*`, `bugfix/*`, `cherry-pick/*` |
| `release/*` | LTS maintenance line (Triggers `uat` env) | Long-lived, version-scoped | Receives `hotfix/*` and intentional `backport/*` |
| `feature/*` | New feature work (Triggers `sit` via PR) | Short-lived | `main` |
| `bugfix/*` | Normal bug fix work for trunk | Short-lived | `main` |
| `hotfix/*` | Urgent fix for a published release line | Short-lived | `release/*` |
| `tag` (`v*`) | Published release snapshot (Triggers `prod` env) | Immutable | Marks a release point |

### Allowed Paths and Pull Requests
- All changes must be made via Pull Requests. Direct pushes to `main` and `release/*` are prohibited by branch protection rules.
- `feature/*`, `bugfix/*` PRs must target `main` and be squash-merged.
- `hotfix/*` PRs must target `release/*`.

### Release Cut and Publishing
1. A `release/vMAJOR.MINOR` branch is cut from a stable `main` commit.
2. Production is deployed **only** when an annotated tag (e.g., `v1.2.0`) is pushed to an intentional release point.
3. Every production artifact and infrastructure state must be traceable to one unique release tag.

## 4. Emergency Secret Incident Flow

If an infrastructure secret, token, or private key is accidentally committed:
1. **Revoke** the leaked credential immediately in Vault or the cloud provider.
2. **Generate** or rotate a replacement credential.
3. Review access logs and audit trails for suspicious use.
4. Rewrite Git history only after the credential is no longer valid.
5. Force-push the rewritten branches and tags.
6. Have collaborators `git fetch --all` and re-align local branches as needed.

> [!CAUTION]
> A secret-scanning gate prevents new leakage but does not replace this incident flow. Never attempt to just "delete the file" in a new commit to hide a leak; Git history must be purged.
