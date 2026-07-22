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
source_vcpu="$(jq -r '.vcpu_count // empty' <<<"${instance}")"
source_ram="$(jq -r '.ram // empty' <<<"${instance}")"
source_disk="$(jq -r '.disk // empty' <<<"${instance}")"

[[ -n "${current_plan}" && -n "${region}" && -n "${current_ip}" && -n "${source_vcpu}" && -n "${source_ram}" && -n "${source_disk}" ]] || {
  echo "::error::Vultr instance response is missing plan, region, main_ip, or capacity values" >&2
  exit 1
}

plans="$(curl -fsS --retry 3 -H "Authorization: Bearer ${VULTR_API_KEY}" \
  'https://api.vultr.com/v2/plans?type=vc2&per_page=500')"
target_spec="$(jq -c --arg plan "${TARGET_PLAN}" '.plans[]? | select(.id == $plan)' <<<"${plans}" | head -n 1)"
[[ -n "${target_spec}" ]] || {
  echo "::error::Vultr did not return capacity metadata for target plan ${TARGET_PLAN}" >&2
  exit 1
}
target_vcpu="$(jq -r '.vcpu_count // empty' <<<"${target_spec}")"
target_ram="$(jq -r '.ram // empty' <<<"${target_spec}")"
target_disk="$(jq -r '.disk // empty' <<<"${target_spec}")"
[[ -n "${target_vcpu}" && -n "${target_ram}" && -n "${target_disk}" ]] || {
  echo "::error::Target plan ${TARGET_PLAN} is missing capacity metadata" >&2
  exit 1
}

if [[ "${TARGET_PLAN}" == "${current_plan}" ]]; then
  direction=same
elif (( target_vcpu >= source_vcpu && target_ram >= source_ram && target_disk >= source_disk )); then
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

if [[ "${direction}" == downgrade ]] && (( target_disk < source_disk )); then
  echo "::error::Snapshot replacement is impossible: source disk=${source_disk}GB, target plan ${TARGET_PLAN} disk=${target_disk}GB. Select a plan with at least ${source_disk}GB disk, or use an application-level backup/restore migration." >&2
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
  echo "source_disk=${source_disk}"
  echo "target_disk=${target_disk}"
  echo "operation_id=${operation_id}"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"

echo "Resize preflight: ${current_plan} -> ${TARGET_PLAN} (${direction})"
