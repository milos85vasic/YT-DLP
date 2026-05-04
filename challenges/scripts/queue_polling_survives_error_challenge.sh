#!/bin/bash
#
# Challenge: Queue polling survives transient errors
# Anti-bluff: Stop metube-direct, wait, restart, assert dashboard recovers.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "[1/4] Verifying services are up..."
if ! curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/history | grep -q "200"; then
    echo -e "${RED}FAIL: Dashboard proxy not responding${NC}"
    exit 1
fi
echo "    Services OK"

echo "[2/4] Stopping metube-direct..."
podman stop metube-direct >/dev/null 2>&1 || true
sleep 3

echo "[3/4] Restarting metube-direct..."
podman start metube-direct >/dev/null 2>&1 || true
sleep 5

echo "[4/4] Verifying dashboard proxy recovers..."
RECOVERED=false
for i in {1..10}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/history 2>/dev/null || echo "000")
    if [ "$CODE" = "200" ]; then
        RECOVERED=true
        break
    fi
    sleep 2
done

if [ "$RECOVERED" = "true" ]; then
    echo -e "${GREEN}PASS: Dashboard polling recovered after metube restart${NC}"
else
    echo -e "${RED}FAIL: Dashboard did not recover within 20 seconds${NC}"
    exit 1
fi
