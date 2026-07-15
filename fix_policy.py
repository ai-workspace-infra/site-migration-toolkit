import os
path = "docs/tasks/vault_auth_split.sh"
with open(path, "r") as f:
    content = f.read()

# Fix the trailing /* for exact paths
content = content.replace('path "kv/data/CICD/*"', 'path "kv/data/CICD"')
content = content.replace('path "kv/data/openclaw/*"', 'path "kv/data/openclaw"')
content = content.replace('path "kv/data/WEB_SAAS/*"', 'path "kv/data/WEB_SAAS"')

# Add metadata paths for CICD and WEB_SAAS as well to prevent any list errors
content = content.replace('path "kv/data/CICD" {\n  capabilities = ["read"]\n}', 'path "kv/data/CICD" {\n  capabilities = ["read"]\n}\npath "kv/metadata/CICD" {\n  capabilities = ["list", "read"]\n}')
content = content.replace('path "kv/data/WEB_SAAS" {\n  capabilities = ["read"]\n}', 'path "kv/data/WEB_SAAS" {\n  capabilities = ["read"]\n}\npath "kv/metadata/WEB_SAAS" {\n  capabilities = ["list", "read"]\n}')

with open(path, "w") as f:
    f.write(content)
