#!/bin/bash
#
# example-config-usage.sh - Example of using the safe configuration library
#
# This script demonstrates how to safely load, validate, and write
# configuration files using the flowless secure configuration system.
#

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the configuration libraries
# shellcheck source=lib/validators.sh
source "$SCRIPT_DIR/lib/validators.sh"
# shellcheck source=lib/config-loader.sh
source "$SCRIPT_DIR/lib/config-loader.sh"
# shellcheck source=lib/config-writer.sh
source "$SCRIPT_DIR/lib/config-writer.sh"

echo "==============================================="
echo "  Flowless Safe Configuration Example"
echo "==============================================="
echo ""

# Example 1: Validate individual values
echo "Example 1: Validating configuration values"
echo "-------------------------------------------"

# Validate a port number
if validate_port "1080"; then
    echo "✓ Port 1080 is valid"
else
    echo "✗ Port 1080 is invalid"
fi

# Try an invalid port
if validate_port "70000"; then
    echo "✓ Port 70000 is valid"
else
    echo "✗ Port 70000 is invalid (expected)"
fi

# Validate an IP address
if validate_ip "192.168.1.1"; then
    echo "✓ IP 192.168.1.1 is valid"
else
    echo "✗ IP 192.168.1.1 is invalid"
fi

# Validate a hostname
if validate_hostname "example.com"; then
    echo "✓ Hostname example.com is valid"
else
    echo "✗ Hostname example.com is invalid"
fi

echo ""

# Example 2: Sanitize user input
echo "Example 2: Sanitizing user input"
echo "---------------------------------"

dangerous_input="rm -rf /; echo 'hacked'"
safe_output=$(sanitize_shell_arg "$dangerous_input")
echo "Original: $dangerous_input"
echo "Sanitized: $safe_output"

echo ""

# Example 3: Safe configuration loading
echo "Example 3: Safe configuration loading"
echo "--------------------------------------"

# Create a test config file
TEST_CONFIG="/tmp/flowless_example.conf"
cat > "$TEST_CONFIG" << 'EOF'
# Example configuration
local_addr=127.0.0.1
local_port=1080
server_addr=example.com
server_port=4000
EOF

# Load the configuration safely
if load_config "$TEST_CONFIG" "EXAMPLE_"; then
    echo "✓ Configuration loaded successfully"
    echo "  EXAMPLE_LOCAL_ADDR = ${EXAMPLE_LOCAL_ADDR}"
    echo "  EXAMPLE_LOCAL_PORT = ${EXAMPLE_LOCAL_PORT}"
    echo "  EXAMPLE_SERVER_ADDR = ${EXAMPLE_SERVER_ADDR}"
    echo "  EXAMPLE_SERVER_PORT = ${EXAMPLE_SERVER_PORT}"
else
    echo "✗ Failed to load configuration"
fi

echo ""

# Example 4: Safe configuration writing
echo "Example 4: Safe configuration writing"
echo "--------------------------------------"

WRITE_CONFIG="/tmp/flowless_write_example.conf"

# Write a single key-value pair
if write_config "$WRITE_CONFIG" "test_key" "test_value"; then
    echo "✓ Configuration written successfully"
    echo "  File: $WRITE_CONFIG"
    
    # Check permissions
    perms=$(stat -c "%a" "$WRITE_CONFIG" 2>/dev/null || stat -f "%Lp" "$WRITE_CONFIG" 2>/dev/null)
    echo "  Permissions: $perms (should be 600)"
fi

# Write multiple keys at once
if write_config_batch "$WRITE_CONFIG" \
    "local_addr" "127.0.0.1" \
    "local_port" "1080" \
    "server_addr" "example.com"; then
    echo "✓ Batch configuration written successfully"
fi

# Display the final config file
echo ""
echo "Final configuration file contents:"
echo "-----------------------------------"
cat "$WRITE_CONFIG"

echo ""

# Example 5: Demonstrating security - rejecting dangerous input
echo "Example 5: Security - Rejecting dangerous input"
echo "------------------------------------------------"

DANGEROUS_CONFIG="/tmp/flowless_dangerous.conf"
cat > "$DANGEROUS_CONFIG" << 'EOF'
safe_key=safe_value
malicious_key=$(whoami)
another_safe=value
EOF

echo "Attempting to load dangerous config..."
if load_config "$DANGEROUS_CONFIG" "DANGER_"; then
    echo "✗ ERROR: Dangerous config was loaded (this shouldn't happen!)"
else
    echo "✓ Dangerous config was correctly rejected"
fi

# Cleanup
rm -f "$TEST_CONFIG" "$WRITE_CONFIG" "$WRITE_CONFIG.backup" "$DANGEROUS_CONFIG"

echo ""
echo "==============================================="
echo "  Examples Complete"
echo "==============================================="
echo ""
echo "Key takeaways:"
echo "1. Always validate user input before using it"
echo "2. Use load_config() instead of 'source' for config files"
echo "3. Use write_config() for atomic, safe file updates"
echo "4. Configuration files are automatically set to secure permissions (600)"
echo "5. The library automatically rejects dangerous characters"
echo ""
