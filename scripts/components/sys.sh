#!/usr/bin/env bash
set -euo pipefail

component_name="sys"

supported_verbs=(
  init
  cleanup
)

required_cmds=()
