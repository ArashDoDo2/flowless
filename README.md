# flowless

**Flow-less stateless packet relay toolkit**

A modular infrastructure tool for managing stateless transport methods. This repository provides installers, configuration templates, service management, and documentation for packet relay mechanisms that operate without maintaining connection state.

---

## Overview

`flowless` is a transport-agnostic management layer supporting multiple stateless relay methods. Each method operates independently with its own local SOCKS5 proxy, allowing simultaneous deployment based on network conditions.

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Application Layer                     │
│                    (Browser, curl, etc.)                     │
└──────────────────┬──────────────────────┬───────────────────┘
                   │                      │
                   ▼                      ▼
        ┌──────────────────┐   ┌──────────────────┐
        │  SOCKS5 Proxy    │   │  SOCKS5 Proxy    │
        │   127.0.0.1      │   │   127.0.0.1      │
        │   :1080          │   │   :14000         │
        └────────┬─────────┘   └────────┬─────────┘
                 │                      │
                 ▼                      ▼
        ┌──────────────────┐   ┌──────────────────┐
        │     Paqet        │   │   GFW-Knocker    │
        │  (KCP/raw)       │   │  (malformed TCP  │
        │                  │   │  + QUIC tunnel)  │
        └────────┬─────────┘   └────────┬─────────┘
                 │                      │
                 └──────────┬───────────┘
                            │
                            ▼
                   ┌────────────────┐
                   │    Internet    │
                   └────────────────┘
```

### Stateless Design

Traditional VPN and proxy solutions maintain connection state, tracking individual flows, sessions, and packets. Stateless relay methods operate differently:

- **No flow tracking**: Each packet is processed independently
- **No session state**: No client-server handshake memory
- **Minimal server resources**: Server doesn't track clients
- **Resilient to disruption**: Connection resumes without re-negotiation

This approach reduces overhead and simplifies infrastructure at the cost of some optimization opportunities.

---

## Supported Methods

### Method Comparison

| Feature               | Paqet                  | GFW-Knocker (GFK)                |
|-----------------------|------------------------|----------------------------------|
| **Difficulty**        | Easy                   | Advanced                         |
| **Local SOCKS5 Port** | 127.0.0.1:1080         | 127.0.0.1:14000                  |
| **Transport**         | KCP over raw sockets   | Malformed TCP + QUIC tunnel      |
| **Server Components** | paqet only             | GFW-Knocker + Xray backend       |
| **Use Case**          | Standard networks      | Highly restricted networks       |
| **Setup Complexity**  | Low                    | High                             |
| **Performance**       | Good                   | Moderate (extra encapsulation)   |

### Paqet

**Transport**: KCP (reliable UDP) over raw sockets  
**Recommendation**: Default choice for most scenarios

Paqet implements a straightforward stateless relay using KCP protocol. Best suited for networks without deep packet inspection.

**Characteristics**:
- Single binary deployment
- Minimal configuration
- Standard network compatibility

### GFW-Knocker (GFK)

**Transport**: Encrypted QUIC over intentionally malformed TCP  
**Recommendation**: Networks with active traffic analysis

GFW-Knocker uses packet manipulation techniques to encapsulate QUIC traffic within malformed TCP segments. Requires backend infrastructure.

**Characteristics**:
- Two-component architecture (GFK + Xray)
- Advanced configuration
- Designed for adversarial network conditions

---

## Decision Flow

```
                    START
                      |
                      v
        Is the network highly restricted?
        (Active DPI, protocol blocking, etc.)
                      |
         ┌────────────┴────────────┐
         │                         │
        YES                       NO
         │                         │
         v                         v
  ┌─────────────────┐    ┌─────────────────┐
  │  GFW-Knocker    │    │     Paqet       │
  │   (Advanced)    │    │     (Easy)      │
  └─────────────────┘    └─────────────────┘
         │                         │
         └────────────┬────────────┘
                      │
                      v
            Both can run simultaneously
```

**Note**: Both methods can be installed and operated concurrently. They use separate ports and do not interfere with each other.

---

## Installation

All installation scripts are located in the `/install` directory.

### Install Paqet Only

```bash
sudo ./install/install-paqet.sh
```

### Install GFW-Knocker Only

```bash
sudo ./install/install-gfk.sh
```

### Install Both Methods

```bash
sudo ./install/install-all.sh
```

### Requirements

- Linux system with systemd
- Root access (for service installation)
- Internet connectivity (for downloading binaries)

---

## Configuration

Configuration files are located in `/config` with sensible defaults.

### Paqet Configuration

Edit `/config/paqet.conf`:
- **Local SOCKS5 port**: 1080
- **Server address**: Must be provided
- **KCP parameters**: Tunable for your network

### GFW-Knocker Configuration

Edit `/config/gfk.conf`:
- **Local SOCKS5 port**: 14000
- **Server address**: Must be provided
- **Backend Xray address**: Required

---

## Service Management

Services are managed via systemd.

### Paqet Service

```bash
# Start
sudo systemctl start flowless-paqet

# Enable on boot
sudo systemctl enable flowless-paqet

# Check status
sudo systemctl status flowless-paqet

# View logs
sudo journalctl -u flowless-paqet -f
```

### GFW-Knocker Service

```bash
# Start
sudo systemctl start flowless-gfk

# Enable on boot
sudo systemctl enable flowless-gfk

# Check status
sudo systemctl status flowless-gfk

# View logs
sudo journalctl -u flowless-gfk -f
```

---

## Testing Connectivity

Once services are running, test with curl:

### Test Paqet (port 1080)

```bash
curl --socks5 127.0.0.1:1080 https://example.com
```

### Test GFW-Knocker (port 14000)

```bash
curl --socks5 127.0.0.1:14000 https://example.com
```

---

## Documentation

Detailed documentation is available in the `/docs` directory:

- Architecture and design principles
- Configuration guides
- Troubleshooting
- Performance tuning

---

## License

This project provides infrastructure tooling only. Binary dependencies maintain their respective licenses.

---

## Project Scope

This repository contains:
- Installation scripts
- Configuration templates
- systemd service definitions
- Documentation

This repository does NOT contain:
- Protocol implementations
- Transport internals
- Binary executables (downloaded during installation)

External binaries are managed by their respective projects.
