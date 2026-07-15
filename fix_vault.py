import os
path = "docs/tasks/vault_auth_split.sh"
with open(path, "r") as f:
    content = f.read()
content = content.replace("nat", "uat")
content = content.replace("NAT", "UAT")
with open(path, "w") as f:
    f.write(content)
