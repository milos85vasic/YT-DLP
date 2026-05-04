#!/bin/bash
#
# Challenge: API contract validation
# Anti-bluff: Verify required fields exist in live responses.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_json_field() {
    local url="$1"
    local field="$2"
    local name="$3"
    local resp=$(curl -s "$url" 2>/dev/null)
    if echo "$resp" | grep -q "$field"; then
        echo "    $name: OK ($field present)"
        return 0
    else
        echo -e "${RED}    $name: FAIL ($field missing)${NC}"
        return 1
    fi
}

echo "[1/3] Validating MeTube Direct API..."
ERRORS=0
check_json_field "http://localhost:8088/version" "version" "MeTube /version" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:8088/version" "yt-dlp" "MeTube /version yt-dlp" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:8088/history" "done" "MeTube /history done" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:8088/history" "queue" "MeTube /history queue" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:8088/history" "pending" "MeTube /history pending" || ERRORS=$((ERRORS+1))

echo "[2/3] Validating Dashboard Proxy API..."
check_json_field "http://localhost:9090/api/version" "version" "Dashboard /api/version" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:9090/api/history" "done" "Dashboard /api/history" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:9090/api/cookie-status" "has_cookies" "Dashboard /api/cookie-status" || ERRORS=$((ERRORS+1))

echo "[3/3] Validating Landing Page API..."
check_json_field "http://localhost:8086/api/cookie-status" "has_cookies" "Landing /api/cookie-status" || ERRORS=$((ERRORS+1))
check_json_field "http://localhost:8086/health" "status" "Landing /health" || ERRORS=$((ERRORS+1))

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}PASS: All API contracts valid${NC}"
else
    echo -e "${RED}FAIL: $ERRORS API contract violation(s)${NC}"
    exit 1
fi
