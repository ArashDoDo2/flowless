# Configuration Guide

## Overview

Flowless uses simple text-based configuration files for each relay method. All configuration files are located in `/etc/flowless/` after installation.

## Configuration Files

- `/etc/flowless/paqet.conf` - Paqet method configuration
- `/etc/flowless/gfk.conf` - GFW-Knocker method configuration

## Paqet Configuration

### Basic Setup

Minimum required configuration:

```conf
# Local proxy
local_addr=127.0.0.1
local_port=1080

# Server (REQUIRED - update these)
server_addr=your-server.example.com
server_port=4000

# Transport
kcp_mode=fast2
```

### Server Settings

**server_addr**: Your Paqet server address
- Can be IP address: `1.2.3.4`
- Can be hostname: `paqet.example.com`

**server_port**: Server listening port
- Default: `4000`
- Common alternatives: `8000`, `9000`, `443` (to blend with HTTPS)

### KCP Mode Selection

Four preset modes available:

| Mode    | Latency | Reliability | Bandwidth Usage | Use Case |
|---------|---------|-------------|-----------------|----------|
| normal  | Medium  | High        | Low             | Unstable networks |
| fast    | Low     | Medium      | Medium          | Balanced (recommended) |
| fast2   | Lower   | Medium-Low  | Higher          | Stable networks (default) |
| fast3   | Lowest  | Low         | Highest         | Very stable networks only |

### Network Tuning

**MTU (Maximum Transmission Unit)**
```conf
kcp_mtu=1350
```
- Default: `1350` (safe for most networks)
- Increase if you have high MTU network: `1400`, `1450`
- Decrease if experiencing fragmentation: `1280`, `1200`

**Window Sizes**
```conf
kcp_sndwnd=512
kcp_rcvwnd=512
```
- Higher values = better throughput, more memory
- Lower values = lower latency, less memory
- Typical range: `128` to `1024`

**Forward Error Correction (FEC)**
```conf
kcp_datashard=10
kcp_parityshard=3
```
- `datashard`: Data packets per FEC group
- `parityshard`: Redundancy packets per group
- Ratio `parityshard/datashard` determines overhead:
  - `3/10` = 30% overhead (default, good balance)
  - `5/10` = 50% overhead (lossy networks)
  - `1/10` = 10% overhead (clean networks)

### Example Configurations

**For Low-Latency Gaming:**
```conf
local_addr=127.0.0.1
local_port=1080
server_addr=game-proxy.example.com
server_port=4000
kcp_mode=fast
kcp_mtu=1400
kcp_sndwnd=256
kcp_rcvwnd=256
kcp_datashard=5
kcp_parityshard=1
```

**For High-Bandwidth Streaming:**
```conf
local_addr=127.0.0.1
local_port=1080
server_addr=stream-proxy.example.com
server_port=4000
kcp_mode=fast2
kcp_mtu=1450
kcp_sndwnd=1024
kcp_rcvwnd=1024
kcp_datashard=10
kcp_parityshard=3
```

**For Unreliable Networks:**
```conf
local_addr=127.0.0.1
local_port=1080
server_addr=robust-proxy.example.com
server_port=4000
kcp_mode=normal
kcp_mtu=1200
kcp_sndwnd=512
kcp_rcvwnd=512
kcp_datashard=10
kcp_parityshard=5
```

## GFW-Knocker Configuration

### Basic Setup

Minimum required configuration:

```conf
# Local proxy
local_addr=127.0.0.1
local_port=14000

# Server (REQUIRED - update these)
server_addr=your-server.example.com
server_port=443

# Backend (REQUIRED - update these)
backend_addr=backend.example.com
backend_port=8443

# Transport
tcp_malform_mode=syn_ack_confusion
quic_encryption=chacha20-poly1305
```

### Server Settings

**server_addr**: Your GFW-Knocker server address
- Typically same as backend, but doesn't have to be

**server_port**: Server listening port
- Recommended: `443` (appears as HTTPS)
- Alternatives: `80` (HTTP), `53` (DNS), `123` (NTP)

### Backend Settings

GFW-Knocker forwards traffic to an Xray backend:

**backend_addr**: Xray server address
- Must be configured on server side
- Can be same host as GFK server

**backend_port**: Xray listening port
- Typically: `8443`, `10000`, `10086`

### TCP Manipulation Modes

Four modes available:

**syn_ack_confusion** (Default, Recommended)
```conf
tcp_malform_mode=syn_ack_confusion
```
Creates invalid TCP state transitions. Most effective against stateful firewalls.

**fragmentation**
```conf
tcp_malform_mode=fragmentation
```
Unusual packet fragmentation patterns. Good against deep packet inspection.

**checksum_invalid**
```conf
tcp_malform_mode=checksum_invalid
```
Intentionally incorrect checksums. Some middle-boxes will forward anyway.

**option_overflow**
```conf
tcp_malform_mode=option_overflow
```
TCP option padding overflow. Exploits parser weaknesses.

### Encryption Selection

**chacha20-poly1305** (Default, Recommended)
```conf
quic_encryption=chacha20-poly1305
```
- Fast on most CPUs
- Constant-time operation (side-channel resistant)
- Mobile-friendly

**aes-128-gcm**
```conf
quic_encryption=aes-128-gcm
```
- Hardware-accelerated on modern CPUs
- Slightly faster on Intel/AMD with AES-NI
- Good balance of security and performance

**aes-256-gcm**
```conf
quic_encryption=aes-256-gcm
```
- Maximum security
- Slightly slower than AES-128
- Use if security is paramount

### Performance Tuning

**Connection Limits**
```conf
max_connections=1024
```
- Adjust based on expected concurrent users
- Higher = more memory usage

**Buffer Sizes**
```conf
buffer_size=4096
```
- Typical values: `2048`, `4096`, `8192`
- Higher = better throughput, more memory

**Rate Limiting** (Optional)
```conf
rate_limit=1000
```
- Packets per second cap
- Useful to avoid detection via rate analysis
- Omit for maximum performance

### Example Configurations

**For Maximum Stealth:**
```conf
local_addr=127.0.0.1
local_port=14000
server_addr=gfk-server.example.com
server_port=443
backend_addr=backend.example.com
backend_port=8443
tcp_malform_mode=syn_ack_confusion
quic_encryption=chacha20-poly1305
connection_timeout=60
max_connections=256
buffer_size=2048
rate_limit=500
```

**For Maximum Performance:**
```conf
local_addr=127.0.0.1
local_port=14000
server_addr=gfk-server.example.com
server_port=443
backend_addr=backend.example.com
backend_port=8443
tcp_malform_mode=fragmentation
quic_encryption=aes-128-gcm
connection_timeout=30
max_connections=2048
buffer_size=8192
# No rate_limit for max speed
```

## Applying Configuration Changes

After modifying configuration files:

1. Validate syntax (manually review)
2. Restart the service:
   ```bash
   sudo systemctl restart flowless-paqet
   # OR
   sudo systemctl restart flowless-gfk
   ```
3. Check service status:
   ```bash
   sudo systemctl status flowless-paqet
   ```
4. Monitor logs for errors:
   ```bash
   sudo journalctl -u flowless-paqet -f
   ```

## Configuration Backup

Best practice: Keep configuration backups

```bash
# Backup
sudo cp /etc/flowless/paqet.conf /etc/flowless/paqet.conf.backup

# Restore if needed
sudo cp /etc/flowless/paqet.conf.backup /etc/flowless/paqet.conf
sudo systemctl restart flowless-paqet
```

## Troubleshooting Configuration Issues

**Service fails to start after config change:**
1. Check logs: `journalctl -u flowless-paqet -n 50`
2. Look for syntax errors
3. Verify required fields present
4. Restore backup and try again

**Connection fails despite correct config:**
1. Verify server is reachable: `ping server_addr`
2. Check firewall allows server_port
3. Confirm server is running and configured
4. Test with curl: `curl --socks5 127.0.0.1:port https://example.com`
