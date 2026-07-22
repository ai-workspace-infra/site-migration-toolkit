#!/usr/bin/env bash
# Fail loudly when an Ansible target resolves to zero reachable hosts.
#
# ansible / ansible-playbook exit 0 even when the host pattern (or --limit)
# matches nothing — a wrong inventory path or host name then turns a whole
# deploy into a silent no-op that still reports a green check. Call this before
# any deploy step so that class of false success fails red instead.
#
# Usage: common_assert_ansible_host.sh <inventory> <host>
set -euo pipefail

inventory="${1:?usage: common_assert_ansible_host.sh <inventory> <host>}"
host="${2:?usage: common_assert_ansible_host.sh <inventory> <host>}"

if [ ! -f "${inventory}" ]; then
  echo "::error::inventory file not found: ${inventory} (cwd=$(pwd))" >&2
  exit 1
fi

ping_out="$(ansible -i "${inventory}" "${host}" -m ping 2>&1 || true)"
echo "${ping_out}"
if ! grep -q 'SUCCESS' <<<"${ping_out}"; then
  echo "::error::Ansible target '${host}' matched no reachable host in ${inventory}; refusing to report a no-op deploy as success." >&2
  exit 1
fi
