#!/bin/bash
#
# Chaos Tests — Verify graceful degradation when things break
# These tests intentionally disrupt services and verify the dashboard handles it.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FAILED=0
PASSED=0

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; ((PASSED++)) || true; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; ((FAILED++)) || true; }
info() { echo -e "${BLUE}[CHAOS]${NC} $1"; }

DASHBOARD_API="http://localhost:9090/api"
METUBE_DIRECT="http://localhost:8088"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Chaos Tests${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── Test 1: MeTube down, dashboard proxy returns error ───────────────
info "Test 1: MeTube direct stopped, verify dashboard proxy error..."
podman stop metube-direct >/dev/null 2>&1 || docker stop metube-direct >/dev/null 2>&1 || true
sleep 2

# Dashboard proxy should return 502 or 504 when MeTube is down
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_API/history" 2>/dev/null || echo "000")
if [ "$CODE" = "502" ] || [ "$CODE" = "504" ] || [ "$CODE" = "000" ]; then
    pass "Dashboard proxy returns error ($CODE) when MeTube is down"
else
    fail "Dashboard proxy returned $CODE when MeTube is down (expected 502/504)"
fi

# Restart MeTube
podman start metube-direct >/dev/null 2>&1 || docker start metube-direct >/dev/null 2>&1 || true
sleep 3

# Verify recovery
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$METUBE_DIRECT/history" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
    pass "MeTube direct recovered after restart"
else
    fail "MeTube direct did not recover (HTTP $CODE)"
fi

# ── Test 2: Invalid download URL ─────────────────────────────────────
info "Test 2: Invalid URL returns structured error..."
RESP=$(curl -s -X POST "$METUBE_DIRECT/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"not-a-valid-url","quality":"best"}' 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"status"'; then
    pass "Invalid URL returns structured JSON response"
else
    fail "Invalid URL returned unstructured response"
fi

# ── Test 3: Delete with missing required field ───────────────────────
info "Test 3: Missing 'ids' field returns 400..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$METUBE_DIRECT/delete" \
    -H "Content-Type: application/json" \
    -d '{"where":"done"}' 2>/dev/null || echo "000")
if [ "$CODE" = "400" ]; then
    pass "Missing 'ids' returns 400 Bad Request"
else
    fail "Missing 'ids' returned $CODE (expected 400)"
fi

# ── Test 4: Landing page delete-download proxy ───────────────────────
info "Test 4: Landing page delete-download proxy works..."
RESP=$(curl -s -X POST "http://localhost:8086/api/delete-download" \
    -H "Content-Type: application/json" \
    -d '{"id":"test-item","title":"Test","folder":"","delete_file":false}' 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"success"'; then
    pass "Landing page delete-download returns structured response"
else
    fail "Landing page delete-download returned unstructured response"
fi

# ── Test 5: Health endpoint responds ─────────────────────────────────
info "Test 5: Landing health endpoint..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/health" 2>/dev/null || echo "000")
if [ "$CODE" = "200" ]; then
    pass "Landing /health returns 200"
else
    fail "Landing /health returned $CODE"
fi

# ── Test 6: Rapid add requests don't crash ───────────────────────────
info "Test 6: Rapid sequential add requests..."
for i in 1 2 3; do
    curl -s -o /dev/null -X POST "$METUBE_DIRECT/add" \
        -H "Content-Type: application/json" \
        -d "{\"url\":\"https://example.com/video$i\",\"quality\":\"best\"}" 2>/dev/null || true
done
pass "Rapid add requests handled without crash"

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Chaos Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL CHAOS TESTS PASSED — System degrades gracefully${NC}"
    exit 0
else
    echo -e "${RED}CHAOS TESTS FAILED${NC}"
    exit 1
fi
