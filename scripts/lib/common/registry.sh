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

# Validation
registry_verify() {
  local component="${1:-${COMPONENT}}"
  local registry_dir="${STATE_DIR}/${component}.registry"
  local exit_code=0
  
  for type in dirs files units; do
    while IFS=' ' read -r path mode; do
      [[ -n "$path" ]] || continue
      
      # Check existence
      if [[ ! -e "$path" ]]; then
        echo "missing: $path" >&2
        exit_code=1
        continue
      fi
      
      # Check mode (if specified)
      if [[ -n "$mode" ]]; then
        local actual_mode
        actual_mode=$(stat -c '%a' "$path" 2>/dev/null)
        # Strip leading 0 from mode for comparison
        local expected_mode="${mode#0}"
        
        if [[ "$actual_mode" != "$expected_mode" ]]; then
          echo "mode mismatch: $path (expected: $mode, actual: $actual_mode)" >&2
          exit_code=1
        fi
      fi
    done < "${registry_dir}/${type}"
  done
  
  # Verify unit_enabled
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -L "$path" ]] || {
      echo "missing symlink: $path" >&2
      exit_code=1
    }
  done < "${registry_dir}/unit_enabled"
  
  return "$exit_code"
}

registry_validate() {
  local component="${1:-${COMPONENT}}"
  local registry_dir="${STATE_DIR}/${component}.registry"
  local errors=0
  
  # Check registry structure
  [[ -d "$registry_dir" ]] || {
    echo "error: registry directory missing: $registry_dir" >&2
    return 1
  }
  
  for type in dirs files units unit_enabled; do
    local file="${registry_dir}/${type}"
    [[ -f "$file" ]] || {
      echo "error: registry file missing: $file" >&2
      ((errors++))
      continue
    }
    
    # Check format (skip for unit_enabled - different format)
    if [[ "$type" != "unit_enabled" ]]; then
      local line_num=0
      while IFS=' ' read -r path mode; do
        ((line_num++))
        
        # Check empty path
        [[ -z "$path" ]] && {
          echo "error: empty path in ${file}:${line_num}" >&2
          ((errors++))
          continue
        }
        
        # Check absolute path
        [[ "$path" == /* ]] || {
          echo "error: relative path in ${file}:${line_num}: $path" >&2
          ((errors++))
        }
        
        # Check mode format (4 octal digits)
        if [[ -n "$mode" ]]; then
          [[ "$mode" =~ ^[0-7]{4}$ ]] || {
            echo "error: invalid mode in ${file}:${line_num}: $mode" >&2
            ((errors++))
          }
        fi
      done < "$file"
    else
      # Validate unit_enabled (single column)
      local line_num=0
      while IFS= read -r path; do
        ((line_num++))
        [[ -z "$path" ]] && continue
        [[ "$path" == /* ]] || {
          echo "error: relative path in ${file}:${line_num}: $path" >&2
          ((errors++))
        }
        
        # Check that enabled unit exists in units registry
        local unit_name=$(basename "$path")
        local unit_path="${SYSTEMD_UNIT_DIR}/${unit_name}"
        if ! registry_has units "$unit_path" "$component"; then
          echo "error: enabled unit not in units registry: $unit_name" >&2
          ((errors++))
        fi
      done < "$file"
    fi
    
    # Check duplicates
    local unique_count
    unique_count=$(sort -u "$file" | wc -l)
    local total_count
    total_count=$(grep -c . "$file" 2>/dev/null || echo 0)
    
    if [[ "$unique_count" -ne "$total_count" ]]; then
      echo "error: duplicate entries in $file" >&2
      ((errors++))
    fi
  done
  
  return "$errors"
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
  
  # Remove units (files only, no systemd operations)
  local units=()
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] && units+=("$path")
  done < "$registry_dir/units"
  (( ${#units[@]} )) && remove_files "${units[@]}"
  
  # Remove files
  local files=()
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] && files+=("$path")
  done < "$registry_dir/files"
  (( ${#files[@]} )) && remove_files "${files[@]}"
  
  # Remove links
  local links=()
  while IFS= read -r path; do
    [[ -n "$path" ]] && links+=("$path")
  done < "$registry_dir/links" 2>/dev/null || true
  (( ${#links[@]} )) && remove_links "${links[@]}"
  
  # Remove directories (reverse order)
  local dirs=()
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] && dirs+=("$path")
  done < <(tac "$registry_dir/dirs")
  (( ${#dirs[@]} )) && remove_dirs "${dirs[@]}"
}
