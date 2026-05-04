#!/bin/bash
#
# Challenge: Container restart resilience
# Anti-bluff: Restart each container, assert HTTP 200 within 30s.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PORTS=("8086:landing" "8088:metube" "9090:dashboard")

echo "[1/2] Restarting all containers..."
podman restart metube-landing metube-direct yt-dlp-dashboard yt-dlp-cli >/dev/null 2>&1 || true
sleep 5

echo "[2/2] Checking all endpoints recover..."
ERRORS=0
for entry in "${PORTS[@]}"; do
    PORT="${entry%%:*}"
    NAME="${entry##*:}"
    OK=false
    for i in {1..15}; do
        CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/" 2>/dev/null || echo "000")
        if [ "$CODE" = "200" ]; then
            OK=true
            break
        fi
        sleep 2
    done
    if [ "$OK" = "true" ]; then
        echo "    $NAME (port $PORT): OK"
    else
        echo -e "${RED}    $NAME (port $PORT): FAIL${NC}"
        ERRORS=$((ERRORS+1))
    fi
done

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}PASS: All containers recovered after restart${NC}"
else
    echo -e "${RED}FAIL: $ERRORS container(s) did not recover${NC}"
    exit 1
fi
