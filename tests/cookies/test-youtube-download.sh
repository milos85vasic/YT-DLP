#!/bin/bash
#
# Test YouTube download functionality
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_VIDEO="https://www.youtube.com/watch?v=dQw4w9WgXcQ"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  YouTube Download Test${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check MeTube is running
echo -e "${BLUE}[1]${NC} Checking MeTube..."
if podman ps | grep -q metube-direct; then
    echo -e "${GREEN}✓${NC} MeTube running"
else
    echo -e "${RED}✗${NC} MeTube not running. Starting..."
    ./start_no_vpn
    sleep 5
fi

echo ""

# Test API endpoints
echo -e "${BLUE}[2]${NC} Testing API endpoints..."

# Check home
echo -n "  - Home page: "
if curl -s "http://localhost:8086/" | grep -qi "metube"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check add endpoint
echo -n "  - Add endpoint: "
RESP=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "http://localhost:8086/add")
if [ "$RESP" = "200" ] || [ "$RESP" = "204" ] || [ "$RESP" = "405" ]; then
    echo -e "${GREEN}✓${NC} (HTTP $RESP)"
else
    echo -e "${RED}✗${NC} (HTTP $RESP)"
fi

# Check upload-cookies endpoint
echo -n "  - Upload-cookies endpoint: "
RESP=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "http://localhost:8086/upload-cookies")
if [ "$RESP" = "200" ] || [ "$RESP" = "204" ]; then
    echo -e "${GREEN}✓${NC} (HTTP $RESP)"
else
    echo -e "${RED}✗${NC} (HTTP $RESP)"
fi

echo ""

# Test download
echo -e "${BLUE}[3]${NC} Testing download request..."
echo "  Video: $TEST_VIDEO"

RESPONSE=$(curl -s --max-time 30 -X POST \
    -H "Content-Type: application/json" \
    -d "{\"url\":\"$TEST_VIDEO\",\"quality\":\"best\",\"download_type\":\"video\",\"format\":\"any\"}" \
    "http://localhost:8086/add" 2>/dev/null)

echo "  Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✓${NC} Download request accepted"
else
    echo -e "${RED}✗${NC} Download request failed"
fi

echo ""

# Wait for download to start
echo -e "${BLUE}[4]${NC} Checking logs for download status..."
echo "  Waiting 15 seconds for download to start..."
sleep 15

echo "  Recent logs:"
podman logs metube-direct 2>&1 | tail -20 | sed 's/^/    /'

echo ""

# Check if download started
echo -e "${BLUE}[5]${NC} Checking download status..."

LOGS=$(podman logs metube-direct 2>&1)

if echo "$LOGS" | grep -q "Rick Astley"; then
    echo -e "${GREEN}✓${NC} Video title found in logs"
else
    echo -e "${YELLOW}⚠${NC} Video title not found"
fi

if echo "$LOGS" | grep -qi "error\|no video formats"; then
    echo -e "${RED}✗${NC} Download error detected"
    echo "  This usually means YouTube is blocking the download."
    echo "  You need to upload valid YouTube cookies."
else
    echo -e "${GREEN}✓${NC} No download errors detected"
fi

if echo "$LOGS" | grep -qi "downloading\|download\|Started"; then
    echo -e "${GREEN}✓${NC} Download appears to be in progress"
else
    echo -e "${YELLOW}⚠${NC} No download activity detected"
fi

echo ""

# Check cookie status
echo -e "${BLUE}[6]${NC} Cookie status..."
curl -s "http://localhost:8086/cookie-status" 2>/dev/null | sed 's/^/  /'

echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "To fix YouTube downloads:"
echo "  1. Open: file://$(pwd)/yt-dlp/cookies/upload-cookies-to-metube.html"
echo "  2. Click 'Login to YouTube & Upload Cookies'"
echo "  3. Login to your Google account"
echo "  4. Wait for cookies to upload"
echo "  5. Try downloading again"
echo ""
