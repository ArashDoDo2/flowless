# Architecture Overview

## Design Philosophy

Flowless is built on the principle of **stateless packet relay**. Unlike traditional proxy and VPN solutions that maintain connection state, flowless methods process each packet independently.

### Core Concepts

#### 1. Stateless Operation

Traditional stateful systems:
```
Client → [Stateful Proxy] → Server
         ↑
         └─ Tracks: sessions, flows, buffers
```

Flowless stateless systems:
```
Client → [Stateless Relay] → Server
         ↑
         └─ No memory of previous packets
```

**Benefits:**
- Minimal server resources
- Fast recovery from network disruption
- Simplified infrastructure
- No session hijacking risk

**Trade-offs:**
- Some optimization opportunities lost
- Per-packet overhead higher
- Careful tuning required

#### 2. Transport Independence

Flowless is a management layer, not a transport implementation. It provides:
- Installation automation
- Configuration management
- Service orchestration
- Monitoring integration

The actual transport protocols (KCP, QUIC, TCP manipulation) are implemented by external binaries.

#### 3. Method Modularity

Each relay method operates independently:
- Separate binaries
- Separate configurations
- Separate SOCKS5 ports
- Separate systemd services

This allows:
- Simultaneous operation
- A/B testing
- Failover scenarios
- Network-specific optimization

## System Architecture

### Component Layout

```
┌────────────────────────────────────────────────────────┐
│                     Flowless Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  Installer   │  │   Config     │  │   Service    │ │
│  │   Scripts    │  │  Templates   │  │  Management  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└────────────────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│                   Transport Layer                       │
│  ┌──────────────┐                  ┌────────────────┐ │
│  │    Paqet     │                  │  GFW-Knocker   │ │
│  │   (Binary)   │                  │    (Binary)    │ │
│  └──────────────┘                  └────────────────┘ │
└────────────────────────────────────────────────────────┘
                          │
                          ▼
                  Network Interface
```

### Data Flow

#### Paqet Data Flow

```
Application (curl, browser, etc.)
    │
    │ SOCKS5 protocol
    ▼
127.0.0.1:1080 (Paqet SOCKS5 proxy)
    │
    │ KCP protocol
    │ (reliable, flow-controlled)
    ▼
Raw Socket (UDP-like)
    │
    │ KCP packets
    ▼
Internet
    │
    ▼
Paqet Server
    │
    │ Decapsulated traffic
    ▼
Target Website
```

#### GFW-Knocker Data Flow

```
Application (curl, browser, etc.)
    │
    │ SOCKS5 protocol
    ▼
127.0.0.1:14000 (GFK SOCKS5 proxy)
    │
    │ QUIC tunnel
    │ (encrypted)
    ▼
TCP Packet Manipulation Layer
    │ Malformed TCP packets
    │ (intentionally invalid state)
    ▼
Internet
    │
    ▼
GFW-Knocker Server
    │ Reconstruct QUIC
    ▼
Xray Backend
    │
    │ Decapsulated traffic
    ▼
Target Website
```

## Security Model

### Threat Model

Flowless methods are designed for scenarios where:
- Network traffic is monitored
- Protocol signatures are detected
- Standard VPN/proxy protocols are blocked

**Not designed for:**
- Complete anonymity (use Tor)
- Endpoint security
- Traffic analysis resistance (timing attacks)

### Security Properties

#### Paqet
- Encrypted KCP payload
- No handshake signature
- Appears as random UDP traffic
- Forward secrecy: Not guaranteed (depends on KCP configuration)

#### GFW-Knocker
- Double-encrypted (QUIC + outer layer)
- Looks like broken TCP connections
- Designed to trigger whitelisting logic
- Forward secrecy: QUIC provides per-connection keys

## Performance Characteristics

### Paqet

**Latency:**
- Overhead: ~5-15ms
- Factors: FEC, retransmission, KCP tuning

**Throughput:**
- Typical: 50-200 Mbps
- Bottleneck: Usually KCP window size and FEC overhead

**Best for:**
- Bulk transfers
- Streaming
- General browsing

### GFW-Knocker

**Latency:**
- Overhead: ~15-40ms
- Factors: TCP manipulation overhead, QUIC + Xray processing

**Throughput:**
- Typical: 20-100 Mbps
- Bottleneck: Double encapsulation overhead

**Best for:**
- Text-based protocols
- Interactive sessions
- Scenarios where detection is primary concern

## Deployment Patterns

### Single Method Deployment

Simplest setup:
```bash
sudo ./install/install-paqet.sh
# OR
sudo ./install/install-gfk.sh
```

### Dual Method Deployment

Both methods running:
```bash
sudo ./install/install-all.sh
```

Applications choose via SOCKS5 port:
- Port 1080: Paqet (fast, general purpose)
- Port 14000: GFW-Knocker (restrictive networks)

### Load Balancing

Use HAProxy or similar to distribute connections:
```
HAProxy (SOCKS5 frontend)
  ├─→ 127.0.0.1:1080 (Paqet)
  └─→ 127.0.0.1:14000 (GFK)
```

### Failover

Use systemd dependencies:
```
flowless-gfk.service
Requires=flowless-paqet.service
After=flowless-paqet.service
```

## Monitoring

### Systemd Integration

View logs:
```bash
journalctl -u flowless-paqet -f
journalctl -u flowless-gfk -f
```

Check service status:
```bash
systemctl status flowless-paqet
systemctl status flowless-gfk
```

### Log Analysis

Typical log patterns:

**Paqet:**
```
[INFO] SOCKS5 connection from 127.0.0.1:xxxxx
[INFO] KCP session established
[INFO] Forwarding to example.com:443
```

**GFW-Knocker:**
```
[INFO] SOCKS5 connection from 127.0.0.1:xxxxx
[INFO] TCP manipulation mode: syn_ack_confusion
[INFO] QUIC tunnel established
[INFO] Backend forward: xray at xxx.xxx.xxx.xxx:8443
```

### Performance Metrics

Key indicators:
- Connection success rate
- Average latency
- Throughput per connection
- Packet loss rate (for Paqet KCP layer)

## Troubleshooting

### Common Issues

**Issue:** Service fails to start
- Check binary exists in /usr/local/bin
- Verify configuration syntax
- Check permissions

**Issue:** Cannot establish connection
- Verify server address in config
- Check firewall rules
- Test network connectivity

**Issue:** Poor performance
- Tune KCP parameters (Paqet)
- Adjust buffer sizes
- Check network MTU

**Issue:** Service keeps restarting
- Check logs: journalctl -u flowless-*
- Verify server is responding
- Check for configuration errors

## Process Lifecycle Management

### Overview

Flowless includes comprehensive process management for backend services:
- **Auto-restart** - Automatic recovery from crashes
- **Exponential backoff** - Intelligent restart delays to prevent loops
- **Graceful shutdown** - Clean termination with fallback to force-kill
- **Health monitoring** - Continuous process and port checks
- **Resource tracking** - CPU, memory, and connection metrics

### Process States

```
┌─────────┐
│ Stopped │
└────┬────┘
     │ systemctl start / flowless start
     ▼
┌─────────┐
│Starting │ ◄───────┐
└────┬────┘         │
     │              │ Auto-restart
     │ PID created  │ (on crash)
     ▼              │
┌─────────┐         │
│ Running │─────────┘
└────┬────┘
     │ systemctl stop / flowless stop
     ▼
┌──────────┐
│ Stopping │ (SIGTERM → wait → SIGKILL)
└────┬─────┘
     │
     ▼
┌─────────┐
│ Stopped │
└─────────┘
```

### State Transitions

**Stopped → Starting**
- Triggered by: `systemctl start`, `flowless start`, or auto-restart
- Actions: Create PID file, start process, wait for validation

**Starting → Running**
- Condition: Process alive after 2 seconds, PID valid, port listening (if applicable)
- Actions: Log success, begin health monitoring

**Starting → Stopped**
- Condition: Process dies immediately after start
- Actions: Remove PID file, log error, trigger restart (if watchdog enabled)

**Running → Stopping**
- Triggered by: `systemctl stop`, `flowless stop`, or shutdown
- Actions: Send SIGTERM, wait (default: 30s), send SIGKILL if needed

**Running → Stopped** (crash)
- Condition: Process exits unexpectedly
- Actions: Watchdog detects, triggers auto-restart with exponential backoff

### Auto-Restart Decision Tree

```
Process crashed?
    │
    ├─ No → Continue monitoring
    │
    └─ Yes
        │
        ├─ Restart count < MAX_RESTARTS?
        │   │
        │   ├─ Yes
        │   │   │
        │   │   ├─ Calculate backoff: 5 * (2 ^ restart_count) seconds
        │   │   ├─ Wait backoff period
        │   │   ├─ Attempt restart via systemctl
        │   │   ├─ Increment restart count
        │   │   └─ Log attempt
        │   │
        │   └─ No
        │       │
        │       ├─ Log: Max restarts exceeded
        │       ├─ Send alert
        │       └─ Give up
        │
        └─ Outside restart window (5 minutes)?
            │
            └─ Yes → Reset restart count to 0
```

### Watchdog Architecture

```
┌─────────────────────────────────────────┐
│       Flowless Watchdog Daemon          │
│  (systemd service: flowless-watchdog)   │
└──────────────┬──────────────────────────┘
               │
               │ Every 30 seconds (configurable)
               │
               ▼
      ┌────────────────┐
      │ Check backends │
      └────────┬───────┘
               │
     ┌─────────┴─────────┐
     │                   │
     ▼                   ▼
┌─────────┐         ┌─────────┐
│  Paqet  │         │   GFW   │
│ Service │         │ Knocker │
└────┬────┘         └────┬────┘
     │                   │
     │ is_process_running?
     │ is_process_healthy?
     │
     ├─ Healthy → Continue
     │
     └─ Crashed → Auto-restart
         │
         ├─ Calculate backoff delay
         ├─ Wait delay
         ├─ systemctl restart
         ├─ Verify started
         └─ Update restart counters
```

### Graceful Shutdown Pattern

Flowless implements a two-phase shutdown pattern:

1. **Phase 1: Graceful (SIGTERM)**
   - Send SIGTERM signal
   - Wait up to timeout (default: 30 seconds)
   - Allow process to clean up resources, close connections

2. **Phase 2: Force (SIGKILL)**
   - If process still running after timeout
   - Send SIGKILL signal (cannot be ignored)
   - Immediately terminates process

Example timeline:
```
T+0s:  Send SIGTERM
T+1s:  Check if stopped
T+2s:  Check if stopped
...
T+29s: Check if stopped
T+30s: Still running → Send SIGKILL
T+31s: Verify stopped
```

### Health Checks

The process manager performs multi-level health checks:

**Level 1: PID Check**
```bash
# Verify PID file exists and contains valid numeric PID
test -f /var/run/flowless-backend.pid
# Verify process is running
kill -0 $PID
```

**Level 2: Port Check**
```bash
# Verify SOCKS5 port is listening
ss -tln sport = :1080 | grep LISTEN
```

**Level 3: Connection Test** (optional)
```bash
# Attempt to connect to SOCKS5 port
timeout 1 bash -c "echo >/dev/tcp/127.0.0.1/1080"
```

A process is considered healthy when:
- PID is valid and process exists
- PID file is not stale
- Port is listening (if port check enabled)
- Process responds to signals

### Resource Monitoring

**Tracked Metrics:**
- **CPU**: Percentage from `ps -o %cpu`
- **Memory**: Resident Set Size (RSS) in KB/MB from `ps -o rss`
- **Uptime**: Calculated from PID file creation time
- **Connections**: Active connections from `ss` or `netstat`

**Update Frequency:**
- On-demand via `flowless stats`
- Real-time via `flowless watch` (2-second intervals)
- Watchdog checks every 30 seconds

**Data Sources:**
```bash
# CPU and memory
ps -p $PID -o %cpu=,%mem=,rss=

# Uptime
stat -c %Y /var/run/flowless-backend.pid

# Connections
ss -tn sport = :$PORT | grep ESTAB | wc -l
```

### Configuration

**Watchdog settings** (`/etc/flowless/watchdog.conf`):
```bash
CHECK_INTERVAL=30      # Health check frequency (seconds)
MAX_RESTARTS=5         # Max restart attempts in window
RESTART_WINDOW=300     # Time window for restart counter (seconds)
WATCHDOG_ENABLED=true  # Enable/disable auto-restart
ALERT_THRESHOLD=3      # Send alerts after N restarts
```

**Restart delays** (exponential backoff):
- Attempt 1: 5 seconds
- Attempt 2: 10 seconds
- Attempt 3: 20 seconds
- Attempt 4: 40 seconds
- Attempt 5: 80 seconds

### Security Considerations

**PID File Validation:**
- Always validate PID is numeric before use
- Check process actually exists before sending signals
- Remove stale PID files automatically
- Prevents PID reuse attacks

**Watchdog Capabilities:**
- Runs as root (required for systemctl restart)
- Limited capabilities: CAP_KILL, CAP_SYS_ADMIN
- Cannot access network or filesystem beyond monitoring
- Isolated with PrivateTmp=true

**Process Isolation:**
- Backends run as dedicated users (flowless-paqet, flowless-gfw)
- Watchdog cannot directly kill user processes
- Must use systemctl for controlled restarts
- Audit trail via journald

### Performance Impact

**Resource overhead:**
- Watchdog: ~1-2 MB memory, negligible CPU
- Health checks: ~0.1% CPU per check
- Monitoring: No persistent overhead (on-demand)

**Restart latency:**
- Detection: Up to CHECK_INTERVAL (30s default)
- Backoff delay: 5-80 seconds depending on attempt
- Restart time: 2-5 seconds for process start
- Total: 37-115 seconds for first restart

**Optimization tips:**
- Reduce CHECK_INTERVAL for faster detection (increases CPU usage)
- Increase RESTART_WINDOW for more lenient restart limits
- Use port health checks only when necessary
- Monitor systemd journal size (watchdog logs verbosely)
