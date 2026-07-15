#!/bin/bash
sed -i 's/OLLAMA_API_KEY:-}"/OLLAMA_API_KEY:-}"\n  printf '"'"'BRANCH=%q\\n'"'"' "${INFRA_REF:-main}"/' scripts/run-on-host-bootstrap.sh
sed -i 's/export .* OLLAMA_API_KEY/& BRANCH/' scripts/run-on-host-bootstrap.sh
sed -i 's|/ai-workspace |/ai-workspace/${BRANCH:-main} |' scripts/run-on-host-bootstrap.sh
