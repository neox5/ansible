#!/usr/bin/env bash
set -euo pipefail

# Source all common library modules
_common_dir="$(dirname -- "${BASH_SOURCE[0]}")/common"

source "${_common_dir}/output.sh"
source "${_common_dir}/fs.sh"
source "${_common_dir}/state.sh"
source "${_common_dir}/registry.sh"
source "${_common_dir}/validate.sh"
source "${_common_dir}/systemd.sh"
