#!/bin/bash
A="${{ inputs.accounts_components || 'vpc,role' }}"
[ "$A" == "all" ] && A="vpc,role"
echo "account=$(echo "$A" | tr -d ' ' | jq -R -c 'split(",")')" >> "$GITHUB_OUTPUT"

R="${{ inputs.resources_components || 's3,ec2' }}"
[ "$R" == "all" ] && R="s3,ec2"
echo "resources=$(echo "$R" | tr -d ' ' | jq -R -c 'split(",")')" >> "$GITHUB_OUTPUT"
