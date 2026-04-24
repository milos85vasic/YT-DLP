#!/bin/bash
#
# E2E Smoke Test — The Source of Truth
# Tests REAL running services with REAL HTTP calls. No mocks.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FAILED=0
PASSED=0

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_pass()  { echo -e "${GREEN}✓ PASS${NC} $1"; ((PASSED++)) || true; }
log_fail()  { echo -e "${RED}✗ FAIL${NC} $1"; ((FAILED++)) || true; }
log_warn()  { echo -e "${YELLOW}⚠ WARN${NC} $1"; }

API_BASE="http://localhost:8088"
DASHBOARD_BASE="http://localhost:9090"
LANDING_BASE="http://localhost:8086"
METUBE_DIRECT="http://localhost:8088"
METUBE_API="http://localhost:9090/api"

# Load .env if present (CI writes CONTAINER_RUNTIME there)
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# ── Helpers ──────────────────────────────────────────────────────────
http_get() {
    local url="$1" expect="${2:-200}"
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    if [ "$code" = "$expect" ]; then
        log_pass "$url → $code"
        return 0
    else
        log_fail "$url → $code (expected $expect)"
        return 1
    fi
}

http_post_json() {
    local url="$1" payload="$2" expect="${3:-200}"
    local code body
    body=$(curl -s -w "\n%{http_code}" -X POST "$url" \
        -H "Content-Type: application/json" -d "$payload" 2>/dev/null || echo -e "\n000")
    code=$(echo "$body" | tail -1)
    if [ "$code" = "$expect" ]; then
        log_pass "POST $url → $code"
        return 0
    else
        log_fail "POST $url → $code (expected $expect)"
        return 1
    fi
}

json_has_field() {
    local url="$1" field="$2"
    local body
    body=$(curl -s "$url" 2>/dev/null || echo "{}")
    if echo "$body" | grep -q "\"$field\""; then
        log_pass "$url has field '$field'"
        return 0
    else
        log_fail "$url missing field '$field'"
        return 1
    fi
}

# ── Service Availability ─────────────────────────────────────────────
echo ""
log_info "=== Gate 1: Service Availability ==="
http_get "$API_BASE/"                    200 || true
http_get "$DASHBOARD_BASE/"              200 || true
http_get "$LANDING_BASE/"                200 || true

# ── MeTube Direct API Contract ───────────────────────────────────────
echo ""
log_info "=== Gate 2: MeTube Direct API Contract ==="
json_has_field "$METUBE_DIRECT/history"     "done"    || true
json_has_field "$METUBE_DIRECT/history"     "queue"   || true
json_has_field "$METUBE_DIRECT/history"     "pending" || true
json_has_field "$METUBE_DIRECT/version"     "version" || true

# Test that history returns arrays
HISTORY=$(curl -s "$METUBE_DIRECT/history" 2>/dev/null || echo "{}")
if echo "$HISTORY" | grep -q '"done".*\[\]'; then
    log_pass "history.done is an array"
else
    log_warn "history.done may be empty or malformed"
fi

# ── Dashboard API Proxy ──────────────────────────────────────────────
echo ""
log_info "=== Gate 3: Dashboard API Proxy ==="
http_get "$DASHBOARD_BASE/api/history"   200 || true
http_get "$DASHBOARD_BASE/api/version"   200 || true

# Test CORS headers
CORS=$(curl -s -I "$DASHBOARD_BASE/api/history" 2>/dev/null | grep -i "access-control" || true)
if [ -n "$CORS" ]; then
    log_pass "Dashboard proxy returns CORS headers"
else
    log_warn "No CORS headers on dashboard proxy"
fi

# ── Landing Page API ─────────────────────────────────────────────────
echo ""
log_info "=== Gate 4: Landing Page API ==="
json_has_field "$LANDING_BASE/api/cookie-status" "has_cookies"       || true
json_has_field "$LANDING_BASE/api/cookie-status" "metube_reachable"  || true
json_has_field "$LANDING_BASE/health"            "status"            || true
json_has_field "$LANDING_BASE/health"            "metube_reachable"  || true

# ── End-to-End User Journey ──────────────────────────────────────────
echo ""
log_info "=== Gate 5: Critical User Journey ==="

# 1. Landing page loads and has dashboard link
LANDING_HTML=$(curl -s "$LANDING_BASE/" 2>/dev/null || echo "")
if echo "$LANDING_HTML" | grep -q "Dashboard\|dashboard"; then
    log_pass "Landing page contains dashboard link"
else
    log_fail "Landing page missing dashboard link"
fi

# 2. Dashboard loads and contains Angular app
DASH_HTML=$(curl -s "$DASHBOARD_BASE/" 2>/dev/null || echo "")
if echo "$DASH_HTML" | grep -qE "app-history|ng-version|router-outlet|main\.js|chunk-"; then
    log_pass "Dashboard contains Angular app markers"
else
    log_fail "Dashboard missing Angular app markers"
fi

# 3. Add a download (the most critical path)
ADD_RESP=$(curl -s -X POST "$METUBE_DIRECT/add" \
    -H "Content-Type: application/json" \
    -d '{"url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ","quality":"best"}' 2>/dev/null || echo "{}")
if echo "$ADD_RESP" | grep -q '"status"'; then
    log_pass "Download add endpoint responds"
else
    log_fail "Download add endpoint broken: ${ADD_RESP:0:100}"
fi

# 4. Delete endpoint works (MeTube rejects empty ids with 400 — that's correct)
DEL_RESP=$(curl -s -X POST "$METUBE_DIRECT/delete" \
    -H "Content-Type: application/json" \
    -d '{"ids":["nonexistent-id"],"where":"done"}' 2>/dev/null || echo "{}")
if echo "$DEL_RESP" | grep -q '"status".*"ok"'; then
    log_pass "Delete endpoint responds correctly"
else
    log_fail "Delete endpoint broken: ${DEL_RESP:0:100}"
fi

# ── Health Checks ────────────────────────────────────────────────────
echo ""
log_info "=== Gate 6: Container Health ==="
# Detect container runtime (CI may use docker while local uses podman)
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-$(command -v podman &>/dev/null && echo podman || echo docker)}
for container in metube-direct yt-dlp-dashboard metube-landing yt-dlp-cli; do
    if $CONTAINER_RUNTIME ps --format "{{.Names}}" 2>/dev/null | grep -q "^${container}$"; then
        log_pass "Container '$container' is running"
    else
        log_fail "Container '$container' is NOT running"
    fi
done

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Smoke Test Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL SMOKE TESTS PASSED — System is healthy${NC}"
    exit 0
else
    echo -e "${RED}SMOKE TESTS FAILED — Do not deploy${NC}"
    exit 1
fi
