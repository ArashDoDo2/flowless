#!/bin/bash
set -e

# Flowless Main Installation Script
# This script installs both Paqet and GFW-Knocker relay services

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << 'EOF'
  __ _                 _                
 / _| | _____      __ | | ___  ___ ___ 
| |_| |/ _ \ \ /\ / / | |/ _ \/ __/ __|
|  _| | (_) \ V  V /  | |  __/\__ \__ \
|_| |_|\___/ \_/\_/   |_|\___||___/___/

Modular Stateless Packet Relay Toolkit
EOF
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Starting flowless installation...${NC}"
echo ""

# Parse arguments
INSTALL_PAQET=0
INSTALL_GFW=0

if [ $# -eq 0 ]; then
    # No arguments, install both
    INSTALL_PAQET=1
    INSTALL_GFW=1
else
    while [ $# -gt 0 ]; do
        case "$1" in
            --paqet)
                INSTALL_PAQET=1
                ;;
            --gfw-knocker)
                INSTALL_GFW=1
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Install flowless relay services"
                echo ""
                echo "Options:"
                echo "  --paqet         Install Paqet only"
                echo "  --gfw-knocker   Install GFW-Knocker only"
                echo "  --help, -h      Show this help message"
                echo ""
                echo "If no options are specified, both services will be installed."
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
fi

# Install Paqet
if [ $INSTALL_PAQET -eq 1 ]; then
    echo -e "${BLUE}=== Installing Paqet ===${NC}"
    if [ -f "$SCRIPT_DIR/install-paqet.sh" ]; then
        bash "$SCRIPT_DIR/install-paqet.sh"
    else
        echo -e "${RED}Error: install-paqet.sh not found${NC}"
        exit 1
    fi
    echo ""
fi

# Install GFW-Knocker
if [ $INSTALL_GFW -eq 1 ]; then
    echo -e "${BLUE}=== Installing GFW-Knocker ===${NC}"
    if [ -f "$SCRIPT_DIR/install-gfw-knocker.sh" ]; then
        bash "$SCRIPT_DIR/install-gfw-knocker.sh"
    else
        echo -e "${RED}Error: install-gfw-knocker.sh not found${NC}"
        exit 1
    fi
    echo ""
fi

# Final summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo "1. Install required binaries in /opt/flowless/bin/"

if [ $INSTALL_PAQET -eq 1 ]; then
    echo "   - paqet binary for Paqet service"
fi

if [ $INSTALL_GFW -eq 1 ]; then
    echo "   - xray binary for GFW-Knocker service"
fi

echo ""
echo "2. Configure services:"

if [ $INSTALL_PAQET -eq 1 ]; then
    echo "   - Edit /etc/flowless/paqet.conf"
fi

if [ $INSTALL_GFW -eq 1 ]; then
    echo "   - Edit /etc/flowless/gfw-knocker.conf"
    echo "   - Edit /etc/flowless/xray-config.json"
fi

echo ""
echo "3. Start services:"

if [ $INSTALL_PAQET -eq 1 ]; then
    echo "   systemctl start paqet"
    echo "   systemctl enable paqet"
fi

if [ $INSTALL_GFW -eq 1 ]; then
    echo "   systemctl start gfw-knocker"
    echo "   systemctl enable gfw-knocker"
fi

echo ""
echo "4. Check status:"

if [ $INSTALL_PAQET -eq 1 ]; then
    echo "   systemctl status paqet"
fi

if [ $INSTALL_GFW -eq 1 ]; then
    echo "   systemctl status gfw-knocker"
fi

echo ""
echo "For more information, see: $REPO_DIR/README.md"
echo ""
