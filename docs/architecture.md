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
