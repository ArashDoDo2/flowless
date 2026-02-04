#!/bin/bash
#
# validators.sh - Input validation functions for flowless
#
# Provides safe validation functions for configuration values.
# Inspired by paqctl's security patterns.
#

# Validate port number (1-65535)
# Usage: validate_port <port>
# Returns: 0 if valid, 1 if invalid
validate_port() {
    local port="$1"
    
    # Check if empty
    if [ -z "$port" ]; then
        echo "Error: Port cannot be empty" >&2
        return 1
    fi
    
    # Check if numeric
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be numeric" >&2
        return 1
    fi
    
    # Check range
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Port must be between 1 and 65535" >&2
        return 1
    fi
    
    return 0
}

# Validate IPv4 address
# Usage: validate_ip <ip>
# Returns: 0 if valid, 1 if invalid
validate_ip() {
    local ip="$1"
    
    # Check if empty
    if [ -z "$ip" ]; then
        echo "Error: IP address cannot be empty" >&2
        return 1
    fi
    
    # Check IPv4 format using regex
    if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "Error: Invalid IP address format" >&2
        return 1
    fi
    
    # Check each octet is 0-255
    local IFS='.'
    local -a octets
    read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if [ "$octet" -gt 255 ]; then
            echo "Error: IP address octet out of range (0-255)" >&2
            return 1
        fi
    done
    
    return 0
}

# Validate filesystem path
# Usage: validate_path <path>
# Returns: 0 if valid, 1 if invalid
validate_path() {
    local path="$1"
    
    # Check if empty
    if [ -z "$path" ]; then
        echo "Error: Path cannot be empty" >&2
        return 1
    fi
    
    # Check length (Linux PATH_MAX is typically 4096)
    if [ ${#path} -ge 4096 ]; then
        echo "Error: Path too long (max 4095 characters)" >&2
        return 1
    fi
    
    # Check for parent directory traversal patterns (../../../etc/passwd)
    # Allow single ../ for relative paths, but reject excessive traversal
    local traversal_count
    traversal_count=$(echo "$path" | grep -o '\.\.' | wc -l)
    if [ "$traversal_count" -gt 2 ]; then
        echo "Error: Excessive parent directory traversal in path" >&2
        return 1
    fi
    
    return 0
}

# Validate hostname or domain name
# Usage: validate_hostname <hostname>
# Returns: 0 if valid, 1 if invalid
validate_hostname() {
    local hostname="$1"
    
    # Check if empty
    if [ -z "$hostname" ]; then
        echo "Error: Hostname cannot be empty" >&2
        return 1
    fi
    
    # Check length (max 253 characters for FQDN)
    if [ ${#hostname} -gt 253 ]; then
        echo "Error: Hostname too long (max 253 characters)" >&2
        return 1
    fi
    
    # Check format: alphanumeric, hyphens, dots
    # Labels can't start or end with hyphen
    # Valid examples: example.com, my-server.example.com, localhost
    if ! [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        echo "Error: Invalid hostname format" >&2
        return 1
    fi
    
    return 0
}

# Sanitize shell argument by removing dangerous characters
# Usage: sanitize_shell_arg <arg>
# Outputs: Sanitized string (prints to stdout)
# Returns: 0 always (sanitization cannot fail)
sanitize_shell_arg() {
    local arg="$1"
    
    # Remove dangerous shell metacharacters using tr:
    # Backticks, dollar signs, parentheses, braces, brackets,
    # redirects, pipes, semicolons, ampersands, exclamation marks,
    # newlines, carriage returns, tabs, single/double quotes, backslashes
    echo "$arg" | tr -d '\`$(){}<>|;&!'"'"'"\r\n\t\\'
}

# Validate that a string contains only safe configuration key characters
# Usage: validate_config_key <key>
# Returns: 0 if valid, 1 if invalid
validate_config_key() {
    local key="$1"
    
    # Check if empty
    if [ -z "$key" ]; then
        echo "Error: Configuration key cannot be empty" >&2
        return 1
    fi
    
    # Whitelist: Must match ^[A-Z_][A-Z_0-9]*$
    # Starts with uppercase letter or underscore
    # Followed by uppercase letters, underscores, or digits
    if ! [[ "$key" =~ ^[A-Z_][A-Z_0-9]*$ ]]; then
        echo "Error: Invalid configuration key format. Must match ^[A-Z_][A-Z_0-9]*$" >&2
        return 1
    fi
    
    return 0
}

# Validate that a string doesn't contain dangerous characters
# Usage: validate_safe_value <value>
# Returns: 0 if safe, 1 if contains dangerous characters
validate_safe_value() {
    local value="$1"
    
    # Check for dangerous characters using case statement (more portable)
    # Check each dangerous character one by one
    case "$value" in
        *'`'*|*'$'*|*'('*|*')'*|*'{'*|*'}'*|*'['*|*']'*|*'<'*|*'>'*|*'|'*|*';'*|*'&'*|*'!'*|*$'\n'*|*$'\r'*|*$'\t'*|*'\'*)
            echo "Error: Value contains dangerous characters" >&2
            return 1
            ;;
    esac
    
    return 0
}
