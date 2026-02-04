#!/bin/bash
#
# test-config.sh - Test suite for flowless configuration management
#
# Tests the validators, config loader, and config writer
#

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source the libraries
# shellcheck source=lib/validators.sh
source "$LIB_DIR/validators.sh"
# shellcheck source=lib/config-loader.sh
source "$LIB_DIR/config-loader.sh"
# shellcheck source=lib/config-writer.sh
source "$LIB_DIR/config-writer.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helper functions
assert_success() {
    local description="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if "$@" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local description="$1"
    shift
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if ! "$@" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_equals() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $description"
        echo "  Expected: $expected"
        echo "  Actual: $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "=========================================="
echo "  Flowless Configuration Tests"
echo "=========================================="
echo ""

# Test validators.sh
echo "Testing validators.sh..."
echo ""

# Port validation tests
echo "Port Validation:"
assert_success "Valid port: 1080" validate_port "1080"
assert_success "Valid port: 1" validate_port "1"
assert_success "Valid port: 65535" validate_port "65535"
assert_failure "Invalid port: 0" validate_port "0"
assert_failure "Invalid port: 65536" validate_port "65536"
assert_failure "Invalid port: -1" validate_port "-1"
assert_failure "Invalid port: abc" validate_port "abc"
assert_failure "Invalid port: empty" validate_port ""
echo ""

# IP validation tests
echo "IP Validation:"
assert_success "Valid IP: 127.0.0.1" validate_ip "127.0.0.1"
assert_success "Valid IP: 192.168.1.1" validate_ip "192.168.1.1"
assert_success "Valid IP: 8.8.8.8" validate_ip "8.8.8.8"
assert_failure "Invalid IP: 256.0.0.1" validate_ip "256.0.0.1"
assert_failure "Invalid IP: 192.168.1" validate_ip "192.168.1"
assert_failure "Invalid IP: abc.def.ghi.jkl" validate_ip "abc.def.ghi.jkl"
assert_failure "Invalid IP: empty" validate_ip ""
echo ""

# Path validation tests
echo "Path Validation:"
assert_success "Valid path: /etc/flowless/paqet.conf" validate_path "/etc/flowless/paqet.conf"
assert_success "Valid path: ./config.conf" validate_path "./config.conf"
assert_success "Valid path: ../config/test.conf" validate_path "../config/test.conf"
assert_failure "Invalid path: empty" validate_path ""
# Test excessive traversal
assert_failure "Invalid path: ../../../../../../../etc/passwd" validate_path "../../../../../../../etc/passwd"
echo ""

# Hostname validation tests
echo "Hostname Validation:"
assert_success "Valid hostname: example.com" validate_hostname "example.com"
assert_success "Valid hostname: my-server.example.com" validate_hostname "my-server.example.com"
assert_success "Valid hostname: localhost" validate_hostname "localhost"
assert_success "Valid hostname: server123" validate_hostname "server123"
assert_failure "Invalid hostname: -invalid.com" validate_hostname "-invalid.com"
assert_failure "Invalid hostname: invalid-.com" validate_hostname "invalid-.com"
assert_failure "Invalid hostname: empty" validate_hostname ""
echo ""

# Sanitization tests
echo "Sanitization:"
result=$(sanitize_shell_arg "normal_text")
assert_equals "Sanitize normal text" "normal_text" "$result"

result=$(sanitize_shell_arg "text_with_\$var")
assert_equals "Sanitize text with dollar sign" "text_with_var" "$result"

result=$(sanitize_shell_arg "text_with_backtick\`")
assert_equals "Sanitize text with backtick" "text_with_backtick" "$result"
echo ""

# Config key validation tests
echo "Config Key Validation:"
assert_success "Valid key: LOCAL_PORT" validate_config_key "LOCAL_PORT"
assert_success "Valid key: SERVER_ADDR" validate_config_key "SERVER_ADDR"
assert_success "Valid key: KCP_MODE" validate_config_key "KCP_MODE"
assert_success "Valid key: _PRIVATE_VAR" validate_config_key "_PRIVATE_VAR"
assert_failure "Invalid key: lowercase" validate_config_key "lowercase"
assert_failure "Invalid key: 123START" validate_config_key "123START"
assert_failure "Invalid key: INVALID-KEY" validate_config_key "INVALID-KEY"
echo ""

# Safe value validation tests
echo "Safe Value Validation:"
assert_success "Safe value: normal text" validate_safe_value "normal text"
assert_success "Safe value: with.dots" validate_safe_value "with.dots"
assert_success "Safe value: with-dashes" validate_safe_value "with-dashes"
assert_failure "Safe value: with\$dollar" validate_safe_value "with\$dollar"
assert_failure "Safe value: with\`backtick" validate_safe_value "with\`backtick"
assert_failure "Safe value: with;semicolon" validate_safe_value "with;semicolon"
echo ""

# Test config-loader.sh
echo "Testing config-loader.sh..."
echo ""

# Create a temporary config file for testing
TEST_DIR=$(mktemp -d)
TEST_CONFIG="$TEST_DIR/test.conf"

cat > "$TEST_CONFIG" << 'EOF'
# Test configuration
local_addr=127.0.0.1
local_port=1080
server_addr=example.com
server_port=4000

# Comment line
kcp_mode=fast2
EOF

echo "Config Loading:"
assert_success "Load valid config file" load_config "$TEST_CONFIG" "TEST_"

# Check if variables were loaded
if [ "${TEST_LOCAL_ADDR}" = "127.0.0.1" ]; then
    echo -e "${GREEN}✓${NC} Variable TEST_LOCAL_ADDR loaded correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Variable TEST_LOCAL_ADDR not loaded correctly"
    echo "  Expected: 127.0.0.1, Got: ${TEST_LOCAL_ADDR}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

if [ "${TEST_LOCAL_PORT}" = "1080" ]; then
    echo -e "${GREEN}✓${NC} Variable TEST_LOCAL_PORT loaded correctly"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Variable TEST_LOCAL_PORT not loaded correctly"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

assert_failure "Reject non-existent file" load_config "/nonexistent/file.conf" "TEST_"
echo ""

# Test dangerous config
DANGEROUS_CONFIG="$TEST_DIR/dangerous.conf"
cat > "$DANGEROUS_CONFIG" << 'EOF'
safe_key=safe_value
dangerous_key=$(rm -rf /)
EOF

echo "Security Tests:"
assert_failure "Reject config with dangerous characters" load_config "$DANGEROUS_CONFIG" "DANGER_"
echo ""

# Test config-writer.sh
echo "Testing config-writer.sh..."
echo ""

WRITE_TEST_CONFIG="$TEST_DIR/write_test.conf"

echo "Config Writing:"
assert_success "Write single key-value" write_config "$WRITE_TEST_CONFIG" "test_key" "test_value"

# Check if file was created with secure permissions
if [ -f "$WRITE_TEST_CONFIG" ]; then
    perms=$(stat -c "%a" "$WRITE_TEST_CONFIG" 2>/dev/null || stat -f "%Lp" "$WRITE_TEST_CONFIG" 2>/dev/null)
    if [ "$perms" = "600" ]; then
        echo -e "${GREEN}✓${NC} File has secure permissions (600)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} File does not have secure permissions"
        echo "  Expected: 600, Got: $perms"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
fi

# Test backup creation
assert_success "Update existing key creates backup" write_config "$WRITE_TEST_CONFIG" "test_key" "new_value"

if [ -f "$WRITE_TEST_CONFIG.backup" ]; then
    echo -e "${GREEN}✓${NC} Backup file created"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} Backup file not created"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi
TESTS_RUN=$((TESTS_RUN + 1))

# Test batch write
BATCH_TEST_CONFIG="$TEST_DIR/batch_test.conf"
assert_success "Batch write multiple keys" write_config_batch "$BATCH_TEST_CONFIG" "key1" "value1" "key2" "value2"
echo ""

# Cleanup
rm -rf "$TEST_DIR"

# Print summary
echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo "Tests run: $TESTS_RUN"
echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
