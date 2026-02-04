#!/bin/bash
#
# Flowless - Install All Methods
# Install both Paqet and GFW-Knocker relay methods
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================="
echo "  Flowless - Complete Installation"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Paqet
echo -e "${GREEN}>>> Installing Paqet...${NC}"
echo ""
if [ -f "$SCRIPT_DIR/install-paqet.sh" ]; then
    bash "$SCRIPT_DIR/install-paqet.sh"
else
    echo -e "${RED}Error: install-paqet.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}>>> Paqet installation complete${NC}"
echo ""
sleep 2

# Install GFW-Knocker
echo -e "${GREEN}>>> Installing GFW-Knocker...${NC}"
echo ""
if [ -f "$SCRIPT_DIR/install-gfk.sh" ]; then
    bash "$SCRIPT_DIR/install-gfk.sh"
else
    echo -e "${RED}Error: install-gfk.sh not found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}>>> GFW-Knocker installation complete${NC}"
echo ""

echo ""
echo -e "${GREEN}========================================"
echo "  All Methods Installed Successfully"
echo "========================================${NC}"
echo ""
echo "Installed methods:"
echo "  • Paqet (SOCKS5: 127.0.0.1:1080)"
echo "  • GFW-Knocker (SOCKS5: 127.0.0.1:14000)"
echo ""
echo "Both methods can run simultaneously on their respective ports."
echo ""
echo "Configuration files:"
echo "  • /etc/flowless/paqet.conf"
echo "  • /etc/flowless/gfk.conf"
echo ""
echo "Service management:"
echo "  • systemctl start flowless-paqet"
echo "  • systemctl start flowless-gfk"
echo ""
echo "Testing:"
echo "  • curl --socks5 127.0.0.1:1080 https://example.com    # Paqet"
echo "  • curl --socks5 127.0.0.1:14000 https://example.com   # GFW-Knocker"
echo ""
