#!/bin/bash
#
# OpenAPI Contract Validation
# Compares running API responses against contracts/metube-api.openapi.yaml
# Fails if the real API diverges from the spec.
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FAILED=0
PASSED=0

pass() { echo -e "${GREEN}✓${NC} $1"; ((PASSED++)) || true; }
fail() { echo -e "${RED}✗${NC} $1"; ((FAILED++)) || true; }
info() { echo -e "${BLUE}[VALIDATE]${NC} $1"; }

METUBE_API="http://localhost:8088"
DASHBOARD_API="http://localhost:9090/api"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  OpenAPI Contract Validation${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# ── Validate HistoryResponse schema ──────────────────────────────────
info "Validating /history response schema..."
HISTORY=$(curl -s "$METUBE_API/history" 2>/dev/null || echo "{}")

# Required fields per OpenAPI spec
for field in done queue pending; do
    if echo "$HISTORY" | grep -q "\"$field\""; then
        pass "HistoryResponse has required field '$field'"
    else
        fail "HistoryResponse missing required field '$field'"
    fi
done

# done must be an array
if echo "$HISTORY" | grep -q '"done".*\[\]\|"done".*\['; then
    pass "history.done is an array"
else
    fail "history.done is not an array"
fi

# ── Validate DownloadInfo schema ─────────────────────────────────────
info "Validating DownloadInfo schema..."
DONE_ITEM=$(echo "$HISTORY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('done',[{}])[0]))" 2>/dev/null || echo "{}")

if [ "$DONE_ITEM" != "{}" ] && [ "$DONE_ITEM" != "null" ]; then
    for field in id title url quality format folder status; do
        if echo "$DONE_ITEM" | grep -q "\"$field\""; then
            pass "DownloadInfo has required field '$field'"
        else
            fail "DownloadInfo missing required field '$field'"
        fi
    done
else
    info "No done items to validate DownloadInfo schema against"
fi

# ── Validate VersionResponse schema ──────────────────────────────────
info "Validating /version response schema..."
VERSION=$(curl -s "$METUBE_API/version" 2>/dev/null || echo "{}")
for field in version "yt-dlp"; do
    if echo "$VERSION" | grep -q "\"$field\""; then
        pass "VersionResponse has required field '$field'"
    else
        fail "VersionResponse missing required field '$field'"
    fi
done

# ── Validate CookieStatusResponse schema ─────────────────────────────
info "Validating /cookie-status response schema..."
COOKIE=$(curl -s "$METUBE_API/cookie-status" 2>/dev/null || echo "{}")
for field in status has_cookies; do
    if echo "$COOKIE" | grep -q "\"$field\""; then
        pass "CookieStatusResponse has required field '$field'"
    else
        fail "CookieStatusResponse missing required field '$field'"
    fi
done

# ── Validate StatusResponse schema (add/delete) ──────────────────────
info "Validating write operation responses..."
ADD_RESP=$(curl -s -X POST "$METUBE_API/add" -H "Content-Type: application/json" -d '{"url":"https://example.com/test","quality":"best"}' 2>/dev/null || echo "{}")
if echo "$ADD_RESP" | grep -q "\"status\""; then
    pass "POST /add returns StatusResponse with 'status' field"
else
    fail "POST /add missing 'status' field"
fi

DEL_RESP=$(curl -s -X POST "$METUBE_API/delete" -H "Content-Type: application/json" -d '{"ids":["test"],"where":"done"}' 2>/dev/null || echo "{}")
if echo "$DEL_RESP" | grep -q "\"status\""; then
    pass "POST /delete returns StatusResponse with 'status' field"
else
    fail "POST /delete missing 'status' field"
fi

# ── Validate cross-service consistency ───────────────────────────────
info "Validating dashboard proxy consistency..."
DASH_HISTORY=$(curl -s "$DASHBOARD_API/history" 2>/dev/null || echo "{}")
if echo "$DASH_HISTORY" | grep -q "\"done\"" && echo "$DASH_HISTORY" | grep -q "\"queue\""; then
    pass "Dashboard proxy preserves HistoryResponse schema"
else
    fail "Dashboard proxy diverges from HistoryResponse schema"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Contract Validation Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Passed: ${GREEN}${PASSED}${NC}"
echo -e "Failed: ${RED}${FAILED}${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}ALL CONTRACT CHECKS PASSED — API matches spec${NC}"
    exit 0
else
    echo -e "${RED}CONTRACT CHECKS FAILED — Update contracts/metube-api.openapi.yaml or fix API${NC}"
    exit 1
fi
