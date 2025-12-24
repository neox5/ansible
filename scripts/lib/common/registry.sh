#!/usr/bin/env bash
set -euo pipefail

# Lifecycle
ensure_registry() {
  local registry_dir="${STATE_DIR}/${COMPONENT}.registry"
  
  # Idempotent: create if doesn't exist
  if [[ ! -d "$registry_dir" ]]; then
    mkdir -p "$registry_dir"
    touch "$registry_dir"/{dirs,files,units,links}
    echo "$(date +%s)" > "$registry_dir/.lock"
  fi
}

# Registration
registry_add() {
  local type="$1" path="$2" mode="${3:-}"
  local registry_file="${STATE_DIR}/${COMPONENT}.registry/${type}"
  
  # Build entry
  local entry="$path"
  [[ -n "$mode" && "$type" != "links" ]] && entry="$path $mode"
  
  # Idempotent check
  grep -q "^${path}[[:space:]]" "$registry_file" 2>/dev/null && return 0
  grep -qxF "$path" "$registry_file" 2>/dev/null && return 0
  
  echo "$entry" >> "$registry_file"
}

registry_remove() {
  local type="$1" path="$2"
  local registry_file="${STATE_DIR}/${COMPONENT}.registry/${type}"
  
  # Read, filter, write back (idempotent - no error on "not found")
  local content
  content=$(grep -v "^${path}[[:space:]]" "$registry_file" 2>/dev/null | \
            grep -vxF "$path" 2>/dev/null || true)
  echo "$content" > "$registry_file"
}

registry_has() {
  local type="$1" path="$2"
  local registry_file="${STATE_DIR}/${COMPONENT}.registry/${type}"
  
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
  
  # Verify links
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ -L "$path" ]] || {
      echo "missing symlink: $path" >&2
      exit_code=1
    }
  done < "${registry_dir}/links"
  
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
  
  for type in dirs files units links; do
    local file="${registry_dir}/${type}"
    [[ -f "$file" ]] || {
      echo "error: registry file missing: $file" >&2
      ((errors++))
      continue
    }
    
    # Check format (skip for links - different format)
    if [[ "$type" != "links" ]]; then
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
      # Validate links (single column)
      local line_num=0
      while IFS= read -r path; do
        ((line_num++))
        [[ -z "$path" ]] && continue
        [[ "$path" == /* ]] || {
          echo "error: relative path in ${file}:${line_num}: $path" >&2
          ((errors++))
        }
      done < "$file"
    fi
    
    # Check duplicates
    local unique_count
    unique_count=$(sort -u "$file" | wc -l)
    local total_count
    total_count=$(wc -l < "$file")
    
    if [[ "$unique_count" -ne "$total_count" ]]; then
      echo "error: duplicate entries in $file" >&2
      ((errors++))
    fi
  done
  
  return "$errors"
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
  
  # Remove symlinks (may or may not exist on filesystem)
  local links=()
  while IFS= read -r path; do
    [[ -n "$path" ]] && links+=("$path")
  done < "$registry_dir/links"
  (( ${#links[@]} )) && remove_links "${links[@]}"
  
  # Remove files
  local files=()
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] && files+=("$path")
  done < "$registry_dir/files"
  (( ${#files[@]} )) && remove_files "${files[@]}"
  
  # Remove directories (reverse order)
  local dirs=()
  while IFS=' ' read -r path mode; do
    [[ -n "$path" ]] && dirs+=("$path")
  done < <(tac "$registry_dir/dirs")
  (( ${#dirs[@]} )) && remove_dirs "${dirs[@]}"
}
