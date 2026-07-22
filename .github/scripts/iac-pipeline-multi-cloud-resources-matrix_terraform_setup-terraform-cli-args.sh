#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MATRIX_TYPE=resources exec "${DIR}/common_setup_matrix_terraform_cli_args.sh"
