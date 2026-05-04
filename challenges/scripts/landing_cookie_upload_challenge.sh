#!/bin/bash
#
# Challenge: Cookie upload lands on disk
# Anti-bluff: POST cookies.txt, verify file exists with expected content.
#
set -e
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "[1/3] Preparing test cookies file..."
COOKIES_FILE="/tmp/test_cookies_$$.txt"
cat > "$COOKIES_FILE" << 'COOKIE'
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	FALSE	1809370960	VISITOR_INFO1_LIVE	test123
COOKIE

echo "[2/3] Uploading cookies to landing page..."
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST \
    -F "cookies=@$COOKIES_FILE" \
    http://localhost:8086/api/upload-cookies 2>/dev/null)
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
rm -f "$COOKIES_FILE"

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}FAIL: Upload returned HTTP $HTTP_CODE${NC}"
    exit 1
fi
echo "    Upload accepted (HTTP 200)"

echo "[3/3] Verifying cookies landed on disk..."
if [ -f "./metube/config/cookies.txt" ] && [ -s "./metube/config/cookies.txt" ]; then
    if grep -q "youtube.com" ./metube/config/cookies.txt; then
        echo -e "${GREEN}PASS: cookies.txt exists on disk with youtube.com domain${NC}"
    else
        echo -e "${RED}FAIL: cookies.txt exists but missing expected domain${NC}"
        exit 1
    fi
else
    echo -e "${RED}FAIL: cookies.txt not found or empty on disk${NC}"
    exit 1
fi
