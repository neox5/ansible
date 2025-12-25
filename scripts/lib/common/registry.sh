#!/usr/bin/env bash
set -euo pipefail

# Lifecycle
ensure_registry() {
  local registry_dir="${STATE_DIR}/${COMPONENT}.registry"
  
  # Idempotent: create if doesn't exist
  if [[ ! -d "$registry_dir" ]]; then
    mkdir -p "$registry_dir"
    touch "$registry_dir"/{dirs,files,units,unit_enabled,links}
    echo "$(date +%s)" > "$registry_dir/.lock"
  fi
}

# Atomic write helper
registry_write_atomic() {
  local registry_file="$1"
  shift
  local entries=("$@")
  
  local temp_file
  temp_file=$(mktemp "${registry_file}.XXXXXX")
  
  # Write entries if any exist
  if [[ "${#entries[@]}" -gt 0 ]]; then
    printf "%s\n" "${entries[@]}" > "$temp_file"
  else
    # Create empty file (0 bytes)
    > "$temp_file"
  fi
  
  # Atomic move
  mv "$temp_file" "$registry_file"
}

# Registration
registry_add() {
  local type="$1" path="$2" mode="${3:-}"
  local registry_file="${STATE_DIR}/${COMPONENT}.registry/${type}"
  
  # Build entry
  local entry="$path"
  [[ -n "$mode" && "$type" != "unit_enabled" ]] && entry="$path $mode"
  
  # Idempotent check
  if grep -q "^${path}[[:space:]]" "$registry_file" 2>/dev/null || \
     grep -qxF "$path" "$registry_file" 2>/dev/null; then
    return 0
  fi
  
  # Append entry
  echo "$entry" >> "$registry_file"
}

registry_remove() {
  local type="$1" path="$2"
  local registry_file="${STATE_DIR}/${COMPONENT}.registry/${type}"
  
  # Read existing entries into array
  local entries=()
  while IFS= read -r line; do
    # Skip lines matching the path to remove
    if [[ "$line" =~ ^${path}[[:space:]] ]] || [[ "$line" == "$path" ]]; then
      continue
    fi
    # Keep non-empty lines
    [[ -n "$line" ]] && entries+=("$line")
  done < "$registry_file" 2>/dev/null || true
  
  # Write back atomically
  registry_write_atomic "$registry_file" "${entries[@]}"
}

registry_has() {
  local type="$1" path="$2"
  local component="${3:-${COMPONENT}}"
  local registry_file="${STATE_DIR}/${component}.registry/${type}"
  
  grep -q "^${path}[[:space:]]" "$registry_file" 2>/dev/null || \
    grep -qxF "$path" "$registry_file" 2>/dev/null
}

# Query
registry_list() {
  local type="$1"
  local component="${2:-${COMPONENT}}"
  
  if [[ "$component" == "all" ]]; then
    cat "${STATE_DIR}"/*.registry/"$type" 2>/dev/null | sort -u
  else
    cat "${STATE_DIR}/${component}.registry/${type}" 2>/dev/null
  fi
}

# Reconciliation
registry_reconcile() {
  local component="${1:-${COMPONENT}}"
  local registry_dir="${STATE_DIR}/${component}.registry"
  local discrepancies=0
  
  [[ -d "$registry_dir" ]] || {
    echo "error: component not installed: $component" >&2
    return 1
  }
  
  # Reconcile files
  local files_to_keep=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    
    if [[ ! -f "$path" ]]; then
      echo "removing missing file from registry: $path" >&2
      ((discrepancies++))
    else
      files_to_keep+=("$path $mode")
    fi
  done < "${registry_dir}/files"
  registry_write_atomic "${registry_dir}/files" "${files_to_keep[@]}"
  
  # Reconcile dirs
  local dirs_to_keep=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    
    if [[ ! -d "$path" ]]; then
      echo "removing missing directory from registry: $path" >&2
      ((discrepancies++))
    else
      dirs_to_keep+=("$path $mode")
    fi
  done < "${registry_dir}/dirs"
  registry_write_atomic "${registry_dir}/dirs" "${dirs_to_keep[@]}"
  
  # Reconcile units
  local units_to_keep=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    
    if [[ ! -f "$path" ]]; then
      echo "removing missing unit from registry: $path" >&2
      ((discrepancies++))
    else
      units_to_keep+=("$path $mode")
    fi
  done < "${registry_dir}/units"
  registry_write_atomic "${registry_dir}/units" "${units_to_keep[@]}"
  
  # Reconcile unit_enabled (check actual symlinks)
  local enabled_to_keep=()
  while IFS= read -r path; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    
    if [[ ! -L "$path" ]]; then
      echo "removing missing enablement link from registry: $path" >&2
      ((discrepancies++))
    else
      enabled_to_keep+=("$path")
    fi
  done < "${registry_dir}/unit_enabled"
  registry_write_atomic "${registry_dir}/unit_enabled" "${enabled_to_keep[@]}"
  
  if [[ "$discrepancies" -eq 0 ]]; then
    echo "registry consistent with system state"
  else
    echo "reconciled $discrepancies discrepancies"
  fi
  
  return 0
}

# Uninstall
uninstall_from_registry() {
  local registry_dir="${STATE_DIR}/${COMPONENT}.registry"
  declare -A removed_paths  # Track already-removed paths
  
  # 1. Remove units (systemd unit files)
  local units=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    units+=("$path")
  done < "$registry_dir/units"
  
  if (( ${#units[@]} > 0 )); then
    remove_files "${units[@]}"
    local path
    for path in "${units[@]}"; do
      removed_paths["$path"]=1
    done
  fi
  
  # 2. Remove files (skip if already removed as unit)
  local files=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    
    # Skip if already processed in units
    if [[ -z "${removed_paths[$path]:-}" ]]; then
      files+=("$path")
    fi
  done < "$registry_dir/files"
  
  if (( ${#files[@]} > 0 )); then
    remove_files "${files[@]}"
  fi
  
  # 3. Remove links
  local links=()
  while IFS= read -r path; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    links+=("$path")
  done < "$registry_dir/links" 2>/dev/null || true
  
  if (( ${#links[@]} > 0 )); then
    remove_links "${links[@]}"
  fi
  
  # 4. Remove directories (reverse order)
  local dirs=()
  while IFS=' ' read -r path mode; do
    # Skip empty lines
    [[ -n "$path" ]] || continue
    dirs+=("$path")
  done < <(tac "$registry_dir/dirs")
  
  if (( ${#dirs[@]} > 0 )); then
    remove_dirs "${dirs[@]}"
  fi
}
