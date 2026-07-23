#!/bin/bash
set -euo pipefail

# Fetch or verify pre-built billing-service release binary for CD deployments
# Keeps CI build steps inside billing-service repository while CD consumes pre-built artifacts.

DIST_DIR="${GITHUB_WORKSPACE}/billing-service/dist"
BINARY_PATH="${DIST_DIR}/billing-service-linux-amd64"

mkdir -p "${DIST_DIR}"

if [ -f "${BINARY_PATH}" ] && [ -s "${BINARY_PATH}" ]; then
  echo "Found pre-built billing-service binary at ${BINARY_PATH}"
  chmod 0755 "${BINARY_PATH}"
  exit 0
fi

echo "Fetching pre-built billing-service binary from GitHub Release assets..."
RELEASE_URL="https://github.com/ai-workspace-services/billing-service/releases/latest/download/billing-service-linux-amd64"

if curl -sSL -f -o "${BINARY_PATH}" "${RELEASE_URL}"; then
  chmod 0755 "${BINARY_PATH}"
  echo "Successfully downloaded pre-built billing-service binary to ${BINARY_PATH}"
else
  echo "::warning::Could not fetch billing-service binary from latest release URL (${RELEASE_URL})."
  if [ "${DEPLOY_ENV:-}" = "sit" ]; then
    echo "SIT environment fallback: compile billing-service locally if Go is available..."
    if command -v go >/dev/null 2>&1; then
      cd "${GITHUB_WORKSPACE}/billing-service"
      go build -buildvcs=false -o "${BINARY_PATH}" ./cmd/billing-service
      chmod 0755 "${BINARY_PATH}"
      echo "SIT fallback build completed successfully."
      exit 0
    fi
  fi
  echo "::error::Pre-built billing-service binary not found and fallback failed."
  exit 1
fi
