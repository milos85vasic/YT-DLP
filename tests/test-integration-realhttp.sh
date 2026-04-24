#!/bin/bash
#
# Real HTTP Integration Tests — No Mocks, No Fantasy Land
# These tests hit ACTUAL running services with ACTUAL HTTP calls.
# If services are not running, these tests fail. That is correct.
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
info() { echo -e "${BLUE}[TEST]${NC} $1"; }

METUBE_DIRECT="http://localhost:8088"
DASHBOARD_API="http://localhost:9090/api"
LANDING_API="http://localhost:8086/api"

# ── Helper: assert JSON field exists ─────────────────────────────────
assert_json_field() {
    local url="$1" field="$2" method="${3:-GET}" payload="${4:-}"
    local body
    if [ "$method" = "POST" ]; then
        body=$(curl -s -X POST "$url" -H "Content-Type: application/json" -d "$payload" 2>/dev/null || echo "{}")
    else
        body=$(curl -s "$url" 2>/dev/null || echo "{}")
    fi
    if echo "$body" | grep -q "\"$field\""; then
        pass "$url has field '$field'"
    else
        fail "$url missing field '$field' (body: ${body:0:120})"
    fi
}

# ── Helper: assert HTTP status ───────────────────────────────────────
assert_http_status() {
    local url="$1" expect="${2:-200}" method="${3:-GET}" payload="${4:-}"
    local code
    if [ "$method" = "POST" ]; then
        code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$url" -H "Content-Type: application/json" -d "$payload" 2>/dev/null || echo "000")
    else
        code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    fi
    if [ "$code" = "$expect" ]; then
        pass "$url → $code"
    else
        fail "$url → $code (expected $expect)"
    fi
}

echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Real HTTP Integration Tests${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── Gate 1: MeTube Direct API ────────────────────────────────────────
info "=== MeTube Direct API ==="
assert_http_status  "$METUBE_DIRECT/history"        200
assert_json_field   "$METUBE_DIRECT/history"        "done"
assert_json_field   "$METUBE_DIRECT/history"        "queue"
assert_json_field   "$METUBE_DIRECT/history"        "pending"
assert_http_status  "$METUBE_DIRECT/version"        200
assert_json_field   "$METUBE_DIRECT/version"        "version"
assert_http_status  "$METUBE_DIRECT/cookie-status"  200
assert_json_field   "$METUBE_DIRECT/cookie-status"  "has_cookies"

# ── Gate 2: Dashboard Proxy API ──────────────────────────────────────
info "=== Dashboard Proxy API ==="
assert_http_status  "$DASHBOARD_API/history"     200
assert_json_field   "$DASHBOARD_API/history"     "done"
assert_http_status  "$DASHBOARD_API/version"     200
assert_json_field   "$DASHBOARD_API/version"     "version"

# ── Gate 3: Landing Page API ─────────────────────────────────────────
info "=== Landing Page API ==="
assert_http_status  "$LANDING_API/cookie-status" 200
assert_json_field   "$LANDING_API/cookie-status" "has_cookies"
assert_json_field   "$LANDING_API/cookie-status" "metube_reachable"

# ── Gate 4: Write Operations ─────────────────────────────────────────
info "=== Write Operations ==="
# Add a download (will fail with invalid URL but should return structured response)
ADD_BODY=$(curl -s -X POST "$METUBE_DIRECT/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best"}' 2>/dev/null || echo "{}")
if echo "$ADD_BODY" | grep -q '"status"'; then
    pass "POST $METUBE_DIRECT/add responds with structured JSON"
else
    fail "POST $METUBE_DIRECT/add returned unstructured response: ${ADD_BODY:0:120}"
fi

# Delete with nonexistent id should succeed (idempotent)
assert_http_status "$METUBE_DIRECT/delete" 200 "POST" '{"ids":["nonexistent-id"],"where":"done"}'

# Delete with invalid payload should fail
assert_http_status "$METUBE_DIRECT/delete" 400 "POST" '{"ids":["test"],"where":"invalid"}'

# ── Gate 5: Cross-Service Consistency ────────────────────────────────
info "=== Cross-Service Consistency ==="
METUBE_HIST=$(curl -s "$METUBE_DIRECT/history" 2>/dev/null || echo "{}")
DASH_HIST=$(curl -s "$DASHBOARD_API/history" 2>/dev/null || echo "{}")
METUBE_DONE=$(echo "$METUBE_HIST" | grep -o '"done"' | wc -l)
DASH_DONE=$(echo "$DASH_HIST" | grep -o '"done"' | wc -l)
if [ "$METUBE_DONE" = "$DASH_DONE" ]; then
    pass "Dashboard proxy returns same structure as MeTube direct"
else
    fail "Dashboard proxy structure differs from MeTube direct (MeTube: $METUBE_DONE, Dash: $DASH_DONE)"
fi

# ── Gate 6: HTML Pages Load ──────────────────────────────────────────
info "=== HTML Pages ==="
assert_http_status "http://localhost:9090/" 200
assert_http_status "http://localhost:8086/" 200
assert_http_status "http://localhost:8088/" 200

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Integration Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL INTEGRATION TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}INTEGRATION TESTS FAILED${NC}"
    exit 1
fi
