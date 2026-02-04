# Flowless Operations Guide

This guide covers operational procedures for managing flowless backends, including process lifecycle management, monitoring, and troubleshooting.

## Table of Contents

1. [Process Management](#process-management)
2. [Monitoring](#monitoring)
3. [Auto-Restart and Watchdog](#auto-restart-and-watchdog)
4. [Troubleshooting](#troubleshooting)
5. [Resource Management](#resource-management)

## Process Management

### Starting Services

Use systemd to start services persistently:

```bash
# Start individual backend
sudo systemctl start paqet
sudo systemctl start gfw-knocker

# Enable auto-start on boot
sudo systemctl enable paqet
sudo systemctl enable gfw-knocker
```

Using the flowless CLI:

```bash
# Start a backend
sudo flowless start paqet
sudo flowless start gfw-knocker
```

### Stopping Services

```bash
# Stop via systemd
sudo systemctl stop paqet
sudo systemctl stop gfw-knocker

# Stop via CLI
sudo flowless stop paqet
sudo flowless stop gfw-knocker
```

**Graceful Shutdown:** The stop command sends SIGTERM and waits up to 30 seconds for graceful shutdown. If the process doesn't stop, SIGKILL is used as a fallback.

### Restarting Services

```bash
# Restart via systemd
sudo systemctl restart paqet

# Restart via CLI (recommended)
sudo flowless restart paqet
```

The restart command performs:
1. Graceful stop of existing process
2. Brief wait period
3. Fresh start with validation

### Checking Status

```bash
# Detailed status of all backends
flowless status

# Status of specific backend
flowless status paqet

# System service status
sudo systemctl status paqet
```

The flowless CLI provides richer information including:
- Process state (running/stopped)
- PID and uptime
- Resource usage (CPU, memory)
- Active connections
- Port status

## Monitoring

### Live Monitoring

Real-time monitoring dashboard:

```bash
# Monitor all backends
flowless watch

# Monitor specific backend
flowless watch paqet
```

**Features:**
- Updates every 2 seconds
- Shows CPU, memory, connections
- System load average
- Press Ctrl+C to exit

### Resource Statistics

```bash
# Resource usage summary
flowless stats

# Specific backend stats
flowless stats paqet
```

**Metrics tracked:**
- **CPU**: Percentage of CPU time used
- **Memory**: Resident Set Size (RSS) in MB
- **Connections**: Active SOCKS5 connections
- **Uptime**: Time since process start

### Logs

```bash
# View live logs
sudo journalctl -u paqet -f
sudo journalctl -u gfw-knocker -f

# View recent logs
sudo journalctl -u paqet -n 100

# Logs since specific time
sudo journalctl -u paqet --since "1 hour ago"
```

## Auto-Restart and Watchdog

### Watchdog Service

The flowless watchdog monitors backends and automatically restarts them on failure.

#### Enable Watchdog

```bash
# Install and enable
sudo cp systemd/flowless-watchdog.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable flowless-watchdog
sudo systemctl start flowless-watchdog
```

#### Check Watchdog Status

```bash
sudo systemctl status flowless-watchdog
sudo journalctl -u flowless-watchdog -f
```

### Configuration

Edit `/etc/flowless/watchdog.conf`:

```bash
# Check interval (seconds)
CHECK_INTERVAL=30

# Max restart attempts within window
MAX_RESTARTS=5

# Restart window (seconds)
RESTART_WINDOW=300

# Enable/disable
WATCHDOG_ENABLED=true

# Alert threshold
ALERT_THRESHOLD=3
```

### Restart Behavior

**Exponential Backoff:**
- 1st restart: 5 seconds delay
- 2nd restart: 10 seconds delay
- 3rd restart: 20 seconds delay
- 4th restart: 40 seconds delay
- 5th restart: 80 seconds delay

**Restart Counter Reset:**
The restart counter resets after 5 minutes (RESTART_WINDOW) of stable operation.

**Max Restarts:**
After 5 failed restart attempts, the watchdog gives up and sends an alert.

### Alerts

Configure email alerts in `/etc/flowless/watchdog.conf`:

```bash
ALERT_EMAIL=admin@example.com
ALERT_THRESHOLD=3
```

Alerts are triggered when:
- Restart attempts reach threshold (default: 3)
- Max restart limit exceeded
- Backend repeatedly crashes

## Troubleshooting

### Process States

**Running (● Green)**
- Process is active with valid PID
- Port is listening
- Responding to health checks

**Starting/Unhealthy (● Yellow)**
- Service enabled but process issues detected
- Port not listening
- PID file missing or stale

**Stopped (○ Red)**
- Service not running
- No PID file
- No port listening

### Common Issues

#### Backend won't start

1. **Check configuration:**
   ```bash
   cat /etc/flowless/paqet.conf
   ```

2. **Check binary exists:**
   ```bash
   ls -l /opt/flowless/bin/paqet
   ls -l /opt/flowless/bin/xray
   ```

3. **Check permissions:**
   ```bash
   sudo -u flowless-paqet /opt/flowless/bin/paqet --version
   ```

4. **View detailed logs:**
   ```bash
   sudo journalctl -u paqet -n 50 --no-pager
   ```

#### Backend crashes repeatedly

1. **Check watchdog logs:**
   ```bash
   sudo journalctl -u flowless-watchdog -n 100
   ```

2. **Look for patterns:**
   - Memory exhaustion
   - Port conflicts
   - Configuration errors

3. **Increase restart limits temporarily:**
   Edit `/etc/flowless/watchdog.conf`:
   ```bash
   MAX_RESTARTS=10
   RESTART_WINDOW=600
   ```

4. **Disable watchdog while debugging:**
   ```bash
   sudo systemctl stop flowless-watchdog
   ```

#### Port already in use

1. **Find conflicting process:**
   ```bash
   sudo ss -tlnp | grep :1080
   sudo lsof -i :1080
   ```

2. **Change port in configuration:**
   Edit `/etc/flowless/paqet.conf`:
   ```bash
   SOCKS_ADDR=127.0.0.1:1081
   ```

3. **Restart service:**
   ```bash
   sudo flowless restart paqet
   ```

#### Stale PID files

The process manager automatically cleans stale PID files. If issues persist:

```bash
# Manually clean PID files
sudo rm -f /var/run/flowless-*.pid

# Restart service
sudo flowless start paqet
```

#### High memory usage

1. **Check current usage:**
   ```bash
   flowless stats
   ```

2. **Investigate process:**
   ```bash
   ps aux | grep paqet
   pmap -x $(pgrep paqet)
   ```

3. **Restart to clear:**
   ```bash
   sudo flowless restart paqet
   ```

4. **Set memory limits in systemd:**
   Edit `/etc/systemd/system/paqet.service`:
   ```ini
   [Service]
   MemoryMax=512M
   MemoryHigh=384M
   ```

### Restart Loops

If a backend is stuck in a restart loop:

1. **Stop watchdog:**
   ```bash
   sudo systemctl stop flowless-watchdog
   ```

2. **Stop the backend:**
   ```bash
   sudo systemctl stop paqet
   ```

3. **Check logs for root cause:**
   ```bash
   sudo journalctl -u paqet --since "10 minutes ago"
   ```

4. **Fix configuration issues**

5. **Test manual start:**
   ```bash
   sudo systemctl start paqet
   sleep 5
   flowless status paqet
   ```

6. **Re-enable watchdog:**
   ```bash
   sudo systemctl start flowless-watchdog
   ```

## Resource Management

### Capacity Planning

Monitor trends over time:

```bash
# Check current usage
flowless stats

# Monitor for 5 minutes
while true; do
    date
    flowless stats
    sleep 60
done
```

### Resource Limits

Configure in systemd service files:

```ini
[Service]
# File descriptors
LimitNOFILE=51200

# Processes
LimitNPROC=512

# Memory (systemd 231+)
MemoryMax=512M
MemoryHigh=384M

# CPU (systemd 232+)
CPUQuota=50%
```

After editing:

```bash
sudo systemctl daemon-reload
sudo systemctl restart paqet
```

### Connection Limits

High connection counts may indicate:
- Heavy usage (normal)
- Connection leaks (investigate)
- Attack attempts (block)

Monitor connections:

```bash
# Active connections
ss -tn sport = :1080 | grep ESTAB

# Connection rate
watch -n 1 'ss -tn sport = :1080 | grep ESTAB | wc -l'
```

### Log Rotation

Ensure logs don't fill disk:

```bash
# Check journal size
sudo journalctl --disk-usage

# Clean old logs
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=500M
```

Create `/etc/systemd/journald.conf.d/flowless.conf`:

```ini
[Journal]
SystemMaxUse=1G
SystemMaxFileSize=100M
MaxRetentionSec=7day
```

## Best Practices

1. **Enable watchdog** for production systems
2. **Monitor resource usage** regularly
3. **Set appropriate restart limits** based on stability
4. **Configure alerts** for critical failures
5. **Keep logs rotated** to prevent disk issues
6. **Test changes** in non-production first
7. **Use flowless CLI** for operational commands
8. **Review logs** after any restart
9. **Document configuration changes**
10. **Regular backups** of configuration files

## Quick Reference

```bash
# Status and monitoring
flowless status                    # Check all backends
flowless stats                     # Resource usage
flowless watch                     # Live monitoring

# Process control
sudo flowless start paqet          # Start backend
sudo flowless stop paqet           # Stop backend
sudo flowless restart paqet        # Restart backend

# Watchdog
sudo systemctl status flowless-watchdog    # Check watchdog
sudo journalctl -u flowless-watchdog -f    # Watchdog logs

# Logs
sudo journalctl -u paqet -f        # Follow logs
sudo journalctl -u paqet -n 100    # Last 100 lines

# Systemd
sudo systemctl enable paqet        # Enable on boot
sudo systemctl disable paqet       # Disable on boot
sudo systemctl daemon-reload       # Reload after config changes
```
