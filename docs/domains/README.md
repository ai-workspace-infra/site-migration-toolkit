# Domain delivery model

`platform-ops-toolkit` owns the environment lifecycle: Terraform provision,
CMDB/inventory generation, node bootstrap, migration, and DNS cutover. It does
not build application images or binaries.

| Domain | Runtime delivery boundary | Bootstrap / delivery entrypoint |
| --- | --- | --- |
| `web-saas` | Caddy,  Web Console, Accounts, Billing，postgresql，Doco-CD manages repository-defined application deployment. | `setup-Doco-CD.yaml` |
| `ai-workspace` | OpenClaw uses a rootless NPM installation; Hermes uses a rootless Python environment. | `setup-ai-workspace-rootless.yml` |
| `agent-proxy` | Caddy, Xray, exporters, Vector, and agent-svc-plus are installed through Playbook roles. | `deploy_agent_proxy` workflow job |
| `open-platform` | Caddy, Gitea, Vault, Zitadel, Grafana, VictoriaMetrics, and related infrastructure are installed through Playbook roles. | `deploy_infra_platform` workflow job |

`infra-platform` and `infra_platform` remain internal compatibility names for
the existing Terraform resources and CMDB group. `open-platform` is the
canonical user-facing domain name.
