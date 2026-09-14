#!/bin/bash
#
# Setup script for systemd user services
# Installs and configures systemd user services for YT-DLP
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
echo -e "${BLUE}   Setting up Systemd User Services${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${CYAN}Project Directory:${NC} ${PROJECT_DIR}"
echo -e "${CYAN}Container Runtime:${NC} ${CONTAINER_RUNTIME}"
echo ""

# Create systemd user directory if it doesn't exist
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
mkdir -p "${SYSTEMD_USER_DIR}"
echo -e "${GREEN}✓${NC} Systemd user directory: ${SYSTEMD_USER_DIR}"

# List of service templates to process
SERVICE_TEMPLATES=(
    "openvpn-yt-dlp"
    "metube"
    "landing-vpn"
    "yt-dlp-cli"
    "yt-dlp-cli-vpn"
    "metube-direct"
    "landing-no-vpn"
    "dashboard"
    "media-postprocessor"
    "watchtower"
)

echo ""
echo -e "${BLUE}Processing service templates...${NC}"
echo ""

for service_name in "${SERVICE_TEMPLATES[@]}"; do
    template_file="${PROJECT_DIR}/systemd-units/${service_name}.service.template"
    target_file="${SYSTEMD_USER_DIR}/${service_name}.service"
    
    if [ ! -f "${template_file}" ]; then
        echo -e "${YELLOW}WARNING: Template not found for ${service_name}${NC}"
        continue
    fi
    
    # Replace placeholders with actual values using @ as sed delimiter to avoid issues with slashes in paths
    sed -e "s@{{PROJECT_DIR}}@${PROJECT_DIR}@g" \
        -e "s@{{PUID}}@${PUID}@g" \
        -e "s@{{PGID}}@${PGID}@g" \
        -e "s@{{VPN_OVPN_PATH}}@${VPN_OVPN_PATH}@g" \
        -e "s@{{TZ}}@${TZ}@g" \
        -e "s@{{DOWNLOAD_DIR}}@${DOWNLOAD_DIR}@g" \
        "${template_file}" > "${target_file}"
    
    echo -e "${GREEN}✓${NC} Installed ${service_name}.service"
done

# Reload systemd daemon to pick up new units
echo ""
echo -e "${BLUE}Reloading systemd daemon...${NC}"
systemctl --user daemon-reload
echo -e "${GREEN}✓${NC} Systemd daemon reloaded"

# Enable services based on USE_VPN setting
echo ""
echo -e "${BLUE}Enabling services based on configuration...${NC}"

if [ "${USE_VPN}" = "true" ]; then
    echo -e "${CYAN}VPN is enabled${NC}"
    # Enable VPN profile services
    SERVICES_TO_ENABLE=(
        "openvpn-yt-dlp.service"
        "metube.service"
        "landing-vpn.service"
        "yt-dlp-cli.service"
        "yt-dlp-cli-vpn.service"
    )
else
    echo -e "${CYAN}VPN is disabled${NC}"
    # Enable no-VPN profile services
    SERVICES_TO_ENABLE=(
        "metube-direct.service"
        "landing-no-vpn.service"
        "dashboard.service"
        "media-postprocessor.service"
        "yt-dlp-cli.service"
    )
fi

# Always enable watchtower if using docker (it's docker-only)
if [ "${CONTAINER_RUNTIME}" = "docker" ]; then
    SERVICES_TO_ENABLE+=("watchtower.service")
fi

for service in "${SERVICES_TO_ENABLE[@]}"; do
    if systemctl --user list-unit-files | grep -q "^${service}"; then
        systemctl --user enable "${service}"
        echo -e "${GREEN}✓${NC} Enabled ${service}"
    else
        echo -e "${YELLOW}WARNING: Service ${service} not found${NC}"
    fi
done

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}   Systemd User Services Setup Complete${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  1. Start services:   systemctl --user start <service>"
echo "  2. Stop services:    systemctl --user stop <service>"
echo "  3. Service status:   systemctl --user status <service>"
echo "  4. List all services: systemctl --user list-units --type=service"
echo ""
echo -e "${CYAN}To start all services:${NC}"
if [ "${USE_VPN}" = "true" ]; then
    echo "  systemctl --user start openvpn-yt-dlp.service metube.service landing-vpn.service yt-dlp-cli.service yt-dlp-cli-vpn.service"
else
    echo "  systemctl --user start metube-direct.service landing-no-vpn.service dashboard.service media-postprocessor.service yt-dlp-cli.service"
fi
if [ "${CONTAINER_RUNTIME}" = "docker" ]; then
    echo "  systemctl --user start watchtower.service"
fi
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"
