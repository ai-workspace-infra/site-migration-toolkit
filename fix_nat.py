import os
path = ".github/workflows/platform-ops.yaml"
with open(path, "r") as f:
    content = f.read()
content = content.replace("nat", "uat")
content = content.replace("NAT", "UAT")
with open(path, "w") as f:
    f.write(content)
