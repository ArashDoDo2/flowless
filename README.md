# flowless

A modular stateless packet relay toolkit providing secure network transport mechanisms.

## Overview

flowless is a lightweight, modular packet relay system designed for stateless network transport. It provides two distinct methods for different use cases:

1. **Paqet** - Simple, efficient KCP-based relay
2. **GFW-Knocker** - Advanced multi-protocol relay with evasion capabilities

## Features

- **Modular Architecture**: Each method operates independently with dedicated configuration
- **Stateless Design**: No session state maintained across connections
- **SOCKS5 Proxy**: Standard interface for client applications
- **Systemd Integration**: Native service management for Linux systems
- **Simple Installation**: Automated scripts for quick deployment

## Architecture

### Paqet

Paqet provides a straightforward relay mechanism using KCP over raw sockets:

- **Protocol**: KCP over raw sockets
- **SOCKS5 Port**: 127.0.0.1:1080
- **Use Case**: General-purpose, efficient packet relay
- **Binary**: Expects `paqet` binary in PATH or `/opt/flowless/bin/`

### GFW-Knocker

GFW-Knocker offers advanced relay capabilities with protocol obfuscation:

- **Protocol**: Malformed TCP + QUIC via Xray backend
- **SOCKS5 Port**: 127.0.0.1:14000
- **Use Case**: Advanced scenarios requiring protocol diversity
- **Binary**: Expects `xray` binary in PATH or `/opt/flowless/bin/`

## Installation

### Prerequisites

- Linux system with systemd
- Root or sudo access
- External binaries (`paqet` and/or `xray`) must be provided separately

### Quick Install

```bash
# Clone repository
git clone https://github.com/ArashDoDo2/flowless.git
cd flowless

# Install both methods
sudo ./scripts/install.sh

# Or install individually
sudo ./scripts/install-paqet.sh
sudo ./scripts/install-gfw-knocker.sh
```

### Manual Installation

1. Copy binaries to `/opt/flowless/bin/`:
   ```bash
   sudo mkdir -p /opt/flowless/bin
   sudo cp /path/to/paqet /opt/flowless/bin/
   sudo cp /path/to/xray /opt/flowless/bin/
   ```

2. Copy configuration files:
   ```bash
   sudo mkdir -p /etc/flowless
   sudo cp config/paqet.conf /etc/flowless/
   sudo cp config/gfw-knocker.conf /etc/flowless/
   ```

3. Install systemd services:
   ```bash
   sudo cp systemd/*.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

## Usage

### Process Management

Flowless includes a CLI tool for easy process management:

```bash
# Check status of all backends
flowless status

# Check specific backend
flowless status paqet

# Start a backend
sudo flowless start paqet
sudo flowless start gfw-knocker

# Stop a backend
sudo flowless stop paqet

# Restart a backend
sudo flowless restart paqet

# List installed backends
flowless list
```

### Monitoring and Statistics

```bash
# View resource usage
flowless stats

# Live monitoring (updates every 2s)
flowless watch

# View specific backend stats
flowless stats paqet
flowless watch paqet
```

The monitoring displays:
- Process status (running/stopped)
- PID and uptime
- CPU and memory usage
- Active SOCKS5 connections
- Port status

### Using Systemd

You can also manage services directly with systemd:

```bash
# Start services
sudo systemctl start paqet
sudo systemctl start gfw-knocker

# Enable auto-start on boot
sudo systemctl enable paqet
sudo systemctl enable gfw-knocker

# Check service status
sudo systemctl status paqet
sudo systemctl status gfw-knocker

# View logs
sudo journalctl -u paqet -f
sudo journalctl -u gfw-knocker -f

# Stop services
sudo systemctl stop paqet
sudo systemctl stop gfw-knocker
```

### Auto-Restart with Watchdog

Enable automatic restart on failures:

```bash
# Install watchdog service
sudo cp systemd/flowless-watchdog.service /etc/systemd/system/
sudo systemctl daemon-reload

# Enable and start watchdog
sudo systemctl enable flowless-watchdog
sudo systemctl start flowless-watchdog

# Check watchdog status
sudo systemctl status flowless-watchdog
```

The watchdog automatically restarts crashed backends with exponential backoff (5s, 10s, 20s, 40s, 80s) and gives up after 5 attempts within 5 minutes.

## Configuration

### Paqet Configuration

Edit `/etc/flowless/paqet.conf`:

```
# Local SOCKS5 address
SOCKS_ADDR=127.0.0.1:1080

# Remote relay endpoint
REMOTE_ADDR=remote.example.com:4000

# KCP parameters
KCP_MODE=fast3
```

### GFW-Knocker Configuration

Edit `/etc/flowless/gfw-knocker.conf`:

```
# Local SOCKS5 address
SOCKS_ADDR=127.0.0.1:14000

# Xray configuration file
XRAY_CONFIG=/etc/flowless/xray-config.json

# Log level
LOG_LEVEL=warning
```

## Network Endpoints

| Method      | Protocol          | Local Address      | Purpose              |
|-------------|-------------------|--------------------|----------------------|
| Paqet       | SOCKS5/KCP        | 127.0.0.1:1080     | General relay        |
| GFW-Knocker | SOCKS5/TCP+QUIC   | 127.0.0.1:14000    | Advanced relay       |

## Client Configuration

Configure your applications to use the SOCKS5 proxy:

- **Paqet**: `socks5://127.0.0.1:1080`
- **GFW-Knocker**: `socks5://127.0.0.1:14000`

Examples:
```bash
# Using curl with Paqet
curl --socks5 127.0.0.1:1080 https://example.com

# Using curl with GFW-Knocker
curl --socks5 127.0.0.1:14000 https://example.com
```

## Directory Structure

```
flowless/
├── README.md              # This file
├── paqet/                 # Paqet-specific files
│   └── README.md          # Paqet documentation
├── gfw-knocker/           # GFW-Knocker-specific files
│   └── README.md          # GFW-Knocker documentation
├── bin/                   # CLI tools
│   └── flowless           # Process management CLI
├── lib/                   # Core libraries
│   ├── process-manager.sh # Process lifecycle management
│   ├── resource-monitor.sh # Resource tracking
│   ├── watchdog.sh        # Auto-restart daemon
│   ├── config-loader.sh   # Configuration loading
│   ├── config-writer.sh   # Configuration writing
│   └── validators.sh      # Input validation
├── config/                # Configuration templates
│   ├── paqet.conf         # Paqet configuration
│   ├── gfw-knocker.conf   # GFW-Knocker configuration
│   ├── watchdog.conf      # Watchdog configuration
│   └── xray-config.json   # Xray configuration template
├── scripts/               # Installation and utility scripts
│   ├── install.sh         # Main installation script
│   ├── install-paqet.sh   # Paqet installer
│   ├── install-gfw-knocker.sh  # GFW-Knocker installer
│   └── flowless-watchdog  # Watchdog daemon script
├── systemd/               # Systemd service files
│   ├── paqet.service      # Paqet service
│   ├── gfw-knocker.service # GFW-Knocker service
│   └── flowless-watchdog.service # Watchdog service
├── tests/                 # Test suites
│   ├── test-config.sh     # Configuration tests
│   └── test-process-manager.sh # Process management tests
└── docs/                  # Documentation
    ├── architecture.md    # System architecture
    ├── configuration.md   # Configuration guide
    ├── operations.md      # Operations guide
    └── troubleshooting.md # Troubleshooting guide
    ├── paqet.service      # Paqet service
    └── gfw-knocker.service # GFW-Knocker service
```

## Troubleshooting

### Service fails to start

1. Check binary exists:
   ```bash
   ls -l /opt/flowless/bin/
   ```

2. Verify configuration:
   ```bash
   cat /etc/flowless/paqet.conf
   cat /etc/flowless/gfw-knocker.conf
   ```

3. Check logs:
   ```bash
   sudo journalctl -u paqet --no-pager
   sudo journalctl -u gfw-knocker --no-pager
   ```

### Port already in use

If ports 1080 or 14000 are already in use, modify the configuration files and restart services.

### Permission denied

Ensure services run with appropriate privileges. Both services are configured to run as dedicated system users.

## Security Considerations

- Services bind to localhost (127.0.0.1) only by default
- Configuration files should have restricted permissions (600)
- Binaries should be verified before installation
- Regular security updates recommended for dependencies

## License

This project provides infrastructure only. Refer to individual binary licenses for protocol implementations.

## Contributing

Contributions welcome. Please ensure:
- Scripts are POSIX-compliant where possible
- Documentation is updated for new features
- Testing performed on multiple distributions

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review logs for error messages
