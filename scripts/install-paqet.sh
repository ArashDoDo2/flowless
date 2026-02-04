#!/bin/bash
set -e

# Paqet Installation Script
# This script installs the Paqet relay service

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

echo -e "${GREEN}Installing Paqet relay service...${NC}"

# Create system user
if ! id "flowless-paqet" &>/dev/null; then
    echo "Creating flowless-paqet user..."
    useradd -r -s /usr/sbin/nologin -d /nonexistent flowless-paqet
else
    echo "User flowless-paqet already exists"
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
chown flowless-paqet:flowless-paqet /var/log/flowless
chmod 755 /var/log/flowless

# Copy configuration file if not exists
if [ ! -f /etc/flowless/paqet.conf ]; then
    echo "Installing default configuration..."
    if [ -f "$(dirname "$0")/../config/paqet.conf" ]; then
        cp "$(dirname "$0")/../config/paqet.conf" /etc/flowless/paqet.conf
    else
        cat > /etc/flowless/paqet.conf << 'EOF'
# Paqet Configuration File
SOCKS_ADDR=127.0.0.1:1080
REMOTE_ADDR=remote.example.com:4000
KCP_MODE=fast3
UDP_BUFFER=4096
TIMEOUT=30
EOF
    fi
    chmod 644 /etc/flowless/paqet.conf
    echo -e "${YELLOW}Configuration file created at /etc/flowless/paqet.conf${NC}"
    echo -e "${YELLOW}Please edit this file with your relay endpoint details${NC}"
else
    echo "Configuration file already exists, skipping"
fi

# Check for paqet binary
if [ ! -f /opt/flowless/bin/paqet ]; then
    echo -e "${YELLOW}Warning: paqet binary not found at /opt/flowless/bin/paqet${NC}"
    echo -e "${YELLOW}Please install the paqet binary before starting the service${NC}"
    BINARY_MISSING=1
else
    echo "Binary found at /opt/flowless/bin/paqet"
    chmod +x /opt/flowless/bin/paqet
    
    # Set capabilities for raw socket access
    if command -v setcap >/dev/null 2>&1; then
        echo "Setting capabilities for raw socket access..."
        setcap cap_net_raw+ep /opt/flowless/bin/paqet || echo -e "${YELLOW}Warning: Could not set capabilities${NC}"
    fi
fi

# Install systemd service
echo "Installing systemd service..."
if [ -f "$(dirname "$0")/../systemd/paqet.service" ]; then
    cp "$(dirname "$0")/../systemd/paqet.service" /etc/systemd/system/
else
    echo -e "${RED}Error: Service file not found${NC}"
    exit 1
fi

# Reload systemd
echo "Reloading systemd daemon..."
systemctl daemon-reload

echo -e "${GREEN}Paqet installation complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Place the paqet binary at: /opt/flowless/bin/paqet"
echo "2. Edit configuration: /etc/flowless/paqet.conf"
echo "3. Start service: systemctl start paqet"
echo "4. Enable auto-start: systemctl enable paqet"
echo "5. Check status: systemctl status paqet"
echo ""

if [ -n "$BINARY_MISSING" ]; then
    echo -e "${YELLOW}Remember: The service will not start until the paqet binary is installed${NC}"
fi
