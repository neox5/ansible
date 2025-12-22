#!/usr/bin/env bash
set -euo pipefail

discover_components() {
  local comp
  for comp in "${ROOT_DIR}/scripts/components/"*.sh; do
    [[ -f "$comp" ]] || continue
    basename "$comp" .sh
  done | sort
}

verb_supported_by_component() {
  local sv
  for sv in "${supported_verbs[@]:-}"; do
    [[ "$sv" == "$VERB" ]] && return 0
  done
  return 1
}

has_fn() {
  declare -F "$1" >/dev/null 2>&1
}

default_help() {
  echo "${COMPONENT} commands:"
  local v
  for v in "${supported_verbs[@]}"; do
    printf "  %-12s\n" "${v}"
  done
}

dispatch() {
  if [[ "$VERB" == "help" ]]; then
    if has_fn c_help; then
      c_help "$@"
      return 0
    fi
    default_help
    return 0
  fi

  verb_supported_by_component || \
    die "${VERB} is not supported by ${COMPONENT}"

  check_base_prereqs
  check_component_prereqs

  local hook="c_${VERB//-/_}"
  if has_fn "$hook"; then
    "$hook" "$@"
    return 0
  fi

  die "${VERB} is not implemented by ${COMPONENT}"
}
