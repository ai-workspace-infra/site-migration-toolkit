#!/usr/bin/env bash
set -euo pipefail

: "${VULTR_API_KEY:?VULTR_API_KEY is required}"
: "${INSTANCE_ID:?INSTANCE_ID is required}"
: "${TARGET_PLAN:?TARGET_PLAN is required}"
: "${RESIZE_MODE:=auto}"
: "${CONFIRM_RESIZE:=false}"

instance="$(curl -fsS --retry 3 -H "Authorization: Bearer ${VULTR_API_KEY}" \
  "https://api.vultr.com/v2/instances/${INSTANCE_ID}" | jq -c '.instance')"
current_plan="$(jq -r '.plan // empty' <<<"${instance}")"
region="$(jq -r '.region // empty' <<<"${instance}")"
os_id="$(jq -r '.os_id // empty' <<<"${instance}")"
current_ip="$(jq -r '.main_ip // empty' <<<"${instance}")"
label="$(jq -r '.label // empty' <<<"${instance}")"

[[ -n "${current_plan}" && -n "${region}" && -n "${current_ip}" ]] || {
  echo "::error::Vultr instance response is missing plan, region, or main_ip" >&2
  exit 1
}

rank() {
  case "$1" in
    vc2-1c-2gb) echo 1 ;;
    vc2-2c-4gb) echo 2 ;;
    vc2-4c-8gb) echo 3 ;;
    *) echo 0 ;;
  esac
}

current_rank="$(rank "${current_plan}")"
target_rank="$(rank "${TARGET_PLAN}")"
[[ "${current_rank}" != 0 && "${target_rank}" != 0 ]] || {
  echo "::error::Unsupported VPS plan: current=${current_plan}, target=${TARGET_PLAN}" >&2
  exit 1
}

if (( target_rank == current_rank )); then
  direction=same
elif (( target_rank > current_rank )); then
  direction=upgrade
else
  direction=downgrade
fi

if [[ "${RESIZE_MODE}" != auto && "${RESIZE_MODE}" != "${direction}" ]]; then
  echo "::error::resize_mode=${RESIZE_MODE} does not match detected direction=${direction}" >&2
  exit 1
fi

if [[ "${direction}" == downgrade && "${CONFIRM_RESIZE}" != true ]]; then
  echo "::error::Downgrade requires confirm_resize=true and the replacement flow." >&2
  exit 1
fi

operation_id="resize-${INSTANCE_ID:0:8}-$(date -u +%Y%m%d%H%M%S)"
{
  echo "direction=${direction}"
  echo "current_plan=${current_plan}"
  echo "region=${region}"
  echo "os_id=${os_id}"
  echo "current_ip=${current_ip}"
  echo "label=${label}"
  echo "operation_id=${operation_id}"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

echo "Resize preflight: ${current_plan} -> ${TARGET_PLAN} (${direction})"
