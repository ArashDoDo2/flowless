#!/bin/bash
#
# GFW-Knocker Installation Script
# Install and configure GFW-Knocker stateless relay method
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/flowless"
SERVICE_DIR="/etc/systemd/system"
BINARY_NAME="gfw-knocker"
SERVICE_NAME="flowless-gfk"

echo "========================================"
echo "  Flowless - GFW-Knocker Installation"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "/var/log/flowless"

# Download GFW-Knocker binary (placeholder URL - replace with actual)
echo -e "${YELLOW}Downloading GFW-Knocker binary...${NC}"
# TODO: Replace with actual download URL
# Example: curl -L -o "$INSTALL_DIR/$BINARY_NAME" "https://example.com/gfw-knocker/latest"
echo -e "${YELLOW}Note: Binary download not implemented. Place 'gfw-knocker' binary in $INSTALL_DIR${NC}"

# Make binary executable
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    echo -e "${GREEN}✓ Binary installed${NC}"
else
    echo -e "${YELLOW}⚠ Binary not found. Please manually install to $INSTALL_DIR/$BINARY_NAME${NC}"
fi

# Copy configuration file
echo -e "${YELLOW}Installing configuration...${NC}"
if [ -f "../config/gfk.conf" ]; then
    cp ../config/gfk.conf "$CONFIG_DIR/"
elif [ -f "./config/gfk.conf" ]; then
    cp ./config/gfk.conf "$CONFIG_DIR/"
else
    echo -e "${YELLOW}⚠ Config template not found, creating default...${NC}"
    cat > "$CONFIG_DIR/gfk.conf" << 'EOF'
# GFW-Knocker Configuration
# Local SOCKS5 proxy settings
local_addr=127.0.0.1
local_port=14000

# GFW-Knocker server settings (REQUIRED - update with your server)
server_addr=YOUR_SERVER_IP
server_port=443

# Backend Xray settings (REQUIRED)
# GFW-Knocker forwards to an Xray backend
backend_addr=YOUR_BACKEND_IP
backend_port=8443

# Packet manipulation parameters
# Adjust based on network conditions
tcp_malform_mode=syn_ack_confusion
quic_encryption=chacha20-poly1305
connection_timeout=30

# Advanced tuning
max_connections=1024
buffer_size=4096
EOF
fi

# Set secure file permissions
chmod 600 "$CONFIG_DIR/gfk.conf"

echo -e "${GREEN}✓ Configuration installed to $CONFIG_DIR/gfk.conf${NC}"
echo -e "${YELLOW}⚠ Remember to edit $CONFIG_DIR/gfk.conf with your server details${NC}"
echo -e "${YELLOW}ℹ To safely update config, use the provided config libraries in lib/config-writer.sh${NC}"

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
if [ -f "../services/flowless-gfk.service" ]; then
    cp ../services/flowless-gfk.service "$SERVICE_DIR/"
elif [ -f "./services/flowless-gfk.service" ]; then
    cp ./services/flowless-gfk.service "$SERVICE_DIR/"
else
    echo -e "${YELLOW}⚠ Service file not found, creating default...${NC}"
    cat > "$SERVICE_DIR/$SERVICE_NAME.service" << 'EOF'
[Unit]
Description=Flowless GFW-Knocker Stateless Relay
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/gfw-knocker -c /etc/flowless/gfk.conf
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security hardening
CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_RAW CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF
fi
echo -e "${GREEN}✓ Service installed${NC}"

# Reload systemd
echo -e "${YELLOW}Reloading systemd...${NC}"
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd reloaded${NC}"

echo ""
echo -e "${GREEN}========================================"
echo "  GFW-Knocker Installation Complete"
echo "========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Edit configuration: $CONFIG_DIR/gfk.conf"
echo "2. Configure backend Xray server"
echo "3. Start service: systemctl start $SERVICE_NAME"
echo "4. Enable on boot: systemctl enable $SERVICE_NAME"
echo "5. Check status: systemctl status $SERVICE_NAME"
echo "6. Test connection: curl --socks5 127.0.0.1:14000 https://example.com"
echo ""
echo -e "${YELLOW}Note: GFW-Knocker requires CAP_NET_RAW capability for packet manipulation${NC}"
echo ""
