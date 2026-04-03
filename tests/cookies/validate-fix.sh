#!/bin/bash
#
# Complete validation script for YouTube cookie fix
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  YouTube Cookie Fix Validation Suite ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Color functions
pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; }
warn() { echo -e "${YELLOW}⚠ WARN${NC}: $1"; }
info() { echo -e "${CYAN}ℹ INFO${NC}: $1"; }

# Start validation
VALIDATION_START=$(date +%s)

# ═══════════════════════════════════════════
# PHASE 1: Infrastructure Tests
# ═══════════════════════════════════════════
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 1: Infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 1.1: Container Runtime
info "Checking container runtime..."
if command -v podman &> /dev/null; then
    pass "Podman is installed"
    CONTAINER_RUNTIME="podman"
elif command -v docker &> /dev/null; then
    pass "Docker is installed"
    CONTAINER_RUNTIME="docker"
else
    fail "No container runtime found"
    exit 1
fi

# Test 1.2: Container Status
info "Checking container status..."
if $CONTAINER_RUNTIME ps | grep -q metube-direct; then
    pass "metube-direct container is running"
else
    warn "metube-direct container is not running"
    info "Starting containers..."
    ./start_no_vpn 2>&1 | tail -5
    sleep 5
fi

# Test 1.3: Port Accessibility
info "Checking MeTube port accessibility..."
if curl -s --max-time 5 "http://localhost:8086/" > /dev/null 2>&1; then
    pass "MeTube is accessible on port 8086"
else
    fail "MeTube is not accessible on port 8086"
fi

# ═══════════════════════════════════════════
# PHASE 2: Configuration Tests
# ═══════════════════════════════════════════
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 2: Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 2.1: Docker Compose Cookie Config
info "Checking docker-compose.yml cookie configuration..."
if grep -q "cookiefile" docker-compose.yml; then
    pass "cookiefile configuration found"
else
    fail "cookiefile configuration not found in docker-compose.yml"
fi

# Test 2.2: Cookie Volume Mount
info "Checking cookie volume mount..."
if grep -q "youtube_cookies.txt" docker-compose.yml; then
    pass "Cookie file volume mount configured"
else
    warn "Cookie file mount may not be configured"
fi

# Test 2.3: Cookie Directory
info "Checking cookie directory..."
if [ -d "./yt-dlp/cookies" ]; then
    pass "Cookie directory exists"
else
    mkdir -p ./yt-dlp/cookies
    pass "Created cookie directory"
fi

# Test 2.4: HTML Upload Page
info "Checking HTML upload page..."
if [ -f "./yt-dlp/cookies/upload-cookies-to-metube.html" ]; then
    pass "HTML upload page exists"
else
    fail "HTML upload page not found"
fi

# ═══════════════════════════════════════════
# PHASE 3: API Tests
# ═══════════════════════════════════════════
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 3: API Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 3.1: Home Endpoint
info "Testing home endpoint..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/")
if [ "$RESP" = "200" ]; then
    pass "Home endpoint returns 200"
else
    fail "Home endpoint returns $RESP"
fi

# Test 3.2: Upload-Cookies Endpoint
info "Testing upload-cookies endpoint..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" -X OPTIONS "http://localhost:8086/upload-cookies")
if [ "$RESP" = "200" ] || [ "$RESP" = "204" ]; then
    pass "upload-cookies endpoint exists"
else
    fail "upload-cookies endpoint not accessible (HTTP $RESP)"
fi

# Test 3.3: Cookie Status Endpoint
info "Testing cookie-status endpoint..."
RESP=$(curl -s "http://localhost:8086/cookie-status" 2>/dev/null)
if echo "$RESP" | grep -q "has_uploaded_cookies\|has_configured_cookies"; then
    pass "cookie-status endpoint works"
    info "Cookie status: $RESP"
else
    warn "cookie-status endpoint returned: $RESP"
fi

# Test 3.4: Add Endpoint
info "Testing add endpoint..."
RESP=$(curl -s -o /dev/null -w "%{http_code}" -X GET "http://localhost:8086/add")
if [ "$RESP" = "405" ]; then
    pass "add endpoint exists (POST required)"
else
    warn "add endpoint returns HTTP $RESP"
fi

# ═══════════════════════════════════════════
# PHASE 4: Functional Tests
# ═══════════════════════════════════════════
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 4: Functional Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 4.1: Cookie Upload
info "Testing cookie upload functionality..."
# Create proper test cookie in Netscape format
cat > /tmp/test_cookies.txt << 'COOKIES'
# Netscape HTTP Cookie File
# Test cookies for validation

.youtube.com	TRUE	/	TRUE	0	VISITOR_INFO1_LIVE	test_visitor_placeholder
.youtube.com	TRUE	/	TRUE	0	YSC	test_ysc_placeholder
.youtube.com	TRUE	/	TRUE	0	PREF	f4=4000000&tz=UTC
.google.com	TRUE	/	TRUE	0	SID	test_sid_placeholder
COOKIES

RESP=$(curl -s -X POST \
    -F "cookies=@/tmp/test_cookies.txt" \
    "http://localhost:8086/upload-cookies" 2>/dev/null)

rm -f /tmp/test_cookies.txt

if echo "$RESP" | grep -q '"status":"ok"'; then
    pass "Cookie upload works: $(echo $RESP | grep -o '[0-9]* bytes')"
else
    fail "Cookie upload failed: $RESP"
fi

# Test 4.2: YouTube Download Request
info "Testing YouTube download request..."
RESP=$(curl -s --max-time 30 -X POST \
    -H "Content-Type: application/json" \
    -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best","download_type":"video","format":"any"}' \
    "http://localhost:8086/add" 2>/dev/null)

if echo "$RESP" | grep -q '"status":"ok"'; then
    pass "Download request accepted"
else
    fail "Download request failed: $RESP"
fi

# Test 4.3: Check Logs for Download Status
info "Checking download logs (waiting 20 seconds)..."
sleep 20

LOGS=$(podman logs metube-direct 2>&1 | tail -50)

if echo "$LOGS" | grep -qi "Rick Astley"; then
    pass "Video metadata extracted (Rick Astley found)"
else
    warn "Video metadata not found in recent logs"
fi

if echo "$LOGS" | grep -qi "bot\|not a bot\|sign in"; then
    fail "YouTube bot detection triggered - cookies needed"
    info "Get cookies from: https://www.youtube.com (logged in)"
elif echo "$LOGS" | grep -qi "downloading\|Starting download"; then
    pass "Download in progress"
elif echo "$LOGS" | grep -qi "completed\|finished"; then
    pass "Download completed"
elif echo "$LOGS" | grep -qi "error\|No video formats"; then
    warn "Download encountered errors"
else
    info "Check logs for download progress"
fi

# ═══════════════════════════════════════════
# PHASE 5: Integration Tests
# ═══════════════════════════════════════════
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Phase 5: Integration Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Test 5.1: yt-dlp Command
info "Testing yt-dlp CLI..."
RESULT=$(podman exec metube-direct timeout 30 yt-dlp --no-playlist --print title "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 2>&1 || echo "ERROR")
if echo "$RESULT" | grep -qi "Rick Astley"; then
    pass "yt-dlp can extract YouTube metadata"
else
    warn "yt-dlp result: $RESULT"
fi

# Test 5.2: Download Directory
info "Checking download directory..."
DOWNLOAD_DIR=$(grep "DOWNLOAD_DIR=" .env 2>/dev/null | cut -d'=' -f2 || echo "/run/media/milosvasic/DATA4TB/Downloads/MeTube")
if [ -d "$DOWNLOAD_DIR" ]; then
    pass "Download directory exists: $DOWNLOAD_DIR"
else
    warn "Download directory not found: $DOWNLOAD_DIR"
fi

# Test 5.3: Recent Downloads
info "Checking for recent downloads..."
RECENT=$(find "$DOWNLOAD_DIR" -name "*.webm" -o -name "*.mp4" 2>/dev/null | head -3)
if [ -n "$RECENT" ]; then
    pass "Recent downloads found:"
    echo "$RECENT" | sed 's/^/  /'
else
    warn "No recent downloads found"
fi

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Validation Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

VALIDATION_END=$(date +%s)
DURATION=$((VALIDATION_END - VALIDATION_START))

echo ""
echo "Validation completed in ${DURATION} seconds"
echo ""
echo "Next steps:"
echo "  1. To upload cookies, open:"
echo "     file://$(pwd)/yt-dlp/cookies/upload-cookies-to-metube.html"
echo ""
echo "  2. Or use the bookmarklet in:"
echo "     yt-dlp/cookies/upload-cookies-bookmarklet.txt"
echo ""
echo "  3. Restart after cookie upload:"
echo "     ./stop && ./start_no_vpn"
echo ""
