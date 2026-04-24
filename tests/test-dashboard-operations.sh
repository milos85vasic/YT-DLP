#!/bin/bash
#
# Full automation test for dashboard operations (POST-FIX):
#   1. History clear (bulk + individual) via URL-based delete
#   2. Queue start/resume for pending items via URL-based start
#
# This test validates that the fixed dashboard (sending URLs instead of IDs)
# correctly clears history and starts pending downloads.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

METUBE_URL="http://localhost:8088"
DASHBOARD_URL="http://localhost:9090"
LANDING_URL="http://localhost:8086"

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
skip() { echo -e "${YELLOW}⚠ SKIP${NC} $1"; }
info() { echo -e "${BLUE}=== $1 ===${NC}"; }

TESTS_PASSED=0
TESTS_FAILED=0

check() {
    local msg="$1"
    shift
    if "$@"; then
        pass "$msg"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        fail "$msg"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# ── Pre-flight ──
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Dashboard Operations Full Automation Test${NC}"
echo -e "${CYAN}============================================${NC}"

info "Pre-flight checks"
for url in "$METUBE_URL" "$DASHBOARD_URL" "$LANDING_URL"; do
    if ! curl -s -o /dev/null --connect-timeout 2 "$url"; then
        fail "$url not reachable"
        exit 1
    fi
done
pass "All services reachable"

# ── Helpers ──

get_history() {
    curl -s "$METUBE_URL/history"
}

count_done() {
    get_history | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('done',[])))"
}

count_pending() {
    get_history | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('pending',[])))"
}

count_queue() {
    get_history | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('queue',[])))"
}

get_first_done_url() {
    get_history | python3 -c "import sys,json; items=json.load(sys.stdin).get('done',[]); print(items[0]['url'] if items else '')"
}

get_first_pending_url() {
    get_history | python3 -c "import sys,json; items=json.load(sys.stdin).get('pending',[]); print(items[0]['url'] if items else '')"
}

add_download() {
    local url="$1"
    local auto_start="${2:-true}"
    curl -s -X POST "$METUBE_URL/add" -H "Content-Type: application/json" -d "{\"url\": \"$url\", \"auto_start\": $auto_start}" > /dev/null
}

# ── Test 1: Bulk history clear via URLs ──
info "Test 1: Bulk history clear via URLs"

DONE_BEFORE=$(count_done)
if [ "$DONE_BEFORE" -eq 0 ]; then
    info "No history items found; adding a test download"
    add_download "https://www.youtube.com/watch?v=jNQXAC9IVRw" || true
    sleep 2
    DONE_BEFORE=$(count_done)
fi

if [ "$DONE_BEFORE" -eq 0 ]; then
    fail "Cannot run test: no done items available"
    exit 1
fi

echo "Done items before clear: $DONE_BEFORE"
URLS=$(get_history | python3 -c "import sys,json; urls=[i['url'] for i in json.load(sys.stdin).get('done',[])]; import json; print(json.dumps(urls))")
echo "Clearing with URLs: $URLS"
curl -s -X POST "$METUBE_URL/delete" -H "Content-Type: application/json" -d "{\"ids\": $URLS, \"where\": \"done\"}" > /dev/null
sleep 1
DONE_AFTER=$(count_done)
echo "Done items after clear: $DONE_AFTER"

check "Bulk clear removes all history items" [ "$DONE_AFTER" -eq 0 ]

# ── Test 2: Individual history cleanup via URL ──
info "Test 2: Individual history cleanup via URL"

add_download "https://www.youtube.com/watch?v=jNQXAC9IVRw" || true
sleep 2
DONE_BEFORE=$(count_done)

if [ "$DONE_BEFORE" -eq 0 ]; then
    skip "No done item available for single cleanup"
else
    URL=$(get_first_done_url)
    curl -s -X POST "$METUBE_URL/delete" -H "Content-Type: application/json" -d "{\"ids\": [\"$URL\"], \"where\": \"done\"}" > /dev/null
    sleep 1
    DONE_AFTER=$(count_done)
    check "Single URL-based delete removes item" [ "$DONE_AFTER" -eq "$((DONE_BEFORE - 1))" ]
fi

# ── Test 3: Pending item start via URLs ──
info "Test 3: Pending item start via URLs"

# Add with auto_start=false to force pending state
add_download "https://www.youtube.com/watch?v=9bZkp7q19f0" false || true
sleep 1
PENDING_AFTER_ADD=$(count_pending)

if [ "$PENDING_AFTER_ADD" -eq 0 ]; then
    skip "No pending items available to test start"
else
    echo "Pending items before start: $PENDING_AFTER_ADD"
    URLS=$(get_history | python3 -c "import sys,json; urls=[i['url'] for i in json.load(sys.stdin).get('pending',[])]; import json; print(json.dumps(urls))")
    echo "Starting with URLs: $URLS"
    curl -s -X POST "$METUBE_URL/start" -H "Content-Type: application/json" -d "{\"ids\": $URLS}" > /dev/null
    sleep 1
    PENDING_AFTER=$(count_pending)
    echo "Pending items after start: $PENDING_AFTER"
    check "URL-based start moves all pending items to queue" [ "$PENDING_AFTER" -eq 0 ]
fi

# ── Test 4: Dashboard proxy passes URL-based delete ──
info "Test 4: Dashboard proxy URL-based delete"

add_download "https://www.youtube.com/watch?v=jNQXAC9IVRw" || true
sleep 2
DONE_BEFORE=$(count_done)

if [ "$DONE_BEFORE" -eq 0 ]; then
    skip "No done item for proxy test"
else
    URL=$(get_first_done_url)
    RESP=$(curl -s -X POST "$DASHBOARD_URL/api/delete" -H "Content-Type: application/json" -d "{\"ids\": [\"$URL\"], \"where\": \"done\"}")
    sleep 1
    DONE_AFTER=$(count_done)
    check "Dashboard proxy delete works with URLs" [ "$DONE_AFTER" -eq "$((DONE_BEFORE - 1))" ]
fi

# ── Test 5: Landing page delete-download with URL ──
info "Test 5: Landing page delete-download proxy with URL"

add_download "https://www.youtube.com/watch?v=jNQXAC9IVRw" || true
sleep 2
DONE_BEFORE=$(count_done)

if [ "$DONE_BEFORE" -eq 0 ]; then
    skip "No done item for landing proxy test"
else
    URL=$(get_first_done_url)
    RESP=$(curl -s -X POST "$LANDING_URL/api/delete-download" -H "Content-Type: application/json" -d "{\"url\": \"$URL\", \"title\": \"test\", \"delete_file\": false}")
    sleep 1
    DONE_AFTER=$(count_done)
    check "Landing page delete-download works with URL" [ "$DONE_AFTER" -eq "$((DONE_BEFORE - 1))" ]
fi

# ── Summary ──
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Dashboard Operations Test Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Passed:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed:  ${RED}$TESTS_FAILED${NC}"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}SOME TESTS FAILED${NC}"
    exit 1
fi
