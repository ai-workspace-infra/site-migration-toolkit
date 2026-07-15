#!/bin/bash
in_group="$(jq -r '.["${{ matrix.host }}"].groups | contains(["agent_proxy"])' cmdb/cmdb.json)"
echo "in_group=${in_group}" >> "$GITHUB_OUTPUT"
