#!/bin/bash
ip="$(jq -r '.["${MATRIX_HOST}"].ip' cmdb/cmdb.json)"
for _ in $(seq 1 60); do
  if nc -z -w 5 "$ip" 22; then exit 0; fi
  sleep 10
done
exit 1
