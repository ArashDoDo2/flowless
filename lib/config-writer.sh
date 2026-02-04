#!/bin/bash
#
# config-writer.sh - Safe configuration file writer for flowless
#
# Writes configuration files safely using atomic operations.
# Inspired by paqctl's atomic file operations.
#
# Security features:
# - Atomic writes (temp file + mv)
# - Escapes special characters in values
# - Secure file permissions (umask 077, chmod 600)
# - Validates all values before writing
# - Creates backups before overwriting
#

# Get the directory of this script to source validators
_CONFIG_WRITER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source validators if not already loaded
if ! declare -f validate_safe_value >/dev/null 2>&1; then
    # shellcheck source=lib/validators.sh
    source "$_CONFIG_WRITER_DIR/validators.sh"
fi

# Write configuration file atomically
# Usage: write_config <config_file> <key> <value>
# Example: write_config "/etc/flowless/paqet.conf" "local_port" "1080"
#
# This function:
# - Creates a backup of existing config
# - Validates the value
# - Writes to a temporary file with secure permissions
# - Atomically moves temp file to target location
#
# Returns: 0 on success, 1 on error
write_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    
    # Validate key
    local upper_key="${key^^}"
    if ! validate_config_key "$upper_key"; then
        echo "Error: Invalid configuration key: $key" >&2
        return 1
    fi
    
    # Validate value
    if ! validate_safe_value "$value"; then
        echo "Error: Value contains dangerous characters" >&2
        return 1
    fi
    
    # Create directory if it doesn't exist
    local config_dir
    config_dir="$(dirname "$config_file")"
    if [ ! -d "$config_dir" ]; then
        if ! mkdir -p "$config_dir"; then
            echo "Error: Failed to create config directory: $config_dir" >&2
            return 1
        fi
    fi
    
    # Create backup if file exists
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup"
        if ! cp "$config_file" "$backup_file"; then
            echo "Error: Failed to create backup" >&2
            return 1
        fi
        echo "Backup created: $backup_file" >&2
    fi
    
    # Create temporary file with secure permissions
    local temp_file
    if ! temp_file="$(mktemp "${config_file}.XXXXXX")"; then
        echo "Error: Failed to create temporary file" >&2
        return 1
    fi
    
    # Set secure permissions on temp file (owner read/write only)
    if ! chmod 600 "$temp_file"; then
        echo "Error: Failed to set permissions on temporary file" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # If config exists, copy it to temp and update the key
    if [ -f "$config_file" ]; then
        local found=0
        while IFS= read -r line || [ -n "$line" ]; do
            # Check if this line contains our key
            if [[ "$line" =~ ^[[:space:]]*${key}= ]]; then
                # Replace the line with new value
                echo "${key}=${value}" >> "$temp_file"
                found=1
            else
                # Keep the line as-is
                echo "$line" >> "$temp_file"
            fi
        done < "$config_file"
        
        # If key wasn't found, append it
        if [ "$found" -eq 0 ]; then
            echo "${key}=${value}" >> "$temp_file"
        fi
    else
        # New file, just write the key=value pair
        echo "${key}=${value}" > "$temp_file"
    fi
    
    # Atomically move temp file to target location
    # mv is atomic on the same filesystem
    if ! mv "$temp_file" "$config_file"; then
        echo "Error: Failed to move temporary file to target location" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Ensure final file has secure permissions
    if ! chmod 600 "$config_file"; then
        echo "Warning: Failed to set final permissions" >&2
    fi
    
    return 0
}

# Write multiple configuration key-value pairs atomically
# Usage: write_config_batch <config_file> <key1> <value1> <key2> <value2> ...
# Example: write_config_batch "/etc/flowless/paqet.conf" "local_port" "1080" "server_port" "4000"
#
# Returns: 0 on success, 1 on error
write_config_batch() {
    local config_file="$1"
    shift
    
    # Validate we have an even number of arguments (key-value pairs)
    if [ $(($# % 2)) -ne 0 ]; then
        echo "Error: write_config_batch requires key-value pairs" >&2
        return 1
    fi
    
    # Validate all keys and values first
    local -a keys=()
    local -a values=()
    while [ $# -gt 0 ]; do
        local key="$1"
        local value="$2"
        shift 2
        
        # Validate key
        local upper_key="${key^^}"
        if ! validate_config_key "$upper_key"; then
            echo "Error: Invalid configuration key: $key" >&2
            return 1
        fi
        
        # Validate value
        if ! validate_safe_value "$value"; then
            echo "Error: Value contains dangerous characters for key: $key" >&2
            return 1
        fi
        
        keys+=("$key")
        values+=("$value")
    done
    
    # Create directory if it doesn't exist
    local config_dir
    config_dir="$(dirname "$config_file")"
    if [ ! -d "$config_dir" ]; then
        if ! mkdir -p "$config_dir"; then
            echo "Error: Failed to create config directory: $config_dir" >&2
            return 1
        fi
    fi
    
    # Create backup if file exists
    if [ -f "$config_file" ]; then
        local backup_file="${config_file}.backup"
        if ! cp "$config_file" "$backup_file"; then
            echo "Error: Failed to create backup" >&2
            return 1
        fi
        echo "Backup created: $backup_file" >&2
    fi
    
    # Create temporary file with secure permissions
    local temp_file
    if ! temp_file="$(mktemp "${config_file}.XXXXXX")"; then
        echo "Error: Failed to create temporary file" >&2
        return 1
    fi
    
    # Set secure permissions on temp file
    if ! chmod 600 "$temp_file"; then
        echo "Error: Failed to set permissions on temporary file" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Build associative array of keys to update
    declare -A updates
    for i in "${!keys[@]}"; do
        updates["${keys[$i]}"]="${values[$i]}"
    done
    
    # If config exists, copy it to temp and update the keys
    local -A found_keys
    if [ -f "$config_file" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            local updated=0
            # Check if this line contains any of our keys
            for key in "${keys[@]}"; do
                if [[ "$line" =~ ^[[:space:]]*${key}= ]]; then
                    # Replace the line with new value
                    echo "${key}=${updates[$key]}" >> "$temp_file"
                    found_keys["$key"]=1
                    updated=1
                    break
                fi
            done
            
            # If no update was made, keep the line as-is
            if [ "$updated" -eq 0 ]; then
                echo "$line" >> "$temp_file"
            fi
        done < "$config_file"
    fi
    
    # Append any keys that weren't found in the file
    for key in "${keys[@]}"; do
        if [ -z "${found_keys[$key]+x}" ]; then
            echo "${key}=${updates[$key]}" >> "$temp_file"
        fi
    done
    
    # Atomically move temp file to target location
    if ! mv "$temp_file" "$config_file"; then
        echo "Error: Failed to move temporary file to target location" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Ensure final file has secure permissions
    if ! chmod 600 "$config_file"; then
        echo "Warning: Failed to set final permissions" >&2
    fi
    
    return 0
}

# Create a new configuration file with secure permissions
# Usage: create_config <config_file> <content>
# Example: create_config "/etc/flowless/new.conf" "key1=value1\nkey2=value2"
#
# Returns: 0 on success, 1 on error
create_config() {
    local config_file="$1"
    local content="$2"
    
    # Check if file already exists
    if [ -f "$config_file" ]; then
        echo "Error: Configuration file already exists: $config_file" >&2
        return 1
    fi
    
    # Create directory if it doesn't exist
    local config_dir
    config_dir="$(dirname "$config_file")"
    if [ ! -d "$config_dir" ]; then
        if ! mkdir -p "$config_dir"; then
            echo "Error: Failed to create config directory: $config_dir" >&2
            return 1
        fi
    fi
    
    # Create temporary file with secure permissions
    local temp_file
    if ! temp_file="$(mktemp "${config_file}.XXXXXX")"; then
        echo "Error: Failed to create temporary file" >&2
        return 1
    fi
    
    # Set secure permissions on temp file (owner read/write only)
    if ! chmod 600 "$temp_file"; then
        echo "Error: Failed to set permissions on temporary file" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Write content to temp file
    if ! echo -e "$content" > "$temp_file"; then
        echo "Error: Failed to write content to temporary file" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    # Atomically move temp file to target location
    if ! mv "$temp_file" "$config_file"; then
        echo "Error: Failed to move temporary file to target location" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    return 0
}
