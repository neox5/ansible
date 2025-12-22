#!/usr/bin/env bash
set -euo pipefail

# Dispatcher template.
# Expects:
# - scripts/lib/paths.sh and scripts/lib/common.sh already sourced
# - component spec sourced from scripts/components/<c>.sh which defines:
#   component_name, supported_verbs (array)
#   optional: lifecycle_mode=systemd|compose|custom
#   optional: unit_names (array)
#   optional: compose_file (repo-relative or absolute)
#   optional: compose_project
#
# Hook naming: c_<verb>, e.g., c_install, c_start, ...

# Global verb set (used for help/validation; components still declare supported_verbs)
readonly -a N150_GLOBAL_VERBS=(
  install
  secrets
  secrets-deploy
  start
  stop
  restart
  status
  check
  run
)

verb_supported_by_component() {
  local v="$1"
  local sv
  for sv in "${supported_verbs[@]:-}"; do
    [[ "$sv" == "$v" ]] && return 0
  done
  return 1
}

has_fn() {
  local fn="$1"
  declare -F "$fn" >/dev/null 2>&1
}

default_systemd() {
  local verb="$1"
  [[ "${#unit_names[@]:-0}" -gt 0 ]] || return 1

  case "$verb" in
    start)   systemctl_cmd start "${unit_names[@]}" ;;
    stop)    systemctl_cmd stop "${unit_names[@]}" ;;
    restart) systemctl_cmd restart "${unit_names[@]}" ;;
    status)  systemctl_cmd status "${unit_names[@]}" ;;
    *) return 1 ;;
  esac
}

default_compose() {
  local verb="$1"

  [[ -n "${compose_file:-}" ]] || return 1
  require_cmd podman-compose

  # Resolve compose file to an absolute path.
  local cf="$compose_file"
  if [[ "$cf" != /* ]]; then
    cf="${ROOT_DIR}/${cf}"
  fi
  [[ -f "$cf" ]] || die "compose file not found: ${cf}"

  local -a base=(podman-compose -f "$cf")
  if [[ -n "${compose_project:-}" ]]; then
    base+=( -p "$compose_project" )
  fi

  case "$verb" in
    start)   run_cmd "${base[@]}" up -d ;;
    stop)    run_cmd "${base[@]}" down ;;
    restart) run_cmd "${base[@]}" down; run_cmd "${base[@]}" up -d ;;
    status)  run_cmd "${base[@]}" ps ;;
    *) return 1 ;;
  esac
}

dispatch() {
  local verb="$1"; shift || true

  # Component-level verb allowlist
  verb_supported_by_component "$verb" || die "${verb} is not supported by ${component_name}"

  local hook="c_${verb//-/_}"   # secrets-deploy -> c_secrets_deploy

  # 1) Component hook wins
  if has_fn "$hook"; then
    "$hook" "$@"
    return 0
  fi

  # 2) Shared defaults (if lifecycle_mode indicates)
  case "${lifecycle_mode:-custom}" in
    systemd)
      if default_systemd "$verb"; then return 0; fi
      ;;
    compose)
      if default_compose "$verb"; then return 0; fi
      ;;
    custom) ;;
    *)
      die "invalid lifecycle_mode for ${component_name}: ${lifecycle_mode}"
      ;;
  esac

  # 3) Hard default
  die "${verb} is not implemented by ${component_name}"
}
