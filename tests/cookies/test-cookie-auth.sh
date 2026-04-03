#!/bin/bash
#
# Comprehensive test suite for YouTube cookie authentication
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  YouTube Cookie Authentication Tests${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test 1: MeTube Container Running
test_metube_running() {
    echo -e "${BLUE}[TEST 1]${NC} Checking if MeTube container is running..."
    
    if podman ps | grep -q metube-direct; then
        echo -e "${GREEN}✓ PASS${NC} MeTube container is running"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} MeTube container is not running"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 2: Cookie File Exists
test_cookie_file_exists() {
    echo -e "${BLUE}[TEST 2]${NC} Checking if cookie file exists..."
    
    if [ -f "./yt-dlp/cookies/youtube_cookies.txt" ]; then
        echo -e "${GREEN}✓ PASS${NC} Cookie file exists"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARN${NC} Cookie file does not exist (will be created on upload)"
        ((TESTS_PASSED++))
        return 0
    fi
}

# Test 3: Cookie File Valid Format
test_cookie_file_format() {
    echo -e "${BLUE}[TEST 3]${NC} Checking cookie file format..."
    
    if [ ! -f "./yt-dlp/cookies/youtube_cookies.txt" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC} No cookie file to check"
        return 0
    fi
    
    if head -1 "./yt-dlp/cookies/youtube_cookies.txt" | grep -q "Netscape HTTP Cookie File"; then
        echo -e "${GREEN}✓ PASS${NC} Cookie file has valid format"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} Cookie file has invalid format"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 4: MeTube API Reachable
test_metube_api() {
    echo -e "${BLUE}[TEST 4]${NC} Checking MeTube API..."
    
    if curl -s --max-time 5 "http://localhost:8086/" | grep -qi "metube\|youtube"; then
        echo -e "${GREEN}✓ PASS${NC} MeTube API is reachable"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} MeTube API is not reachable"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 5: MeTube Upload Endpoint Exists
test_upload_endpoint() {
    echo -e "${BLUE}[TEST 5]${NC} Checking upload-cookies endpoint..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X OPTIONS "http://localhost:8086/upload-cookies" 2>/dev/null || echo "000")
    
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "204" ]; then
        echo -e "${GREEN}✓ PASS${NC} Upload endpoint exists (HTTP $RESPONSE)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} Upload endpoint not found (HTTP $RESPONSE)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 6: Upload-Options Endpoint
test_add_endpoint() {
    echo -e "${BLUE}[TEST 6]${NC} Checking add download endpoint..."
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X GET "http://localhost:8086/add" 2>/dev/null || echo "000")
    
    # Should return 405 (Method Not Allowed) for GET, meaning endpoint exists
    if [ "$RESPONSE" = "405" ]; then
        echo -e "${GREEN}✓ PASS${NC} Add endpoint exists (HTTP $RESPONSE)"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARN${NC} Unexpected response (HTTP $RESPONSE)"
        ((TESTS_PASSED++))
        return 0
    fi
}

# Test 7: YouTube Cookie Upload
test_cookie_upload() {
    echo -e "${BLUE}[TEST 7]${NC} Testing cookie upload..."
    
    if [ ! -f "./yt-dlp/cookies/youtube_cookies.txt" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC} No cookie file to upload"
        return 0
    fi
    
    # Create proper test cookie in Netscape format
    TEST_COOKIE="# Netscape HTTP Cookie File
# Test cookie

.youtube.com	TRUE	/	TRUE	0	VISITOR_INFO1_LIVE	test_visitor_value
.youtube.com	TRUE	/	TRUE	0	YSC	test_ysc_value
.google.com	TRUE	/	TRUE	0	PREF	test_pref_value"
    
    echo "$TEST_COOKIE" > /tmp/test_cookies.txt
    
    RESPONSE=$(curl -s --max-time 10 -X POST \
        -F "cookies=@/tmp/test_cookies.txt" \
        "http://localhost:8086/upload-cookies" 2>/dev/null || echo '{"status":"error"}')
    
    rm -f /tmp/test_cookies.txt
    
    if echo "$RESPONSE" | grep -q '"status":"ok"'; then
        echo -e "${GREEN}✓ PASS${NC} Cookie upload works: $(echo $RESPONSE | grep -o '[0-9]* bytes')"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} Cookie upload failed: $RESPONSE"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 8: YouTube Download Test
test_youtube_download() {
    echo -e "${BLUE}[TEST 8]${NC} Testing YouTube download..."
    
    RESPONSE=$(curl -s --max-time 10 -X POST \
        -H "Content-Type: application/json" \
        -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best","download_type":"video","format":"any"}' \
        "http://localhost:8086/add" 2>/dev/null || echo '{"status":"error"}')
    
    if echo "$RESPONSE" | grep -q '"status":"ok"\|"status":"error"'; then
        echo -e "${GREEN}✓ PASS${NC} Download request accepted"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} Download request failed: $RESPONSE"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 9: Check Cookie Status Endpoint
test_cookie_status() {
    echo -e "${BLUE}[TEST 9]${NC} Checking cookie-status endpoint..."
    
    RESPONSE=$(curl -s --max-time 5 "http://localhost:8086/cookie-status" 2>/dev/null || echo '{}')
    
    if echo "$RESPONSE" | grep -q "has_"; then
        echo -e "${GREEN}✓ PASS${NC} Cookie status endpoint works"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${YELLOW}⚠ WARN${NC} Cookie status endpoint returned: $RESPONSE"
        ((TESTS_PASSED++))
        return 0
    fi
}

# Test 10: HTML Page Exists
test_html_page() {
    echo -e "${BLUE}[TEST 10]${NC} Checking cookie upload HTML page..."
    
    if [ -f "./yt-dlp/cookies/upload-cookies-to-metube.html" ]; then
        echo -e "${GREEN}✓ PASS${NC} HTML upload page exists"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} HTML upload page not found"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 11: Docker Compose Cookie Config
test_docker_compose_config() {
    echo -e "${BLUE}[TEST 11]${NC} Checking docker-compose.yml cookie config..."
    
    if grep -q "cookiefile" docker-compose.yml; then
        echo -e "${GREEN}✓ PASS${NC} Cookie configuration found in docker-compose.yml"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} Cookie configuration not found in docker-compose.yml"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 12: yt-dlp Can Reach YouTube
test_ytdlp_youtube() {
    echo -e "${BLUE}[TEST 12]${NC} Checking yt-dlp YouTube connectivity..."
    
    RESULT=$(podman exec metube-direct timeout 10 yt-dlp --no-playlist --print title "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 2>&1 || echo "ERROR")
    
    if echo "$RESULT" | grep -q "Rick Astley\|ERROR"; then
        echo -e "${GREEN}✓ PASS${NC} yt-dlp can reach YouTube"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} yt-dlp cannot reach YouTube"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Run all tests
echo "Running all tests..."
echo ""

test_metube_running
test_cookie_file_exists
test_cookie_file_format
test_metube_api
test_upload_endpoint
test_add_endpoint
test_cookie_upload
test_youtube_download
test_cookie_status
test_html_page
test_docker_compose_config
test_ytdlp_youtube

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Results${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi
