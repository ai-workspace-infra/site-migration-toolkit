#!/usr/bin/env bash
set -e

if [ -f cmdb.json ]; then
  hosts="$(jq -c 'keys' cmdb.json)"
  count="$(jq 'length' cmdb.json)"
else
  hosts="[]"
  count="0"
fi

if [ -n "$GITHUB_OUTPUT" ]; then
  echo "hosts=${hosts}" >> "$GITHUB_OUTPUT"
  echo "count=${count}" >> "$GITHUB_OUTPUT"
else
  echo "hosts=${hosts}"
  echo "count=${count}"
fi
