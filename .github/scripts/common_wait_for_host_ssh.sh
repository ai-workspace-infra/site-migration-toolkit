#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env MATRIX_HOST
ip="$(jq -r --arg host "$MATRIX_HOST" '.[$host].ip' cmdb/cmdb.json)"
for _ in $(seq 1 60); do
  if nc -z -w 5 "$ip" 22; then exit 0; fi
  sleep 10
done
exit 1
