import os
import glob

# 1. Fix platform-ops.yaml
path = ".github/workflows/platform-ops.yaml"
with open(path, "r") as f:
    content = f.read()

# Fix VAULT_KV_WEB_SAAS to always use kv/data/WEB_SAAS
content = content.replace(
    "  VAULT_KV_WEB_SAAS: ${{ (github.event_name == 'push' && (startsWith(github.ref, 'refs/heads/release/') || startsWith(github.ref, 'refs/tags/v'))) && 'kv/data/WEB_SAAS' || (github.event_name == 'workflow_dispatch' && github.event.inputs.vault_env_path == 'prod') && 'kv/data/WEB_SAAS' || format('kv/data/{0}/web-saas', github.event_name == 'push' && (github.ref == 'refs/heads/main' && 'uat' || 'sit') || github.event.inputs.vault_env_path) }}",
    "  VAULT_KV_WEB_SAAS: kv/data/WEB_SAAS"
)

# Introduce env_suffix in outputs
content = content.replace(
    "for key in deployment_env resource_file terraform_workspace state_key run target_domains terraform_action toolkit_action infra_ref console_ref offline_mode source_host source_domain_base target_domain_base confirm_dns_switch; do",
    "for key in deployment_env resource_file terraform_workspace state_key run target_domains terraform_action toolkit_action infra_ref console_ref offline_mode source_host source_domain_base target_domain_base env_suffix confirm_dns_switch; do"
)
content = content.replace(
    "      target_domain_base: ${{ steps.route.outputs.target_domain_base }}",
    "      target_domain_base: ${{ steps.route.outputs.target_domain_base }}\n      env_suffix: ${{ steps.route.outputs.env_suffix }}"
)

# Route step updates
route_update_dispatch = """            target_domain_base="${{ github.event.inputs.target_domain_base }}"
            confirm_dns_switch="${{ github.event.inputs.confirm_dns_switch }}"
          else"""

route_update_dispatch_new = """            target_domain_base="${{ github.event.inputs.target_domain_base }}"
            confirm_dns_switch="${{ github.event.inputs.confirm_dns_switch }}"
            if [ "${deployment_env}" = "sit" ]; then
              env_suffix="-sit"
            elif [ "${deployment_env}" = "uat" ]; then
              env_suffix="-uat"
            else
              env_suffix=""
            fi
          else"""
content = content.replace(route_update_dispatch, route_update_dispatch_new)

content = content.replace(
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=uat.svc.plus; confirm_dns_switch=false",
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=svc.plus; env_suffix=-uat; confirm_dns_switch=false"
)
content = content.replace(
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=onwalk.net; confirm_dns_switch=false",
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=onwalk.net; env_suffix=\"\"; confirm_dns_switch=false"
)
content = content.replace(
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=sit.svc.plus; confirm_dns_switch=false",
    "source_host=install.svc.plus; source_domain_base=svc.plus; target_domain_base=svc.plus; env_suffix=-sit; confirm_dns_switch=false"
)

# Replacements in playbooks invocation
content = content.replace("accounts.${{ needs.provision.outputs.target_domain_base }}", "accounts${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}")
content = content.replace("console.${{ needs.provision.outputs.target_domain_base }}", "console${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}")
content = content.replace("iam.${{ needs.provision.outputs.target_domain_base }}", "iam${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}")
content = content.replace("observability.${{ needs.provision.outputs.target_domain_base }}", "observability${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}")
content = content.replace("target_host=www.${{ needs.provision.outputs.target_domain_base }}", "target_host=www${{ needs.provision.outputs.env_suffix }}.${{ needs.provision.outputs.target_domain_base }}")

with open(path, "w") as f:
    f.write(content)

# 2. Fix service_domains in terraform configs
yaml_files = glob.glob("../iac_modules/terraform-hcl-standard/vultr-vps/config/resources/**/*.yaml", recursive=True)
for yf in yaml_files:
    with open(yf, "r") as f:
        y_content = f.read()
    if ".uat." in y_content or ".sit." in y_content:
        y_content = y_content.replace(".uat.svc.plus", "-uat.svc.plus")
        y_content = y_content.replace(".sit.svc.plus", "-sit.svc.plus")
        with open(yf, "w") as f:
            f.write(y_content)
