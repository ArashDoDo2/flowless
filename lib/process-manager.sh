#!/bin/bash
# Process Manager - Lifecycle management for flowless backends
# Handles process startup, shutdown, PID management, and health checks

set -euo pipefail

# Default directories
PID_DIR="/var/run"
LOG_DIR="/var/log/flowless"

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/validators.sh" || { echo "Failed to load validators.sh"; exit 1; }

# Logging functions
log_info() {
    echo "[INFO] $*" >&2
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

log_success() {
    echo "[SUCCESS] $*" >&2
}

# Get PID file path for a backend
get_pid_file() {
    local name="$1"
    echo "${PID_DIR}/flowless-${name}.pid"
}

# Get log file path for a backend
get_log_file() {
    local name="$1"
    echo "${LOG_DIR}/${name}.log"
}

# Check if process is running by PID
is_pid_running() {
    local pid="$1"
    
    # Validate PID is numeric
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Check if process exists
    kill -0 "$pid" 2>/dev/null
}

# Check if a named process is running
is_process_running() {
    local name="$1"
    local pid_file
    pid_file=$(get_pid_file "$name")
    
    if [ ! -f "$pid_file" ]; then
        return 1
    fi
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    
    if ! is_pid_running "$pid"; then
        # Stale PID file
        rm -f "$pid_file"
        return 1
    fi
    
    return 0
}

# Get PID of a named process
get_process_pid() {
    local name="$1"
    local pid_file
    pid_file=$(get_pid_file "$name")
    
    if [ ! -f "$pid_file" ]; then
        return 1
    fi
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    
    if ! is_pid_running "$pid"; then
        rm -f "$pid_file"
        return 1
    fi
    
    echo "$pid"
}

# Check if a port is listening
check_port_listening() {
    local port="$1"
    
    if command -v ss >/dev/null 2>&1; then
        ss -tln "sport = :${port}" 2>/dev/null | grep -q "LISTEN"
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep -q ":${port}.*LISTEN"
    else
        # Fallback: try to connect
        timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/${port}" 2>/dev/null
    fi
}

# Check if process is healthy (running + port listening if applicable)
is_process_healthy() {
    local name="$1"
    local port="${2:-}"
    
    # Check if process is running
    if ! is_process_running "$name"; then
        return 1
    fi
    
    # If port is specified, check if it's listening
    if [ -n "$port" ]; then
        if ! check_port_listening "$port"; then
            return 1
        fi
    fi
    
    return 0
}

# Start a process with monitoring
start_process() {
    local name="$1"
    local command="$2"
    local args="${3:-}"
    local port="${4:-}"
    
    local pid_file
    pid_file=$(get_pid_file "$name")
    local log_file
    log_file=$(get_log_file "$name")
    
    # Check if already running
    if is_process_running "$name"; then
        log_warn "$name is already running"
        return 0
    fi
    
    log_info "Starting $name..."
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR"
    
    # Start process in background
    (
        umask 077
        nohup "$command" $args > "$log_file" 2>&1 &
        local pid=$!
        
        # Save PID immediately
        echo "$pid" > "$pid_file"
        
        # Wait briefly and check if still running
        sleep 2
        if is_pid_running "$pid"; then
            log_success "$name started (PID: $pid)"
            
            # If port is specified, wait for it to be ready
            if [ -n "$port" ]; then
                local waited=0
                while [ $waited -lt 10 ]; do
                    if check_port_listening "$port"; then
                        log_success "$name is listening on port $port"
                        return 0
                    fi
                    sleep 1
                    waited=$((waited + 1))
                done
                log_warn "$name started but port $port is not listening"
            fi
            return 0
        else
            log_error "$name died immediately after start"
            rm -f "$pid_file"
            return 1
        fi
    )
}

# Stop process with graceful shutdown
stop_process() {
    local name="$1"
    local timeout="${2:-30}"
    local pid_file
    pid_file=$(get_pid_file "$name")
    
    if ! is_process_running "$name"; then
        log_warn "$name is not running"
        rm -f "$pid_file"
        return 0
    fi
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    
    if [ -z "$pid" ] || ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        log_error "Invalid PID file for $name"
        return 1
    fi
    
    log_info "Stopping $name (PID: $pid)..."
    
    # Try graceful shutdown first (SIGTERM)
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for process to exit
    local waited=0
    while is_pid_running "$pid" && [ $waited -lt $timeout ]; do
        sleep 1
        waited=$((waited + 1))
    done
    
    # Force kill if still running
    if is_pid_running "$pid"; then
        log_warn "$name didn't stop gracefully, force killing..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    # Verify stopped
    if ! is_pid_running "$pid"; then
        log_success "$name stopped"
        rm -f "$pid_file"
        return 0
    else
        log_error "Failed to stop $name"
        return 1
    fi
}

# Restart a process
restart_process() {
    local name="$1"
    local command="$2"
    local args="${3:-}"
    local port="${4:-}"
    
    log_info "Restarting $name..."
    
    # Stop if running
    if is_process_running "$name"; then
        stop_process "$name" || return 1
    fi
    
    # Wait a moment
    sleep 1
    
    # Start
    start_process "$name" "$command" "$args" "$port"
}

# Get process information
get_process_info() {
    local name="$1"
    local pid_file
    pid_file=$(get_pid_file "$name")
    
    if [ ! -f "$pid_file" ]; then
        echo "status=stopped"
        return 1
    fi
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    
    if ! is_pid_running "$pid"; then
        echo "status=stopped"
        rm -f "$pid_file"
        return 1
    fi
    
    echo "status=running"
    echo "pid=$pid"
    
    # Get start time from PID file
    if [ -f "$pid_file" ]; then
        local start_time
        start_time=$(stat -c %Y "$pid_file" 2>/dev/null || echo 0)
        echo "start_time=$start_time"
    fi
}
