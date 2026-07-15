#!/bin/bash
PLAN="${INPUT_INSTANCE_PLAN_____4C8G_}"
DOMAIN="${INPUT_DOMAIN_____ALL_}"

# agent-proxy 默认使用 1C2G
if [ "$DOMAIN" == "agent-proxy" ] && [ "$PLAN" == "4C8G" ]; then
  PLAN="1C2G"
fi

if [ "$PLAN" == "1C2G" ]; then
  echo "api=vc2-1c-2gb" >> "$GITHUB_OUTPUT"
elif [ "$PLAN" == "2C4G" ]; then
  echo "api=vc2-2c-4gb" >> "$GITHUB_OUTPUT"
else
  echo "api=vc2-4c-8gb" >> "$GITHUB_OUTPUT"
fi
