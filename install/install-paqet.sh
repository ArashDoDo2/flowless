#!/bin/bash
#
# Paqet Installation Script
# Install and configure Paqet stateless relay method
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
BINARY_NAME="paqet"
SERVICE_NAME="flowless-paqet"

echo "=================================="
echo "  Flowless - Paqet Installation"
echo "=================================="
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

# Download Paqet binary (placeholder URL - replace with actual)
echo -e "${YELLOW}Downloading Paqet binary...${NC}"
# TODO: Replace with actual download URL
# Example: curl -L -o "$INSTALL_DIR/$BINARY_NAME" "https://example.com/paqet/latest"
echo -e "${YELLOW}Note: Binary download not implemented. Place 'paqet' binary in $INSTALL_DIR${NC}"

# Make binary executable
if [ -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    chmod +x "$INSTALL_DIR/$BINARY_NAME"
    echo -e "${GREEN}✓ Binary installed${NC}"
else
    echo -e "${YELLOW}⚠ Binary not found. Please manually install to $INSTALL_DIR/$BINARY_NAME${NC}"
fi

# Copy configuration file
echo -e "${YELLOW}Installing configuration...${NC}"
if [ -f "../config/paqet.conf" ]; then
    cp ../config/paqet.conf "$CONFIG_DIR/"
elif [ -f "./config/paqet.conf" ]; then
    cp ./config/paqet.conf "$CONFIG_DIR/"
else
    echo -e "${YELLOW}⚠ Config template not found, creating default...${NC}"
    cat > "$CONFIG_DIR/paqet.conf" << 'EOF'
# Paqet Configuration
# Local SOCKS5 proxy settings
local_addr=127.0.0.1
local_port=1080

# Server settings (REQUIRED - update with your server)
server_addr=YOUR_SERVER_IP
server_port=4000

# KCP parameters
# These can be tuned for your network conditions
kcp_mode=fast2
kcp_mtu=1350
kcp_sndwnd=512
kcp_rcvwnd=512
kcp_datashard=10
kcp_parityshard=3
EOF
fi

# Set secure file permissions
chmod 600 "$CONFIG_DIR/paqet.conf"

echo -e "${GREEN}✓ Configuration installed to $CONFIG_DIR/paqet.conf${NC}"
echo -e "${YELLOW}⚠ Remember to edit $CONFIG_DIR/paqet.conf with your server details${NC}"
echo -e "${YELLOW}ℹ To safely update config, use the provided config libraries in lib/config-writer.sh${NC}"

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
if [ -f "../services/flowless-paqet.service" ]; then
    cp ../services/flowless-paqet.service "$SERVICE_DIR/"
elif [ -f "./services/flowless-paqet.service" ]; then
    cp ./services/flowless-paqet.service "$SERVICE_DIR/"
else
    echo -e "${YELLOW}⚠ Service file not found, creating default...${NC}"
    cat > "$SERVICE_DIR/$SERVICE_NAME.service" << 'EOF'
[Unit]
Description=Flowless Paqet Stateless Relay
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/paqet -c /etc/flowless/paqet.conf
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

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
echo -e "${GREEN}=================================="
echo "  Paqet Installation Complete"
echo "==================================${NC}"
echo ""
echo "Next steps:"
echo "1. Edit configuration: $CONFIG_DIR/paqet.conf"
echo "2. Start service: systemctl start $SERVICE_NAME"
echo "3. Enable on boot: systemctl enable $SERVICE_NAME"
echo "4. Check status: systemctl status $SERVICE_NAME"
echo "5. Test connection: curl --socks5 127.0.0.1:1080 https://example.com"
echo ""
