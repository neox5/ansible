#!/usr/bin/env bash
set -euo pipefail

# Framework-supported verbs
readonly FRAMEWORK_VERBS=(
  install
  uninstall
  start
  stop
  verify
  help
)

discover_components() {
  local comp
  for comp in "${ROOT_DIR}/scripts/components/"*.sh; do
    [[ -f "$comp" ]] || continue
    basename "$comp" .sh
  done | sort
}

is_valid_verb() {
  local verb="$1"
  local v
  for v in "${FRAMEWORK_VERBS[@]}"; do
    [[ "$v" == "$verb" ]] && return 0
  done
  return 1
}

get_verb_implementation_type() {
  local verb="$1"
  
  # Check component-specific hook first
  local hook="c_${verb//-/_}"
  if has_fn "$hook"; then
    echo "component"
    return 0
  fi
  
  # Check default implementation
  local default_hook="default_${verb//-/_}"
  if has_fn "$default_hook"; then
    echo "default"
    return 0
  fi
  
  # Not implemented
  echo "none"
  return 1
}

component_implements_verb() {
  local verb="$1"
  local impl_type
  
  impl_type=$(get_verb_implementation_type "$verb")
  [[ "$impl_type" != "none" ]]
}

has_fn() {
  declare -F "$1" >/dev/null 2>&1
}

default_help() {
  echo "${COMPONENT} verbs:"
  
  local verb impl_type label
  for verb in "${FRAMEWORK_VERBS[@]}"; do
    impl_type=$(get_verb_implementation_type "$verb")
    
    case "$impl_type" in
      component)
        label="component"
        ;;
      default)
        label="default"
        ;;
      none)
        continue  # Skip unimplemented verbs
        ;;
    esac
    
    printf "  %-12s (%s)\n" "$verb" "$label"
  done
}

default_verify() {
  require_installed
  
  # Validate registry structure
  registry_validate || {
    echo "error: registry validation failed" >&2
    return 1
  }
  
  # Verify disk state matches registry
  registry_verify || {
    echo "error: registry verification failed" >&2
    return 1
  }
  
  echo "base verification passed"
}

default_uninstall() {
  if ! is_installed; then
    echo "not installed"
    return 0
  fi
  
  # Reconcile registry with actual state first
  registry_reconcile >/dev/null 2>&1 || true
  
  # Validate no enabled units (check actual system state)
  verify_no_enabled_units || return 1
  
  # Validate no active units (check actual system state)
  verify_no_active_units || return 1
  
  # Uninstall from registry
  uninstall_from_registry
  
  # Remove registry
  rm -rf "${STATE_DIR}/${COMPONENT}.registry"
}

dispatch() {
  # Validate verb exists in framework
  is_valid_verb "$VERB" || \
    die "unknown verb: ${VERB}"
  
  # Validate component implements verb
  component_implements_verb "$VERB" || \
    die "${COMPONENT} does not implement '${VERB}'"
  
  # Help handling
  if [[ "$VERB" == "help" ]]; then
    if has_fn c_help; then
      c_help "$@"
    else
      default_help
    fi
    return 0
  fi

  # Check base prerequisites
  check_base_prereqs
  check_component_prereqs

  # Resolve hook (component-specific or default)
  local hook="c_${VERB//-/_}"
  if ! has_fn "$hook"; then
    hook="default_${VERB//-/_}"
  fi

  # PRE-HOOK: Install only
  if [[ "$VERB" == "install" ]]; then
    if is_installed && [[ "${1:-}" != "--force" ]]; then
      echo "already installed (use --force to overwrite)"
      return 0
    fi
    ensure_registry
  fi
  
  # Execute operation
  "$hook" "$@"
}
