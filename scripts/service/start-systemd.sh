#!/bin/bash
#
# Start all YT-DLP services using systemctl --user
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Source the .env file to get configuration
if [ -f "${PROJECT_DIR}/.env" ]; then
    set -a
    source "${PROJECT_DIR}/.env"
    set +a
else
    echo -e "${RED}ERROR: .env file not found in ${PROJECT_DIR}${NC}"
    exit 1
fi

# Determine container runtime
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME="podman"
elif command -v docker &> /dev/null; then
    CONTAINER_RUNTIME="docker"
else
    echo -e "${RED}ERROR: No container runtime found (podman or docker)${NC}"
    exit 1
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Starting Services via Systemd${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${CYAN}Container Runtime:${NC} ${CONTAINER_RUNTIME}"
echo -e "${CYAN}VPN Enabled:${NC} ${USE_VPN:-false}"
echo ""

# Define services to start based on USE_VPN setting
if [ "${USE_VPN}" = "true" ]; then
    echo -e "${CYAN}Starting VPN services...${NC}"
    SERVICES=(
        "openvpn-yt-dlp.service"
        "metube.service"
        "landing-vpn.service"
        "yt-dlp-cli.service"
        "yt-dlp-cli-vpn.service"
    )
else
    echo -e "${CYAN}Starting non-VPN services...${NC}"
    SERVICES=(
        "metube-direct.service"
        "landing-no-vpn.service"
        "dashboard.service"
        "media-postprocessor.service"
        "yt-dlp-cli.service"
    )
fi

# Add watchtower if using docker
if [ "${CONTAINER_RUNTIME}" = "docker" ]; then
    SERVICES+=("watchtower.service")
    echo -e "${CYAN}Including watchtower service (docker mode)${NC}"
fi

# Start all services
echo ""
echo -e "${BLUE}Starting services...${NC}"
FAILED=0
for service in "${SERVICES[@]}"; do
    echo -n "  Starting $service... "
    if systemctl --user start "$service"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        FAILED=$((FAILED + 1))
    fi
done

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All services started successfully!${NC}"
else
    echo ""
    echo -e "${RED}${FAILED} service(s) failed to start${NC}"
    exit 1
fi

# Show next steps
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  Check status:   ./scripts/service/status-systemd.sh"
echo "  Stop services:  ./scripts/service/stop-systemd.sh"
