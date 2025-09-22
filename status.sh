#!/bin/bash

# Script to check status of all services

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Service Status ===${NC}"
echo ""

# Load configuration
if [ -f .env ]; then
    source .env
    echo "Configuration:"
    echo "  • VPN Enabled: ${USE_VPN}"
    echo ""
fi

# Check all containers
echo "Services:"
declare -A containers=(
    ["openvpn"]="JDownloader VPN"
    ["jdownloader2"]="JDownloader"
    ["openvpn-yt-dlp"]="yt-dlp VPN"
    ["yt-dlp"]="yt-dlp"
)

for container in "${!containers[@]}"; do
    if docker ps --format "table {{.Names}}" | grep -q "^${container}$"; then
        # Get container info
        STATUS=$(docker inspect -f '{{.State.Status}}' $container 2>/dev/null || echo "unknown")
        
        echo -e "  ${GREEN}✓${NC} ${containers[$container]}: $STATUS"
        
        # Additional info for VPN containers
        if [[ "$container" =~ ^openvpn ]]; then
            if [ "$STATUS" = "running" ]; then
                IP=$(docker exec $container wget -qO- ifconfig.me 2>/dev/null || echo "Unable to get IP")
                echo "    IP: $IP"
            fi
        fi
    else
        # Check if container exists but is stopped
        if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
            echo -e "  ${YELLOW}○${NC} ${containers[$container]}: stopped"
        else
            echo -e "  ${RED}✗${NC} ${containers[$container]}: not found"
        fi
    fi
done

# Port status
echo ""
echo "Exposed Ports:"
netstat -tuln 2>/dev/null | grep -E ':(3129|3130|5800|5900|8080|8081)' | while read line; do
    PORT=$(echo $line | grep -oE ':[0-9]+' | sed 's/://')
    case $PORT in
        3129)
            echo "  • Port $PORT: JDownloader VPN"
            ;;
        3130)
            echo "  • Port $PORT: yt-dlp VPN"
            ;;
        5800)
            echo "  • Port $PORT: JDownloader Web UI"
            ;;
        5900)
            echo "  • Port $PORT: JDownloader VNC"
            ;;
        8080|8081)
            echo "  • Port $PORT: yt-dlp (reserved)"
            ;;
    esac
done

# Disk usage
echo ""
echo "Disk Usage:"
if [ -d "${DOWNLOAD_DIR}" ]; then
    SIZE=$(du -sh "${DOWNLOAD_DIR}" 2>/dev/null | cut -f1)
    echo "  • Downloads: $SIZE (${DOWNLOAD_DIR})"
fi
