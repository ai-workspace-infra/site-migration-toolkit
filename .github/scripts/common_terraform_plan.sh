#!/bin/bash
set -eo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/common_require_env.sh"
require_env CONFIG_DIR
make plan CONFIG_DIR=../../../../../${CONFIG_DIR}