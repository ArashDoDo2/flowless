#!/bin/bash
#
# config-loader.sh - Safe configuration file loader for flowless
#
# Loads configuration files WITHOUT using eval or source, preventing code injection.
# Inspired by paqctl's _load_settings() function.
#
# Security features:
# - No eval/source on user config files
# - Whitelist-based key validation
# - Rejects dangerous characters in values
# - Uses case statements for safe variable assignment
# - Validates numeric values
#

# Get the directory of this script to source validators
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source validators if not already loaded
if ! declare -f validate_safe_value >/dev/null 2>&1; then
    # shellcheck source=lib/validators.sh
    source "$SCRIPT_DIR/validators.sh"
fi

# Load configuration from file safely
# Usage: load_config <config_file> <prefix>
# Example: load_config "/etc/flowless/paqet.conf" "PAQET_"
#
# This function:
# - Reads config file line by line
# - Validates keys against whitelist (uppercase, underscores, digits)
# - Validates values don't contain dangerous characters
# - Sets variables with optional prefix
# - Skips comments and empty lines
#
# Returns: 0 on success, 1 on error
load_config() {
    local config_file="$1"
    local prefix="${2:-}"
    
    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        echo "Error: Configuration file not found: $config_file" >&2
        return 1
    fi
    
    # Check if config file is readable
    if [ ! -r "$config_file" ]; then
        echo "Error: Configuration file not readable: $config_file" >&2
        return 1
    fi
    
    local line_num=0
    local key value
    
    # Read configuration file line by line
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Skip comments (lines starting with #)
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Parse key=value pairs
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z_0-9]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            
            # Convert key to uppercase for validation
            local upper_key="${key^^}"
            
            # Validate key format (must be uppercase letters, underscores, digits)
            if ! validate_config_key "$upper_key"; then
                echo "Error: Invalid key at line $line_num: $key" >&2
                echo "Keys must match: ^[A-Z_][A-Z_0-9]*$" >&2
                return 1
            fi
            
            # Validate value doesn't contain dangerous characters
            if ! validate_safe_value "$value"; then
                echo "Error: Dangerous characters in value at line $line_num" >&2
                echo "Key: $key" >&2
                return 1
            fi
            
            # Use case statement for safe assignment (no eval)
            # This approach prevents code injection even if key/value are malicious
            _safe_set_var "$prefix$upper_key" "$value"
            
        else
            # Line doesn't match key=value format
            echo "Warning: Skipping invalid line $line_num: $line" >&2
        fi
        
    done < "$config_file"
    
    return 0
}

# Safely set a variable without using eval
# Usage: _safe_set_var <var_name> <value>
# This uses printf -v which is safe from code injection
_safe_set_var() {
    local var_name="$1"
    local value="$2"
    
    # Use printf -v for safe variable assignment
    # This is equivalent to var_name="$value" but works with dynamic names
    printf -v "$var_name" '%s' "$value"
}

# Get a configuration value safely
# Usage: get_config <var_name> [<prefix>]
# Returns: Prints value to stdout, returns 0 if found, 1 if not
get_config() {
    local var_name="$1"
    local prefix="${2:-}"
    local full_name="$prefix$var_name"
    
    # Check if variable is set
    if [ -z "${!full_name+x}" ]; then
        return 1
    fi
    
    # Print value
    echo "${!full_name}"
    return 0
}

# Validate and load a port configuration value
# Usage: load_config_port <config_file> <key> <var_name> [<prefix>]
# Example: load_config_port "/etc/flowless/paqet.conf" "local_port" "LOCAL_PORT"
#
# Returns: 0 on success, 1 on error
load_config_port() {
    local config_file="$1"
    local key="$2"
    local var_name="$3"
    local prefix="${4:-}"
    
    # First load the config
    if ! load_config "$config_file" "$prefix"; then
        return 1
    fi
    
    # Get the value
    local upper_key="${key^^}"
    local value
    if ! value=$(get_config "$upper_key" "$prefix"); then
        echo "Error: Required port configuration key not found: $key" >&2
        return 1
    fi
    
    # Validate it's a valid port
    if ! validate_port "$value"; then
        echo "Error: Invalid port value for $key: $value" >&2
        return 1
    fi
    
    # Set the output variable
    _safe_set_var "$var_name" "$value"
    return 0
}

# Validate and load an IP address configuration value
# Usage: load_config_ip <config_file> <key> <var_name> [<prefix>]
load_config_ip() {
    local config_file="$1"
    local key="$2"
    local var_name="$3"
    local prefix="${4:-}"
    
    # Get the value
    local upper_key="${key^^}"
    local value
    if ! value=$(get_config "$upper_key" "$prefix"); then
        echo "Error: Required IP configuration key not found: $key" >&2
        return 1
    fi
    
    # Validate it's a valid IP
    if ! validate_ip "$value"; then
        echo "Error: Invalid IP value for $key: $value" >&2
        return 1
    fi
    
    # Set the output variable
    _safe_set_var "$var_name" "$value"
    return 0
}

# Validate and load a hostname configuration value
# Usage: load_config_hostname <config_file> <key> <var_name> [<prefix>]
load_config_hostname() {
    local config_file="$1"
    local key="$2"
    local var_name="$3"
    local prefix="${4:-}"
    
    # Get the value
    local upper_key="${key^^}"
    local value
    if ! value=$(get_config "$upper_key" "$prefix"); then
        echo "Error: Required hostname configuration key not found: $key" >&2
        return 1
    fi
    
    # Validate hostname or IP
    if ! validate_hostname "$value" && ! validate_ip "$value"; then
        echo "Error: Invalid hostname/IP value for $key: $value" >&2
        return 1
    fi
    
    # Set the output variable
    _safe_set_var "$var_name" "$value"
    return 0
}
