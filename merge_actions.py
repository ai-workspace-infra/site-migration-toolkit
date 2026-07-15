import re

with open('.github/workflows/platform-ops.yaml', 'r') as f:
    content = f.read()

# 1. Replace the inputs block
old_inputs = """      toolkit_action:
        description: "Toolkit 执行动作 (deploy = 仅在新环境部署全部服务，不执行数据迁移)"
        required: false
        default: "migrate"
        type: choice
        options: [migrate, backup, restore, deploy]
      terraform_action:
        description: "apply 创建/更新，destroy 销毁"
        required: false
        default: "apply"
        type: choice
        options: [apply, destroy]"""

new_inputs = """      action:
        description: "执行动作 (deploy:仅部署服务 | destroy:销毁 | migrate/backup/restore:数据操作)"
        required: true
        default: "deploy"
        type: choice
        options: [deploy, destroy, migrate, backup, restore]"""

content = content.replace(old_inputs, new_inputs)

# 2. Update the assignment in route step
old_assignment = """            run="${{ github.event.inputs.run_provision_and_deploy }}"
            terraform_action="${{ github.event.inputs.terraform_action }}"
            toolkit_action="${{ github.event.inputs.toolkit_action }}"
            infra_ref="${{ github.event.inputs.infra_ref }}\""""

new_assignment = """            run="${{ github.event.inputs.run_provision_and_deploy }}"
            
            user_action="${{ github.event.inputs.action }}"
            if [ "$user_action" = "destroy" ]; then
              terraform_action="destroy"
              toolkit_action="none"
            else
              terraform_action="apply"
              toolkit_action="$user_action"
            fi
            
            infra_ref="${{ github.event.inputs.infra_ref }}\""""

content = content.replace(old_assignment, new_assignment)

# 3. Replace direct usages of github.event.inputs.toolkit_action and terraform_action
content = content.replace("github.event.inputs.toolkit_action", "needs.provision.outputs.toolkit_action")
content = content.replace("github.event.inputs.terraform_action", "needs.provision.outputs.terraform_action")
# also fix target_domains, source_host etc which were relying on github.event.inputs directly downstream
content = content.replace("github.event.inputs.target_domains", "needs.provision.outputs.target_domains")
content = content.replace("github.event.inputs.source_host", "needs.provision.outputs.source_host")
content = content.replace("github.event.inputs.target_domain_base", "needs.provision.outputs.target_domain_base")
content = content.replace("github.event.inputs.source_domain_base", "needs.provision.outputs.source_domain_base")

with open('.github/workflows/platform-ops.yaml', 'w') as f:
    f.write(content)
