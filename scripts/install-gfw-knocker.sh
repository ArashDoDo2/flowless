#!/bin/bash
set -e

# GFW-Knocker Installation Script
# This script installs the GFW-Knocker relay service

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

echo -e "${GREEN}Installing GFW-Knocker relay service...${NC}"

# Create system user
if ! id "flowless-gfw" &>/dev/null; then
    echo "Creating flowless-gfw user..."
    useradd -r -s /usr/sbin/nologin -d /nonexistent flowless-gfw
else
    echo "User flowless-gfw already exists"
fi

# Create directories
echo "Creating directories..."
mkdir -p /opt/flowless/bin
mkdir -p /etc/flowless
mkdir -p /var/log/flowless

# Set permissions
chown root:root /opt/flowless/bin
chmod 755 /opt/flowless/bin
chown root:root /etc/flowless
chmod 755 /etc/flowless
chown flowless-gfw:flowless-gfw /var/log/flowless
chmod 755 /var/log/flowless

# Copy configuration files if not exists
if [ ! -f /etc/flowless/gfw-knocker.conf ]; then
    echo "Installing default configuration..."
    if [ -f "$(dirname "$0")/../config/gfw-knocker.conf" ]; then
        cp "$(dirname "$0")/../config/gfw-knocker.conf" /etc/flowless/gfw-knocker.conf
    else
        cat > /etc/flowless/gfw-knocker.conf << 'EOF'
# GFW-Knocker Configuration File
SOCKS_ADDR=127.0.0.1:14000
XRAY_CONFIG=/etc/flowless/xray-config.json
LOG_LEVEL=warning
EOF
    fi
    chmod 644 /etc/flowless/gfw-knocker.conf
    echo -e "${YELLOW}Configuration file created at /etc/flowless/gfw-knocker.conf${NC}"
else
    echo "Configuration file already exists, skipping"
fi

# Copy Xray configuration if not exists
if [ ! -f /etc/flowless/xray-config.json ]; then
    echo "Installing default Xray configuration..."
    if [ -f "$(dirname "$0")/../config/xray-config.json" ]; then
        cp "$(dirname "$0")/../config/xray-config.json" /etc/flowless/xray-config.json
    else
        cat > /etc/flowless/xray-config.json << 'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 14000,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "remote.example.com",
            "port": 443,
            "users": [
              {
                "id": "00000000-0000-0000-0000-000000000000",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls"
      }
    }
  ]
}
EOF
    fi
    chmod 600 /etc/flowless/xray-config.json
    echo -e "${YELLOW}Xray configuration created at /etc/flowless/xray-config.json${NC}"
    echo -e "${YELLOW}Please edit this file with your relay endpoint details${NC}"
else
    echo "Xray configuration already exists, skipping"
fi

# Check for xray binary
if [ ! -f /opt/flowless/bin/xray ]; then
    echo -e "${YELLOW}Warning: xray binary not found at /opt/flowless/bin/xray${NC}"
    echo -e "${YELLOW}Please install the xray binary before starting the service${NC}"
    BINARY_MISSING=1
else
    echo "Binary found at /opt/flowless/bin/xray"
    chmod +x /opt/flowless/bin/xray
fi

# Install systemd service
echo "Installing systemd service..."
if [ -f "$(dirname "$0")/../systemd/gfw-knocker.service" ]; then
    cp "$(dirname "$0")/../systemd/gfw-knocker.service" /etc/systemd/system/
else
    echo -e "${RED}Error: Service file not found${NC}"
    exit 1
fi

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo -e "${GREEN}GFW-Knocker installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Place the xray binary at: /opt/flowless/bin/xray"
echo "2. Edit configuration: /etc/flowless/gfw-knocker.conf"
echo "3. Edit Xray config: /etc/flowless/xray-config.json"
echo "4. Start service: systemctl start gfw-knocker"
echo "5. Enable auto-start: systemctl enable gfw-knocker"
echo "6. Check status: systemctl status gfw-knocker"
echo ""

if [ -n "$BINARY_MISSING" ]; then
    echo -e "${YELLOW}Remember: The service will not start until the xray binary is installed${NC}"
fi
