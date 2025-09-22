#!/bin/bash

# Check VPN connection status

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

echo "Checking VPN connection..."
echo ""

# Check container status
if ! docker ps | grep -q openvpn; then
    
    echo "ERROR: OpenVPN container is not running!"
    exit 1
fi

# Get IP information
IP_INFO=$(docker exec openvpn wget -qO- http://ipinfo.io/json 2>/dev/null)

if [ -z "$IP_INFO" ]; then
    
    echo "ERROR: Cannot retrieve IP information. VPN might not be connected."
    exit 1
fi

# Parse JSON manually (basic parsing)
IP=$(echo "$IP_INFO" | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
COUNTRY=$(echo "$IP_INFO" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
CITY=$(echo "$IP_INFO" | grep -o '"city":"[^"]*"' | cut -d'"' -f4)
ORG=$(echo "$IP_INFO" | grep -o '"org":"[^"]*"' | cut -d'"' -f4)

echo "VPN Connection Status:"
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
