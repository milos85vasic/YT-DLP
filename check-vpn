#!/bin/bash

# Check VPN connection status for yt-dlp

set -e

# Load .env file
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

if [ "$USE_VPN" != "true" ]; then
    echo "VPN is not enabled in configuration."
    exit 0
fi

echo "Checking yt-dlp VPN connection..."
echo ""

# Check container status
if ! docker ps | grep -q openvpn-yt-dlp; then
    echo "ERROR: yt-dlp OpenVPN container is not running!"
    exit 1
fi

# Get IP information
IP_INFO=$(docker exec openvpn-yt-dlp wget -qO- http://ipinfo.io/json 2>/dev/null)

if [ -z "$IP_INFO" ]; then
    echo "ERROR: Cannot retrieve IP information. VPN might not be connected."
    exit 1
fi

# Parse JSON manually (basic parsing)
IP=$(echo "$IP_INFO" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
COUNTRY=$(echo "$IP_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
CITY=$(echo "$IP_INFO" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
ORG=$(echo "$IP_INFO" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)

echo "yt-dlp VPN Connection Status:"
echo "  • IP Address: $IP"
echo "  • Location: $CITY, $COUNTRY"
echo "  • Provider: $ORG"
echo ""

# Check if it looks like VPN
if echo "$ORG" | grep -iE "vpn|proxy|hosting|datacenter" > /dev/null; then
    echo "✓ VPN connection appears to be active"
else
    echo "⚠ WARNING: This might not be a VPN connection!"
fi

# Compare with JDownloader VPN if it's running
if docker ps | grep -q "^openvpn$"; then
    echo ""
    echo "Checking JDownloader VPN for comparison..."
    JD_IP=$(docker exec openvpn wget -qO- http://ipinfo.io/ip 2>/dev/null || echo "Unable to get IP")
    if [ -n "$JD_IP" ] && [ "$JD_IP" != "$IP" ]; then
        echo "  • JDownloader VPN IP: $JD_IP"
        echo "  ✓ Using different VPN endpoints (good for load distribution)"
    elif [ "$JD_IP" = "$IP" ]; then
        echo "  • JDownloader VPN IP: $JD_IP"
        echo "  ⚠ Both services using same VPN endpoint"
    fi
fi
