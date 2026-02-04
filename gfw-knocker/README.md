# GFW-Knocker

Advanced packet relay with protocol obfuscation using malformed TCP and QUIC via Xray backend.

## Overview

GFW-Knocker is the advanced relay method in flowless, designed for scenarios requiring sophisticated protocol handling and evasion capabilities. It leverages Xray's powerful features including malformed TCP packets and QUIC protocol for enhanced reliability and obfuscation.

## Features

- **Multi-Protocol**: Malformed TCP + QUIC support
- **Xray Backend**: Industry-standard transport framework
- **Protocol Obfuscation**: Advanced evasion techniques
- **Stateless Design**: No persistent session state
- **SOCKS5 Interface**: Standard proxy protocol
- **Flexible Configuration**: Extensive Xray configuration options

## Network Configuration

- **SOCKS5 Endpoint**: 127.0.0.1:14000
- **Transport Protocols**: Malformed TCP, QUIC
- **Backend**: Xray-core
- **Binding**: Localhost only (secure by default)

## Binary Requirements

GFW-Knocker expects the Xray binary to be available:

- **Binary Name**: `xray`
- **Locations checked** (in order):
  1. `/opt/flowless/bin/xray`
  2. `xray` in system PATH

- **Permissions**: Must be executable
- **Version**: Xray-core 1.7.0 or later recommended
- **Architecture**: Match system architecture (amd64, arm64, etc.)

## Configuration

### Main Configuration

Configuration file: `/etc/flowless/gfw-knocker.conf`

```bash
# Local SOCKS5 listening address
SOCKS_ADDR=127.0.0.1:14000

# Xray configuration file path
XRAY_CONFIG=/etc/flowless/xray-config.json

# Log level: debug, info, warning, error, none
LOG_LEVEL=warning

# Optional: Asset directory for geoip/geosite
ASSET_DIR=/opt/flowless/assets
```

### Xray Configuration

The Xray configuration file (`/etc/flowless/xray-config.json`) controls protocol behavior. See the template in `config/xray-config.json`.

Key sections:
- **Inbounds**: SOCKS5 proxy listener configuration
- **Outbounds**: Remote relay and protocol settings
- **Routing**: Traffic routing rules
- **Transport**: TCP/QUIC protocol settings

Example structure:
```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": 14000,
    "listen": "127.0.0.1",
    "protocol": "socks",
    "settings": {
      "auth": "noauth",
      "udp": true
    }
  }],
  "outbounds": [{
    "protocol": "vmess",
    "settings": {
      "vnext": [{
        "address": "remote.example.com",
        "port": 443,
        "users": [{
          "id": "uuid-here",
          "alterId": 0,
          "security": "auto"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "serverName": "remote.example.com"
      }
    }
  }]
}
```

## Service Management

### Systemd Service

The GFW-Knocker service is managed via systemd:

```bash
# Start service
sudo systemctl start gfw-knocker

# Stop service
sudo systemctl stop gfw-knocker

# Restart service
sudo systemctl restart gfw-knocker

# Enable auto-start
sudo systemctl enable gfw-knocker

# Check status
sudo systemctl status gfw-knocker

# View logs
sudo journalctl -u gfw-knocker -f
```

### Service Details

- **Service Name**: `gfw-knocker.service`
- **Run User**: `flowless-gfw` (created during installation)
- **Run Group**: `flowless-gfw`
- **Restart Policy**: Always (automatic restart on failure)

## Usage

### Client Configuration

Configure applications to use the SOCKS5 proxy:

```bash
# Environment variable
export ALL_PROXY=socks5://127.0.0.1:14000

# Curl example
curl --socks5 127.0.0.1:14000 https://example.com

# Browser: Configure SOCKS5 proxy to 127.0.0.1:14000
```

### Testing Connection

```bash
# Test SOCKS5 connectivity
curl -v --socks5 127.0.0.1:14000 https://www.google.com

# Check if port is listening
sudo netstat -tlnp | grep 14000
# or
sudo ss -tlnp | grep 14000
```

## Troubleshooting

### Service won't start

1. **Check Xray binary exists**:
   ```bash
   ls -l /opt/flowless/bin/xray
   ```

2. **Verify binary is executable**:
   ```bash
   sudo chmod +x /opt/flowless/bin/xray
   ```

3. **Validate Xray configuration**:
   ```bash
   /opt/flowless/bin/xray -test -config /etc/flowless/xray-config.json
   ```

4. **Check main configuration**:
   ```bash
   cat /etc/flowless/gfw-knocker.conf
   ```

5. **Review logs**:
   ```bash
   sudo journalctl -u gfw-knocker --no-pager -n 50
   ```

### Configuration validation errors

```bash
# Test Xray configuration syntax
sudo -u flowless-gfw /opt/flowless/bin/xray -test -config /etc/flowless/xray-config.json

# Common issues:
# - Invalid JSON syntax
# - Missing required fields
# - Invalid UUID format
# - Incorrect protocol parameters
```

### Port already in use

If port 14000 is occupied:

1. **Find the process**:
   ```bash
   sudo lsof -i :14000
   ```

2. **Change port in Xray config**:
   ```bash
   sudo nano /etc/flowless/xray-config.json
   # Modify "port" in inbounds section
   ```

3. **Restart service**:
   ```bash
   sudo systemctl restart gfw-knocker
   ```

### Connection issues

1. **Verify remote endpoint**:
   ```bash
   # Check DNS resolution
   nslookup remote.example.com
   
   # Check connectivity
   telnet remote.example.com 443
   ```

2. **Check TLS/SSL issues**:
   ```bash
   openssl s_client -connect remote.example.com:443
   ```

3. **Review Xray logs**:
   ```bash
   # Enable debug logging in xray-config.json
   # Set "loglevel": "debug"
   sudo systemctl restart gfw-knocker
   sudo journalctl -u gfw-knocker -f
   ```

### Protocol-specific issues

**Malformed TCP**:
- Ensure remote endpoint supports malformed TCP handling
- Check firewall/IDS rules that might block unusual packets
- Verify MTU settings for fragmentation

**QUIC Protocol**:
- Ensure UDP port is accessible
- Check firewall allows UDP traffic
- Verify QUIC version compatibility

## Protocol Details

### Malformed TCP

Malformed TCP packets are used for:
- Deep Packet Inspection (DPI) evasion
- Bypassing certain network filters
- Protocol fingerprint obfuscation

The technique involves sending TCP packets with:
- Unusual flag combinations
- Non-standard segment sizes
- Custom TCP options
- Strategic fragmentation

### QUIC Protocol

QUIC (Quick UDP Internet Connections) provides:
- Improved connection establishment (0-RTT)
- Built-in encryption (TLS 1.3)
- Better mobility support
- Reduced head-of-line blocking
- NAT-friendly design

## Performance Tuning

### Xray Optimization

In `xray-config.json`:

```json
{
  "policy": {
    "levels": {
      "0": {
        "connIdle": 300,
        "downlinkOnly": 0,
        "handshake": 4,
        "uplinkOnly": 0
      }
    },
    "system": {
      "statsInboundUplink": false,
      "statsInboundDownlink": false,
      "statsOutboundUplink": false,
      "statsOutboundDownlink": false
    }
  }
}
```

### System Optimization

```bash
# Increase file descriptors
echo "* soft nofile 51200" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 51200" | sudo tee -a /etc/security/limits.conf

# TCP buffer tuning
sudo sysctl -w net.core.rmem_max=16777216
sudo sysctl -w net.core.wmem_max=16777216
sudo sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216'
sudo sysctl -w net.ipv4.tcp_wmem='4096 87380 16777216'

# UDP buffer tuning (for QUIC)
sudo sysctl -w net.core.netdev_max_backlog=5000
```

## Security Considerations

- Service binds to localhost only by default
- Xray configuration should have restricted permissions (600)
- Use strong encryption (AES-256-GCM recommended)
- Regularly update Xray binary from official sources
- Enable TLS certificate verification in production
- Consider rotating UUID/credentials periodically
- Monitor logs for suspicious activity

## Advanced Configuration

### Multiple Outbounds

Configure multiple relay endpoints for failover:

```json
{
  "outbounds": [
    {
      "tag": "primary",
      "protocol": "vmess",
      "settings": { /* primary endpoint */ }
    },
    {
      "tag": "backup",
      "protocol": "vless",
      "settings": { /* backup endpoint */ }
    },
    {
      "tag": "direct",
      "protocol": "freedom"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "outboundTag": "primary",
        "network": "tcp,udp"
      }
    ]
  }
}
```

### Protocol Chains

Chain multiple protocols for enhanced obfuscation:

```json
{
  "streamSettings": {
    "network": "ws",
    "security": "tls",
    "wsSettings": {
      "path": "/path",
      "headers": {
        "Host": "example.com"
      }
    }
  }
}
```

### Traffic Routing

Route different traffic types to different outbounds:

```json
{
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "domain": ["geosite:cn"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:geolocation-!cn"],
        "outboundTag": "primary"
      }
    ]
  }
}
```

## Implementation Notes

This module expects the `xray` binary to:
- Support standard Xray-core configuration format
- Implement SOCKS5 server protocol
- Handle malformed TCP and QUIC protocols
- Support graceful shutdown on SIGTERM/SIGINT
- Log to stdout/stderr for systemd capture
- Validate configuration with `-test` flag

## References

- [Xray-core Documentation](https://xtls.github.io/)
- [QUIC Protocol Specification](https://www.rfc-editor.org/rfc/rfc9000.html)
- [SOCKS5 Protocol (RFC 1928)](https://www.rfc-editor.org/rfc/rfc1928.html)
