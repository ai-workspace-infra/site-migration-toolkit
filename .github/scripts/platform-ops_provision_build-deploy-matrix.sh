#!/bin/bash
hosts="$(jq -c 'keys' cmdb.json)"
echo "hosts=${hosts}" >> "$GITHUB_OUTPUT"
echo "count=$(jq 'length' cmdb.json)" >> "$GITHUB_OUTPUT"
