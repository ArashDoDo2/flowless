#!/bin/bash
# Watchdog - Monitor and auto-restart failed processes with exponential backoff

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/process-manager.sh" || { echo "Failed to load process-manager.sh"; exit 1; }
source "${SCRIPT_DIR}/config-loader.sh" || { echo "Failed to load config-loader.sh"; exit 1; }

# Default configuration
WATCHDOG_INTERVAL="${WATCHDOG_INTERVAL:-30}"
MAX_RESTARTS="${MAX_RESTARTS:-5}"
RESTART_WINDOW="${RESTART_WINDOW:-300}"
WATCHDOG_ENABLED="${WATCHDOG_ENABLED:-true}"
ALERT_THRESHOLD="${ALERT_THRESHOLD:-3}"
ALERT_EMAIL="${ALERT_EMAIL:-}"

# Load watchdog configuration if it exists
if [ -f "/etc/flowless/watchdog.conf" ]; then
    load_config "/etc/flowless/watchdog.conf"
    WATCHDOG_INTERVAL=$(get_config "CHECK_INTERVAL" "$WATCHDOG_INTERVAL")
    MAX_RESTARTS=$(get_config "MAX_RESTARTS" "$MAX_RESTARTS")
    RESTART_WINDOW=$(get_config "RESTART_WINDOW" "$RESTART_WINDOW")
    WATCHDOG_ENABLED=$(get_config "WATCHDOG_ENABLED" "$WATCHDOG_ENABLED")
    ALERT_THRESHOLD=$(get_config "ALERT_THRESHOLD" "$ALERT_THRESHOLD")
    ALERT_EMAIL=$(get_config "ALERT_EMAIL" "$ALERT_EMAIL")
fi

# Restart attempt tracking
declare -A RESTART_COUNTS
declare -A LAST_RESTART_TIME

# Get list of installed backends
get_installed_backends() {
    local backends=()
    
    # Check for paqet
    if systemctl list-unit-files 2>/dev/null | grep -q "^paqet.service"; then
        backends+=("paqet")
    fi
    
    # Check for gfw-knocker
    if systemctl list-unit-files 2>/dev/null | grep -q "^gfw-knocker.service"; then
        backends+=("gfw-knocker")
    fi
    
    echo "${backends[@]}"
}

# Get backend configuration
get_backend_config() {
    local backend="$1"
    
    case "$backend" in
        paqet)
            echo "command=/opt/flowless/bin/paqet"
            echo "port=1080"
            echo "config=/etc/flowless/paqet.conf"
            ;;
        gfw-knocker)
            echo "command=/opt/flowless/bin/xray"
            echo "port=14000"
            echo "config=/etc/flowless/gfw-knocker.conf"
            ;;
        *)
            return 1
            ;;
    esac
}

# Send alert
send_alert() {
    local message="$1"
    
    log_error "ALERT: $message"
    
    # Send email if configured
    if [ -n "$ALERT_EMAIL" ] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "Flowless Alert" "$ALERT_EMAIL"
    fi
    
    # Log to syslog if available
    if command -v logger >/dev/null 2>&1; then
        logger -t flowless-watchdog "ALERT: $message"
    fi
}

# Restart a backend service
restart_backend() {
    local name="$1"
    
    log_info "Attempting to restart $name via systemd..."
    
    if systemctl restart "$name" 2>/dev/null; then
        # Wait for process to be ready
        sleep 3
        
        if is_process_running "$name"; then
            return 0
        fi
    fi
    
    return 1
}

# Watch a process and restart if needed
watch_process() {
    local name="$1"
    local current_time=$(date +%s)
    
    # Reset counter if outside restart window
    local last_restart="${LAST_RESTART_TIME[$name]:-0}"
    if [ $((current_time - last_restart)) -gt "$RESTART_WINDOW" ]; then
        RESTART_COUNTS[$name]=0
    fi
    
    # Check if process is running
    if ! is_process_running "$name"; then
        local restart_count="${RESTART_COUNTS[$name]:-0}"
        
        if [ "$restart_count" -lt "$MAX_RESTARTS" ]; then
            # Calculate backoff delay (exponential: 5, 10, 20, 40, 80 seconds)
            # Cap at 300 seconds to prevent overflow
            local delay=$((5 * (2 ** restart_count)))
            if [ "$delay" -gt 300 ]; then
                delay=300
            fi
            
            log_warn "$name crashed! Restarting in ${delay}s (attempt $((restart_count + 1))/$MAX_RESTARTS)"
            
            # Send alert if threshold reached
            if [ "$restart_count" -ge "$ALERT_THRESHOLD" ]; then
                send_alert "$name has crashed $restart_count times, attempting restart (attempt $((restart_count + 1))/$MAX_RESTARTS)"
            fi
            
            sleep "$delay"
            
            # Attempt restart
            if restart_backend "$name"; then
                RESTART_COUNTS[$name]=$((restart_count + 1))
                LAST_RESTART_TIME[$name]=$current_time
                log_success "$name restarted successfully"
            else
                log_error "$name restart failed"
                RESTART_COUNTS[$name]=$((restart_count + 1))
                LAST_RESTART_TIME[$name]=$current_time
            fi
        else
            log_error "$name has crashed $MAX_RESTARTS times, giving up"
            send_alert "$name has exceeded max restart attempts ($MAX_RESTARTS)"
        fi
    fi
}

# Main watchdog loop
run_watchdog() {
    log_info "Flowless watchdog started (interval: ${WATCHDOG_INTERVAL}s, max restarts: $MAX_RESTARTS)"
    
    if [ "$WATCHDOG_ENABLED" != "true" ]; then
        log_warn "Watchdog is disabled in configuration"
        exit 0
    fi
    
    while true; do
        # Get list of installed backends
        local backends
        backends=$(get_installed_backends)
        
        if [ -z "$backends" ]; then
            log_warn "No backends found to monitor"
        else
            # Check each installed backend
            for backend in $backends; do
                watch_process "$backend"
            done
        fi
        
        sleep "$WATCHDOG_INTERVAL"
    done
}
