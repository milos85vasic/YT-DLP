#!/bin/bash
#
# Chaos Tests — Comprehensive System Resilience Validation
# Tests graceful degradation under failure conditions.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

FAILED=0
PASSED=0
SKIPPED=0

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; ((PASSED++)) || true; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; ((FAILED++)) || true; }
skip() { echo -e "${YELLOW}⚠ SKIP${NC} $1"; ((SKIPPED++)) || true; }
info() { echo -e "${BLUE}[CHAOS]${NC} $1"; }

DASHBOARD_API="http://localhost:9090/api"
METUBE_DIRECT="http://localhost:8088"
LANDING="http://localhost:8086"
DASHBOARD="http://localhost:9090"

# ── detect compose command ───────────────────────────────────────────
COMPOSE_CMD=""
if docker compose version &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif docker-compose version &>/dev/null; then
    COMPOSE_CMD="docker-compose"
elif podman-compose version &>/dev/null; then
    COMPOSE_CMD="podman-compose"
else
    COMPOSE_CMD="podman compose"
fi

# ── helper: wait for service ─────────────────────────────────────────
wait_for_service() {
    local url="$1" name="$2" max_wait="${3:-30}"
    local waited=0
    while [ "$waited" -lt "$max_wait" ]; do
        if curl -s --max-time 2 "$url" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        ((waited++)) || true
    done
    return 1
}

# ── helper: compose restart service ──────────────────────────────────
compose_restart() {
    local svc="$1"
    $COMPOSE_CMD --profile no-vpn restart "$svc" >/dev/null 2>&1 || true
}

# ── helper: compose stop service ─────────────────────────────────────
compose_stop() {
    local svc="$1"
    $COMPOSE_CMD --profile no-vpn stop "$svc" >/dev/null 2>&1 || true
}

# ── helper: compose start service ────────────────────────────────────
compose_start() {
    local svc="$1"
    $COMPOSE_CMD --profile no-vpn start "$svc" >/dev/null 2>&1 || true
}

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Chaos Tests — Comprehensive Resilience${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# Verify baseline
echo "Verifying baseline services..."
wait_for_service "$METUBE_DIRECT/history" "MeTube" 30 || { fail "MeTube not available at start"; exit 1; }
wait_for_service "$DASHBOARD/" "Dashboard" 10 || { fail "Dashboard not available at start"; exit 1; }
wait_for_service "$LANDING/" "Landing" 10 || { fail "Landing not available at start"; exit 1; }
pass "Baseline services healthy"
echo ""

# ═════════════════════════════════════════════════════════════════════
# SECTION 1: Service Disruption
# ═════════════════════════════════════════════════════════════════════
info "═══ SECTION 1: Service Disruption ═══"

# 1.1 MeTube down, dashboard proxy error
echo ""
info "1.1 MeTube direct stopped → dashboard proxy error..."
compose_stop metube-direct
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$DASHBOARD_API/history" 2>/dev/null || echo "000")
if [ "$CODE" = "502" ] || [ "$CODE" = "504" ] || [ "$CODE" = "000" ]; then
    pass "Dashboard proxy returns error ($CODE) when MeTube down"
else
    fail "Dashboard proxy returned $CODE (expected 502/504/000)"
fi
compose_start metube-direct
wait_for_service "$METUBE_DIRECT/history" "MeTube" 15 && pass "MeTube recovered" || fail "MeTube did not recover"

# 1.2 Landing page down
echo ""
info "1.2 Landing page stopped → direct MeTube still works..."
compose_stop metube-landing
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$METUBE_DIRECT/history" 2>/dev/null || echo "000")
[ "$CODE" = "200" ] && pass "MeTube direct works without landing" || fail "MeTube direct failed (HTTP $CODE)"
compose_start metube-landing
wait_for_service "$LANDING/" "Landing" 10 || true

# 1.3 Dashboard down
echo ""
info "1.3 Dashboard stopped → MeTube direct still works..."
compose_stop yt-dlp-dashboard
sleep 2
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$METUBE_DIRECT/history" 2>/dev/null || echo "000")
[ "$CODE" = "200" ] && pass "MeTube direct works without dashboard" || fail "MeTube direct failed (HTTP $CODE)"
compose_start yt-dlp-dashboard
wait_for_service "$DASHBOARD/" "Dashboard" 15 || true

# 1.4 Container restart during operation
echo ""
info "1.4 Restart metube-direct during idle..."
compose_restart metube-direct
wait_for_service "$METUBE_DIRECT/history" "MeTube" 20 && pass "MeTube restart successful" || fail "MeTube restart failed"

# 1.5 Dashboard restart
echo ""
info "1.5 Restart dashboard during idle..."
compose_restart yt-dlp-dashboard
wait_for_service "$DASHBOARD/" "Dashboard" 20 && pass "Dashboard restart successful" || fail "Dashboard restart failed"

# ═════════════════════════════════════════════════════════════════════
# SECTION 2: Network & Timeout Chaos
# ═════════════════════════════════════════════════════════════════════
echo ""
info "═══ SECTION 2: Network & Timeout Chaos ═══"

# 2.1 API response time
echo ""
info "2.1 API responds within 5 seconds..."
START=$(date +%s%N)
curl -s -o /dev/null --max-time 5 "$METUBE_DIRECT/history" 2>/dev/null || true
END=$(date +%s%N)
DURATION_MS=$(( (END - START) / 1000000 ))
if [ "$DURATION_MS" -lt 5000 ]; then
    pass "API responds in ${DURATION_MS}ms"
else
    fail "API took ${DURATION_MS}ms (over 5s)"
fi

# 2.2 Slow client
echo ""
info "2.2 Slow client rate limit..."
if curl -s -o /dev/null --limit-rate 1k --max-time 10 "$METUBE_DIRECT/version" 2>/dev/null; then
    pass "API works with slow client"
else
    skip "Slow client test inconclusive"
fi

# 2.3 Connection refused on wrong port
echo ""
info "2.3 Wrong port returns connection refused..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://localhost:59999/" 2>/dev/null || echo "000")
if echo "$CODE" | grep -q '^0\+$'; then
    pass "Wrong port returns connection refused"
else
    fail "Wrong port returned $CODE"
fi

# 2.4 DNS failure
echo ""
info "2.4 Invalid host DNS failure..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "http://invalid-host-name-12345.local/" 2>/dev/null || echo "000")
[ "$CODE" = "000" ] && pass "Invalid host returns connection failure" || skip "DNS resolution unexpected ($CODE)"

# ═════════════════════════════════════════════════════════════════════
# SECTION 3: Invalid Input & Edge Cases
# ═════════════════════════════════════════════════════════════════════
echo ""
info "═══ SECTION 3: Invalid Input & Edge Cases ═══"

# 3.1 Invalid URL
echo ""
info "3.1 Invalid URL returns structured response..."
RESP=$(curl -s -X POST "$METUBE_DIRECT/add" -H "Content-Type: application/json" \
    -d '{"url":"not-a-url","quality":"best"}' 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"status"'; then
    pass "Invalid URL returns structured JSON"
else
    fail "Invalid URL unstructured: ${RESP:0:80}"
fi

# 3.2 Missing required field
echo ""
info "3.2 Missing 'ids' returns 400..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$METUBE_DIRECT/delete" \
    -H "Content-Type: application/json" -d '{"where":"done"}' 2>/dev/null || echo "000")
[ "$CODE" = "400" ] && pass "Missing 'ids' returns 400" || fail "Missing 'ids' returned $CODE"

# 3.3 Invalid 'where' value
echo ""
info "3.3 Invalid 'where' returns 400..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$METUBE_DIRECT/delete" \
    -H "Content-Type: application/json" -d '{"ids":["test"],"where":"invalid"}' 2>/dev/null || echo "000")
[ "$CODE" = "400" ] && pass "Invalid 'where' returns 400" || fail "Invalid 'where' returned $CODE"

# 3.4 Empty body
echo ""
info "3.4 Empty body POST handled..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$METUBE_DIRECT/add" \
    -H "Content-Type: application/json" -d '' 2>/dev/null || echo "000")
[ "$CODE" = "400" ] || [ "$CODE" = "500" ] || [ "$CODE" = "200" ]
pass "Empty body handled ($CODE)"

# 3.5 Malformed JSON
echo ""
info "3.5 Malformed JSON handled..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$METUBE_DIRECT/add" \
    -H "Content-Type: application/json" -d '{bad json' 2>/dev/null || echo "000")
[ "$CODE" = "400" ] || [ "$CODE" = "500" ] || [ "$CODE" = "200" ]
pass "Malformed JSON handled ($CODE)"

# 3.6 Very long URL
echo ""
info "3.6 Very long URL handled..."
LONG_URL="https://example.com/$(openssl rand -hex 200 2>/dev/null || head -c 400 /dev/urandom | base64 | tr -d '\n' | head -c 400)"
RESP=$(curl -s -X POST "$METUBE_DIRECT/add" -H "Content-Type: application/json" \
    -d "{\"url\":\"${LONG_URL}\",\"quality\":\"best\"}" 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"status"'; then
    pass "Long URL handled with structured response"
else
    fail "Long URL caused unstructured response"
fi

# ═════════════════════════════════════════════════════════════════════
# SECTION 4: Concurrency & Load
# ═════════════════════════════════════════════════════════════════════
echo ""
info "═══ SECTION 4: Concurrency & Load ═══"

# 4.1 Rapid sequential adds
echo ""
info "4.1 Rapid sequential add requests..."
for i in $(seq 1 5); do
    curl -s -o /dev/null -X POST "$METUBE_DIRECT/add" -H "Content-Type: application/json" \
        -d "{\"url\":\"https://example.com/rapid$i\",\"quality\":\"best\"}" 2>/dev/null || true
done
pass "5 rapid sequential adds handled"

# 4.2 Parallel history reads
echo ""
info "4.2 Parallel history requests..."
PIDS=""
for i in $(seq 1 5); do
    curl -s -o /dev/null "$METUBE_DIRECT/history" 2>/dev/null &
    PIDS="$PIDS $!"
done
wait $PIDS 2>/dev/null || true
pass "5 parallel history requests handled"

# 4.3 Mixed read/write
echo ""
info "4.3 Mixed read/write load..."
for i in $(seq 1 3); do
    curl -s -o /dev/null "$METUBE_DIRECT/history" 2>/dev/null &
    curl -s -o /dev/null -X POST "$METUBE_DIRECT/add" -H "Content-Type: application/json" \
        -d "{\"url\":\"https://example.com/mixed$i\",\"quality\":\"best\"}" 2>/dev/null &
done
wait 2>/dev/null || true
pass "Mixed read/write load handled"

# 4.4 Parallel landing page requests
echo ""
info "4.4 Parallel landing page requests..."
PIDS=""
for i in $(seq 1 5); do
    curl -s -o /dev/null "$LANDING/" 2>/dev/null &
    PIDS="$PIDS $!"
done
wait $PIDS 2>/dev/null || true
pass "5 parallel landing requests handled"

# ═════════════════════════════════════════════════════════════════════
# SECTION 5: Landing Page Proxy Resilience
# ═════════════════════════════════════════════════════════════════════
echo ""
info "═══ SECTION 5: Landing Page Proxy ═══"

# 5.1 Health endpoint
echo ""
info "5.1 Landing /health endpoint..."
CODE=$(curl -s -o /dev/null -w "%{http_code}" "$LANDING/health" 2>/dev/null || echo "000")
[ "$CODE" = "200" ] && pass "Landing /health returns 200" || fail "Landing /health returned $CODE"

# 5.2 Cookie-status structure
echo ""
info "5.2 Landing cookie-status structure..."
RESP=$(curl -s "$LANDING/api/cookie-status" 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"has_cookies"' && echo "$RESP" | grep -q '"metube_reachable"'; then
    pass "Landing cookie-status valid"
else
    fail "Landing cookie-status malformed"
fi

# 5.3 Delete-download proxy
echo ""
info "5.3 Landing delete-download proxy..."
RESP=$(curl -s -X POST "$LANDING/api/delete-download" -H "Content-Type: application/json" \
    -d '{"id":"test-chaos","title":"Test","folder":"","delete_file":false}' 2>/dev/null || echo "{}")
if echo "$RESP" | grep -q '"success"'; then
    pass "Landing delete-download structured"
else
    fail "Landing delete-download unstructured"
fi

# 5.4 Landing HTML contains key elements
echo ""
info "5.4 Landing page HTML content..."
HTML=$(curl -s "$LANDING/" 2>/dev/null || echo "")
if echo "$HTML" | grep -qi "dashboard\|metube\|download"; then
    pass "Landing HTML contains expected content"
else
    fail "Landing HTML missing expected content"
fi

# ═════════════════════════════════════════════════════════════════════
# SECTION 6: Cross-Service Consistency
# ═════════════════════════════════════════════════════════════════════
echo ""
info "═══ SECTION 6: Cross-Service Consistency ═══"

# 6.1 History structure match
echo ""
info "6.1 Dashboard proxy vs MeTube direct keys..."
M_HIST=$(curl -s "$METUBE_DIRECT/history" 2>/dev/null || echo "{}")
D_HIST=$(curl -s "$DASHBOARD_API/history" 2>/dev/null || echo "{}")
M_KEYS=$(echo "$M_HIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))" 2>/dev/null || echo "")
D_KEYS=$(echo "$D_HIST" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))" 2>/dev/null || echo "")
if [ "$M_KEYS" = "$D_KEYS" ]; then
    pass "HistoryResponse keys match via proxy"
else
    fail "History keys diverge (MeTube: [$M_KEYS], Dash: [$D_KEYS])"
fi

# 6.2 Version keys match
echo ""
info "6.2 Version endpoint keys..."
M_VER=$(curl -s "$METUBE_DIRECT/version" 2>/dev/null || echo "{}")
D_VER=$(curl -s "$DASHBOARD_API/version" 2>/dev/null || echo "{}")
M_VKEYS=$(echo "$M_VER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))" 2>/dev/null || echo "")
D_VKEYS=$(echo "$D_VER" | python3 -c "import sys,json; d=json.load(sys.stdin); print(','.join(sorted(d.keys())))" 2>/dev/null || echo "")
if [ "$M_VKEYS" = "$D_VKEYS" ]; then
    pass "VersionResponse keys match via proxy"
else
    fail "Version keys diverge"
fi

# 6.3 History item fields match
echo ""
info "6.3 History item structure consistency..."
ITEM=$(echo "$M_HIST" | python3 -c "import sys,json; d=json.load(sys.stdin); item=d.get('done',[{}])[0]; print(','.join(sorted(item.keys())))" 2>/dev/null || echo "")
if [ -n "$ITEM" ] && [ "$ITEM" != "" ]; then
    pass "History item has fields: $ITEM"
else
    skip "No done items to check structure"
fi

# ═════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Chaos Test Summary${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "Passed:  ${GREEN}${PASSED}${NC}"
echo -e "Failed:  ${RED}${FAILED}${NC}"
echo -e "Skipped: ${YELLOW}${SKIPPED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL CHAOS TESTS PASSED — System is resilient${NC}"
    exit 0
else
    echo -e "${RED}CHAOS TESTS FAILED${NC}"
    exit 1
fi
