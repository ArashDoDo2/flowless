#!/bin/bash
#
# test-process-manager.sh - Test suite for process management
#
# Tests process lifecycle, PID management, resource monitoring, and watchdog
#

set -euo pipefail

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# Source the libraries
source "$LIB_DIR/process-manager.sh"
source "$LIB_DIR/resource-monitor.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_TMP_DIR="/tmp/flowless-test-$$"
TEST_PID_DIR="$TEST_TMP_DIR/run"
TEST_LOG_DIR="$TEST_TMP_DIR/log"

# Override default directories for testing
PID_DIR="$TEST_PID_DIR"
LOG_DIR="$TEST_LOG_DIR"

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
    
    if "$@" >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} $description (expected to fail)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        echo -e "${GREEN}✓${NC} $description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
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
        echo -e "${RED}✗${NC} $description (expected: $expected, got: $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Setup test environment
setup_test() {
    mkdir -p "$TEST_PID_DIR"
    mkdir -p "$TEST_LOG_DIR"
}

# Cleanup test environment
cleanup_test() {
    # Kill any test processes
    if [ -d "$TEST_PID_DIR" ]; then
        for pidfile in "$TEST_PID_DIR"/*.pid; do
            if [ -f "$pidfile" ]; then
                local pid
                pid=$(cat "$pidfile" 2>/dev/null || echo "")
                if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # Remove test directory
    rm -rf "$TEST_TMP_DIR"
}

# Create a test process (long-running sleep)
create_test_process() {
    local name="$1"
    local duration="${2:-3600}"
    
    nohup sleep "$duration" >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "$(get_pid_file "$name")"
    echo "$pid"
}

# Test: PID validation
test_pid_validation() {
    echo -e "\n${BLUE}Testing PID validation...${NC}"
    
    # Valid PID format
    assert_success "Valid PID (123)" is_pid_running "$$"
    
    # Invalid PID formats
    assert_failure "Invalid PID (abc)" is_pid_running "abc"
    assert_failure "Invalid PID (empty)" is_pid_running ""
    assert_failure "Invalid PID (negative)" is_pid_running "-123"
    assert_failure "Invalid PID (non-existent)" is_pid_running "999999"
}

# Test: PID file operations
test_pid_file_operations() {
    echo -e "\n${BLUE}Testing PID file operations...${NC}"
    
    # Get PID file path
    local pid_file
    pid_file=$(get_pid_file "test-backend")
    assert_equals "PID file path format" "$TEST_PID_DIR/flowless-test-backend.pid" "$pid_file"
    
    # Create test process
    local test_pid
    test_pid=$(create_test_process "test-backend")
    
    # Check if process is running
    assert_success "Process detected as running" is_process_running "test-backend"
    
    # Get process PID
    local retrieved_pid
    retrieved_pid=$(get_process_pid "test-backend")
    assert_equals "Retrieved correct PID" "$test_pid" "$retrieved_pid"
    
    # Kill test process
    kill -KILL "$test_pid" 2>/dev/null || true
    sleep 1
    
    # Check if process is detected as stopped
    assert_failure "Process detected as stopped" is_process_running "test-backend"
    
    # PID file should be removed after checking stopped process
    assert_failure "Stale PID file removed" test -f "$pid_file"
}

# Test: Process start
test_process_start() {
    echo -e "\n${BLUE}Testing process start...${NC}"
    
    # Start a simple process
    assert_success "Start process" start_process "test-sleep" "sleep" "10"
    
    # Check if it's running
    assert_success "Process is running after start" is_process_running "test-sleep"
    
    # Check PID file exists
    assert_success "PID file created" test -f "$(get_pid_file "test-sleep")"
    
    # Check log file created
    assert_success "Log file created" test -f "$(get_log_file "test-sleep")"
    
    # Try to start again (should detect already running)
    assert_success "Start already running process (idempotent)" start_process "test-sleep" "sleep" "10"
    
    # Cleanup
    stop_process "test-sleep" 5 >/dev/null 2>&1 || true
}

# Test: Process stop (graceful)
test_process_stop_graceful() {
    echo -e "\n${BLUE}Testing graceful process stop...${NC}"
    
    # Start a process
    start_process "test-graceful" "sleep" "30" >/dev/null 2>&1
    sleep 1
    
    # Stop it gracefully
    assert_success "Stop process gracefully" stop_process "test-graceful" 5
    
    # Check if it's stopped
    assert_failure "Process is stopped" is_process_running "test-graceful"
    
    # Check PID file is removed
    assert_failure "PID file removed after stop" test -f "$(get_pid_file "test-graceful")"
}

# Test: Process stop (force kill)
test_process_stop_force() {
    echo -e "\n${BLUE}Testing force kill on unresponsive process...${NC}"
    
    # Create a test script that ignores SIGTERM
    local test_script="$TEST_TMP_DIR/trap_script.sh"
    cat > "$test_script" << 'EOF'
#!/bin/bash
trap "" TERM
while true; do
    sleep 1
done
EOF
    chmod +x "$test_script"
    
    # Start the stubborn process
    start_process "test-stubborn" "$test_script" "" >/dev/null 2>&1
    sleep 1
    
    # Try to stop with short timeout (will force kill)
    assert_success "Force kill stubborn process" stop_process "test-stubborn" 2
    
    # Check if it's stopped
    assert_failure "Stubborn process is stopped" is_process_running "test-stubborn"
}

# Test: Process restart
test_process_restart() {
    echo -e "\n${BLUE}Testing process restart...${NC}"
    
    # Start a process
    start_process "test-restart" "sleep" "30" >/dev/null 2>&1
    sleep 1
    
    local original_pid
    original_pid=$(get_process_pid "test-restart")
    
    # Restart it
    assert_success "Restart process" restart_process "test-restart" "sleep" "30"
    sleep 1
    
    # Check if new process is running
    assert_success "Process running after restart" is_process_running "test-restart"
    
    local new_pid
    new_pid=$(get_process_pid "test-restart")
    
    # PIDs should be different
    if [ "$original_pid" != "$new_pid" ]; then
        echo -e "${GREEN}✓${NC} New PID assigned after restart"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} New PID not assigned after restart"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Cleanup
    stop_process "test-restart" 5 >/dev/null 2>&1 || true
}

# Test: Port checking
test_port_checking() {
    echo -e "\n${BLUE}Testing port checking...${NC}"
    
    # Start a simple HTTP server on a random port
    local test_port=18888
    python3 -m http.server "$test_port" >/dev/null 2>&1 &
    local server_pid=$!
    sleep 2
    
    # Check if port is listening
    assert_success "Detect listening port" check_port_listening "$test_port"
    
    # Check non-listening port
    assert_failure "Detect non-listening port" check_port_listening "19999"
    
    # Cleanup
    kill -KILL "$server_pid" 2>/dev/null || true
}

# Test: Process health check
test_process_health() {
    echo -e "\n${BLUE}Testing process health checks...${NC}"
    
    # Create a test process
    local test_pid
    test_pid=$(create_test_process "test-health")
    
    # Health check without port
    assert_success "Healthy process (no port check)" is_process_healthy "test-health"
    
    # Start a server for port check
    local test_port=18889
    python3 -m http.server "$test_port" >/dev/null 2>&1 &
    local server_pid=$!
    echo "$server_pid" > "$(get_pid_file "test-server")"
    sleep 2
    
    # Health check with port
    assert_success "Healthy process (with port check)" is_process_healthy "test-server" "$test_port"
    
    # Stop server but keep PID file
    kill -KILL "$server_pid" 2>/dev/null || true
    sleep 1
    
    # Health check should fail (port not listening)
    assert_failure "Unhealthy process (port not listening)" is_process_healthy "test-server" "$test_port"
    
    # Cleanup
    kill -KILL "$test_pid" 2>/dev/null || true
    rm -f "$(get_pid_file "test-server")"
}

# Test: Resource monitoring
test_resource_monitoring() {
    echo -e "\n${BLUE}Testing resource monitoring...${NC}"
    
    # Create a test process
    start_process "test-stats" "sleep" "30" >/dev/null 2>&1
    sleep 2
    
    # Get process stats
    local stats
    stats=$(get_process_stats "test-stats")
    
    # Check stats contain expected fields
    assert_success "Stats contain status" echo "$stats" | grep -q "status=running"
    assert_success "Stats contain PID" echo "$stats" | grep -q "pid="
    assert_success "Stats contain CPU" echo "$stats" | grep -q "cpu="
    assert_success "Stats contain memory" echo "$stats" | grep -q "mem_kb="
    assert_success "Stats contain uptime" echo "$stats" | grep -q "uptime="
    
    # Test format_uptime function
    local uptime_1m
    uptime_1m=$(format_uptime 90)
    assert_equals "Format uptime (90s)" "1m 30s" "$uptime_1m"
    
    local uptime_1h
    uptime_1h=$(format_uptime 3665)
    assert_equals "Format uptime (3665s)" "1h 1m" "$uptime_1h"
    
    local uptime_1d
    uptime_1d=$(format_uptime 90000)
    assert_equals "Format uptime (90000s)" "1d 1h" "$uptime_1d"
    
    # Cleanup
    stop_process "test-stats" 5 >/dev/null 2>&1 || true
}

# Test: Get process info
test_process_info() {
    echo -e "\n${BLUE}Testing process info retrieval...${NC}"
    
    # Test stopped process
    local info_stopped
    info_stopped=$(get_process_info "nonexistent" 2>/dev/null || echo "status=stopped")
    assert_equals "Info for stopped process" "status=stopped" "$info_stopped"
    
    # Create and test running process
    local test_pid
    test_pid=$(create_test_process "test-info")
    
    local info_running
    info_running=$(get_process_info "test-info")
    
    assert_success "Info contains running status" echo "$info_running" | grep -q "status=running"
    assert_success "Info contains PID" echo "$info_running" | grep -q "pid=$test_pid"
    assert_success "Info contains start time" echo "$info_running" | grep -q "start_time="
    
    # Cleanup
    kill -KILL "$test_pid" 2>/dev/null || true
}

# Test: System stats
test_system_stats() {
    echo -e "\n${BLUE}Testing system statistics...${NC}"
    
    local sys_stats
    sys_stats=$(get_system_stats)
    
    assert_success "System stats contain total memory" echo "$sys_stats" | grep -q "total_mem_mb="
    assert_success "System stats contain available memory" echo "$sys_stats" | grep -q "avail_mem_mb="
    assert_success "System stats contain load average" echo "$sys_stats" | grep -q "load_average="
}

# Main test execution
main() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Flowless Process Manager Test Suite                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    
    # Setup
    setup_test
    
    # Run tests
    test_pid_validation
    test_pid_file_operations
    test_process_start
    test_process_stop_graceful
    test_process_stop_force
    test_process_restart
    test_port_checking
    test_process_health
    test_resource_monitoring
    test_process_info
    test_system_stats
    
    # Cleanup
    cleanup_test
    
    # Summary
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    TEST SUMMARY                            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Total tests run:    $TESTS_RUN"
    echo -e "Tests passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed:       ${RED}$TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Run main if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
