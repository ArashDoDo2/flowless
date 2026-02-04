# Paqet

Simple and efficient packet relay using KCP over raw sockets.

## Overview

Paqet is the straightforward relay method in flowless, designed for general-purpose packet relay with minimal overhead. It uses KCP (a fast and reliable ARQ protocol) over raw sockets for efficient data transmission.

## Features

- **KCP Protocol**: Fast and reliable transport
- **Raw Sockets**: Direct packet handling for efficiency
- **Stateless**: No session state maintained
- **SOCKS5 Interface**: Standard proxy protocol
- **Low Overhead**: Minimal processing and latency

## Network Configuration

- **SOCKS5 Endpoint**: 127.0.0.1:1080
- **Transport Protocol**: KCP over raw sockets
- **Binding**: Localhost only (secure by default)

## Binary Requirements

Paqet expects an external binary named `paqet` to be available:

- **Locations checked** (in order):
  1. `/opt/flowless/bin/paqet`
  2. `paqet` in system PATH

- **Permissions**: Must be executable
- **Architecture**: Match system architecture (amd64, arm64, etc.)

## Configuration

Configuration file: `/etc/flowless/paqet.conf`

### Parameters

```bash
# Local SOCKS5 listening address
SOCKS_ADDR=127.0.0.1:1080

# Remote relay endpoint address
REMOTE_ADDR=relay.example.com:4000

# KCP mode: fast, fast2, fast3 (fastest), normal
KCP_MODE=fast3

# Optional: UDP buffer size (bytes)
UDP_BUFFER=4096

# Optional: Connection timeout (seconds)
TIMEOUT=30
```

### Example Configuration

```bash
# Basic configuration for typical usage
SOCKS_ADDR=127.0.0.1:1080
REMOTE_ADDR=203.0.113.10:4000
KCP_MODE=fast3
```

## Service Management

### Systemd Service

The Paqet service is managed via systemd:

```bash
# Start service
sudo systemctl start paqet

# Stop service
sudo systemctl stop paqet

# Restart service
sudo systemctl restart paqet

# Enable auto-start
sudo systemctl enable paqet

# Check status
sudo systemctl status paqet

# View logs
sudo journalctl -u paqet -f
```

### Service Details

- **Service Name**: `paqet.service`
- **Run User**: `flowless-paqet` (created during installation)
- **Run Group**: `flowless-paqet`
- **Restart Policy**: Always (automatic restart on failure)

## Usage

### Client Configuration

Configure applications to use the SOCKS5 proxy:

```bash
# Environment variable
export ALL_PROXY=socks5://127.0.0.1:1080

# Curl example
curl --socks5 127.0.0.1:1080 https://example.com

# Browser: Configure SOCKS5 proxy to 127.0.0.1:1080
```

### Testing Connection

```bash
# Test SOCKS5 connectivity
curl -v --socks5 127.0.0.1:1080 https://www.google.com

# Check if port is listening
sudo netstat -tlnp | grep 1080
# or
sudo ss -tlnp | grep 1080
```

## Troubleshooting

### Service won't start

1. **Check binary exists**:
   ```bash
   ls -l /opt/flowless/bin/paqet
   ```

2. **Verify binary is executable**:
   ```bash
   sudo chmod +x /opt/flowless/bin/paqet
   ```

3. **Check configuration**:
   ```bash
   cat /etc/flowless/paqet.conf
   ```

4. **Review logs**:
   ```bash
   sudo journalctl -u paqet --no-pager -n 50
   ```

### Port already in use

If port 1080 is occupied:

1. **Find the process**:
   ```bash
   sudo lsof -i :1080
   ```

2. **Change port in configuration**:
   ```bash
   sudo nano /etc/flowless/paqet.conf
   # Change SOCKS_ADDR=127.0.0.1:1080 to another port
   ```

3. **Restart service**:
   ```bash
   sudo systemctl restart paqet
   ```

### Connection issues

1. **Verify remote endpoint is reachable**:
   ```bash
   ping -c 3 relay.example.com
   ```

2. **Check firewall rules**:
   ```bash
   sudo iptables -L -n
   ```

3. **Test raw socket permissions**:
   ```bash
   # Service needs CAP_NET_RAW capability
   sudo getcap /opt/flowless/bin/paqet
   ```

### Permission denied errors

Raw sockets require special capabilities:

```bash
# Grant CAP_NET_RAW capability
sudo setcap cap_net_raw+ep /opt/flowless/bin/paqet
```

## Performance Tuning

### KCP Modes

- **normal**: Balanced mode, suitable for most scenarios
- **fast**: Faster mode with reduced latency
- **fast2**: Very fast mode, higher bandwidth usage
- **fast3**: Fastest mode, maximum throughput

### Network Optimization

```bash
# Increase UDP buffer sizes (in paqet.conf)
UDP_BUFFER=8192

# System-wide UDP buffer tuning
sudo sysctl -w net.core.rmem_max=8388608
sudo sysctl -w net.core.wmem_max=8388608
```

## Security Notes

- Service binds to localhost (127.0.0.1) only by default
- Raw socket access requires elevated privileges
- Configuration file should have restricted permissions (600)
- Consider firewall rules for additional protection
- Regularly update the `paqet` binary from trusted sources

## Technical Details

### KCP Protocol

KCP (KCP is a Fast and Reliable ARQ Protocol) provides:
- Reduced latency compared to TCP
- Configurable reliability and flow control
- Suitable for real-time applications
- Better performance over unreliable networks

### Raw Sockets

Raw sockets provide:
- Direct packet access at IP layer
- Bypass kernel TCP/IP stack for efficiency
- Custom protocol implementation capability
- Requires elevated privileges (CAP_NET_RAW)

## Implementation Notes

This module expects the `paqet` binary to:
- Accept standard command-line arguments for configuration
- Implement SOCKS5 server on specified address
- Handle KCP transport over raw sockets
- Support graceful shutdown on SIGTERM
- Log to stdout/stderr for systemd capture
