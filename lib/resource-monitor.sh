#!/bin/bash
# Resource Monitor - Track CPU, memory, uptime, and connections for processes

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/process-manager.sh" || { echo "Failed to load process-manager.sh"; exit 1; }

# Format uptime from seconds to human-readable string
format_uptime() {
    local uptime="$1"
    
    if [ "$uptime" -ge 86400 ]; then
        echo "$((uptime / 86400))d $((uptime % 86400 / 3600))h"
    elif [ "$uptime" -ge 3600 ]; then
        echo "$((uptime / 3600))h $((uptime % 3600 / 60))m"
    elif [ "$uptime" -ge 60 ]; then
        echo "$((uptime / 60))m $((uptime % 60))s"
    else
        echo "${uptime}s"
    fi
}

# Get connection count for a port
get_connection_count() {
    local port="$1"
    
    if command -v ss >/dev/null 2>&1; then
        ss -tn "sport = :${port}" 2>/dev/null | grep -c ESTAB || echo 0
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tn 2>/dev/null | grep ":${port}.*ESTABLISHED" | wc -l
    else
        echo 0
    fi
}

# Get process statistics
get_process_stats() {
    local name="$1"
    local port="${2:-}"
    
    local pid_file
    pid_file=$(get_pid_file "$name")
    
    if [ ! -f "$pid_file" ]; then
        echo "status=not_running"
        return 1
    fi
    
    local pid
    pid=$(cat "$pid_file" 2>/dev/null)
    
    if ! [[ "$pid" =~ ^[0-9]+$ ]] || ! is_pid_running "$pid"; then
        echo "status=not_running"
        rm -f "$pid_file"
        return 1
    fi
    
    # Get CPU and memory from ps
    local cpu_mem
    cpu_mem=$(ps -p "$pid" -o %cpu=,%mem=,rss= 2>/dev/null | tr -s ' ')
    
    if [ -z "$cpu_mem" ]; then
        echo "status=not_running"
        return 1
    fi
    
    local cpu=$(echo "$cpu_mem" | awk '{print $1}')
    local mem_percent=$(echo "$cpu_mem" | awk '{print $2}')
    local mem_rss=$(echo "$cpu_mem" | awk '{print $3}')  # KB
    
    # Calculate uptime
    local start_time
    start_time=$(stat -c %Y "$pid_file" 2>/dev/null || echo 0)
    local current_time=$(date +%s)
    local uptime=$((current_time - start_time))
    
    # Format uptime
    local uptime_str
    uptime_str=$(format_uptime "$uptime")
    
    # Get connection count if port is specified
    local connections=0
    if [ -n "$port" ]; then
        connections=$(get_connection_count "$port")
    fi
    
    # Output structured data
    echo "status=running"
    echo "pid=$pid"
    echo "cpu=$cpu"
    echo "mem_percent=$mem_percent"
    echo "mem_kb=$mem_rss"
    echo "mem_mb=$((mem_rss / 1024))"
    echo "uptime=$uptime"
    echo "uptime_str=$uptime_str"
    echo "connections=$connections"
}

# Get system-wide stats
get_system_stats() {
    # Total memory in MB
    local total_mem_kb
    total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_mem_mb=$((total_mem_kb / 1024))
    
    # Available memory in MB
    local avail_mem_kb
    avail_mem_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local avail_mem_mb=$((avail_mem_kb / 1024))
    
    # CPU load
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[ \t]*//')
    
    echo "total_mem_mb=$total_mem_mb"
    echo "avail_mem_mb=$avail_mem_mb"
    echo "load_average=$load"
}
