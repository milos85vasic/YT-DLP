#!/bin/bash
#
# Challenge: No-VPN profile services are directly accessible
# Anti-bluff: Verify all expected ports respond with 200.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "[1/2] Checking all no-vpn endpoints..."
ERRORS=0

check_port() {
    local port="$1"
    local name="$2"
    local path="${3:-/}"
    CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$path" 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
        echo "    $name (port $port): OK"
    else
        echo -e "${RED}    $name (port $port): FAIL (HTTP $CODE)${NC}"
        ERRORS=$((ERRORS+1))
    fi
}

check_port 8086 "Landing" "/health"
check_port 8088 "MeTube Direct" "/version"
check_port 9090 "Dashboard"

echo "[2/2] Checking yt-dlp-cli DNS resolution..."
if podman exec yt-dlp-cli nslookup google.com >/dev/null 2>&1; then
    echo "    yt-dlp-cli DNS: OK"
else
    echo -e "${RED}    yt-dlp-cli DNS: FAIL${NC}"
    ERRORS=$((ERRORS+1))
fi

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}PASS: All no-vpn services accessible${NC}"
else
    echo -e "${RED}FAIL: $ERRORS service(s) inaccessible${NC}"
    exit 1
fi
