#!/bin/bash
#
# Status of all YT-DLP services using systemctl --user
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
echo -e "${BLUE}   Service Status via Systemd${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${CYAN}Container Runtime:${NC} ${CONTAINER_RUNTIME}"
echo -e "${CYAN}VPN Enabled:${NC} ${USE_VPN:-false}"
echo ""

# Define all possible services
ALL_SERVICES=(
    "openvpn-yt-dlp.service"
    "metube.service"
    "landing-vpn.service"
    "yt-dlp-cli.service"
    "yt-dlp-cli-vpn.service"
    "metube-direct.service"
    "landing-no-vpn.service"
    "dashboard.service"
    "media-postprocessor.service"
    "watchtower.service"
)

echo -e "${BLUE}Service Status:${NC}"
echo ""

for service in "${ALL_SERVICES[@]}"; do
    # Only show status if the service unit file exists
    if systemctl --user list-unit-files | grep -q "^${service}"; then
        # Get the service status
        STATUS=$(systemctl --user show "$service" --property=SubState --value 2>/dev/null || echo "unknown")
        ENABLED=$(systemctl --user is-enabled "$service" 2>/dev/null || echo "disabled")
        
        # Format the output
        if [ "$STATUS" = "running" ]; then
            STATUS_DISPLAY="${GREEN}$STATUS${NC}"
        elif [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ]; then
            STATUS_DISPLAY="${YELLOW}$STATUS${NC}"
        else
            STATUS_DISPLAY="${RED}$STATUS${NC}"
        fi
        
        echo -e "  ${service%.*}: ${STATUS_DISPLAY} (enabled: $ENABLED)"
    fi
done

echo ""
echo -e "${BLUE}Hint:${NC} Use 'systemctl --user status <service>' for detailed information"
