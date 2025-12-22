#!/usr/bin/env bash
set -euo pipefail

verb_supported_by_component() {
  local v="$1"
  local sv
  for sv in "${supported_verbs[@]:-}"; do
    [[ "$sv" == "$v" ]] && return 0
  done
  return 1
}

has_fn() {
  declare -F "$1" >/dev/null 2>&1
}

default_help() {
  echo "Component: ${component_name}"
  echo ""
  echo "Supported verbs:"
  local v
  for v in "${supported_verbs[@]}"; do
    echo "  ${v}"
  done
}

handle_sys_component() {
  local verb="$1"; shift || true
  
  case "$verb" in
    init)
      ensure_dirs 0755 \
        "${STATE_DIR}" \
        "${ETC_ROOT}" \
        "${SHARE_ROOT}"
      ;;
    cleanup)
      if state_markers_exist; then
        echo "error: cannot cleanup - components still deployed:" >&2
        ls "${STATE_DIR}" | sed 's/\.lock$//' | sed 's/^/  - /' >&2
        exit 1
      fi
      rm -rf -- \
        "${VAR_ROOT}" \
        "${ETC_ROOT}" \
        "${SHARE_ROOT}"
      ;;
    *)
      die "${verb} is not implemented by ${component_name}"
      ;;
  esac
}

dispatch() {
  local verb="$1"; shift || true

  if [[ "$verb" == "help" ]]; then
    if has_fn c_help; then
      c_help "$@"
      return 0
    fi
    default_help
    return 0
  fi

  verb_supported_by_component "$verb" || \
    die "${verb} is not supported by ${component_name}"

  check_base_prereqs
  check_component_prereqs

  if [[ "${component_name}" == "sys" ]]; then
    handle_sys_component "$verb" "$@"
    return 0
  fi

  local hook="c_${verb//-/_}"
  if has_fn "$hook"; then
    "$hook" "$@"
    return 0
  fi

  die "${verb} is not implemented by ${component_name}"
}
